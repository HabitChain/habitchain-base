// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { HabitChain } from "../contracts/HabitChain.sol";

/**
 * @notice Deployment script for HabitChain contract
 * @dev Deploys HabitChain with network-specific Aave V3 addresses
 * Example:
 * yarn deploy --file DeployHabitChain.s.sol  # local anvil chain
 * yarn deploy --file DeployHabitChain.s.sol --network baseSepolia # Base Sepolia testnet
 */
contract DeployHabitChain is ScaffoldETHDeploy {
    struct NetworkConfig {
        address aavePool;
        address weth;
        address aWeth;
    }

    function run() external ScaffoldEthDeployerRunner {
        NetworkConfig memory config = getNetworkConfig();

        HabitChain habitChain = new HabitChain(
            config.aavePool,
            config.weth,
            config.aWeth,
            deployer // Use deployer as treasury
        );

        console.logString(string.concat("HabitChain deployed at: ", vm.toString(address(habitChain))));
        console.logString(string.concat("Treasury address: ", vm.toString(deployer)));
        console.logString(string.concat("Aave Pool: ", vm.toString(config.aavePool)));
        console.logString(string.concat("WETH: ", vm.toString(config.weth)));
        console.logString(string.concat("aWETH: ", vm.toString(config.aWeth)));

        deployments.push(Deployment({ name: "HabitChain", addr: address(habitChain) }));
    }

    function getNetworkConfig() internal view returns (NetworkConfig memory) {
        uint256 chainId = block.chainid;

        // Base Mainnet (Chain ID: 8453)
        if (chainId == 8453) {
            return NetworkConfig({
                aavePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                weth: 0x4200000000000000000000000000000000000006,
                aWeth: 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7
            });
        }
        // Base Sepolia (Chain ID: 84532)
        else if (chainId == 84532) {
            return NetworkConfig({
                aavePool: 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b,
                weth: 0x4200000000000000000000000000000000000006,
                aWeth: 0x9c8Aa5E801E3E072e0eD1BE4A2dE836E20aCABd1
            });
        }
        // Local fork - use Base Mainnet addresses
        else if (chainId == 31337) {
            return NetworkConfig({
                aavePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                weth: 0x4200000000000000000000000000000000000006,
                aWeth: 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7
            });
        }
        // Unsupported chain
        else {
            revert InvalidChain();
        }
    }
}

