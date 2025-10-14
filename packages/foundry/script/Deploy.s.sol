//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { DeployHabitChain } from "./DeployHabitChain.s.sol";

/**
 * @notice Main deployment script for all contracts
 * @dev Run this when you want to deploy multiple contracts at once
 *
 * Example: yarn deploy # runs this script(without`--file` flag)
 */
contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        // Deploys all your contracts sequentially
        // Add new deployments here when needed

        DeployHabitChain deployHabitChain = new DeployHabitChain();
        deployHabitChain.run();

        // Deploy another contract if needed
        // DeployMyContract myContract = new DeployMyContract();
        // myContract.run();
    }
}
