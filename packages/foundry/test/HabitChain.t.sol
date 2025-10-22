// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/HabitChain.sol";
import "../contracts/interfaces/IPool.sol";
import "../contracts/interfaces/IWETH.sol";
import "../contracts/interfaces/IAToken.sol";

contract HabitChainTest is Test {
    HabitChain public habitChain;

    // Aave V3 addresses on Base Mainnet
    address constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AWETH = 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7;

    address public treasury;
    address public user1;
    address public user2;

    uint256 public baseFork;

    // Events to test
    event Deposited(address indexed user, uint256 amount);
    event HabitCreated(
        uint256 indexed habitId, address indexed user, string name, uint256 stakeAmount, uint256 timestamp
    );
    event CheckInCompleted(uint256 indexed habitId, address indexed user, uint256 timestamp, uint256 checkInCount);
    event HabitSettled(
        uint256 indexed habitId, address indexed user, bool success, uint256 totalAmount, uint256 yieldEarned, uint256 timestamp
    );
    event TreasuryFunded(uint256 indexed habitId, uint256 amount);

    function setUp() public {
        // Fork Base mainnet for real Aave integration at a specific block for consistency
        string memory rpcUrl = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
        // Using block 20000000 - known good state with Aave liquidity
        baseFork = vm.createFork(rpcUrl, 20000000);
        vm.selectFork(baseFork);

        // Set up test accounts
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Deploy HabitChain
        habitChain = new HabitChain(AAVE_POOL, WETH, AWETH, treasury);

        console.log("HabitChain deployed at:", address(habitChain));
        console.log("Fork block number:", block.number);
    }

    function testDeposit() public {
        vm.startPrank(user1);

        uint256 depositAmount = 1 ether;

        vm.expectEmit(true, false, false, true);
        emit Deposited(user1, depositAmount);

        habitChain.deposit{ value: depositAmount }();

        assertEq(habitChain.getUserBalance(user1), depositAmount);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);

        // Deposit first
        uint256 depositAmount = 1 ether;
        habitChain.deposit{ value: depositAmount }();

        uint256 withdrawAmount = 0.5 ether;
        uint256 balanceBefore = user1.balance;

        habitChain.withdraw(withdrawAmount);

        assertEq(habitChain.getUserBalance(user1), depositAmount - withdrawAmount);
        assertEq(user1.balance, balanceBefore + withdrawAmount);

        vm.stopPrank();
    }

    function testCreateHabit() public {
        vm.startPrank(user1);

        // Deposit ETH
        uint256 depositAmount = 1 ether;
        habitChain.deposit{ value: depositAmount }();

        // Create habit
        string memory habitName = "Morning Meditation";
        uint256 stakeAmount = 0.1 ether;

        vm.expectEmit(true, true, false, false);
        emit HabitCreated(1, user1, habitName, stakeAmount, block.timestamp);

        uint256 habitId = habitChain.createHabit(habitName, stakeAmount);

        // Verify habit was created
        assertEq(habitId, 1);
        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.id, habitId);
        assertEq(habit.user, user1);
        assertEq(habit.name, habitName);
        assertEq(habit.stakeAmount, stakeAmount);
        assertTrue(habit.isActive);
        assertFalse(habit.isSettled);
        assertEq(habit.checkInCount, 0);

        // Verify balance was deducted
        assertEq(habitChain.getUserBalance(user1), depositAmount - stakeAmount);

        // Verify aToken was received
        assertTrue(habit.aTokenAmount > 0);

        vm.stopPrank();
    }

    function testCheckIn() public {
        vm.startPrank(user1);

        // Setup: Deposit and create habit
        habitChain.deposit{ value: 1 ether }();
        uint256 habitId = habitChain.createHabit("Exercise", 0.1 ether);

        // First check-in
        vm.expectEmit(true, true, false, true);
        emit CheckInCompleted(habitId, user1, block.timestamp, 1);

        habitChain.checkIn(habitId);

        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.checkInCount, 1);
        assertEq(habit.lastCheckIn, block.timestamp);

        // Try to check in again same day - should fail
        vm.expectRevert(HabitChain.AlreadyCheckedInToday.selector);
        habitChain.checkIn(habitId);

        // Move forward 1 day
        vm.warp(block.timestamp + 1 days);

        // Second check-in should succeed
        habitChain.checkIn(habitId);
        habit = habitChain.getHabit(habitId);
        assertEq(habit.checkInCount, 2);

        vm.stopPrank();
    }

    function testSuccessfulSettlement() public {
        vm.startPrank(user1);

        // Setup: Deposit and create habit
        uint256 depositAmount = 1 ether;
        habitChain.deposit{ value: depositAmount }();
        uint256 stakeAmount = 0.1 ether;
        uint256 habitId = habitChain.createHabit("Reading", stakeAmount);

        // Check in
        habitChain.checkIn(habitId);

        uint256 balanceBefore = habitChain.getUserBalance(user1);

        // Simulate time passing to accrue some yield (optional, may be minimal)
        vm.warp(block.timestamp + 30 days);

        // Settle successfully
        habitChain.forceSettle(habitId, true);

        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertFalse(habit.isActive);
        assertTrue(habit.isSettled);

        // User should get back at least the stake amount (possibly more with yield)
        uint256 balanceAfter = habitChain.getUserBalance(user1);
        assertGe(balanceAfter, balanceBefore + stakeAmount);

        vm.stopPrank();
    }

    function testSlashedSettlement() public {
        vm.startPrank(user1);

        // Setup: Deposit and create habit
        habitChain.deposit{ value: 1 ether }();
        uint256 stakeAmount = 0.1 ether;
        uint256 habitId = habitChain.createHabit("Yoga", stakeAmount);

        // Don't check in - fail the habit
        uint256 balanceBefore = habitChain.getUserBalance(user1);
        uint256 treasuryBefore = habitChain.getTreasuryBalance();

        // Settle as failed
        habitChain.forceSettle(habitId, false);

        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertFalse(habit.isActive);
        assertTrue(habit.isSettled);

        // User balance should remain the same (no refund)
        assertEq(habitChain.getUserBalance(user1), balanceBefore);

        // Treasury should receive the slashed amount
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        assertGt(treasuryAfter, treasuryBefore);
        assertGe(treasuryAfter, treasuryBefore + stakeAmount);

        vm.stopPrank();
    }

    function testFullUserFlow() public {
        vm.startPrank(user1);

        // 1. User deposits tokens
        uint256 depositAmount = 2 ether;
        habitChain.deposit{ value: depositAmount }();
        assertEq(habitChain.getUserBalance(user1), depositAmount);

        // 2. User creates two habits
        uint256 habit1Id = habitChain.createHabit("Morning Run", 0.5 ether);
        uint256 habit2Id = habitChain.createHabit("Evening Study", 0.5 ether);

        uint256[] memory userHabits = habitChain.getUserHabits(user1);
        assertEq(userHabits.length, 2);
        assertEq(habitChain.getUserActiveHabitsCount(user1), 2);

        // 3. User performs check-in for habit 1 only
        habitChain.checkIn(habit1Id);

        HabitChain.Habit memory habit1 = habitChain.getHabit(habit1Id);
        HabitChain.Habit memory habit2 = habitChain.getHabit(habit2Id);

        assertEq(habit1.checkInCount, 1);
        assertEq(habit2.checkInCount, 0);

        // 4. Simulate time passing
        vm.warp(block.timestamp + 30 days);

        // 5. Settle habit 1 (success) and habit 2 (failure)
        uint256 balanceBeforeSettlement = habitChain.getUserBalance(user1);
        uint256 treasuryBeforeSettlement = habitChain.getTreasuryBalance();

        habitChain.forceSettle(habit1Id, true);
        habitChain.forceSettle(habit2Id, false);

        // Verify settlements
        habit1 = habitChain.getHabit(habit1Id);
        habit2 = habitChain.getHabit(habit2Id);

        assertTrue(habit1.isSettled);
        assertTrue(habit2.isSettled);
        assertFalse(habit1.isActive);
        assertFalse(habit2.isActive);

        // User should get back habit1 stake + yield
        uint256 balanceAfterSettlement = habitChain.getUserBalance(user1);
        assertGt(balanceAfterSettlement, balanceBeforeSettlement);

        // Treasury should get habit2 stake + yield
        uint256 treasuryAfterSettlement = habitChain.getTreasuryBalance();
        assertGt(treasuryAfterSettlement, treasuryBeforeSettlement);

        assertEq(habitChain.getUserActiveHabitsCount(user1), 0);

        vm.stopPrank();
    }

    function testMultipleUsers() public {
        // User 1 creates a habit
        vm.startPrank(user1);
        habitChain.deposit{ value: 1 ether }();
        uint256 user1HabitId = habitChain.createHabit("Meditation", 0.2 ether);
        vm.stopPrank();

        // User 2 creates a habit
        vm.startPrank(user2);
        habitChain.deposit{ value: 1 ether }();
        uint256 user2HabitId = habitChain.createHabit("Journaling", 0.3 ether);
        vm.stopPrank();

        // Verify separate habits
        assertEq(user1HabitId, 1);
        assertEq(user2HabitId, 2);

        HabitChain.Habit memory habit1 = habitChain.getHabit(user1HabitId);
        HabitChain.Habit memory habit2 = habitChain.getHabit(user2HabitId);

        assertEq(habit1.user, user1);
        assertEq(habit2.user, user2);
    }

    function testCannotCheckInOtherUsersHabit() public {
        // User 1 creates a habit
        vm.prank(user1);
        habitChain.deposit{ value: 1 ether }();
        vm.prank(user1);
        uint256 habitId = habitChain.createHabit("Running", 0.1 ether);

        // User 2 tries to check in - should fail
        vm.prank(user2);
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.checkIn(habitId);
    }

    function testCannotSettleOtherUsersHabit() public {
        // User 1 creates a habit
        vm.prank(user1);
        habitChain.deposit{ value: 1 ether }();
        vm.prank(user1);
        uint256 habitId = habitChain.createHabit("Swimming", 0.1 ether);

        // User 2 tries to settle - should fail
        vm.prank(user2);
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.forceSettle(habitId, true);
    }

    function testMinimumStakeRequirement() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 1 ether }();

        // Try to create habit with less than minimum stake
        vm.expectRevert(HabitChain.InsufficientStake.selector);
        habitChain.createHabit("Low Stake Habit", 0.0001 ether);

        vm.stopPrank();
    }

    function testCannotCreateHabitWithEmptyName() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 1 ether }();

        vm.expectRevert(HabitChain.EmptyHabitName.selector);
        habitChain.createHabit("", 0.1 ether);

        vm.stopPrank();
    }

    function testWithdrawInsufficientBalance() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 0.5 ether }();

        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.withdraw(1 ether);

        vm.stopPrank();
    }

    function testTreasuryWithdrawal() public {
        // Setup: Create a failed habit to fund treasury
        vm.startPrank(user1);
        habitChain.deposit{ value: 1 ether }();
        uint256 habitId = habitChain.createHabit("Failed Habit", 0.5 ether);
        habitChain.forceSettle(habitId, false);
        vm.stopPrank();

        uint256 treasuryBalance = habitChain.getTreasuryBalance();
        assertTrue(treasuryBalance > 0);

        // Treasury can withdraw
        uint256 treasuryEthBefore = treasury.balance;
        vm.prank(treasury);
        habitChain.withdrawTreasury(treasuryBalance);

        assertEq(habitChain.getTreasuryBalance(), 0);
        assertEq(treasury.balance, treasuryEthBefore + treasuryBalance);
    }

    function testNonTreasuryCannotWithdrawTreasuryFunds() public {
        // Setup: Fund treasury
        vm.startPrank(user1);
        habitChain.deposit{ value: 1 ether }();
        uint256 habitId = habitChain.createHabit("Failed Habit", 0.5 ether);
        habitChain.forceSettle(habitId, false);
        vm.stopPrank();

        // User tries to withdraw treasury funds - should fail
        vm.prank(user1);
        vm.expectRevert("Only treasury can withdraw");
        habitChain.withdrawTreasury(0.1 ether);
    }

    function testAaveIntegrationYieldAccrual() public {
        vm.startPrank(user1);

        // Deposit and create habit
        habitChain.deposit{ value: 1 ether }();
        uint256 stakeAmount = 0.5 ether;
        uint256 habitId = habitChain.createHabit("Long Term Habit", stakeAmount);

        // Simulate significant time passing for yield accrual
        // Note: In a real fork, Aave interest accrues, but in fast-forwarded time it may be minimal
        vm.warp(block.timestamp + 365 days);

        // The aToken balance grows automatically in Aave
        // When we settle, we should get more than we put in

        uint256 balanceBeforeSettle = habitChain.getUserBalance(user1);
        habitChain.forceSettle(habitId, true);
        uint256 balanceAfterSettle = habitChain.getUserBalance(user1);

        // User should receive at least the original stake
        assertGe(balanceAfterSettle, balanceBeforeSettle + stakeAmount);

        // In a real Aave environment with time passing, we'd see yield
        // For this test, we verify the mechanism works even if yield is minimal
        console.log("Original stake:", stakeAmount);
        console.log("Amount received:", balanceAfterSettle - balanceBeforeSettle);

        vm.stopPrank();
    }
}

