// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainGlobalSettleTest
 * @notice Tests for global settlement functionality (PRIMARY SETTLEMENT MECHANISM)
 */
contract HabitChainGlobalSettleTest is HabitChainBaseTest {
    function test_HappyPathFromTestingDoc() public {
        // This is the exact scenario from TESTING_HAPPY_PATH.md
        
        vm.startPrank(user1);
        
        // Deposit 0.6 ETH
        habitChain.deposit{ value: 0.6 ether }();
        assertApproxEqAbs(habitChain.getUserBalance(user1), 0.6 ether, 1e15, "Initial deposit");
        
        // Create habit 1: "Run in the morning" with 0.2 ETH stake
        uint256 habit1 = habitChain.createHabit("Run in the morning", 0.2 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 0.4 ether, 1e15, "After habit 1");
        
        // Create habit 2: "Go to the gym" with 0.2 ETH stake
        uint256 habit2 = habitChain.createHabit("Go to the gym", 0.2 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 0.2 ether, 1e15, "After habit 2");
        
        // Check-in on habit 1 only
        habitChain.checkIn(habit1);
        
        // Do NOT check-in on habit 2
        
        vm.stopPrank();
        
        // Trigger global settlement
        habitChain.globalSettle();
        
        // Verify habit 1: stays active, yield to user
        HabitChain.Habit memory h1After = getHabit(habit1);
        assertTrue(h1After.isActive, "Habit 1 should be active");
        assertFalse(h1After.isSettled, "Habit 1 should not be settled");
        assertEq(h1After.stakeAmount, 0.2 ether, "Habit 1 stake should remain");
        
        // Verify habit 2: slashed (stake = 0), funds to treasury
        HabitChain.Habit memory h2After = getHabit(habit2);
        assertTrue(h2After.isActive, "Habit 2 should still be active");
        assertFalse(h2After.isSettled, "Habit 2 should not be permanently settled");
        assertEq(h2After.stakeAmount, 0, "Habit 2 should be slashed (stake = 0)");
        
        // Verify treasury received funds
        uint256 treasuryBalance = habitChain.getTreasuryBalance();
        assertGe(treasuryBalance, 0.2 ether - 1e15, "Treasury should receive slashed funds");
        
        // Verify user available balance (should have received yield from habit 1)
        uint256 userBalance = habitChain.getUserBalance(user1);
        assertGe(userBalance, 0.2 ether - 1e15, "User available balance should be at least 0.2 ETH");
    }

    function test_AllHabitsCheckedIn() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 3 ether }();
        
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.5 ether);
        uint256 habit3 = habitChain.createHabit("Habit 3", 0.5 ether);
        
        // Check in all habits
        habitChain.checkIn(habit1);
        habitChain.checkIn(habit2);
        habitChain.checkIn(habit3);
        
        vm.stopPrank();
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        habitChain.globalSettle();
        
        // All habits should remain active with stake
        assertEq(getHabit(habit1).stakeAmount, 0.5 ether);
        assertEq(getHabit(habit2).stakeAmount, 0.5 ether);
        assertEq(getHabit(habit3).stakeAmount, 0.5 ether);
        
        // Treasury should not receive any new funds
        assertEq(habitChain.getTreasuryBalance(), treasuryBefore, "Treasury should not increase");
    }

    function test_NoHabitsCheckedIn() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 3 ether }();
        
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.5 ether);
        uint256 habit3 = habitChain.createHabit("Habit 3", 0.5 ether);
        
        // Don't check in any habits
        
        vm.stopPrank();
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        habitChain.globalSettle();
        
        // All habits should be slashed
        assertEq(getHabit(habit1).stakeAmount, 0);
        assertEq(getHabit(habit2).stakeAmount, 0);
        assertEq(getHabit(habit3).stakeAmount, 0);
        
        // Treasury should receive all slashed funds
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        assertGe(treasuryAfter - treasuryBefore, 1.5 ether - 1e14, "Treasury should receive all stakes");
    }

    function test_MixedSuccessFailure() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 4 ether }();
        
        uint256 habit1 = habitChain.createHabit("Success 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Failure 1", 0.5 ether);
        uint256 habit3 = habitChain.createHabit("Success 2", 0.5 ether);
        uint256 habit4 = habitChain.createHabit("Failure 2", 0.5 ether);
        
        // Check in only habit1 and habit3
        habitChain.checkIn(habit1);
        habitChain.checkIn(habit3);
        
        vm.stopPrank();
        
        habitChain.globalSettle();
        
        // Verify successes
        assertEq(getHabit(habit1).stakeAmount, 0.5 ether, "Habit 1 should retain stake");
        assertEq(getHabit(habit3).stakeAmount, 0.5 ether, "Habit 3 should retain stake");
        
        // Verify failures
        assertEq(getHabit(habit2).stakeAmount, 0, "Habit 2 should be slashed");
        assertEq(getHabit(habit4).stakeAmount, 0, "Habit 4 should be slashed");
    }

    function test_SettlementWithNoActiveHabits() public {
        // Call global settle with no habits created
        habitChain.globalSettle();
        
        // Should complete without error
        assertTrue(true, "Settlement with no habits should succeed");
    }

    function test_SettlementWithOnlySlashedHabits() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 2 ether }();
        
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.5 ether);
        
        vm.stopPrank();
        
        // First settlement - slashes both habits
        habitChain.globalSettle();
        
        assertEq(getHabit(habit1).stakeAmount, 0);
        assertEq(getHabit(habit2).stakeAmount, 0);
        
        // Second settlement - should skip already slashed habits
        habitChain.globalSettle();
        
        // Habits should still be active but slashed
        assertTrue(getHabit(habit1).isActive);
        assertTrue(getHabit(habit2).isActive);
        assertEq(getHabit(habit1).stakeAmount, 0);
        assertEq(getHabit(habit2).stakeAmount, 0);
    }

    function test_SettlementWithAlreadySettledHabits() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.prank(user1);
        habitChain.forceSettle(habitId, true);
        
        // Habit is now settled and inactive
        assertFalse(getHabit(habitId).isActive);
        assertTrue(getHabit(habitId).isSettled);
        
        // Global settlement should skip this habit
        habitChain.globalSettle();
        
        // State should remain unchanged
        assertFalse(getHabit(habitId).isActive);
        assertTrue(getHabit(habitId).isSettled);
    }

    function test_MultipleUsersWithHabits() public {
        // User 1 creates habits
        vm.startPrank(user1);
        habitChain.deposit{ value: 2 ether }();
        uint256 u1h1 = habitChain.createHabit("User1 Habit1", 0.5 ether);
        uint256 u1h2 = habitChain.createHabit("User1 Habit2", 0.5 ether);
        habitChain.checkIn(u1h1); // Check in first habit only
        vm.stopPrank();
        
        // User 2 creates habits
        vm.startPrank(user2);
        habitChain.deposit{ value: 2 ether }();
        uint256 u2h1 = habitChain.createHabit("User2 Habit1", 0.5 ether);
        uint256 u2h2 = habitChain.createHabit("User2 Habit2", 0.5 ether);
        habitChain.checkIn(u2h1);
        habitChain.checkIn(u2h2); // Check in both habits
        vm.stopPrank();
        
        habitChain.globalSettle();
        
        // Verify user1's habits
        assertEq(getHabit(u1h1).stakeAmount, 0.5 ether, "User1 habit1 should retain stake");
        assertEq(getHabit(u1h2).stakeAmount, 0, "User1 habit2 should be slashed");
        
        // Verify user2's habits
        assertEq(getHabit(u2h1).stakeAmount, 0.5 ether, "User2 habit1 should retain stake");
        assertEq(getHabit(u2h2).stakeAmount, 0.5 ether, "User2 habit2 should retain stake");
    }

    function test_HabitCheckedInExactlyAt24HourBoundary() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        // Advance exactly 24 hours
        skipSeconds(86400);
        
        // Global settlement - should consider this as success (within 24h from now)
        habitChain.globalSettle();
        
        // Habit should retain stake (checked in within last 24 hours)
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether);
    }

    function test_HabitCheckedIn25HoursAgo() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        // Advance 25 hours (90000 seconds)
        skipSeconds(90000);
        
        // Global settlement - should consider this as failure (more than 24h ago)
        habitChain.globalSettle();
        
        // Habit should be slashed
        assertEq(getHabit(habitId).stakeAmount, 0);
    }

    function test_HabitsRemainActiveAfterDailySettlement_Success() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        habitChain.globalSettle();
        
        // Habit should remain active (not permanently settled)
        assertTrue(getHabit(habitId).isActive, "Should remain active");
        assertFalse(getHabit(habitId).isSettled, "Should not be permanently settled");
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether, "Should retain stake");
    }

    function test_HabitsSlashedButActiveAfterDailySettlement_Failure() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        // Don't check in
        
        habitChain.globalSettle();
        
        // Habit should be active but slashed (stake = 0)
        assertTrue(getHabit(habitId).isActive, "Should remain active");
        assertFalse(getHabit(habitId).isSettled, "Should not be permanently settled");
        assertEq(getHabit(habitId).stakeAmount, 0, "Stake should be 0 (slashed)");
    }

    function test_CheckInCountPersistsAfterSettlement() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        skipDays(1);
        habitChain.checkIn(habitId);
        skipDays(1);
        habitChain.checkIn(habitId);
        
        vm.stopPrank();
        
        assertEq(getHabit(habitId).checkInCount, 3, "Should have 3 check-ins");
        
        habitChain.globalSettle();
        
        // Check-in count should persist
        assertEq(getHabit(habitId).checkInCount, 3, "Check-in count should persist");
    }

    function test_LastCheckInPersistsAfterSettlement() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        uint256 lastCheckInBefore = getHabit(habitId).lastCheckIn;
        
        habitChain.globalSettle();
        
        // Last check-in timestamp should persist
        assertEq(getHabit(habitId).lastCheckIn, lastCheckInBefore, "Last check-in should persist");
    }

    function test_LiquidityIndexUpdatesOnSuccess() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        uint256 liquidityIndexBefore = getHabit(habitId).liquidityIndex;
        
        // Skip time for liquidity index to potentially change
        skipDays(30);
        
        habitChain.globalSettle();
        
        uint256 liquidityIndexAfter = getHabit(habitId).liquidityIndex;
        
        // Liquidity index should be updated (or at least set to current value)
        assertGt(liquidityIndexAfter, 0, "Liquidity index should be set");
    }

    function test_YieldDistributionOnSuccess() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Exercise", 1 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        uint256 userBalanceBefore = habitChain.getUserBalance(user1);
        
        // Skip time for yield accrual
        skipDays(30);
        
        habitChain.globalSettle();
        
        uint256 userBalanceAfter = habitChain.getUserBalance(user1);
        
        // User should receive yield (balance should increase, even if minimally)
        assertGe(userBalanceAfter, userBalanceBefore, "User should receive yield on success");
    }

    function test_YieldDistributionOnFailure() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Exercise", 1 ether);
        
        // Don't check in
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        // Skip time for yield accrual
        skipDays(30);
        
        habitChain.globalSettle();
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        
        // Treasury should receive stake + yield
        assertGe(treasuryAfter - treasuryBefore, 1 ether - 1e15, "Treasury should receive stake + yield");
    }

    function test_GlobalSettlementCompletedEventEmission() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 3 ether }();
        habitChain.createHabit("Habit 1", 0.5 ether);
        habitChain.createHabit("Habit 2", 0.5 ether);
        habitChain.createHabit("Habit 3", 0.5 ether);
        vm.stopPrank();
        
        vm.expectEmit(false, false, false, false);
        emit GlobalSettlementCompleted(0, 0, 0, block.timestamp);
        
        habitChain.globalSettle();
    }

    function test_SequentialDailySettlementsOverMultipleDays() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 2 ether }();
        uint256 habitId = habitChain.createHabit("Daily Exercise", 0.5 ether);
        
        // Day 1: Check in and settle
        habitChain.checkIn(habitId);
        vm.stopPrank();
        habitChain.globalSettle();
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether, "Day 1: Should retain stake");
        
        skipDays(1);
        
        // Day 2: Check in and settle
        vm.prank(user1);
        habitChain.checkIn(habitId);
        habitChain.globalSettle();
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether, "Day 2: Should retain stake");
        
        skipDays(1);
        
        // Day 3: Don't check in, settle
        habitChain.globalSettle();
        assertEq(getHabit(habitId).stakeAmount, 0, "Day 3: Should be slashed");
        
        skipDays(1);
        
        // Day 4: Refund and check in
        vm.startPrank(user1);
        habitChain.refundHabit(habitId, 0.5 ether);
        habitChain.checkIn(habitId);
        vm.stopPrank();
        habitChain.globalSettle();
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether, "Day 4: Should retain stake after refund");
    }
}

