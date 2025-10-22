// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainWithdrawTest
 * @notice Tests for withdrawal functionality
 */
contract HabitChainWithdrawTest is HabitChainBaseTest {
    function test_PartialWithdrawal() public {
        vm.startPrank(user1);

        // Deposit 2 ETH
        habitChain.deposit{ value: 2 ether }();
        
        // Withdraw 1 ETH
        uint256 balanceBefore = user1.balance;
        habitChain.withdraw(1 ether);
        uint256 balanceAfter = user1.balance;

        // Verify user received ETH
        assertApproxEqAbs(balanceAfter - balanceBefore, 1 ether, 1e15, "Should receive 1 ETH");
        
        // Verify remaining balance
        assertApproxEqAbs(habitChain.getUserBalance(user1), 1 ether, 1e15, "Should have 1 ETH left");

        vm.stopPrank();
    }

    function test_FullWithdrawal() public {
        vm.startPrank(user1);

        uint256 depositAmount = 3 ether;
        habitChain.deposit{ value: depositAmount }();
        
        uint256 userBalance = habitChain.getUserBalance(user1);
        uint256 ethBalanceBefore = user1.balance;
        
        habitChain.withdraw(userBalance);
        
        uint256 ethBalanceAfter = user1.balance;

        // Verify user received all ETH back
        assertApproxEqAbs(ethBalanceAfter - ethBalanceBefore, depositAmount, 1e15, "Should receive full deposit");
        
        // Verify balance is now zero
        assertEq(habitChain.getUserBalance(user1), 0, "Balance should be zero");

        vm.stopPrank();
    }

    function test_WithdrawExactBalance() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1.5 ether }();
        uint256 balance = habitChain.getUserBalance(user1);
        
        habitChain.withdraw(balance);
        
        assertEq(habitChain.getUserBalance(user1), 0, "Should withdraw exact balance");

        vm.stopPrank();
    }

    function testRevert_WithdrawMoreThanBalance() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.withdraw(2 ether);

        vm.stopPrank();
    }

    function testRevert_WithdrawZero() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        vm.expectRevert("Must withdraw more than 0");
        habitChain.withdraw(0);

        vm.stopPrank();
    }

    function test_MultipleWithdrawalsInSequence() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 5 ether }();
        
        habitChain.withdraw(1 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 4 ether, 1e15, "After 1st withdrawal");
        
        habitChain.withdraw(2 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 2 ether, 1e15, "After 2nd withdrawal");
        
        habitChain.withdraw(1.5 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 0.5 ether, 1e15, "After 3rd withdrawal");

        vm.stopPrank();
    }

    function test_WithdrawAfterCreatingHabits() public {
        vm.startPrank(user1);

        // Deposit 3 ETH
        habitChain.deposit{ value: 3 ether }();
        
        // Create habit with 1 ETH stake
        habitChain.createHabit("Exercise", 1 ether);
        
        // Available balance should be 2 ETH
        assertApproxEqAbs(habitChain.getUserBalance(user1), 2 ether, 1e15, "Available balance");
        
        // Can withdraw available balance
        habitChain.withdraw(1 ether);
        assertApproxEqAbs(habitChain.getUserBalance(user1), 1 ether, 1e15, "After withdrawal");
        
        // Cannot withdraw more than available
        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.withdraw(2 ether);

        vm.stopPrank();
    }

    function test_WithdrawWithAccruedYield() public {
        vm.startPrank(user1);

        uint256 depositAmount = 10 ether;
        habitChain.deposit{ value: depositAmount }();
        
        // Simulate time passing for yield accrual (1 year)
        skipDays(365);
        
        // In Aave, the balance should grow slightly
        uint256 balanceAfterTime = habitChain.getUserBalance(user1);
        
        // Withdraw all
        uint256 ethBefore = user1.balance;
        habitChain.withdraw(balanceAfterTime);
        uint256 ethAfter = user1.balance;
        
        // Should receive at least the original deposit (possibly more with yield)
        assertGe(ethAfter - ethBefore, depositAmount - 1e15, "Should get back at least deposit");

        vm.stopPrank();
    }

    function test_VerifyETHReceivedCorrectly() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 5 ether }();
        
        uint256 withdrawAmount = 2 ether;
        uint256 ethBefore = user1.balance;
        
        habitChain.withdraw(withdrawAmount);
        
        uint256 ethAfter = user1.balance;
        uint256 ethReceived = ethAfter - ethBefore;
        
        assertApproxEqAbs(ethReceived, withdrawAmount, 1e15, "ETH received should match withdrawal");

        vm.stopPrank();
    }

    function test_WithdrawEmitsCorrectEvent() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 2 ether }();
        
        uint256 withdrawAmount = 1 ether;
        
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user1, withdrawAmount);
        
        habitChain.withdraw(withdrawAmount);

        vm.stopPrank();
    }

    function testRevert_WithdrawWithNoBalance() public {
        vm.startPrank(user1);

        vm.expectRevert(HabitChain.InsufficientBalance.selector);
        habitChain.withdraw(1 ether);

        vm.stopPrank();
    }

    function test_WithdrawTinyAmount() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        
        // Withdraw very small amount
        habitChain.withdraw(0.0001 ether);
        
        assertLt(habitChain.getUserBalance(user1), 1 ether, "Balance should decrease");
        assertGt(habitChain.getUserBalance(user1), 0.999 ether, "Most balance should remain");

        vm.stopPrank();
    }
}

