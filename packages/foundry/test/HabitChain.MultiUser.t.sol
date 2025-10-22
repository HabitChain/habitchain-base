// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainMultiUserTest
 * @notice Tests for multi-user scenarios and isolation
 */
contract HabitChainMultiUserTest is HabitChainBaseTest {
    function test_ThreeUsersCreateSeparateHabits() public {
        // User 1
        vm.startPrank(user1);
        habitChain.deposit{ value: 2 ether }();
        uint256 u1h1 = habitChain.createHabit("User1 Exercise", 0.5 ether);
        vm.stopPrank();
        
        // User 2
        vm.startPrank(user2);
        habitChain.deposit{ value: 2 ether }();
        uint256 u2h1 = habitChain.createHabit("User2 Reading", 0.6 ether);
        vm.stopPrank();
        
        // User 3
        vm.startPrank(user3);
        habitChain.deposit{ value: 2 ether }();
        uint256 u3h1 = habitChain.createHabit("User3 Meditation", 0.7 ether);
        vm.stopPrank();
        
        // Verify habits are separate
        assertEq(getHabit(u1h1).user, user1);
        assertEq(getHabit(u2h1).user, user2);
        assertEq(getHabit(u3h1).user, user3);
        
        assertEq(getHabit(u1h1).stakeAmount, 0.5 ether);
        assertEq(getHabit(u2h1).stakeAmount, 0.6 ether);
        assertEq(getHabit(u3h1).stakeAmount, 0.7 ether);
    }

    function test_UserCannotCheckInOtherUsersHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "User1 Habit", 0.5 ether);
        
        // User2 tries to check in user1's habit
        vm.prank(user2);
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.checkIn(habitId);
        
        // User3 tries to check in user1's habit
        vm.prank(user3);
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.checkIn(habitId);
    }

    // Note: test_UserCannotSettleOtherUsersHabit removed - natural settle can be called by anyone

    function test_UserCannotRefundOtherUsersHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "User1 Habit", 0.5 ether);
        
        // Slash the habit
        habitChain.naturalSettle();
        
        // User2 tries to refund user1's habit
        vm.startPrank(user2);
        habitChain.deposit{ value: 1 ether }();
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.refundHabit(habitId, 0.5 ether);
        vm.stopPrank();
    }

    function test_GlobalSettlementAffectsAllUsersCorrectly() public {
        // User 1: 2 habits, check in 1
        vm.startPrank(user1);
        habitChain.deposit{ value: 3 ether }();
        uint256 u1h1 = habitChain.createHabit("U1H1", 0.5 ether);
        uint256 u1h2 = habitChain.createHabit("U1H2", 0.5 ether);
        habitChain.checkIn(u1h1);
        vm.stopPrank();
        
        // User 2: 2 habits, check in both
        vm.startPrank(user2);
        habitChain.deposit{ value: 3 ether }();
        uint256 u2h1 = habitChain.createHabit("U2H1", 0.6 ether);
        uint256 u2h2 = habitChain.createHabit("U2H2", 0.6 ether);
        habitChain.checkIn(u2h1);
        habitChain.checkIn(u2h2);
        vm.stopPrank();
        
        // User 3: 2 habits, check in none
        vm.startPrank(user3);
        habitChain.deposit{ value: 3 ether }();
        uint256 u3h1 = habitChain.createHabit("U3H1", 0.7 ether);
        uint256 u3h2 = habitChain.createHabit("U3H2", 0.7 ether);
        vm.stopPrank();
        
        // Global settlement
        habitChain.naturalSettle();
        
        // Verify User 1: 1 success, 1 failure
        assertEq(getHabit(u1h1).stakeAmount, 0.5 ether, "U1H1 should retain stake");
        assertEq(getHabit(u1h2).stakeAmount, 0, "U1H2 should be slashed");
        
        // Verify User 2: both success
        assertEq(getHabit(u2h1).stakeAmount, 0.6 ether, "U2H1 should retain stake");
        assertEq(getHabit(u2h2).stakeAmount, 0.6 ether, "U2H2 should retain stake");
        
        // Verify User 3: both failure
        assertEq(getHabit(u3h1).stakeAmount, 0, "U3H1 should be slashed");
        assertEq(getHabit(u3h2).stakeAmount, 0, "U3H2 should be slashed");
    }

    function test_MixedSuccessFailureAcrossMultipleUsers() public {
        // Setup 3 users with different patterns
        vm.startPrank(user1);
        habitChain.deposit{ value: 2 ether }();
        uint256 u1h1 = habitChain.createHabit("U1 Success", 0.5 ether);
        habitChain.checkIn(u1h1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        habitChain.deposit{ value: 2 ether }();
        uint256 u2h1 = habitChain.createHabit("U2 Failure", 0.5 ether);
        // Don't check in
        vm.stopPrank();
        
        vm.startPrank(user3);
        habitChain.deposit{ value: 2 ether }();
        uint256 u3h1 = habitChain.createHabit("U3 Success", 0.5 ether);
        habitChain.checkIn(u3h1);
        vm.stopPrank();
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        habitChain.naturalSettle();
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        
        // 2 successes, 1 failure
        assertEq(getHabit(u1h1).stakeAmount, 0.5 ether);
        assertEq(getHabit(u2h1).stakeAmount, 0);
        assertEq(getHabit(u3h1).stakeAmount, 0.5 ether);
        
        // Treasury should receive only from user2's failed habit
        assertGe(treasuryAfter - treasuryBefore, 0.5 ether - 1e15, "Treasury receives from failure");
    }

    function test_UserBalancesRemainIsolated() public {
        // All users deposit same amount
        depositFor(user1, 5 ether);
        depositFor(user2, 5 ether);
        depositFor(user3, 5 ether);
        
        assertEq(habitChain.getUserBalance(user1), 5 ether);
        assertEq(habitChain.getUserBalance(user2), 5 ether);
        assertEq(habitChain.getUserBalance(user3), 5 ether);
        
        // User1 creates habit
        createHabitFor(user1, "U1 Habit", 2 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 3 ether, 1e15, "U1 balance");
        assertEq(habitChain.getUserBalance(user2), 5 ether, "U2 balance unchanged");
        assertEq(habitChain.getUserBalance(user3), 5 ether, "U3 balance unchanged");
        
        // User2 withdraws
        withdrawFor(user2, 1 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 3 ether, 1e15, "U1 balance unchanged");
        assertApproxEqAbs(habitChain.getUserBalance(user2), 4 ether, 1e15, "U2 balance");
        assertEq(habitChain.getUserBalance(user3), 5 ether, "U3 balance unchanged");
    }

    function test_TreasuryReceivesSlashesFromMultipleUsers() public {
        // Setup habits from multiple users
        uint256 u1h1 = setupBasicHabit(user1, 2 ether, "U1H1", 0.5 ether);
        uint256 u2h1 = setupBasicHabit(user2, 2 ether, "U2H1", 0.6 ether);
        uint256 u3h1 = setupBasicHabit(user3, 2 ether, "U3H1", 0.7 ether);
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        // All fail
        habitChain.naturalSettle();
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        
        // Treasury should receive all slashed amounts
        assertGe(treasuryAfter - treasuryBefore, 1.8 ether - 1e14, "Treasury receives all slashed funds");
    }

    function test_ConcurrentDepositsFromMultipleUsers() public {
        // Simulate concurrent deposits (in same block)
        vm.prank(user1);
        habitChain.deposit{ value: 1 ether }();
        
        vm.prank(user2);
        habitChain.deposit{ value: 2 ether }();
        
        vm.prank(user3);
        habitChain.deposit{ value: 3 ether }();
        
        // All deposits should be tracked correctly
        assertEq(habitChain.getUserBalance(user1), 1 ether);
        assertEq(habitChain.getUserBalance(user2), 2 ether);
        assertEq(habitChain.getUserBalance(user3), 3 ether);
    }

    function test_UserHabitCountsAreAccurate() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 5 ether }();
        habitChain.createHabit("H1", 0.5 ether);
        habitChain.createHabit("H2", 0.5 ether);
        habitChain.createHabit("H3", 0.5 ether);
        vm.stopPrank();
        
        assertEq(habitChain.getUserActiveHabitsCount(user1), 3);
        
        vm.startPrank(user2);
        habitChain.deposit{ value: 5 ether }();
        habitChain.createHabit("H4", 0.5 ether);
        habitChain.createHabit("H5", 0.5 ether);
        vm.stopPrank();
        
        assertEq(habitChain.getUserActiveHabitsCount(user2), 2);
        assertEq(habitChain.getUserActiveHabitsCount(user3), 0);
    }

    function test_GetUserHabitsReturnsCorrectHabitsPerUser() public {
        // User 1 creates habits
        vm.startPrank(user1);
        habitChain.deposit{ value: 3 ether }();
        uint256 u1h1 = habitChain.createHabit("U1H1", 0.5 ether);
        uint256 u1h2 = habitChain.createHabit("U1H2", 0.5 ether);
        vm.stopPrank();
        
        // User 2 creates habits
        vm.startPrank(user2);
        habitChain.deposit{ value: 3 ether }();
        uint256 u2h1 = habitChain.createHabit("U2H1", 0.5 ether);
        uint256 u2h2 = habitChain.createHabit("U2H2", 0.5 ether);
        uint256 u2h3 = habitChain.createHabit("U2H3", 0.5 ether);
        vm.stopPrank();
        
        // Verify User 1's habits
        uint256[] memory u1Habits = habitChain.getUserHabits(user1);
        assertEq(u1Habits.length, 2);
        assertEq(u1Habits[0], u1h1);
        assertEq(u1Habits[1], u1h2);
        
        // Verify User 2's habits
        uint256[] memory u2Habits = habitChain.getUserHabits(user2);
        assertEq(u2Habits.length, 3);
        assertEq(u2Habits[0], u2h1);
        assertEq(u2Habits[1], u2h2);
        assertEq(u2Habits[2], u2h3);
        
        // Verify User 3 has no habits
        uint256[] memory u3Habits = habitChain.getUserHabits(user3);
        assertEq(u3Habits.length, 0);
    }

    function test_GetUserActiveHabitsCountAccuracyPerUser() public {
        // User 1: Create 3 habits, 1 gets slashed
        vm.startPrank(user1);
        habitChain.deposit{ value: 3 ether }();
        habitChain.createHabit("U1H1", 0.5 ether);
        habitChain.createHabit("U1H2", 0.5 ether);
        habitChain.createHabit("U1H3", 0.5 ether);
        vm.stopPrank();
        
        assertEq(habitChain.getUserActiveHabitsCount(user1), 3, "User1 should have 3 active");
        
        // Slash all via global settlement
        habitChain.naturalSettle();
        
        assertEq(habitChain.getUserActiveHabitsCount(user1), 0, "User1 should have 0 active (all slashed)");
        
        // User 2: Create habits and keep them funded
        vm.startPrank(user2);
        habitChain.deposit{ value: 3 ether }();
        uint256 u2h1 = habitChain.createHabit("U2H1", 0.5 ether);
        uint256 u2h2 = habitChain.createHabit("U2H2", 0.5 ether);
        habitChain.checkIn(u2h1);
        habitChain.checkIn(u2h2);
        vm.stopPrank();
        
        habitChain.naturalSettle();
        
        assertEq(habitChain.getUserActiveHabitsCount(user2), 2, "User2 should still have 2 active");
    }
}

