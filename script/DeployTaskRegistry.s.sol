// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../src/TaskRegistry.sol";
import "forge-std/Script.sol";

contract DeployTaskRegistryScript is Script {
    function run() external {
        // Load the Revnet token address from .env
        address tskToken   = vm.envAddress("TSK_REVNET_ADDRESS");
        address robAddress = vm.envAddress("ROB_ADDRESS");

        // Begin broadcasting transactions with your Base private key
        vm.startBroadcast(vm.envAddress("PRIVATE_KEY_BASE"));

        // Deploy TaskRegistry(tskToken, robAddress)
        TaskRegistry registry = new TaskRegistry(
            tskToken,
            robAddress
        );
        console.log("TaskRegistry deployed at:", address(registry));

        vm.stopBroadcast();
    }
}
