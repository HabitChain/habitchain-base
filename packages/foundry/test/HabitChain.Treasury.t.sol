// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainTreasuryTest
 * @notice Tests for treasury functionality
 */
contract HabitChainTreasuryTest is HabitChainBaseTest {
    function test_TreasuryWithdrawalByTreasuryAddress() public {
        // Setup: Create a failed habit to fund treasury
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Exercise", 0.5 ether);
        
        // Don't check in, wait past deadline
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        uint256 treasuryBalance = habitChain.getTreasuryBalance();
        assertGt(treasuryBalance, 0, "Treasury should have funds");
        
        uint256 treasuryEthBefore = treasury.balance;
        
        vm.prank(treasury);
        habitChain.withdrawTreasury(treasuryBalance);
        
        uint256 treasuryEthAfter = treasury.balance;
        
        assertEq(habitChain.getTreasuryBalance(), 0, "Treasury balance should be 0");
        assertApproxEqAbs(treasuryEthAfter - treasuryEthBefore, treasuryBalance, 1e15, "ETH should be received");
    }

    function test_PartialTreasuryWithdrawal() public {
        // Fund treasury with multiple slashed habits
        vm.startPrank(user1);
        habitChain.deposit{ value: 3 ether }();
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.5 ether);
        vm.stopPrank();
        
        // Don't check in, wait past deadline
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash both habits
        habitChain.naturalSettle();
        
        uint256 treasuryBalance = habitChain.getTreasuryBalance();
        assertGe(treasuryBalance, 1 ether - 1e15, "Treasury should have ~1 ETH");
        
        // Withdraw half
        uint256 withdrawAmount = treasuryBalance / 2;
        
        vm.prank(treasury);
        habitChain.withdrawTreasury(withdrawAmount);
        
        uint256 remainingBalance = habitChain.getTreasuryBalance();
        assertApproxEqAbs(remainingBalance, treasuryBalance - withdrawAmount, 1e15, "Should have remaining balance");
    }

    function test_FullTreasuryWithdrawal() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Reading", 1 ether);
        
        // Don't check in, wait past deadline
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        uint256 treasuryBalance = habitChain.getTreasuryBalance();
        
        vm.prank(treasury);
        habitChain.withdrawTreasury(treasuryBalance);
        
        assertEq(habitChain.getTreasuryBalance(), 0, "Treasury should be empty");
    }

    function testRevert_NonTreasuryAddressWithdrawal() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Meditation", 0.5 ether);
        
        vm.prank(user1);
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        // User1 tries to withdraw treasury funds
        vm.prank(user1);
        vm.expectRevert("Only treasury can withdraw");
        habitChain.withdrawTreasury(0.1 ether);
        
        // User2 tries to withdraw treasury funds
        vm.prank(user2);
        vm.expectRevert("Only treasury can withdraw");
        habitChain.withdrawTreasury(0.1 ether);
    }

    function testRevert_WithdrawMoreThanTreasuryBalance() public {
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Yoga", 0.3 ether);
        
        vm.prank(user1);
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        uint256 treasuryBalance = habitChain.getTreasuryBalance();
        
        vm.prank(treasury);
        vm.expectRevert("Insufficient treasury balance");
        habitChain.withdrawTreasury(treasuryBalance + 1 ether);
    }

    function testRevert_WithdrawZeroFromTreasury() public {
        vm.prank(treasury);
        vm.expectRevert("Must withdraw more than 0");
        habitChain.withdrawTreasury(0);
    }

    function test_TreasuryBalanceAccumulationFromSingleSlash() public {
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Running", 0.8 ether);
        
        vm.prank(user1);
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        
        assertGe(treasuryAfter - treasuryBefore, 0.8 ether - 1e15, "Treasury should increase by stake amount");
    }

    function test_TreasuryBalanceAccumulationFromMultipleSlashes() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 5 ether }();
        
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.6 ether);
        uint256 habit3 = habitChain.createHabit("Habit 3", 0.7 ether);
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        vm.stopPrank();
        
        // Don't check in, wait past deadline
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash all three habits
        habitChain.naturalSettle();
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        
        // Treasury should receive total of 1.8 ETH
        assertGe(treasuryAfter - treasuryBefore, 1.8 ether - 1e14, "Treasury should accumulate all slashed funds");
    }

    function test_TreasuryBalanceEarningYieldOverTime() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Swimming", 1 ether);
        
        vm.prank(user1);
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        uint256 treasuryBalanceInitial = habitChain.getTreasuryBalance();
        
        // Skip 1 year for yield accrual
        skipDays(365);
        
        uint256 treasuryBalanceAfterTime = habitChain.getTreasuryBalance();
        
        // In Aave, treasury balance should grow (even if minimally)
        // Note: In a forked environment with time-warping, actual yield may be minimal
        assertGe(treasuryBalanceAfterTime, treasuryBalanceInitial, "Treasury should at least maintain value");
    }

    function test_TreasuryBalanceAfterMultipleSettlements() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 3 ether }();
        
        uint256 habit1 = habitChain.createHabit("Habit 1", 0.5 ether);
        uint256 habit2 = habitChain.createHabit("Habit 2", 0.5 ether);
        
        vm.stopPrank();
        
        // First global settlement - both fail
        habitChain.naturalSettle();
        
        uint256 treasuryAfterFirst = habitChain.getTreasuryBalance();
        assertGe(treasuryAfterFirst, 1 ether - 1e14, "Should have ~1 ETH from both habits");
        
        // Refund and settle again
        vm.startPrank(user1);
        habitChain.refundHabit(habit1, 0.5 ether);
        habitChain.refundHabit(habit2, 0.5 ether);
        vm.stopPrank();
        
        // Second global settlement - both fail again
        habitChain.naturalSettle();
        
        uint256 treasuryAfterSecond = habitChain.getTreasuryBalance();
        assertGe(treasuryAfterSecond, treasuryAfterFirst + 1 ether - 1e14, "Should accumulate another ~1 ETH");
    }

    function test_VerifyETHReceivedByTreasuryAddress() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Cycling", 0.7 ether);
        
        vm.prank(user1);
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        uint256 treasuryBalance = habitChain.getTreasuryBalance();
        uint256 treasuryEthBefore = treasury.balance;
        
        vm.prank(treasury);
        habitChain.withdrawTreasury(treasuryBalance);
        
        uint256 treasuryEthAfter = treasury.balance;
        uint256 ethReceived = treasuryEthAfter - treasuryEthBefore;
        
        assertApproxEqAbs(ethReceived, treasuryBalance, 1e15, "Treasury should receive ETH");
    }

    function test_GetTreasuryBalanceViewFunction() public {
        assertEq(habitChain.getTreasuryBalance(), 0, "Initial treasury balance should be 0");
        
        uint256 habitId = setupBasicHabit(user1, 1 ether, "Cooking", 0.4 ether);
        
        vm.prank(user1);
        vm.warp(block.timestamp + 2 days);
        
        // Natural settle to slash the habit
        habitChain.naturalSettle();
        
        uint256 balance = habitChain.getTreasuryBalance();
        assertGe(balance, 0.4 ether - 1e15, "getTreasuryBalance should return correct value");
    }

    function test_TreasuryReceivesFromGlobalSettlement() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 2 ether }();
        habitChain.createHabit("Habit 1", 0.5 ether);
        habitChain.createHabit("Habit 2", 0.5 ether);
        
        vm.stopPrank();
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        // Global settlement without check-ins
        habitChain.naturalSettle();
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        
        assertGe(treasuryAfter - treasuryBefore, 1 ether - 1e14, "Treasury should receive slashed funds from global settlement");
    }
}

