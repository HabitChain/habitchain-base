// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainDepositTest
 * @notice Tests for deposit functionality
 */
contract HabitChainDepositTest is HabitChainBaseTest {
    function test_SuccessfulSingleDeposit() public {
        uint256 depositAmount = 1 ether;

        vm.startPrank(user1);

        vm.expectEmit(true, false, false, true);
        emit Deposited(user1, depositAmount);

        habitChain.deposit{ value: depositAmount }();

        assertEq(habitChain.getUserBalance(user1), depositAmount, "Balance should match deposit amount");
        vm.stopPrank();
    }

    function test_MultipleSequentialDeposits() public {
        vm.startPrank(user1);

        habitChain.deposit{ value: 1 ether }();
        assertEq(habitChain.getUserBalance(user1), 1 ether);

        habitChain.deposit{ value: 2 ether }();
        assertEq(habitChain.getUserBalance(user1), 3 ether);

        habitChain.deposit{ value: 0.5 ether }();
        assertEq(habitChain.getUserBalance(user1), 3.5 ether);

        vm.stopPrank();
    }

    function testRevert_ZeroDeposit() public {
        vm.prank(user1);
        vm.expectRevert("Must deposit more than 0");
        habitChain.deposit{ value: 0 }();
    }

    function test_LargeDeposit() public {
        uint256 largeAmount = 50 ether;

        vm.startPrank(user1);
        habitChain.deposit{ value: largeAmount }();

        assertEq(habitChain.getUserBalance(user1), largeAmount);
        vm.stopPrank();
    }

    function test_VerifyAWETHBalanceTracking() public {
        uint256 depositAmount = 1 ether;

        vm.startPrank(user1);
        habitChain.deposit{ value: depositAmount }();

        // The user balance should be tracked in aWETH terms
        uint256 userBalance = habitChain.getUserBalance(user1);
        
        // Due to Aave's 1:1 initial exchange rate, should be approximately equal
        assertApproxEqAbs(userBalance, depositAmount, 1e15, "aWETH balance should match deposit");

        vm.stopPrank();
    }

    function test_VerifyAaveIntegration() public {
        uint256 depositAmount = 5 ether;

        // Get aWETH balance before
        IAToken aWeth = IAToken(AWETH);
        uint256 contractAWETHBefore = aWeth.balanceOf(address(habitChain));

        vm.prank(user1);
        habitChain.deposit{ value: depositAmount }();

        // Verify aWETH was received by contract
        uint256 contractAWETHAfter = aWeth.balanceOf(address(habitChain));
        assertGt(contractAWETHAfter, contractAWETHBefore, "Contract should receive aWETH from Aave");
    }

    function test_MultipleUsersDepositingSimultaneously() public {
        // User 1 deposits
        vm.prank(user1);
        habitChain.deposit{ value: 1 ether }();

        // User 2 deposits
        vm.prank(user2);
        habitChain.deposit{ value: 2 ether }();

        // User 3 deposits
        vm.prank(user3);
        habitChain.deposit{ value: 3 ether }();

        // Verify balances are isolated
        assertEq(habitChain.getUserBalance(user1), 1 ether);
        assertEq(habitChain.getUserBalance(user2), 2 ether);
        assertEq(habitChain.getUserBalance(user3), 3 ether);
    }

    function test_VerySmallDeposit() public {
        uint256 tinyAmount = 0.0001 ether;

        vm.startPrank(user1);
        habitChain.deposit{ value: tinyAmount }();

        assertGt(habitChain.getUserBalance(user1), 0, "Should accept tiny deposits");
        vm.stopPrank();
    }

    function test_DepositEmitsCorrectEvent() public {
        uint256 depositAmount = 2.5 ether;

        vm.startPrank(user1);

        vm.expectEmit(true, false, false, true);
        emit Deposited(user1, depositAmount);

        habitChain.deposit{ value: depositAmount }();

        vm.stopPrank();
    }

    function test_DepositWithExistingBalance() public {
        vm.startPrank(user1);

        // First deposit
        habitChain.deposit{ value: 1 ether }();
        uint256 balanceAfterFirst = habitChain.getUserBalance(user1);

        // Second deposit
        habitChain.deposit{ value: 1 ether }();
        uint256 balanceAfterSecond = habitChain.getUserBalance(user1);

        assertGt(balanceAfterSecond, balanceAfterFirst, "Balance should increase");
        assertApproxEqAbs(balanceAfterSecond, 2 ether, 1e15, "Should have approximately 2 ETH");

        vm.stopPrank();
    }
}

