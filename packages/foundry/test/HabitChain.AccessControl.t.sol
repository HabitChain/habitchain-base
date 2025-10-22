// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainAccessControlTest
 * @notice Tests for access control and edge cases
 */
contract HabitChainAccessControlTest is HabitChainBaseTest {
    function testRevert_CheckInNotHabitOwner() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "User1 Habit", 0.5 ether);
        
        vm.prank(user2);
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.checkIn(habitId);
    }

    // Note: testRevert_SettleNotHabitOwner removed - natural settle can be called by anyone

    function testRevert_RefundNotHabitOwner() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "User1 Habit", 0.5 ether);
        
        habitChain.naturalSettle();
        
        vm.startPrank(user2);
        habitChain.deposit{ value: 1 ether }();
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.refundHabit(habitId, 0.5 ether);
        vm.stopPrank();
    }

    function testRevert_CheckInHabitNotFound() public {
        vm.prank(user1);
        vm.expectRevert(HabitChain.HabitNotFound.selector);
        habitChain.checkIn(9999);
    }

    function testRevert_CheckInHabitIdZero() public {
        vm.prank(user1);
        vm.expectRevert(HabitChain.HabitNotFound.selector);
        habitChain.checkIn(0);
    }

    // Note: testRevert_SettleHabitNotFound removed - natural settle handles missing habits gracefully

    function testRevert_RefundHabitNotFound() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 1 ether }();
        vm.expectRevert(HabitChain.HabitNotFound.selector);
        habitChain.refundHabit(9999, 0.5 ether);
        vm.stopPrank();
    }

    function testRevert_TreasuryWithdrawNonTreasuryAddress() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Habit", 0.5 ether);
        
        // Don't check in, wait past deadline
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        vm.prank(user1);
        vm.expectRevert("Only treasury can withdraw");
        habitChain.withdrawTreasury(0.1 ether);
        
        vm.prank(user2);
        vm.expectRevert("Only treasury can withdraw");
        habitChain.withdrawTreasury(0.1 ether);
    }

    function test_HabitWithVeryLargeStake() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 150 ether }();
        
        uint256 habitId = habitChain.createHabit("Large Stake Habit", 100 ether);
        
        assertEq(getHabit(habitId).stakeAmount, 100 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 50 ether, 1e15, "Remaining balance");
        
        vm.stopPrank();
    }

    function test_HabitWithMinimumStake() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 1 ether }();
        
        uint256 minStake = 0.001 ether;
        uint256 habitId = habitChain.createHabit("Min Stake Habit", minStake);
        
        assertEq(getHabit(habitId).stakeAmount, minStake);
        
        vm.stopPrank();
    }

    function test_VeryLongHabitName() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 1 ether }();
        
        // Create 1000+ character habit name
        string memory longName = "A";
        for (uint256 i = 0; i < 10; i++) {
            longName = string(abi.encodePacked(longName, longName));
        }
        
        uint256 habitId = habitChain.createHabit(longName, 0.1 ether);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        assertTrue(bytes(habit.name).length > 1000, "Name should be very long");
        
        vm.stopPrank();
    }

    function test_TimeBoundaryExactly1Day() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        
        // Advance exactly 1 day (86400 seconds)
        skipSeconds(86400);
        
        // Should be able to check in
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 2);
        
        vm.stopPrank();
    }

    function testRevert_TimeBoundary1DayMinus1Second() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        
        // Advance 1 day - 1 second (86399 seconds)
        skipSeconds(86399);
        
        // Should NOT be able to check in
        vm.expectRevert(HabitChain.AlreadyCheckedInToday.selector);
        habitChain.checkIn(habitId);
        
        vm.stopPrank();
    }

    function test_TimeBoundary1DayPlus1Second() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        
        // Advance 1 day + 1 second (86401 seconds)
        skipSeconds(86401);
        
        // Should be able to check in
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 2);
        
        vm.stopPrank();
    }

    function test_SequentialHabitIdGeneration() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 5 ether }();
        uint256 h1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 h2 = habitChain.createHabit("Habit 2", 0.5 ether);
        uint256 h3 = habitChain.createHabit("Habit 3", 0.5 ether);
        vm.stopPrank();
        
        vm.startPrank(user2);
        habitChain.deposit{ value: 5 ether }();
        uint256 h4 = habitChain.createHabit("Habit 4", 0.5 ether);
        uint256 h5 = habitChain.createHabit("Habit 5", 0.5 ether);
        vm.stopPrank();
        
        assertEq(h1, 1);
        assertEq(h2, 2);
        assertEq(h3, 3);
        assertEq(h4, 4);
        assertEq(h5, 5);
    }

    // Note: testRevert_OperationsOnHabitAfterSettlement removed - natural settle keeps habits active
    // Note: testRevert_DoubleSettlementAttempts removed - permanent settlement no longer exists

    function test_MultipleHabitsAcrossAllUsers() public {
        // Stress test with many habits from different users
        
        vm.startPrank(user1);
        habitChain.deposit{ value: 10 ether }();
        for (uint256 i = 0; i < 5; i++) {
            habitChain.createHabit(string(abi.encodePacked("U1H", i)), 0.5 ether);
        }
        vm.stopPrank();
        
        vm.startPrank(user2);
        habitChain.deposit{ value: 10 ether }();
        for (uint256 i = 0; i < 5; i++) {
            habitChain.createHabit(string(abi.encodePacked("U2H", i)), 0.5 ether);
        }
        vm.stopPrank();
        
        vm.startPrank(user3);
        habitChain.deposit{ value: 10 ether }();
        for (uint256 i = 0; i < 5; i++) {
            habitChain.createHabit(string(abi.encodePacked("U3H", i)), 0.5 ether);
        }
        vm.stopPrank();
        
        // Verify all habits were created
        assertEq(habitChain.getUserHabits(user1).length, 5);
        assertEq(habitChain.getUserHabits(user2).length, 5);
        assertEq(habitChain.getUserHabits(user3).length, 5);
        
        assertEq(habitChain.getUserActiveHabitsCount(user1), 5);
        assertEq(habitChain.getUserActiveHabitsCount(user2), 5);
        assertEq(habitChain.getUserActiveHabitsCount(user3), 5);
    }

    function test_EdgeCaseZeroBalanceOperations() public {
        vm.startPrank(user1);
        
        // User has zero balance
        assertEq(habitChain.getUserBalance(user1), 0);
        
        // Cannot create habit with zero balance
        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.createHabit("Habit", 0.1 ether);
        
        // Cannot withdraw with zero balance
        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.withdraw(0.1 ether);
        
        vm.stopPrank();
    }

    function test_EmptyStringOperations() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 1 ether }();
        
        // Empty habit name should revert
        vm.expectRevert(HabitChain.EmptyHabitName.selector);
        habitChain.createHabit("", 0.1 ether);
        
        vm.stopPrank();
    }

    function test_GetHabitCurrentValueOnNonExistentHabit() public {
        (uint256 value, uint256 yield) = habitChain.getHabitCurrentValue(9999);
        
        assertEq(value, 0, "Non-existent habit should return 0 value");
        assertEq(yield, 0, "Non-existent habit should return 0 yield");
    }

    // Note: test_GetHabitCurrentValueOnSettledHabit removed - permanent settlement no longer exists

    function test_GetHabitCurrentValueOnSlashedHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        habitChain.naturalSettle();
        
        (uint256 value, uint256 yield) = habitChain.getHabitCurrentValue(habitId);
        
        assertEq(value, 0, "Slashed habit should return 0 value");
        assertEq(yield, 0, "Slashed habit should return 0 yield");
    }
}

