// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainCreateHabitTest
 * @notice Tests for habit creation functionality
 */
contract HabitChainCreateHabitTest is HabitChainBaseTest {
    function test_CreateHabitWithValidNameAndStake() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 2 ether }();
        
        string memory habitName = "Morning Meditation";
        uint256 stakeAmount = 0.5 ether;
        
        vm.expectEmit(true, true, false, false);
        emit HabitCreated(1, user1, habitName, stakeAmount, block.timestamp);
        
        uint256 habitId = habitChain.createHabit(habitName, stakeAmount);
        
        assertEq(habitId, 1, "First habit should have ID 1");
        
        HabitChain.Habit memory habit = getHabit(habitId);
        assertEq(habit.id, habitId);
        assertEq(habit.user, user1);
        assertEq(habit.name, habitName);
        assertEq(habit.stakeAmount, stakeAmount);
        assertTrue(habit.isActive);
        assertFalse(habit.isSettled);
        assertEq(habit.checkInCount, 0);
        assertEq(habit.lastCheckIn, 0);

        vm.stopPrank();
    }

    function testRevert_EmptyName() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        vm.expectRevert(HabitChain.EmptyHabitName.selector);
        habitChain.createHabit("", 0.1 ether);

        vm.stopPrank();
    }

    function testRevert_BelowMinimumStake() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        vm.expectRevert(HabitChain.InsufficientStake.selector);
        habitChain.createHabit("Low Stake Habit", 0.0001 ether);

        vm.stopPrank();
    }

    function test_StakeExactlyMinStake() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        uint256 minStake = 0.001 ether;
        uint256 habitId = habitChain.createHabit("Min Stake Habit", minStake);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        assertEq(habit.stakeAmount, minStake);

        vm.stopPrank();
    }

    function testRevert_InsufficientUserBalance() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 0.5 ether }();
        
        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.createHabit("Expensive Habit", 1 ether);

        vm.stopPrank();
    }

    function test_CreateMultipleHabitsFromSameUser() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 5 ether }();
        
        uint256 habit1 = habitChain.createHabit("Running", 1 ether);
        uint256 habit2 = habitChain.createHabit("Reading", 1 ether);
        uint256 habit3 = habitChain.createHabit("Meditation", 1 ether);
        
        assertEq(habit1, 1);
        assertEq(habit2, 2);
        assertEq(habit3, 3);
        
        uint256[] memory userHabits = habitChain.getUserHabits(user1);
        assertEq(userHabits.length, 3);
        assertEq(userHabits[0], habit1);
        assertEq(userHabits[1], habit2);
        assertEq(userHabits[2], habit3);

        vm.stopPrank();
    }

    function test_VeryLongHabitName() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        // Create a 500 character habit name
        string memory longName = "This is a very long habit name that tests the limits of what can be stored in a string. It contains many characters and should still work correctly even though it is extremely verbose and unnecessarily detailed. We want to make sure that the contract can handle habit names of various lengths without any issues. This is important for ensuring that users have flexibility in naming their habits. The contract should be able to store and retrieve this long name without any problems. Here we continue to add more text to reach our goal of a very long string.";
        
        uint256 habitId = habitChain.createHabit(longName, 0.1 ether);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        assertEq(habit.name, longName);

        vm.stopPrank();
    }

    function test_SpecialCharactersInHabitName() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        string memory specialName = "Run 5km @6am #fitness $health 100% effort! (daily) [goal]";
        uint256 habitId = habitChain.createHabit(specialName, 0.1 ether);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        assertEq(habit.name, specialName);

        vm.stopPrank();
    }

    function test_VerifyBalanceDeduction() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 3 ether }();
        uint256 balanceBefore = habitChain.getUserBalance(user1);
        
        uint256 stakeAmount = 1 ether;
        habitChain.createHabit("Exercise", stakeAmount);
        
        uint256 balanceAfter = habitChain.getUserBalance(user1);
        
        assertApproxEqAbs(balanceBefore - balanceAfter, stakeAmount, 1e15, "Balance should decrease by stake amount");

        vm.stopPrank();
    }

    function test_VerifyHabitStructInitialization() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 2 ether }();
        
        string memory name = "Yoga Practice";
        uint256 stake = 0.5 ether;
        uint256 timestampBefore = block.timestamp;
        
        uint256 habitId = habitChain.createHabit(name, stake);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        
        assertEq(habit.id, habitId, "ID should match");
        assertEq(habit.user, user1, "User should match");
        assertEq(habit.name, name, "Name should match");
        assertEq(habit.stakeAmount, stake, "Stake amount should match");
        assertTrue(habit.isActive, "Should be active");
        assertFalse(habit.isSettled, "Should not be settled");
        assertEq(habit.checkInCount, 0, "Check-in count should be 0");
        assertEq(habit.lastCheckIn, 0, "Last check-in should be 0");
        assertEq(habit.createdAt, timestampBefore, "Created timestamp should match");

        vm.stopPrank();
    }

    function test_VerifyATokenAmountAndLiquidityIndex() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 2 ether }();
        
        uint256 stakeAmount = 1 ether;
        uint256 habitId = habitChain.createHabit("Swimming", stakeAmount);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        
        assertGt(habit.aTokenAmount, 0, "aToken amount should be set");
        assertGt(habit.liquidityIndex, 0, "Liquidity index should be captured");
        assertApproxEqAbs(habit.aTokenAmount, stakeAmount, 1e15, "aToken amount should match stake");

        vm.stopPrank();
    }

    function test_VerifyHabitAddedToUserHabitsArray() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 3 ether }();
        
        uint256[] memory habitsBefore = habitChain.getUserHabits(user1);
        assertEq(habitsBefore.length, 0, "Should start with no habits");
        
        uint256 habitId = habitChain.createHabit("Cycling", 1 ether);
        
        uint256[] memory habitsAfter = habitChain.getUserHabits(user1);
        assertEq(habitsAfter.length, 1, "Should have one habit");
        assertEq(habitsAfter[0], habitId, "Habit ID should match");

        vm.stopPrank();
    }

    function test_HabitCreatedEventEmission() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        string memory name = "Guitar Practice";
        uint256 stake = 0.2 ether;
        
        vm.expectEmit(true, true, false, false);
        emit HabitCreated(1, user1, name, stake, block.timestamp);
        
        habitChain.createHabit(name, stake);

        vm.stopPrank();
    }

    function test_SequentialHabitIds() public {
        vm.startPrank(user1);
        habitChain.deposit{ value: 3 ether }();
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        habitChain.deposit{ value: 3 ether }();
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.5 ether);
        vm.stopPrank();

        vm.startPrank(user3);
        habitChain.deposit{ value: 3 ether }();
        uint256 habit3 = habitChain.createHabit("Habit 3", 0.5 ether);
        vm.stopPrank();

        assertEq(habit1, 1);
        assertEq(habit2, 2);
        assertEq(habit3, 3);
    }
}

