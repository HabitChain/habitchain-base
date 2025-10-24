// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChain Settlement Lock Tests
 * @notice Tests for the settlement-locking mechanism that prevents check-ins until previous cycles are settled
 */
contract HabitChainSettlementLockTest is HabitChainBaseTest {
    /**
     * @notice Test that habits created in Cycle 0 can check in during Cycle 0
     */
    function test_CanCheckInDuringCycle0() public {
        // Setup: Deposit and create habit in Cycle 0
        uint256 depositAmount = 1 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habitId = habitChain.createHabit("Morning Run", stakeAmount);
        
        // Verify we're in Cycle 0
        assertEq(habitChain.getCurrentCycle(), 0, "Should be in Cycle 0");
        
        // Should be able to check in immediately
        habitChain.checkIn(habitId);
        
        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.lastCheckInCycle, 0, "Should have checked in during Cycle 0");
        assertEq(habit.checkInCount, 1, "Check-in count should be 1");
        
        vm.stopPrank();
    }

    /**
     * @notice Test that habits are locked after cycle ends until settlement
     */
    function test_HabitLockedAfterCycleEndsUntilSettlement() public {
        // Setup: Create habit in Cycle 0 but DON'T check in
        uint256 depositAmount = 1 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habitId = habitChain.createHabit("Morning Run", stakeAmount);
        
        // Verify we're in Cycle 0
        assertEq(habitChain.getCurrentCycle(), 0, "Should be in Cycle 0");
        
        // DON'T check in during Cycle 0
        
        // Advance to Cycle 1 (move forward by checkInPeriod)
        vm.warp(block.timestamp + 1 days);
        assertEq(habitChain.getCurrentCycle(), 1, "Should be in Cycle 1");
        
        // Try to check in during Cycle 1 - should FAIL because Cycle 0 hasn't been settled
        vm.expectRevert(HabitChain.MustSettlePreviousCycle.selector);
        habitChain.checkIn(habitId);
        
        vm.stopPrank();
    }

    /**
     * @notice Test that after settlement, habit can check in again (if not slashed)
     */
    function test_CanCheckInAfterSuccessfulSettlement() public {
        // Setup: Create habit in Cycle 0 and check in
        uint256 depositAmount = 1 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habitId = habitChain.createHabit("Morning Run", stakeAmount);
        
        // Check in during Cycle 0
        habitChain.checkIn(habitId);
        
        // Advance to Cycle 1
        vm.warp(block.timestamp + 1 days);
        assertEq(habitChain.getCurrentCycle(), 1, "Should be in Cycle 1");
        
        // Settle Cycle 0
        habitChain.naturalSettle();
        
        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.lastSettledCycle, 0, "Should have settled Cycle 0");
        assertEq(habit.stakeAmount, stakeAmount, "Stake should still be intact (successful)");
        
        // Now should be able to check in during Cycle 1
        habitChain.checkIn(habitId);
        
        habit = habitChain.getHabit(habitId);
        assertEq(habit.lastCheckInCycle, 1, "Should have checked in during Cycle 1");
        assertEq(habit.checkInCount, 2, "Check-in count should be 2");
        
        vm.stopPrank();
    }

    /**
     * @notice Test that after settlement, slashed habit cannot check in (must refund first)
     */
    function test_CannotCheckInAfterFailedSettlement() public {
        // Setup: Create habit in Cycle 0 but DON'T check in
        uint256 depositAmount = 1 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habitId = habitChain.createHabit("Morning Run", stakeAmount);
        
        // DON'T check in during Cycle 0
        
        // Advance to Cycle 1
        vm.warp(block.timestamp + 1 days);
        assertEq(habitChain.getCurrentCycle(), 1, "Should be in Cycle 1");
        
        // Settle Cycle 0 (should fail because no check-in)
        habitChain.naturalSettle();
        
        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.lastSettledCycle, 0, "Should have settled Cycle 0");
        assertEq(habit.stakeAmount, 0, "Stake should be slashed (failed)");
        
        // Try to check in - should fail because habit is slashed
        vm.expectRevert(HabitChain.HabitNotSlashed.selector);
        habitChain.checkIn(habitId);
        
        vm.stopPrank();
    }

    /**
     * @notice Test that refunded habit can check in again
     */
    function test_CanCheckInAfterRefund() public {
        // Setup: Create habit, fail settlement, then refund
        uint256 depositAmount = 2 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habitId = habitChain.createHabit("Morning Run", stakeAmount);
        
        // DON'T check in during Cycle 0
        
        // Advance to Cycle 1
        vm.warp(block.timestamp + 1 days);
        
        // Settle (will slash the habit)
        habitChain.naturalSettle();
        
        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.stakeAmount, 0, "Habit should be slashed");
        
        // Refund the habit
        habitChain.refundHabit(habitId, stakeAmount);
        
        habit = habitChain.getHabit(habitId);
        assertEq(habit.stakeAmount, stakeAmount, "Stake should be restored");
        assertEq(habit.lastSettledCycle, 0, "lastSettledCycle should be reset to allow check-in in Cycle 1");
        
        // Now should be able to check in during Cycle 1
        habitChain.checkIn(habitId);
        
        habit = habitChain.getHabit(habitId);
        assertEq(habit.lastCheckInCycle, 1, "Should have checked in during Cycle 1");
        
        vm.stopPrank();
    }

    /**
     * @notice Test multiple cycles: check in, settle, check in, settle
     */
    function test_MultipleCyclesCheckInAndSettle() public {
        uint256 depositAmount = 1 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habitId = habitChain.createHabit("Morning Run", stakeAmount);
        
        // Cycle 0: Check in
        habitChain.checkIn(habitId);
        assertEq(habitChain.getCurrentCycle(), 0);
        
        // Move to Cycle 1
        vm.warp(block.timestamp + 1 days);
        assertEq(habitChain.getCurrentCycle(), 1);
        
        // Settle Cycle 0 (success)
        habitChain.naturalSettle();
        
        // Check in during Cycle 1
        habitChain.checkIn(habitId);
        
        // Move to Cycle 2
        vm.warp(block.timestamp + 1 days);
        assertEq(habitChain.getCurrentCycle(), 2);
        
        // Settle Cycle 1 (success)
        habitChain.naturalSettle();
        
        // Check in during Cycle 2
        habitChain.checkIn(habitId);
        
        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.checkInCount, 3, "Should have 3 check-ins");
        assertEq(habit.lastSettledCycle, 1, "Should have settled Cycle 1");
        assertEq(habit.lastCheckInCycle, 2, "Should have checked in Cycle 2");
        
        vm.stopPrank();
    }

    /**
     * @notice Test that settlement settles only ONE cycle at a time per habit
     */
    function test_SettlementProcessesOneCycleAtATime() public {
        uint256 depositAmount = 1 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habitId = habitChain.createHabit("Morning Run", stakeAmount);
        
        // Check in during Cycle 0
        habitChain.checkIn(habitId);
        
        // Skip ahead 3 cycles without settling
        vm.warp(block.timestamp + 3 days);
        assertEq(habitChain.getCurrentCycle(), 3);
        
        HabitChain.Habit memory habit = habitChain.getHabit(habitId);
        assertEq(habit.lastSettledCycle, type(uint256).max, "Should still have lastSettledCycle = max (sentinel) before first settle");
        
        // First settle: should settle Cycle 0 only
        habitChain.naturalSettle();
        habit = habitChain.getHabit(habitId);
        assertEq(habit.lastSettledCycle, 0, "Should have settled Cycle 0");
        assertEq(habit.stakeAmount, stakeAmount, "Cycle 0 was successful (checked in)");
        
        // Second settle: should settle Cycle 1 (which had no check-in)
        habitChain.naturalSettle();
        habit = habitChain.getHabit(habitId);
        assertEq(habit.lastSettledCycle, 1, "Should have settled Cycle 1");
        assertEq(habit.stakeAmount, 0, "Cycle 1 failed (no check-in), should be slashed");
        
        vm.stopPrank();
    }

    /**
     * @notice Test two habits with different check-in patterns
     */
    function test_TwoHabitsDifferentPatterns() public {
        uint256 depositAmount = 2 ether;
        uint256 stakeAmount = 0.5 ether;
        
        vm.startPrank(user1);
        vm.deal(user1, depositAmount);
        
        habitChain.deposit{value: depositAmount}();
        uint256 habit1 = habitChain.createHabit("Morning Run", stakeAmount);
        uint256 habit2 = habitChain.createHabit("Evening Gym", stakeAmount);
        
        // Cycle 0: Check in only habit1
        habitChain.checkIn(habit1);
        // habit2 has no check-in
        
        // Move to Cycle 1
        vm.warp(block.timestamp + 1 days);
        
        // Try to check in habit2 - should fail (must settle first)
        vm.expectRevert(HabitChain.MustSettlePreviousCycle.selector);
        habitChain.checkIn(habit2);
        
        // Settle Cycle 0
        habitChain.naturalSettle();
        
        // Check results
        HabitChain.Habit memory h1 = habitChain.getHabit(habit1);
        HabitChain.Habit memory h2 = habitChain.getHabit(habit2);
        
        assertEq(h1.stakeAmount, stakeAmount, "Habit1 should keep stake (checked in)");
        assertEq(h2.stakeAmount, 0, "Habit2 should be slashed (no check-in)");
        
        // Habit1 can check in during Cycle 1
        habitChain.checkIn(habit1);
        
        // Habit2 cannot check in (slashed)
        vm.expectRevert(HabitChain.HabitNotSlashed.selector);
        habitChain.checkIn(habit2);
        
        vm.stopPrank();
    }
}

