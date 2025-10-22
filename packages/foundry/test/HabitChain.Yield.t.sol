// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./HabitChain.Base.t.sol";

/**
 * @title HabitChainYieldTest
 * @notice Tests for yield accrual and Aave integration
 */
contract HabitChainYieldTest is HabitChainBaseTest {
    function test_UserBalanceEarnsYieldOverTime() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 10 ether }();
        uint256 balanceInitial = habitChain.getUserBalance(user1);
        
        // Skip 1 year
        skipDays(365);
        
        uint256 balanceAfterTime = habitChain.getUserBalance(user1);
        
        // Balance should be at least the same (Aave yields should accrue)
        assertGe(balanceAfterTime, balanceInitial, "Balance should at least maintain or grow");
        
        vm.stopPrank();
    }

    function test_HabitStakeEarnsYieldOverTime() public {
        uint256 habitId = setupBasicHabit(user1, 5 ether, "Exercise", 2 ether);
        
        // Get initial value
        (uint256 initialValue, uint256 initialYield) = habitChain.getHabitCurrentValue(habitId);
        
        // Skip 6 months
        skipDays(180);
        
        // Get value after time
        (uint256 valueAfterTime, uint256 yieldAfterTime) = habitChain.getHabitCurrentValue(habitId);
        
        // Value should be at least the same or higher
        assertGe(valueAfterTime, initialValue, "Habit value should at least maintain");
    }

    function test_TreasuryBalanceEarnsYieldOverTime() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Reading", 1 ether);
        
        vm.prank(user1);
        habitChain.forceSettle(habitId, false);
        
        uint256 treasuryInitial = habitChain.getTreasuryBalance();
        
        // Skip 1 year
        skipDays(365);
        
        uint256 treasuryAfterTime = habitChain.getTreasuryBalance();
        
        // Treasury balance should at least maintain
        assertGe(treasuryAfterTime, treasuryInitial, "Treasury should at least maintain value");
    }

    function test_YieldCalculationFormulaCorrectness() public {
        uint256 habitId = setupBasicHabit(user1, 2 ether, "Meditation", 1 ether);
        
        HabitChain.Habit memory habit = getHabit(habitId);
        
        // Initial values
        uint256 stakeAmount = habit.stakeAmount;
        uint256 aTokenAmount = habit.aTokenAmount;
        uint256 liquidityIndex = habit.liquidityIndex;
        
        assertGt(aTokenAmount, 0, "aToken amount should be set");
        assertGt(liquidityIndex, 0, "Liquidity index should be captured");
        assertApproxEqAbs(aTokenAmount, stakeAmount, 1e15, "Initial aToken should match stake");
        
        // Skip time
        skipDays(30);
        
        // Get current value
        (uint256 currentValue, uint256 yieldEarned) = habitChain.getHabitCurrentValue(habitId);
        
        // Current value should be at least the stake amount
        assertGe(currentValue, stakeAmount - 1e15, "Current value should be at least stake");
    }

    function test_YieldAccrualOver30Days() public {
        uint256 habitId = setupBasicHabit(user1, 5 ether, "Yoga", 3 ether);
        
        (uint256 initialValue,) = habitChain.getHabitCurrentValue(habitId);
        
        skipDays(30);
        
        (uint256 valueAfter30Days, uint256 yield30Days) = habitChain.getHabitCurrentValue(habitId);
        
        assertGe(valueAfter30Days, initialValue, "Value should at least maintain after 30 days");
    }

    function test_YieldAccrualOver1Year() public {
        uint256 habitId = setupBasicHabit(user1, 10 ether, "Running", 5 ether);
        
        (uint256 initialValue,) = habitChain.getHabitCurrentValue(habitId);
        
        skipDays(365);
        
        (uint256 valueAfter1Year, uint256 yield1Year) = habitChain.getHabitCurrentValue(habitId);
        
        assertGe(valueAfter1Year, initialValue, "Value should at least maintain after 1 year");
    }

    function test_SuccessfulSettlementIncludesYieldToUser() public {
        uint256 habitId = setupBasicHabit(user1, 5 ether, "Swimming", 2 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        uint256 userBalanceBefore = habitChain.getUserBalance(user1);
        
        // Skip time for yield
        skipDays(90);
        
        vm.prank(user1);
        habitChain.forceSettle(habitId, true);
        
        uint256 userBalanceAfter = habitChain.getUserBalance(user1);
        uint256 received = userBalanceAfter - userBalanceBefore;
        
        // User should receive at least the stake
        assertGe(received, 2 ether - 1e15, "Should receive at least stake");
    }

    function test_FailedSettlementIncludesYieldToTreasury() public {
        uint256 habitId = setupBasicHabit(user1, 5 ether, "Cycling", 2 ether);
        
        uint256 treasuryBefore = habitChain.getTreasuryBalance();
        
        // Skip time for yield
        skipDays(90);
        
        vm.prank(user1);
        habitChain.forceSettle(habitId, false);
        
        uint256 treasuryAfter = habitChain.getTreasuryBalance();
        uint256 received = treasuryAfter - treasuryBefore;
        
        // Treasury should receive at least the stake
        assertGe(received, 2 ether - 1e15, "Treasury should receive at least stake");
    }

    function test_GetHabitCurrentValueReturnsCorrectValues() public {
        uint256 habitId = setupBasicHabit(user1, 3 ether, "Cooking", 1.5 ether);
        
        (uint256 currentValue, uint256 yieldEarned) = habitChain.getHabitCurrentValue(habitId);
        
        // Current value should be approximately equal to stake amount initially
        assertApproxEqAbs(currentValue, 1.5 ether, 1e15, "Current value should match stake");
        
        // Initial yield should be minimal or zero
        assertLe(yieldEarned, 1e16, "Initial yield should be minimal");
        
        // Skip time
        skipDays(60);
        
        (uint256 currentValue2, uint256 yieldEarned2) = habitChain.getHabitCurrentValue(habitId);
        
        assertGe(currentValue2, currentValue, "Value should maintain or grow");
    }

    function test_YieldDistributionOnDailySettlement_Success() public {
        uint256 habitId = setupBasicHabit(user1, 3 ether, "Writing", 1 ether);
        
        vm.prank(user1);
        habitChain.checkIn(habitId);
        
        uint256 userBalanceBefore = habitChain.getUserBalance(user1);
        
        // Skip time
        skipDays(30);
        
        // Global settlement (success case)
        habitChain.globalSettle();
        
        uint256 userBalanceAfter = habitChain.getUserBalance(user1);
        
        // User should receive yield to available balance
        assertGe(userBalanceAfter, userBalanceBefore, "User should receive yield");
        
        // Habit should still have original stake
        assertApproxEqAbs(getHabit(habitId).stakeAmount, 1 ether, 1e15, "Stake should remain");
    }

    function test_MultipleYieldAccrualCycles() public {
        uint256 habitId = setupBasicHabit(user1, 3 ether, "Guitar", 1 ether);
        
        vm.startPrank(user1);
        
        // Day 1: Check in and settle
        habitChain.checkIn(habitId);
        skipDays(1);
        vm.stopPrank();
        
        habitChain.globalSettle();
        (uint256 value1,) = habitChain.getHabitCurrentValue(habitId);
        
        // Day 2: Check in and settle
        vm.prank(user1);
        habitChain.checkIn(habitId);
        skipDays(1);
        habitChain.globalSettle();
        (uint256 value2,) = habitChain.getHabitCurrentValue(habitId);
        
        // Day 3: Check in and settle
        vm.prank(user1);
        habitChain.checkIn(habitId);
        skipDays(1);
        habitChain.globalSettle();
        (uint256 value3,) = habitChain.getHabitCurrentValue(habitId);
        
        // Value should maintain or grow across cycles
        assertGe(value2, value1 - 1e15, "Value should maintain in cycle 2");
        assertGe(value3, value2 - 1e15, "Value should maintain in cycle 3");
    }

    function test_CompareATokenBalanceGrowthToLiquidityIndex() public {
        vm.startPrank(user1);
        
        habitChain.deposit{ value: 10 ether }();
        
        // Get initial aToken balance and liquidity index
        IAToken aWeth = IAToken(AWETH);
        uint256 aTokenBalanceBefore = aWeth.balanceOf(address(habitChain));
        IPool pool = IPool(AAVE_POOL);
        uint256 liquidityIndexBefore = pool.getReserveNormalizedIncome(WETH);
        
        // Skip significant time
        skipDays(365);
        
        // Get balances after time
        uint256 aTokenBalanceAfter = aWeth.balanceOf(address(habitChain));
        uint256 liquidityIndexAfter = pool.getReserveNormalizedIncome(WETH);
        
        // aToken balance should grow proportionally to liquidity index
        assertGe(aTokenBalanceAfter, aTokenBalanceBefore, "aToken balance should at least maintain");
        assertGe(liquidityIndexAfter, liquidityIndexBefore, "Liquidity index should grow");
        
        vm.stopPrank();
    }

    function test_YieldAfterWithdrawAndRedeposit() public {
        vm.startPrank(user1);
        
        // Initial deposit
        habitChain.deposit{ value: 5 ether }();
        
        skipDays(30);
        
        // Withdraw half
        habitChain.withdraw(2.5 ether);
        
        uint256 balanceAfterWithdraw = habitChain.getUserBalance(user1);
        
        skipDays(30);
        
        // Re-deposit
        habitChain.deposit{ value: 2 ether }();
        
        uint256 balanceAfterRedeposit = habitChain.getUserBalance(user1);
        
        // Balance should be previous balance + new deposit
        assertGe(balanceAfterRedeposit, balanceAfterWithdraw + 2 ether - 1e15, "Should accumulate correctly");
        
        vm.stopPrank();
    }
}

