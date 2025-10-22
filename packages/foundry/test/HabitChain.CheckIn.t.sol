// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainCheckInTest
 * @notice Tests for check-in functionality
 */
contract HabitChainCheckInTest is HabitChainBaseTest {
    function test_FirstCheckIn() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        vm.prank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit CheckInCompleted(habitId, user1, block.timestamp, 1);
        
        habitChain.checkIn(habitId);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        assertEq(habit.checkInCount, 1, "Check-in count should be 1");
        assertEq(habit.lastCheckIn, block.timestamp, "Last check-in should be current timestamp");
    }

    function test_CheckInUpdatesLastCheckInTimestamp() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Reading", 0.3 ether);
        
        uint256 timestampBefore = block.timestamp;
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        assertEq(habit.lastCheckIn, timestampBefore, "Timestamp should be set");
    }

    function test_CheckInIncrementsCheckInCount() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Meditation", 0.5 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 1);
        
        skipDays(1);
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 2);
        
        skipDays(1);
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 3);
        
        vm.stopPrank();
    }

    function testRevert_SameDayDuplicateCheckIn() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Running", 0.4 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        
        // Try to check in again immediately
        vm.expectRevert(HabitChain.AlreadyCheckedInToday.selector);
        habitChain.checkIn(habitId);
        
        vm.stopPrank();
    }

    function test_CheckInNextDay() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Writing", 0.3 ether);
        
        vm.startPrank(user1);
        
        // First check-in
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 1);
        
        // Advance exactly 1 day
        skipDays(1);
        
        // Second check-in should succeed
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 2);
        
        vm.stopPrank();
    }

    function test_CheckInAfterMissingSeveralDays() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Yoga", 0.2 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        
        // Skip 7 days
        skipDays(7);
        
        // Should still be able to check in
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 2);
        
        vm.stopPrank();
    }

    function testRevert_CheckInOnInactiveHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Swimming", 0.5 ether);
        
        vm.startPrank(user1);
        
        // Settle the habit (makes it inactive)
        habitChain.forceSettle(habitId, true);
        
        // Try to check in on inactive habit
        vm.expectRevert(HabitChain.HabitNotActive.selector);
        habitChain.checkIn(habitId);
        
        vm.stopPrank();
    }

    function testRevert_CheckInOnSettledHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Cycling", 0.4 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        habitChain.forceSettle(habitId, true);
        
        // Habit is now settled and inactive
        vm.expectRevert(HabitChain.HabitNotActive.selector);
        habitChain.checkIn(habitId);
        
        vm.stopPrank();
    }

    function testRevert_CheckInOtherUsersHabit() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Cooking", 0.3 ether);
        
        // User2 tries to check in user1's habit
        vm.prank(user2);
        vm.expectRevert(HabitChain.NotHabitOwner.selector);
        habitChain.checkIn(habitId);
    }

    function testRevert_CheckInNonExistentHabit() public {
        vm.prank(user1);
        vm.expectRevert(HabitChain.HabitNotFound.selector);
        habitChain.checkIn(999);
    }

    function test_CheckInExactlyAt24HourBoundary() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Drawing", 0.2 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        uint256 firstCheckIn = block.timestamp;
        
        // Advance exactly 24 hours (86400 seconds)
        skipSeconds(86400);
        
        // Should be able to check in
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 2);
        
        vm.stopPrank();
    }

    function test_MultipleConsecutiveDailyCheckIns() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Journal", 0.3 ether);
        
        vm.startPrank(user1);
        
        for (uint256 i = 1; i <= 7; i++) {
            habitChain.checkIn(habitId);
            assertEq(getHabit(habitId).checkInCount, i);
            
            if (i < 7) {
                skipDays(1);
            }
        }
        
        vm.stopPrank();
    }

    function test_CheckInCompletedEventEmission() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Stretching", 0.2 ether);
        
        vm.prank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit CheckInCompleted(habitId, user1, block.timestamp, 1);
        
        habitChain.checkIn(habitId);
    }

    function testRevert_CheckInWithin24Hours() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Language", 0.3 ether);
        
        vm.startPrank(user1);
        
        habitChain.checkIn(habitId);
        
        // Try after 23 hours (should fail)
        skipHours(23);
        vm.expectRevert(HabitChain.AlreadyCheckedInToday.selector);
        habitChain.checkIn(habitId);
        
        // Try after 24 hours (should succeed)
        skipHours(1);
        habitChain.checkIn(habitId);
        assertEq(getHabit(habitId).checkInCount, 2);
        
        vm.stopPrank();
    }
}

