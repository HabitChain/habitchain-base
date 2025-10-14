// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IAToken.sol";

/**
 * @title HabitChain
 * @notice A DeFi-powered habit tracking protocol where users stake ETH on their habits
 * @dev Integrates with Aave V3 to generate yield on staked funds
 */
contract HabitChain {
    // Structs
    struct Habit {
        uint256 id;
        address user;
        string name;
        uint256 stakeAmount;
        uint256 aTokenAmount; // Amount of aWETH representing stake + yield
        uint256 createdAt;
        uint256 lastCheckIn;
        uint256 checkInCount;
        bool isActive;
        bool isSettled;
    }

    // State Variables
    IPool public immutable aavePool;
    IWETH public immutable weth;
    IAToken public immutable aWeth;
    address public immutable treasury;

    mapping(address => uint256) public userBalances;
    mapping(uint256 => Habit) public habits;
    mapping(address => uint256[]) public userHabits;
    uint256 public nextHabitId;
    uint256 public treasuryBalance;

    // Constants
    uint256 public constant MIN_STAKE = 0.001 ether;
    uint256 public constant ONE_DAY = 1 days;

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event HabitCreated(
        uint256 indexed habitId,
        address indexed user,
        string name,
        uint256 stakeAmount,
        uint256 timestamp
    );
    event CheckInCompleted(uint256 indexed habitId, address indexed user, uint256 timestamp, uint256 checkInCount);
    event HabitSettled(
        uint256 indexed habitId,
        address indexed user,
        bool success,
        uint256 totalAmount,
        uint256 yieldEarned,
        uint256 timestamp
    );
    event TreasuryFunded(uint256 indexed habitId, uint256 amount);

    // Errors
    error InsufficientBalance();
    error InsufficientStake();
    error HabitNotFound();
    error HabitNotActive();
    error HabitAlreadySettled();
    error NotHabitOwner();
    error AlreadyCheckedInToday();
    error EmptyHabitName();

    /**
     * @notice Constructor to initialize HabitChain with Aave integration
     * @param _aavePool Address of Aave V3 Pool contract
     * @param _weth Address of WETH contract
     * @param _aWeth Address of aWETH token contract
     * @param _treasury Address where slashed funds are sent
     */
    constructor(address _aavePool, address _weth, address _aWeth, address _treasury) {
        require(_aavePool != address(0), "Invalid Aave Pool address");
        require(_weth != address(0), "Invalid WETH address");
        require(_aWeth != address(0), "Invalid aWETH address");
        require(_treasury != address(0), "Invalid treasury address");

        aavePool = IPool(_aavePool);
        weth = IWETH(_weth);
        aWeth = IAToken(_aWeth);
        treasury = _treasury;
        nextHabitId = 1;
    }

    /**
     * @notice Deposit ETH into the protocol
     */
    function deposit() external payable {
        require(msg.value > 0, "Must deposit more than 0");
        userBalances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw available ETH from the protocol
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external {
        if (userBalances[msg.sender] < amount) revert InsufficientBalance();

        userBalances[msg.sender] -= amount;
        (bool success,) = msg.sender.call{ value: amount }("");
        require(success, "ETH transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Create a new habit with a stake
     * @param name Name of the habit
     * @param stakeAmount Amount of ETH to stake
     */
    function createHabit(string calldata name, uint256 stakeAmount) external returns (uint256) {
        if (bytes(name).length == 0) revert EmptyHabitName();
        if (stakeAmount < MIN_STAKE) revert InsufficientStake();
        if (userBalances[msg.sender] < stakeAmount) revert InsufficientBalance();

        // Deduct from user balance
        userBalances[msg.sender] -= stakeAmount;

        // Wrap ETH to WETH
        weth.deposit{ value: stakeAmount }();

        // Approve Aave Pool to spend WETH
        weth.approve(address(aavePool), stakeAmount);

        // Get aWETH balance before supply
        uint256 aTokenBefore = aWeth.balanceOf(address(this));

        // Supply WETH to Aave
        aavePool.supply(address(weth), stakeAmount, address(this), 0);

        // Get aWETH balance after supply
        uint256 aTokenAfter = aWeth.balanceOf(address(this));
        uint256 aTokenReceived = aTokenAfter - aTokenBefore;

        // Create habit
        uint256 habitId = nextHabitId++;
        habits[habitId] = Habit({
            id: habitId,
            user: msg.sender,
            name: name,
            stakeAmount: stakeAmount,
            aTokenAmount: aTokenReceived,
            createdAt: block.timestamp,
            lastCheckIn: 0,
            checkInCount: 0,
            isActive: true,
            isSettled: false
        });

        userHabits[msg.sender].push(habitId);

        emit HabitCreated(habitId, msg.sender, name, stakeAmount, block.timestamp);

        return habitId;
    }

    /**
     * @notice Perform a daily check-in for a habit
     * @param habitId ID of the habit to check in
     */
    function checkIn(uint256 habitId) external {
        Habit storage habit = habits[habitId];

        if (habit.id == 0) revert HabitNotFound();
        if (!habit.isActive) revert HabitNotActive();
        if (habit.user != msg.sender) revert NotHabitOwner();

        // Check if already checked in today
        if (habit.lastCheckIn > 0 && block.timestamp - habit.lastCheckIn < ONE_DAY) {
            revert AlreadyCheckedInToday();
        }

        habit.lastCheckIn = block.timestamp;
        habit.checkInCount++;

        emit CheckInCompleted(habitId, msg.sender, block.timestamp, habit.checkInCount);
    }

    /**
     * @notice Force settle a habit (testing only - determines success/failure)
     * @param habitId ID of the habit to settle
     * @param success Whether the habit was completed successfully
     */
    function forceSettle(uint256 habitId, bool success) external {
        Habit storage habit = habits[habitId];

        if (habit.id == 0) revert HabitNotFound();
        if (!habit.isActive) revert HabitNotActive();
        if (habit.isSettled) revert HabitAlreadySettled();
        if (habit.user != msg.sender) revert NotHabitOwner();

        // Mark as settled
        habit.isActive = false;
        habit.isSettled = true;

        // Get the current aToken balance for this habit (includes accrued interest)
        uint256 currentATokenBalance = aWeth.balanceOf(address(this));
        uint256 habitATokenShare = habit.aTokenAmount;
        
        // For simplicity, if this is the only active position, withdraw it all
        // Otherwise, calculate proportional withdrawal
        // Note: In production, a more sophisticated accounting system would be needed
        uint256 wethReceived;
        if (currentATokenBalance >= habitATokenShare) {
            // Withdraw based on original aToken amount received
            // Aave's withdraw takes the asset amount, and will burn corresponding aTokens
            wethReceived = aavePool.withdraw(address(weth), habit.stakeAmount, address(this));
        } else {
            // Edge case: withdraw whatever we have
            wethReceived = aavePool.withdraw(address(weth), habit.stakeAmount, address(this));
        }

        // Unwrap WETH to ETH
        weth.withdraw(wethReceived);

        // Calculate yield (total received minus original stake)
        uint256 yieldEarned = wethReceived > habit.stakeAmount ? wethReceived - habit.stakeAmount : 0;

        if (success) {
            // User gets back stake + yield
            userBalances[msg.sender] += wethReceived;
            emit HabitSettled(habitId, msg.sender, true, wethReceived, yieldEarned, block.timestamp);
        } else {
            // Stake + yield goes to treasury
            treasuryBalance += wethReceived;
            emit TreasuryFunded(habitId, wethReceived);
            emit HabitSettled(habitId, msg.sender, false, wethReceived, yieldEarned, block.timestamp);
        }
    }

    /**
     * @notice Get user's available balance
     * @param user Address of the user
     * @return balance User's available balance
     */
    function getUserBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }

    /**
     * @notice Get habit details
     * @param habitId ID of the habit
     * @return habit Habit struct
     */
    function getHabit(uint256 habitId) external view returns (Habit memory) {
        return habits[habitId];
    }

    /**
     * @notice Get all habit IDs for a user
     * @param user Address of the user
     * @return habitIds Array of habit IDs
     */
    function getUserHabits(address user) external view returns (uint256[] memory) {
        return userHabits[user];
    }

    /**
     * @notice Get current aWETH balance for a habit (including yield)
     * @param habitId ID of the habit
     * @return Current aWETH balance
     */
    function getHabitCurrentValue(uint256 habitId) external view returns (uint256) {
        Habit memory habit = habits[habitId];
        if (habit.id == 0 || habit.isSettled) return 0;
        // In real scenario, aToken balance grows over time
        // For this view function, we return the stored aTokenAmount
        // The actual balance will be higher due to yield
        return habit.aTokenAmount;
    }

    /**
     * @notice Get treasury balance
     * @return Treasury balance
     */
    function getTreasuryBalance() external view returns (uint256) {
        return treasuryBalance;
    }

    /**
     * @notice Get total active habits for a user
     * @param user Address of the user
     * @return count Number of active habits
     */
    function getUserActiveHabitsCount(address user) external view returns (uint256 count) {
        uint256[] memory habitIds = userHabits[user];
        for (uint256 i = 0; i < habitIds.length; i++) {
            if (habits[habitIds[i]].isActive) {
                count++;
            }
        }
    }

    /**
     * @notice Withdraw funds from treasury (only treasury address)
     * @param amount Amount to withdraw
     */
    function withdrawTreasury(uint256 amount) external {
        require(msg.sender == treasury, "Only treasury can withdraw");
        require(treasuryBalance >= amount, "Insufficient treasury balance");

        treasuryBalance -= amount;
        (bool success,) = treasury.call{ value: amount }("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable { }
}

