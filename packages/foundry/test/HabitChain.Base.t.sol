// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/HabitChain.sol";
import "../contracts/interfaces/IPool.sol";
import "../contracts/interfaces/IWETH.sol";
import "../contracts/interfaces/IAToken.sol";

/**
 * @title HabitChainBaseTest
 * @notice Base test contract with shared setup and helper functions
 * @dev All HabitChain test contracts should inherit from this
 */
contract HabitChainBaseTest is Test {
    HabitChain public habitChain;

    // Aave V3 addresses on Base Mainnet
    address constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AWETH = 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7;

    address public treasury;
    address public user1;
    address public user2;
    address public user3;

    uint256 public baseFork;

    // Events to test
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event HabitCreated(
        uint256 indexed habitId, address indexed user, string name, uint256 stakeAmount, uint256 timestamp
    );
    event CheckInCompleted(uint256 indexed habitId, address indexed user, uint256 timestamp, uint256 checkInCount);
    event HabitSettled(
        uint256 indexed habitId, address indexed user, bool success, uint256 totalAmount, uint256 yieldEarned, uint256 timestamp
    );
    event HabitRefunded(uint256 indexed habitId, address indexed user, uint256 stakeAmount, uint256 timestamp);
    event TreasuryFunded(uint256 indexed habitId, uint256 amount);
    event NaturalSettlementCompleted(uint256 totalSettled, uint256 successfulHabits, uint256 failedHabits, uint256 timestamp);
    event CheckInPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    function setUp() public virtual {
        // Fork Base mainnet for real Aave integration at a specific block for consistency
        string memory rpcUrl = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
        // Using block 20000000 - known good state with Aave liquidity
        baseFork = vm.createFork(rpcUrl, 20000000);
        vm.selectFork(baseFork);

        // Set up test accounts
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Fund test accounts with generous amounts for testing
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(treasury, 100 ether);

        // Deploy HabitChain
        habitChain = new HabitChain(AAVE_POOL, WETH, AWETH, treasury);
    }

    // ============ Helper Functions ============

    /**
     * @notice Helper function to deposit ETH for a user
     */
    function depositFor(address user, uint256 amount) internal {
        vm.prank(user);
        habitChain.deposit{ value: amount }();
    }

    /**
     * @notice Helper function to create a habit for a user
     */
    function createHabitFor(address user, string memory name, uint256 stakeAmount) internal returns (uint256) {
        vm.prank(user);
        return habitChain.createHabit(name, stakeAmount);
    }

    /**
     * @notice Helper function to check-in for a habit
     */
    function checkInFor(address user, uint256 habitId) internal {
        vm.prank(user);
        habitChain.checkIn(habitId);
    }

    /**
     * @notice Helper function to withdraw for a user
     */
    function withdrawFor(address user, uint256 amount) internal {
        vm.prank(user);
        habitChain.withdraw(amount);
    }

    /**
     * @notice Helper function to refund a habit for a user
     */
    function refundHabitFor(address user, uint256 habitId, uint256 stakeAmount) internal {
        vm.prank(user);
        habitChain.refundHabit(habitId, stakeAmount);
    }

    /**
     * @notice Helper function to advance time by specified number of days
     */
    function skipDays(uint256 numDays) internal {
        vm.warp(block.timestamp + (numDays * 1 days));
    }

    /**
     * @notice Helper function to advance time by specified number of hours
     */
    function skipHours(uint256 numHours) internal {
        vm.warp(block.timestamp + (numHours * 1 hours));
    }

    /**
     * @notice Helper function to advance time by specified number of seconds
     */
    function skipSeconds(uint256 numSeconds) internal {
        vm.warp(block.timestamp + numSeconds);
    }

    /**
     * @notice Helper function to get habit details
     */
    function getHabit(uint256 habitId) internal view returns (HabitChain.Habit memory) {
        return habitChain.getHabit(habitId);
    }

    /**
     * @notice Helper function to verify habit state
     */
    function assertHabitState(
        uint256 habitId,
        address expectedUser,
        uint256 expectedStakeAmount,
        bool expectedIsActive,
        bool expectedIsSettled
    ) internal {
        HabitChain.Habit memory habit = getHabit(habitId);
        assertEq(habit.user, expectedUser, "Wrong habit user");
        assertEq(habit.stakeAmount, expectedStakeAmount, "Wrong stake amount");
        assertEq(habit.isActive, expectedIsActive, "Wrong isActive state");
        assertEq(habit.isSettled, expectedIsSettled, "Wrong isSettled state");
    }

    /**
     * @notice Helper to setup a basic scenario: deposit and create habit
     */
    function setupBasicHabit(address user, uint256 depositAmount, string memory habitName, uint256 stakeAmount)
        internal
        returns (uint256 habitId)
    {
        depositFor(user, depositAmount);
        habitId = createHabitFor(user, habitName, stakeAmount);
    }

}

