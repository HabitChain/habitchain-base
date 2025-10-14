// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IWETH
 * @notice Interface for Wrapped ETH (WETH) contract
 */
interface IWETH {
    /**
     * @notice Deposit ETH to get WETH
     */
    function deposit() external payable;

    /**
     * @notice Withdraw WETH to get ETH
     * @param amount The amount of WETH to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Approve spender to spend WETH
     * @param spender The address to approve
     * @param amount The amount to approve
     * @return success Whether the approval was successful
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Get WETH balance of an account
     * @param account The account to check
     * @return balance The WETH balance
     */
    function balanceOf(address account) external view returns (uint256);
}

