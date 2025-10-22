// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainForceSettleTest
 * @notice Tests for force settlement functionality
 */
contract HabitChainForceSettleTest is HabitChainBaseTest {
    function test_SuccessfulSettlement() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Exercise", 0.5 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        
        uint256 balanceBefore = habitChain.getUserBalance(user1);
        
        habitChain.forceSettle(habitId, true);
        
        uint256 balanceAfter = habitChain.getUserBalance(user1);
        
        // User should receive at least their stake back
        assertGe(balanceAfter, balanceBefore + 0.5 ether - 1e15, "Should receive stake back");
        
        vm.stopPrank();
    }

    function test_FailedSettlement() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Reading", 0.5 ether);
        
        vm.startPrank(user1);
        
        uint256 userBalanceBefore = habitChain.getUserBalance(user1);
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        // Settle without checking in (failure)
        habitChain.forceSettle(habitId, false);
        
        uint256 userBalanceAfter = habitChain.getUserBalance(user1);
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        
        // User balance should remain the same
        assertEq(userBalanceAfter, userBalanceBefore, "User balance unchanged on failure");
        
        // Treasury should receive the slashed amount
        assertGt(treasuryAfter, treasuryBefore, "Treasury should increase");
        
        vm.stopPrank();
    }

    function test_SettlementMarksHabitAsInactive() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Meditation", 0.3 ether);
        
        vm.startPrank(user1);
        
        assertTrue(getHabit(habitId).isActive, "Should be active before settlement");
        
        habitChain.forceSettle(habitId, true);
        
        assertFalse(getHabit(habitId).isActive, "Should be inactive after settlement");
        
        vm.stopPrank();
    }

    function test_SettlementMarksHabitAsSettled() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Yoga", 0.4 ether);
        
        vm.startPrank(user1);
        
        assertFalse(getHabit(habitId).isSettled, "Should not be settled before settlement");
        
        habitChain.forceSettle(habitId, true);
        
        assertTrue(getHabit(habitId).isSettled, "Should be settled after settlement");
        
        vm.stopPrank();
    }

    function test_SuccessfulSettlementReturnsFundsWithYield() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Running", 1 ether);
        
        vm.startPrank(user1);
        
        // Simulate time passing for yield accrual
        skipDays(30);
        
        uint256 balanceBefore = habitChain.getUserBalance(user1);
        
        habitChain.forceSettle(habitId, true);
        
        uint256 balanceAfter = habitChain.getUserBalance(user1);
        uint256 received = balanceAfter - balanceBefore;
        
        // Should receive at least the stake amount (possibly more with yield)
        assertGe(received, 1 ether - 1e15, "Should receive at least stake amount");
        
        vm.stopPrank();
    }

    function test_FailedSettlementSendsFundsWithYieldToTreasury() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Swimming", 1 ether);
        
        vm.startPrank(user1);
        
        // Simulate time passing for yield accrual
        skipDays(30);
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        habitChain.forceSettle(habitId, false);
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        uint256 treasuryReceived = treasuryAfter - treasuryBefore;
        
        // Treasury should receive at least the stake amount
        assertGe(treasuryReceived, 1 ether - 1e15, "Treasury should receive at least stake");
        
        vm.stopPrank();
    }

    function testRevert_SettleAlreadySettledHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Cycling", 0.3 ether);
        
        vm.startPrank(user1);
        
        habitChain.forceSettle(habitId, true);
        
        // Try to settle again
        vm.expectRevert(HabitChain.HabitAlreadySettled.selector);
        habitChain.forceSettle(habitId, true);
        
        vm.stopPrank();
    }

    function testRevert_SettleInactiveHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Cooking", 0.3 ether);
        
        vm.startPrank(user1);
        
        // First settlement makes it inactive
        habitChain.forceSettle(habitId, true);
        
        // Try to settle inactive habit
        vm.expectRevert(HabitChain.HabitAlreadySettled.selector);
        habitChain.forceSettle(habitId, false);
        
        vm.stopPrank();
    }

    function testRevert_SettleOtherUsersHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Writing", 0.3 ether);
        
        // User2 tries to settle user1's habit
        vm.prank(user2);
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.forceSettle(habitId, true);
    }

    function testRevert_SettleNonExistentHabit() public {
        vm.prank(user1);
        vm.expectRevert(HabitChain.HabitNotFound.selector);
        habitChain.forceSettle(999, true);
    }

    function test_HabitSettledEventWithCorrectParameters() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Guitar", 0.3 ether);
        
        vm.startPrank(user1);
        
        // We can't predict exact values due to Aave yield, but we can verify the event is emitted
        vm.expectEmit(true, true, true, false);
        emit HabitSettled(habitId, user1, true, 0, 0, block.timestamp);
        
        habitChain.forceSettle(habitId, true);
        
        vm.stopPrank();
    }

    function test_TreasuryFundedEventOnFailure() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Drawing", 0.3 ether);
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, false);
        emit TreasuryFunded(habitId, 0);
        
        habitChain.forceSettle(habitId, false);
        
        vm.stopPrank();
    }

    function test_SettlementAfterSignificantYieldAccrual() public {
        uint256 habitId = setupBasicHabit(user1, 5 ether, "Language", 2 ether);
        
        vm.startPrank(user1);
        
        // Simulate 1 year passing
        skipDays(365);
        
        uint256 balanceBefore = habitChain.getUserBalance(user1);
        
        habitChain.forceSettle(habitId, true);
        
        uint256 balanceAfter = habitChain.getUserBalance(user1);
        uint256 received = balanceAfter - balanceBefore;
        
        // Should receive at least the original stake
        assertGe(received, 2 ether - 1e15, "Should receive at least original stake");
        
        vm.stopPrank();
    }

    function test_MultipleSettlementsFromSameUser() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 5 ether }();
        
        uint256 habit1 = habitChain.createHabit("Habit 1", 1 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 1 ether);
        uint256 habit3 = habitChain.createHabit("Habit 3", 1 ether);
        
        habitChain.forceSettle(habit1, true);
        habitChain.forceSettle(habit2, false);
        habitChain.forceSettle(habit3, true);
        
        assertTrue(getHabit(habit1).isSettled);
        assertTrue(getHabit(habit2).isSettled);
        assertTrue(getHabit(habit3).isSettled);
        
        vm.stopPrank();
    }
}

