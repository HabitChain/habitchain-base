// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/HabitChain.sol";
import "../contracts/interfaces/IPool.sol";
import "../contracts/interfaces/IWETH.sol";
import "../contracts/interfaces/IAToken.sol";

/**
 * @title HabitChainYieldTest
 * @notice Comprehensive tests for yield calculation and tracking
 * @dev Forks Base mainnet to test real Aave yield accrual
 */
contract HabitChainYieldTest is Test {
    HabitChain public habitChain;

    // Aave V3 addresses on Base Mainnet
    address constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AWETH = 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7;

    address public treasury;
    address public user1;
    address public user2;
    address public user3;

    uint256 public baseFork;

    // Constants for time simulation
    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_WEEK = 7 days;
    uint256 constant ONE_MONTH = 30 days;

    function setUp() public {
        // Fork Base mainnet for real Aave integration
        string memory rpcUrl = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
        baseFork = vm.createFork(rpcUrl);
        vm.selectFork(baseFork);

        // Set up test accounts
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Fund test accounts with substantial amounts for testing
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);

        // Deploy HabitChain
        habitChain = new HabitChain(AAVE_POOL, WETH, AWETH, treasury);

        console.log("=== Test Setup ===");
        console.log("HabitChain deployed at:", address(habitChain));
        console.log("Fork block number:", block.number);
        console.log("Fork timestamp:", block.timestamp);
    }

    /**
     * @notice Test basic yield accrual over time
     * @dev Creates a habit, waits, and checks if yield has accrued
     */
    function testYieldAccrualOverTime() public {
        vm.startPrank(user1);

        // Deposit and create habit
        uint256 depositAmount = 10 ether;
        habitChain.deposit{value: depositAmount}();

        uint256 stakeAmount = 1 ether;
        uint256 habitId = habitChain.createHabit("Daily Exercise", stakeAmount);

        // Get initial value
        (uint256 initialValue, uint256 initialYield) = habitChain.getHabitCurrentValue(habitId);
        console.log("\n=== Initial State ===");
        console.log("Initial value:", initialValue);
        console.log("Initial yield:", initialYield);
        assertEq(initialYield, 0, "Initial yield should be 0");

        // Advance time by 30 days
        vm.warp(block.timestamp + ONE_MONTH);
        vm.roll(block.number + 216000); // ~30 days of blocks (12s per block)

        // Get value after time passed
        (uint256 valueAfter, uint256 yieldAfter) = habitChain.getHabitCurrentValue(habitId);
        console.log("\n=== After 30 Days ===");
        console.log("Value after:", valueAfter);
        console.log("Yield after:", yieldAfter);
        console.log("Yield percentage:", (yieldAfter * 10000) / stakeAmount, "basis points");

        // Verify yield has accrued
        assertGt(valueAfter, initialValue, "Value should increase over time");
        assertGt(yieldAfter, 0, "Yield should be positive after 30 days");

        vm.stopPrank();
    }

    /**
     * @notice Test yield calculation with multiple habits
     * @dev Tests that yield is calculated independently for each habit
     */
    function testMultipleHabitsYieldTracking() public {
        vm.startPrank(user1);

        // Deposit
        uint256 depositAmount = 10 ether;
        habitChain.deposit{value: depositAmount}();

        // Create first habit
        uint256 habit1Id = habitChain.createHabit("Morning Run", 1 ether);

        // Advance 15 days
        vm.warp(block.timestamp + (ONE_DAY * 15));
        vm.roll(block.number + 108000);

        // Create second habit (starts with current liquidity index)
        uint256 habit2Id = habitChain.createHabit("Evening Meditation", 1 ether);

        // Advance another 15 days
        vm.warp(block.timestamp + (ONE_DAY * 15));
        vm.roll(block.number + 108000);

        // Check yields
        (uint256 habit1Value, uint256 habit1Yield) = habitChain.getHabitCurrentValue(habit1Id);
        (uint256 habit2Value, uint256 habit2Yield) = habitChain.getHabitCurrentValue(habit2Id);

        console.log("\n=== Multiple Habits Yield ===");
        console.log("Habit 1 (30 days):");
        console.log("  Value:", habit1Value);
        console.log("  Yield:", habit1Yield);
        console.log("Habit 2 (15 days):");
        console.log("  Value:", habit2Value);
        console.log("  Yield:", habit2Yield);

        // Habit 1 should have more yield (30 days vs 15 days)
        assertGt(habit1Yield, habit2Yield, "Habit 1 should have more yield (30 days)");

        vm.stopPrank();
    }

    /**
     * @notice Test settlement with yield distribution
     * @dev Tests that yield is correctly distributed on successful settlement
     */
    function testSuccessfulSettlementWithYield() public {
        vm.startPrank(user1);

        // Deposit and create habit
        uint256 depositAmount = 10 ether;
        habitChain.deposit{value: depositAmount}();
        uint256 initialBalance = habitChain.getUserBalance(user1);

        uint256 stakeAmount = 1 ether;
        uint256 habitId = habitChain.createHabit("Daily Reading", stakeAmount);

        // Check-in to ensure success
        habitChain.checkIn(habitId);

        // Advance time
        vm.warp(block.timestamp + ONE_MONTH);
        vm.roll(block.number + 216000);

        // Get expected values before settlement
        (uint256 expectedValue, uint256 expectedYield) = habitChain.getHabitCurrentValue(habitId);

        console.log("\n=== Settlement with Yield ===");
        console.log("Expected value:", expectedValue);
        console.log("Expected yield:", expectedYield);

        // Force settle (success)
        habitChain.forceSettle(habitId, true);

        // Check user received stake + yield
        uint256 finalBalance = habitChain.getUserBalance(user1);
        uint256 balanceIncrease = finalBalance - initialBalance + stakeAmount; // +stakeAmount because it was deducted

        console.log("Balance increase:", balanceIncrease);
        console.log("Initial balance:", initialBalance);
        console.log("Final balance:", finalBalance);

        // User should receive approximately stake + yield
        assertApproxEqRel(balanceIncrease, expectedValue, 0.001e18, "User should receive stake + yield");
        assertGt(balanceIncrease, stakeAmount, "User should receive more than original stake");

        vm.stopPrank();
    }

    /**
     * @notice Test failed settlement with yield going to treasury
     * @dev Tests that yield goes to treasury on failed settlement
     */
    function testUnsuccessfulSettlementWithYield() public {
        vm.startPrank(user1);

        // Deposit and create habit
        uint256 depositAmount = 10 ether;
        habitChain.deposit{value: depositAmount}();

        uint256 stakeAmount = 1 ether;
        uint256 habitId = habitChain.createHabit("Morning Workout", stakeAmount);

        // Don't check in (will fail)

        // Advance time
        vm.warp(block.timestamp + ONE_MONTH);
        vm.roll(block.number + 216000);

        // Get expected values
        (uint256 expectedValue, uint256 expectedYield) = habitChain.getHabitCurrentValue(habitId);

        console.log("\n=== Failed Settlement ===");
        console.log("Expected value to treasury:", expectedValue);
        console.log("Expected yield to treasury:", expectedYield);

        uint256 treasuryBefore = habitChain.getTreasuryBalance();

        // Force settle (fail)
        habitChain.forceSettle(habitId, false);

        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        uint256 treasuryIncrease = treasuryAfter - treasuryBefore;

        console.log("Treasury increase:", treasuryIncrease);

        // Treasury should receive stake + yield
        assertApproxEqRel(treasuryIncrease, expectedValue, 0.001e18, "Treasury should receive stake + yield");
        assertGt(treasuryIncrease, stakeAmount, "Treasury should receive more than original stake");

        vm.stopPrank();
    }

    /**
     * @notice Test global settlement with yield calculations
     * @dev Tests that globalSettle correctly calculates yield for all habits
     */
    function testGlobalSettleWithYield() public {
        // Setup multiple users with habits
        setupMultipleUsersWithHabits();

        // Advance time (29 days)
        vm.warp(block.timestamp + (ONE_DAY * 29));
        vm.roll(block.number + 208800);

        // Check in habits that should succeed (within 24h before settlement)
        vm.prank(user1);
        habitChain.checkIn(1); // User1 Habit A

        vm.prank(user3);
        habitChain.checkIn(4); // User3 Habit

        // Advance just a bit more (few hours, still within 24h window)
        vm.warp(block.timestamp + 2 hours);
        vm.roll(block.number + 600);

        console.log("\n=== Global Settle with Yield ===");

        // Get pre-settlement state
        uint256 user1BalanceBefore = habitChain.getUserBalance(user1);
        uint256 user2BalanceBefore = habitChain.getUserBalance(user2);
        uint256 user3BalanceBefore = habitChain.getUserBalance(user3);
        uint256 treasuryBefore = habitChain.getTreasuryBalance();

        // Perform global settlement
        habitChain.globalSettle();

        // Check post-settlement state
        uint256 user1BalanceAfter = habitChain.getUserBalance(user1);
        uint256 user2BalanceAfter = habitChain.getUserBalance(user2);
        uint256 user3BalanceAfter = habitChain.getUserBalance(user3);
        uint256 treasuryAfter = habitChain.getTreasuryBalance();

        console.log("User1 balance change:", user1BalanceAfter - user1BalanceBefore);
        console.log("User2 balance change:", user2BalanceAfter - user2BalanceBefore);
        console.log("User3 balance change:", user3BalanceAfter - user3BalanceBefore);
        console.log("Treasury change:", treasuryAfter - treasuryBefore);

        // All balances should have changed (received settlements)
        assertGt(user1BalanceAfter, user1BalanceBefore, "User1 should receive settlement");
        assertGt(user3BalanceAfter, user3BalanceBefore, "User3 should receive settlement");
        assertGt(treasuryAfter, treasuryBefore, "Treasury should receive failed settlements");
    }

    /**
     * @notice Test yield accrual with different time periods
     * @dev Tests yield calculation accuracy across various time periods
     */
    function testYieldAccrualVariousTimePeriods() public {
        vm.startPrank(user1);

        uint256 depositAmount = 10 ether;
        habitChain.deposit{value: depositAmount}();

        uint256 stakeAmount = 1 ether;
        uint256 habitId = habitChain.createHabit("Test Habit", stakeAmount);

        console.log("\n=== Yield Over Time Periods ===");

        // Test 1 day
        vm.warp(block.timestamp + ONE_DAY);
        vm.roll(block.number + 7200);
        (uint256 value1d, uint256 yield1d) = habitChain.getHabitCurrentValue(habitId);
        console.log("After 1 day - Value:", value1d, "Yield:", yield1d);

        // Test 7 days
        vm.warp(block.timestamp + (6 * ONE_DAY));
        vm.roll(block.number + 43200);
        (uint256 value7d, uint256 yield7d) = habitChain.getHabitCurrentValue(habitId);
        console.log("After 7 days - Value:", value7d, "Yield:", yield7d);

        // Test 30 days
        vm.warp(block.timestamp + (23 * ONE_DAY));
        vm.roll(block.number + 165600);
        (uint256 value30d, uint256 yield30d) = habitChain.getHabitCurrentValue(habitId);
        console.log("After 30 days - Value:", value30d, "Yield:", yield30d);

        // Verify yield increases over time
        assertGt(yield7d, yield1d, "Yield should increase from day 1 to day 7");
        assertGt(yield30d, yield7d, "Yield should increase from day 7 to day 30");

        vm.stopPrank();
    }

    /**
     * @notice Test that yield continues to accrue even after check-in
     * @dev Ensures check-in doesn't affect yield calculation
     */
    function testYieldAccrualAfterCheckIn() public {
        vm.startPrank(user1);

        uint256 depositAmount = 10 ether;
        habitChain.deposit{value: depositAmount}();

        uint256 habitId = habitChain.createHabit("Daily Habit", 1 ether);

        // Get initial value
        (, uint256 initialYield) = habitChain.getHabitCurrentValue(habitId);

        // Advance 10 days and check in
        vm.warp(block.timestamp + (10 * ONE_DAY));
        vm.roll(block.number + 72000);
        habitChain.checkIn(habitId);

        (, uint256 yieldAfterCheckIn) = habitChain.getHabitCurrentValue(habitId);

        // Advance another 10 days
        vm.warp(block.timestamp + (10 * ONE_DAY));
        vm.roll(block.number + 72000);

        (, uint256 finalYield) = habitChain.getHabitCurrentValue(habitId);

        console.log("\n=== Yield After Check-In ===");
        console.log("Initial yield:", initialYield);
        console.log("Yield after check-in (10d):", yieldAfterCheckIn);
        console.log("Final yield (20d):", finalYield);

        // Yield should continue to accrue
        assertGt(yieldAfterCheckIn, initialYield, "Yield should accrue before check-in");
        assertGt(finalYield, yieldAfterCheckIn, "Yield should continue after check-in");

        vm.stopPrank();
    }

    /**
     * @notice Test large stake amounts with yield
     * @dev Ensures yield calculation works correctly with large amounts
     */
    function testLargeStakeYieldCalculation() public {
        vm.startPrank(user1);

        // Deposit large amount
        uint256 depositAmount = 50 ether;
        habitChain.deposit{value: depositAmount}();

        // Create habit with large stake
        uint256 largeStake = 10 ether;
        uint256 habitId = habitChain.createHabit("Big Commitment", largeStake);

        // Advance time
        vm.warp(block.timestamp + ONE_MONTH);
        vm.roll(block.number + 216000);

        (uint256 value, uint256 yield) = habitChain.getHabitCurrentValue(habitId);

        console.log("\n=== Large Stake Yield ===");
        console.log("Stake:", largeStake);
        console.log("Value:", value);
        console.log("Yield:", yield);
        console.log("Yield %:", (yield * 10000) / largeStake, "basis points");

        assertGt(yield, 0, "Should earn yield on large stakes");
        assertGt(value, largeStake, "Value should exceed stake");

        vm.stopPrank();
    }

    /**
     * @notice Helper function to setup multiple users with various habits
     */
    function setupMultipleUsersWithHabits() internal {
        // User 1: 2 habits
        vm.startPrank(user1);
        habitChain.deposit{value: 10 ether}();
        habitChain.createHabit("User1 Habit A", 1 ether); // habitId 1
        habitChain.createHabit("User1 Habit B", 1 ether); // habitId 2
        vm.stopPrank();

        // User 2: 1 habit
        vm.startPrank(user2);
        habitChain.deposit{value: 10 ether}();
        habitChain.createHabit("User2 Habit", 1 ether); // habitId 3
        vm.stopPrank();

        // User 3: 1 habit
        vm.startPrank(user3);
        habitChain.deposit{value: 10 ether}();
        habitChain.createHabit("User3 Habit", 1 ether); // habitId 4
        vm.stopPrank();

        console.log("\n=== Setup Complete ===");
        console.log("User1: 2 habits (IDs: 1, 2)");
        console.log("User2: 1 habit (ID: 3)");
        console.log("User3: 1 habit (ID: 4)");
    }

    /**
     * @notice Test edge case: settlement immediately after creation (minimal yield)
     */
    function testSettlementImmediatelyAfterCreation() public {
        vm.startPrank(user1);

        habitChain.deposit{value: 10 ether}();
        uint256 habitId = habitChain.createHabit("Quick Test", 1 ether);
        
        habitChain.checkIn(habitId);

        // Settle almost immediately (advance 1 block)
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        (uint256 value, uint256 yield) = habitChain.getHabitCurrentValue(habitId);

        console.log("\n=== Immediate Settlement ===");
        console.log("Value:", value);
        console.log("Yield:", yield);

        habitChain.forceSettle(habitId, true);

        // Yield should be minimal or zero
        assertLe(yield, 1e15, "Yield should be minimal for immediate settlement");

        vm.stopPrank();
    }
}

