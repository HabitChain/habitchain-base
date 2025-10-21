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
        uint256 stakeAmount; // Original stake amount (in ETH/WETH terms)
        uint256 aTokenAmount; // Amount of aWETH at time of creation
        uint256 liquidityIndex; // Liquidity index at time of creation (for yield calculation)
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

    mapping(address => uint256) public userBalances; // Tracks aWETH balance (keeps earning yield in Aave)
    mapping(uint256 => Habit) public habits;
    mapping(address => uint256[]) public userHabits;
    uint256 public nextHabitId;
    uint256 public treasuryBalance; // Tracks aWETH balance (keeps earning yield in Aave)

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
    event GlobalSettlementCompleted(uint256 totalSettled, uint256 successfulHabits, uint256 failedHabits, uint256 timestamp);

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
     * @notice Deposit ETH into the protocol (automatically supplied to Aave)
     * @dev ETH is wrapped to WETH, supplied to Aave, and aWETH balance is credited
     */
    function deposit() external payable {
        require(msg.value > 0, "Must deposit more than 0");
        
        // Wrap ETH to WETH
        weth.deposit{ value: msg.value }();
        
        // Approve Aave Pool to spend WETH
        weth.approve(address(aavePool), msg.value);
        
        // Get aWETH balance before supply
        uint256 aTokenBefore = aWeth.balanceOf(address(this));
        
        // Supply WETH to Aave
        aavePool.supply(address(weth), msg.value, address(this), 0);
        
        // Get aWETH balance after supply
        uint256 aTokenAfter = aWeth.balanceOf(address(this));
        uint256 aTokenReceived = aTokenAfter - aTokenBefore;
        
        // Credit user's aWETH balance
        userBalances[msg.sender] += aTokenReceived;
        
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw available ETH from the protocol
     * @param amount Amount of ETH to withdraw (will burn equivalent aWETH)
     * @dev Withdraws from Aave, unwraps WETH to ETH, and sends to user
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Must withdraw more than 0");
        
        // Note: userBalances tracks aWETH, but we need to calculate how much aWETH to burn
        // For simplicity, we assume 1:1 ratio (in reality aWETH grows over time)
        // A more sophisticated implementation would calculate the exchange rate
        
        if (userBalances[msg.sender] < amount) revert InsufficientBalance();
        
        // Deduct aWETH balance
        userBalances[msg.sender] -= amount;
        
        // Withdraw from Aave (this burns aWETH and returns WETH)
        uint256 wethReceived = aavePool.withdraw(address(weth), amount, address(this));
        
        // Unwrap WETH to ETH
        weth.withdraw(wethReceived);
        
        // Send ETH to user
        (bool success,) = msg.sender.call{ value: wethReceived }("");
        require(success, "ETH transfer failed");

        emit Withdrawn(msg.sender, wethReceived);
    }

    /**
     * @notice Create a new habit with a stake
     * @param name Name of the habit
     * @param stakeAmount Amount of aWETH to stake from user's balance
     */
    function createHabit(string calldata name, uint256 stakeAmount) external returns (uint256) {
        if (bytes(name).length == 0) revert EmptyHabitName();
        if (stakeAmount < MIN_STAKE) revert InsufficientStake();
        if (userBalances[msg.sender] < stakeAmount) revert InsufficientBalance();

        // Deduct aWETH from user balance (funds stay in Aave)
        userBalances[msg.sender] -= stakeAmount;

        // Get current liquidity index for yield calculation
        uint256 currentLiquidityIndex = aavePool.getReserveNormalizedIncome(address(weth));

        // Create habit
        uint256 habitId = nextHabitId++;
        habits[habitId] = Habit({
            id: habitId,
            user: msg.sender,
            name: name,
            stakeAmount: stakeAmount,
            aTokenAmount: stakeAmount,
            liquidityIndex: currentLiquidityIndex,
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

        _settleHabit(habitId, success);
    }

    /**
     * @notice Settle all active habits (simulates end-of-day settlement)
     * @dev Iterates through all habits and settles based on check-in status
     *      Success = checked in within last 24 hours (returns funds to user)
     *      Failure = not checked in within last 24 hours (sends funds to treasury)
     *      After settlement, habits reset for the next day
     */
    function globalSettle() external {
        uint256 totalSettled = 0;
        uint256 successfulHabits = 0;
        uint256 failedHabits = 0;

        // Iterate through all habit IDs
        for (uint256 habitId = 1; habitId < nextHabitId; habitId++) {
            Habit storage habit = habits[habitId];

            // Skip if habit doesn't exist, is inactive, already settled, or has been slashed (0 stake)
            if (habit.id == 0 || !habit.isActive || habit.isSettled || habit.stakeAmount == 0) {
                continue;
            }

            // Determine success based on check-in status
            // Success: checked in within last 24 hours
            bool success = habit.lastCheckIn > 0 && (block.timestamp - habit.lastCheckIn) < ONE_DAY;

            // Process daily settlement (distributes funds but keeps habit active for next day)
            _dailySettleHabit(habitId, success);

            totalSettled++;
            if (success) {
                successfulHabits++;
            } else {
                failedHabits++;
            }
        }

        emit GlobalSettlementCompleted(totalSettled, successfulHabits, failedHabits, block.timestamp);
    }

    /**
     * @notice Internal function to settle a habit
     * @param habitId ID of the habit to settle
     * @param success Whether the habit was completed successfully
     * @dev Transfers aWETH internally without withdrawing from Aave, keeping funds earning yield
     */
    function _settleHabit(uint256 habitId, bool success) internal {
        Habit storage habit = habits[habitId];

        // Mark as settled
        habit.isActive = false;
        habit.isSettled = true;

        // Calculate current value with yield
        (uint256 currentValue, uint256 yieldEarned) = _calculateHabitValue(habitId);

        if (success) {
            // Transfer aWETH balance to user (funds stay in Aave, keep earning yield)
            userBalances[habit.user] += currentValue;
            emit HabitSettled(habitId, habit.user, true, currentValue, yieldEarned, block.timestamp);
        } else {
            // Transfer aWETH balance to treasury (funds stay in Aave, keep earning yield)
            treasuryBalance += currentValue;
            emit TreasuryFunded(habitId, currentValue);
            emit HabitSettled(habitId, habit.user, false, currentValue, yieldEarned, block.timestamp);
        }
    }

    /**
     * @notice Internal function to process daily settlement (simulates day passing)
     * @param habitId ID of the habit to settle
     * @param success Whether the habit was completed successfully
     * @dev Distributes funds based on success/failure but keeps habit active and resets for next day
     */
    function _dailySettleHabit(uint256 habitId, bool success) internal {
        Habit storage habit = habits[habitId];

        // Calculate current value with yield
        (uint256 currentValue, uint256 yieldEarned) = _calculateHabitValue(habitId);

        if (success) {
            // User succeeded - return funds and auto-restake for next day
            // Any yield earned goes to user's available balance
            if (yieldEarned > 0) {
                userBalances[habit.user] += yieldEarned;
            }
            
            // Update habit tracking values with current liquidity index for next day
            uint256 currentLiquidityIndex = aavePool.getReserveNormalizedIncome(address(weth));
            habit.liquidityIndex = currentLiquidityIndex;
            // aTokenAmount stays the same (funds stay staked in Aave)
            // stakeAmount stays the same (same stake requirement for next day)
            
            emit HabitSettled(habitId, habit.user, true, currentValue, yieldEarned, block.timestamp);
        } else {
            // User failed - transfer entire balance to treasury, habit needs to be restaked
            treasuryBalance += currentValue;
            emit TreasuryFunded(habitId, currentValue);
            emit HabitSettled(habitId, habit.user, false, currentValue, yieldEarned, block.timestamp);
            
            // Habit becomes unfunded but stays active
            habit.aTokenAmount = 0;
            habit.stakeAmount = 0;
            habit.liquidityIndex = 0;
            // User needs to create a new habit or manually restake
        }

        // Reset check-in tracking for next day
        habit.lastCheckIn = 0;
        habit.checkInCount = 0;
        // Habit stays active (isActive remains true)
        // Habit is not marked as permanently settled (isSettled remains false)
    }

    /**
     * @notice Calculate the current value of a habit including accrued yield
     * @param habitId ID of the habit
     * @return currentValue The current total value (stake + yield)
     * @return yieldEarned The yield earned since creation
     * @dev Uses Aave's liquidity index to calculate yield growth
     */
    function _calculateHabitValue(uint256 habitId) internal view returns (uint256 currentValue, uint256 yieldEarned) {
        Habit storage habit = habits[habitId];
        
        // Safety check: if habit has been slashed (liquidityIndex = 0), return 0
        if (habit.liquidityIndex == 0 || habit.aTokenAmount == 0) {
            return (0, 0);
        }
        
        // Get current liquidity index
        uint256 currentLiquidityIndex = aavePool.getReserveNormalizedIncome(address(weth));
        
        // Calculate current value based on liquidity index growth
        // Formula: currentValue = (aTokenAmount * currentLiquidityIndex) / initialLiquidityIndex
        // Note: Aave's liquidity index is in ray (27 decimals), so we need to handle precision
        currentValue = (habit.aTokenAmount * currentLiquidityIndex) / habit.liquidityIndex;
        
        // Calculate yield earned
        yieldEarned = currentValue > habit.stakeAmount ? currentValue - habit.stakeAmount : 0;
        
        return (currentValue, yieldEarned);
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
     * @notice Get current value for a habit (including yield)
     * @param habitId ID of the habit
     * @return currentValue Current total value (stake + yield)
     * @return yieldEarned Yield earned since creation
     */
    function getHabitCurrentValue(uint256 habitId) external view returns (uint256 currentValue, uint256 yieldEarned) {
        Habit memory habit = habits[habitId];
        if (habit.id == 0 || habit.isSettled) return (0, 0);
        
        return _calculateHabitValue(habitId);
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
     * @return count Number of active habits (excludes slashed habits with 0 stake)
     */
    function getUserActiveHabitsCount(address user) external view returns (uint256 count) {
        uint256[] memory habitIds = userHabits[user];
        for (uint256 i = 0; i < habitIds.length; i++) {
            Habit memory habit = habits[habitIds[i]];
            // Only count habits that are active AND have stake (not slashed)
            if (habit.isActive && habit.stakeAmount > 0) {
                count++;
            }
        }
    }

    /**
     * @notice Withdraw funds from treasury (only treasury address)
     * @param amount Amount of ETH to withdraw (will burn equivalent aWETH)
     * @dev Withdraws from Aave, unwraps WETH to ETH, and sends to treasury
     */
    function withdrawTreasury(uint256 amount) external {
        require(msg.sender == treasury, "Only treasury can withdraw");
        require(amount > 0, "Must withdraw more than 0");
        require(treasuryBalance >= amount, "Insufficient treasury balance");

        // Deduct aWETH balance
        treasuryBalance -= amount;
        
        // Withdraw from Aave (this burns aWETH and returns WETH)
        uint256 wethReceived = aavePool.withdraw(address(weth), amount, address(this));
        
        // Unwrap WETH to ETH
        weth.withdraw(wethReceived);
        
        // Send ETH to treasury
        (bool success,) = treasury.call{ value: wethReceived }("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable { }
}

