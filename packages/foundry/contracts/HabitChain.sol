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
        uint256 lastSettled; // Last time this habit was settled (timestamp for compatibility)
        uint256 lastCheckInCycle; // Which cycle user last checked in
        uint256 lastSettledCycle; // Last cycle that was settled for this habit
        bool isActive;
        bool isSettled;
    }

    // State Variables
    IPool public immutable aavePool;
    IWETH public immutable weth;
    IAToken public immutable aWeth;
    address public immutable treasury;
    uint256 public immutable cycleStartTime; // Global cycle start time (set at deployment)

    mapping(address => uint256) public userBalances; // Tracks aWETH balance (keeps earning yield in Aave)
    mapping(uint256 => Habit) public habits;
    mapping(address => uint256[]) public userHabits;
    uint256 public nextHabitId;
    uint256 public treasuryBalance; // Tracks aWETH balance (keeps earning yield in Aave)

    // Constants
    uint256 public constant MIN_STAKE = 0.001 ether;
    uint256 public checkInPeriod = 1 days; // Configurable check-in period (default 24 hours)

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
    event HabitRefunded(uint256 indexed habitId, address indexed user, uint256 stakeAmount, uint256 timestamp);
    event TreasuryFunded(uint256 indexed habitId, uint256 amount);
    event NaturalSettlementCompleted(uint256 totalSettled, uint256 successfulHabits, uint256 failedHabits, uint256 timestamp);
    event CheckInPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    // Errors
    error InsufficientBalance();
    error InsufficientStake();
    error HabitNotFound();
    error HabitNotActive();
    error HabitAlreadySettled();
    error NotHabitOwner();
    error AlreadyCheckedInToday();
    error EmptyHabitName();
    error HabitNotSlashed();
    error NoHabitsEligibleForSettlement();
    error CheckInPeriodExpired();
    error MustSettlePreviousCycle();

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
        cycleStartTime = block.timestamp;
    }

    /**
     * @notice Get the current cycle number
     * @return Current cycle number based on time elapsed since deployment
     */
    function getCurrentCycle() public view returns (uint256) {
        return (block.timestamp - cycleStartTime) / checkInPeriod;
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
        uint256 currentCycle = getCurrentCycle();
        
        // Initialize lastSettledCycle:
        // - If created in Cycle 0: use sentinel value (max uint256) meaning "no prior cycles exist"
        // - If created in Cycle N (N>0): use N-1 meaning "all cycles before N are implicitly settled"
        uint256 initialLastSettledCycle;
        if (currentCycle == 0) {
            initialLastSettledCycle = type(uint256).max; // Sentinel: no cycles settled yet, but that's OK for Cycle 0
        } else {
            initialLastSettledCycle = currentCycle - 1; // Ready for current cycle
        }
        
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
            lastSettled: 0,
            lastCheckInCycle: 0, // Never checked in yet
            lastSettledCycle: initialLastSettledCycle,
            isActive: true,
            isSettled: false
        });

        userHabits[msg.sender].push(habitId);

        emit HabitCreated(habitId, msg.sender, name, stakeAmount, block.timestamp);

        return habitId;
    }

    /**
     * @notice Perform a check-in for a habit
     * @param habitId ID of the habit to check in
     * @dev Requires that all previous cycles have been settled before allowing check-in
     */
    function checkIn(uint256 habitId) external {
        Habit storage habit = habits[habitId];

        if (habit.id == 0) revert HabitNotFound();
        if (!habit.isActive) revert HabitNotActive();
        if (habit.user != msg.sender) revert NotHabitOwner();
        if (habit.stakeAmount == 0) revert HabitNotSlashed(); // Can't check in on slashed habit

        uint256 currentCycle = getCurrentCycle();
        uint256 creationCycle = (habit.createdAt - cycleStartTime) / checkInPeriod;

        // CRITICAL: Must settle previous cycle before checking in
        // We only need to check settlement if we're past the creation cycle
        // If we're in Cycle N and habit was created in Cycle C, we need cycles C through N-1 to be settled
        if (currentCycle > creationCycle) {
            // Special case: habits created in Cycle 0 have lastSettledCycle = type(uint256).max (sentinel)
            // They MUST be settled before checking in during any future cycle
            if (habit.lastSettledCycle == type(uint256).max) {
                revert MustSettlePreviousCycle();
            }
            // Normal case: check if we've settled all cycles up to current - 1
            if (habit.lastSettledCycle < currentCycle - 1) {
                revert MustSettlePreviousCycle();
            }
        }

        // Check if already checked in this cycle
        // We need to handle the case where lastCheckInCycle is 0 (could mean Cycle 0 or never checked in)
        if (habit.checkInCount > 0 && habit.lastCheckInCycle == currentCycle) {
            revert AlreadyCheckedInToday();
        }

        habit.lastCheckIn = block.timestamp;
        habit.lastCheckInCycle = currentCycle;
        habit.checkInCount++;

        emit CheckInCompleted(habitId, msg.sender, block.timestamp, habit.checkInCount);
    }

    /**
     * @notice Refund a slashed habit by restaking
     * @param habitId ID of the habit to refund
     * @param stakeAmount Amount of aWETH to restake from user's balance
     */
    function refundHabit(uint256 habitId, uint256 stakeAmount) external {
        Habit storage habit = habits[habitId];

        if (habit.id == 0) revert HabitNotFound();
        if (!habit.isActive) revert HabitNotActive();
        if (habit.user != msg.sender) revert NotHabitOwner();
        if (habit.stakeAmount > 0) revert HabitNotSlashed();
        if (stakeAmount < MIN_STAKE) revert InsufficientStake();
        if (userBalances[msg.sender] < stakeAmount) revert InsufficientBalance();

        // Deduct aWETH from user balance (funds stay in Aave)
        userBalances[msg.sender] -= stakeAmount;

        // Get current liquidity index for yield calculation
        uint256 currentLiquidityIndex = aavePool.getReserveNormalizedIncome(address(weth));

        // Update habit with new stake
        habit.stakeAmount = stakeAmount;
        habit.aTokenAmount = stakeAmount;
        habit.liquidityIndex = currentLiquidityIndex;
        habit.lastCheckIn = 0; // Reset check-in timestamp (for display)
        habit.lastCheckInCycle = 0; // Reset cycle (needs to check in this cycle)
        habit.lastSettled = block.timestamp; // Reset settlement timer
        
        // Update lastSettledCycle to allow check-in in current cycle
        uint256 currentCycle = getCurrentCycle();
        if (currentCycle == 0) {
            habit.lastSettledCycle = type(uint256).max; // Sentinel for Cycle 0
        } else {
            habit.lastSettledCycle = currentCycle - 1; // Ready for current cycle
        }
        
        // Habit remains active (isActive stays true)

        emit HabitRefunded(habitId, msg.sender, stakeAmount, block.timestamp);
    }

    /**
     * @notice Set the check-in period for habits (can be called by anyone for testing)
     * @param _period New check-in period in seconds
     */
    function setCheckInPeriod(uint256 _period) external {
        require(_period > 0, "Period must be greater than 0");
        uint256 oldPeriod = checkInPeriod;
        checkInPeriod = _period;
        emit CheckInPeriodUpdated(oldPeriod, _period);
    }

    /**
     * @notice Natural settlement - settles habits that have passed their deadline
     * @dev Can be called by anyone at any time
     *      Settles all habits that have unsettled cycles (where lastSettledCycle < currentCycle - 1)
     *      Uses global cycle-based logic for consistent settlement timing
     */
    function naturalSettle() external {
        uint256 totalSettled = 0;
        uint256 successfulHabits = 0;
        uint256 failedHabits = 0;
        uint256 currentCycle = getCurrentCycle();

        // Must be in cycle 1 or later to settle (can't settle during cycle 0)
        if (currentCycle == 0) {
            return;
        }

        // Iterate through all habit IDs
        for (uint256 habitId = 1; habitId < nextHabitId; habitId++) {
            Habit storage habit = habits[habitId];

            // Skip if habit doesn't exist, is inactive, permanently settled, or has been slashed (0 stake)
            if (habit.id == 0 || !habit.isActive || habit.isSettled || habit.stakeAmount == 0) {
                continue;
            }

            uint256 creationCycle = (habit.createdAt - cycleStartTime) / checkInPeriod;

            // Skip if habit was created in current cycle (not eligible yet)
            if (creationCycle >= currentCycle) {
                continue;
            }

            // Check if this habit has unsettled cycles
            // We can settle any cycle from (lastSettledCycle + 1) up to (currentCycle - 1)
            // Special handling for type(uint256).max (habits created in Cycle 0 before first settlement)
            bool needsSettlement;
            uint256 cycleToSettle;
            
            if (habit.lastSettledCycle == type(uint256).max) {
                // Never settled before - need to settle from creation cycle onwards
                needsSettlement = true;
                cycleToSettle = creationCycle;
            } else if (habit.lastSettledCycle >= currentCycle - 1) {
                // Already settled all past cycles
                needsSettlement = false;
                cycleToSettle = 0; // Unused
            } else {
                // Need to settle the next cycle
                needsSettlement = true;
                cycleToSettle = habit.lastSettledCycle + 1;
            }
            
            if (!needsSettlement) {
                continue;
            }
            
            // Determine success: did they check in during the cycle being settled?
            // Must check both cycle match AND that they actually checked in (checkInCount > 0)
            // This handles the case where lastCheckInCycle = 0 could mean "never checked in" OR "checked in Cycle 0"
            bool success = (habit.checkInCount > 0) && (habit.lastCheckInCycle == cycleToSettle);

            // Process daily settlement (distributes funds but keeps habit active for next cycle)
            _dailySettleHabit(habitId, success);
            
            // Update the last settled cycle
            habit.lastSettledCycle = cycleToSettle;

            totalSettled++;
            if (success) {
                successfulHabits++;
            } else {
                failedHabits++;
            }
        }

        // Only emit event if any habits were settled
        if (totalSettled > 0) {
            emit NaturalSettlementCompleted(totalSettled, successfulHabits, failedHabits, block.timestamp);
        }
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

        // Update settlement timestamp to prevent double-settlement
        habit.lastSettled = block.timestamp;

        // Don't reset check-in tracking - preserve historical data
        // habit.lastCheckIn stays as is (shows last time user checked in)
        // habit.checkInCount stays as is (cumulative count across all settlements)
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
     * @notice Get current cycle information
     * @return currentCycle Current cycle number
     * @return cycleStart Timestamp when current cycle started
     * @return cycleEnd Timestamp when current cycle ends
     */
    function getCycleInfo() external view returns (uint256 currentCycle, uint256 cycleStart, uint256 cycleEnd) {
        currentCycle = getCurrentCycle();
        cycleStart = cycleStartTime + (currentCycle * checkInPeriod);
        cycleEnd = cycleStart + checkInPeriod;
        return (currentCycle, cycleStart, cycleEnd);
    }

    /**
     * @notice Get habit cycle status
     * @param habitId ID of the habit
     * @return lastCheckInCycle The cycle when habit was last checked in
     * @return checkedInThisCycle Whether habit has been checked in during current cycle
     */
    function getHabitCycleStatus(uint256 habitId) external view returns (uint256 lastCheckInCycle, bool checkedInThisCycle) {
        Habit memory habit = habits[habitId];
        if (habit.id == 0) return (0, false);
        
        uint256 currentCycle = getCurrentCycle();
        lastCheckInCycle = habit.lastCheckInCycle;
        // Only checked in this cycle if lastCheckInCycle > 0 (not never-checked-in) AND matches current cycle
        checkedInThisCycle = habit.lastCheckInCycle > 0 && habit.lastCheckInCycle >= currentCycle;
        
        return (lastCheckInCycle, checkedInThisCycle);
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

