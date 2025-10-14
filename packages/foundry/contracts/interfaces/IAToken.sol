// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAToken
 * @notice Defines the basic interface for an Aave aToken.
 */
interface IAToken {
    /**
     * @notice Returns the amount of tokens owned by `account`.
     * @param account The address to query
     * @return The amount of tokens owned by account
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Returns the scaled balance of the user
     * @param user The address of the user
     * @return The scaled balance of the user
     */
    function scaledBalanceOf(address user) external view returns (uint256);
}

