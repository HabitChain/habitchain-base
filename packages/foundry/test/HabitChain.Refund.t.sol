// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainRefundTest
 * @notice Tests for habit refund functionality
 */
contract HabitChainRefundTest is HabitChainBaseTest {
    function test_RefundSlashedHabit() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Exercise", 0.5 ether);
        
        // Slash the habit via global settlement without check-in
        habitChain.globalSettle();
        
        assertEq(getHabit(habitId).stakeAmount, 0, "Habit should be slashed");
        
        vm.startPrank(user1);
        
        uint256 balanceBefore = habitChain.getUserBalance(user1);
        
        vm.expectEmit(true, true, false, true);
        emit HabitRefunded(habitId, user1, 0.5 ether, block.timestamp);
        
        habitChain.refundHabit(habitId, 0.5 ether);
        
        uint256 balanceAfter = habitChain.getUserBalance(user1);
        
        // Balance should decrease by refund amount
        assertApproxEqAbs(balanceBefore - balanceAfter, 0.5 ether, 1e15, "Balance should decrease");
        
        // Habit should have stake again
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether, "Habit should have stake");
        
        vm.stopPrank();
    }

    function test_RefundRestoresHabitToActiveState() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Reading", 0.5 ether);
        
        // Slash the habit
        habitChain.globalSettle();
        
        assertTrue(getHabit(habitId).isActive, "Should remain active even when slashed");
        assertEq(getHabit(habitId).stakeAmount, 0, "Stake should be 0");
        
        vm.prank(user1);
        habitChain.refundHabit(habitId, 0.5 ether);
        
        // Verify habit is properly funded again
        assertTrue(getHabit(habitId).isActive, "Should be active");
        assertFalse(getHabit(habitId).isSettled, "Should not be settled");
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether, "Should have stake");
    }

    function test_RefundWithExactMinStake() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Meditation", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.prank(user1);
        uint256 minStake = 0.001 ether;
        habitChain.refundHabit(habitId, minStake);
        
        assertEq(getHabit(habitId).stakeAmount, minStake, "Should accept min stake");
    }

    function test_RefundWithMoreThanOriginalStake() public {
        uint256 habitId = setupBasicHabit(user1, 3 ether, "Yoga", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.prank(user1);
        habitChain.refundHabit(habitId, 1 ether);
        
        assertEq(getHabit(habitId).stakeAmount, 1 ether, "Should accept higher stake");
    }

    function testRevert_RefundHabitThatStillHasStake() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Running", 0.5 ether);
        
        // Habit still has stake (not slashed)
        vm.prank(user1);
        vm.expectRevert(HabitChain.HabitNotSlashed.selector);
        habitChain.refundHabit(habitId, 0.5 ether);
    }

    function testRevert_RefundWithInsufficientBalance() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Swimming", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.startPrank(user1);
        
        // Available balance is ~0.5 ETH, try to refund with 2 ETH
        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.refundHabit(habitId, 2 ether);
        
        vm.stopPrank();
    }

    function testRevert_RefundWithBelowMinStake() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Cycling", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.prank(user1);
        vm.expectRevert(HabitChain.InsufficientStake.selector);
        habitChain.refundHabit(habitId, 0.0001 ether);
    }

    function testRevert_RefundOtherUsersHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Cooking", 0.3 ether);
        
        habitChain.globalSettle();
        
        vm.startPrank(user2);
        habitChain.deposit{ value: 1 ether }();
        
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.refundHabit(habitId, 0.3 ether);
        
        vm.stopPrank();
    }

    function testRevert_RefundInactiveHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Writing", 0.3 ether);
        
        vm.startPrank(user1);
        
        // Force settle makes it inactive
        habitChain.forceSettle(habitId, true);
        
        vm.expectRevert(HabitChain.HabitNotActive.selector);
        habitChain.refundHabit(habitId, 0.3 ether);
        
        vm.stopPrank();
    }

    function testRevert_RefundNonExistentHabit() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 1 ether }();
        
        vm.expectRevert(HabitChain.HabitNotFound.selector);
        habitChain.refundHabit(999, 0.5 ether);
        
        vm.stopPrank();
    }

    function test_VerifyBalanceDeductionAfterRefund() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Guitar", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.startPrank(user1);
        
        uint256 balanceBefore = habitChain.getUserBalance(user1);
        uint256 refundAmount = 0.6 ether;
        
        habitChain.refundHabit(habitId, refundAmount);
        
        uint256 balanceAfter = habitChain.getUserBalance(user1);
        
        assertApproxEqAbs(balanceBefore - balanceAfter, refundAmount, 1e15, "Balance should decrease by refund amount");
        
        vm.stopPrank();
    }

    function test_VerifyATokenAmountAndLiquidityIndexUpdate() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Drawing", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.prank(user1);
        habitChain.refundHabit(habitId, 0.7 ether);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        
        assertGt(habit.aTokenAmount, 0, "aToken amount should be set");
        assertGt(habit.liquidityIndex, 0, "Liquidity index should be set");
        assertApproxEqAbs(habit.aTokenAmount, 0.7 ether, 1e15, "aToken amount should match refund");
    }

    function test_HabitRefundedEventEmission() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Language", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.prank(user1);
        
        uint256 refundAmount = 0.5 ether;
        
        vm.expectEmit(true, true, false, true);
        emit HabitRefunded(habitId, user1, refundAmount, block.timestamp);
        
        habitChain.refundHabit(habitId, refundAmount);
    }

    function test_CheckInAfterRefundingHabit() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Exercise", 0.5 ether);
        
        // Slash the habit
        habitChain.globalSettle();
        
        vm.startPrank(user1);
        
        // Refund the habit
        habitChain.refundHabit(habitId, 0.5 ether);
        
        // Should be able to check in after refund
        habitChain.checkIn(habitId);
        
        assertEq(getHabit(habitId).checkInCount, 1, "Should be able to check in");
        
        vm.stopPrank();
    }

    function test_RefundMultipleSlashedHabits() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 5 ether }();
        
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.5 ether);
        uint256 habit3 = habitChain.createHabit("Habit 3", 0.5 ether);
        
        vm.stopPrank();
        
        // Slash all habits
        habitChain.globalSettle();
        
        vm.startPrank(user1);
        
        // Refund all three habits
        habitChain.refundHabit(habit1, 0.5 ether);
        habitChain.refundHabit(habit2, 0.6 ether);
        habitChain.refundHabit(habit3, 0.4 ether);
        
        assertEq(getHabit(habit1).stakeAmount, 0.5 ether);
        assertEq(getHabit(habit2).stakeAmount, 0.6 ether);
        assertEq(getHabit(habit3).stakeAmount, 0.4 ether);
        
        vm.stopPrank();
    }

    function test_RefundAndImmediatelyCheckIn() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Running", 0.5 ether);
        
        habitChain.globalSettle();
        
        vm.startPrank(user1);
        
        habitChain.refundHabit(habitId, 0.5 ether);
        habitChain.checkIn(habitId);
        
        assertEq(getHabit(habitId).checkInCount, 1);
        assertEq(getHabit(habitId).stakeAmount, 0.5 ether);
        
        vm.stopPrank();
    }
}

