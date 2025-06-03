// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "revnet-core/src/BasicRevnetDeployer.sol";
import "forge-std/Script.sol";

contract DeployRevnetScript is Script {
    function run() external {
        // Load environment variables
        string memory juiceboxProjectIdStr = vm.envString("JUICEBOX_PROJECT_ID");
        uint256 juiceboxProjectId = vm.parseUint(juiceboxProjectIdStr);

        address jbController   = /* Juicebox controller address on Base */;
        address jbDirectory    = /* Juicebox directory address on Base */;
        address jbEthTerminal  = /* Juicebox ETH payment terminal on Base */;

        // 1. Broadcast with your Base‐wallet key
        vm.startBroadcast(vm.envAddress("PRIVATE_KEY_BASE"));

        // 2. Deploy BasicRevnetDeployer
        BasicRevnetDeployer revnetDeployer = new BasicRevnetDeployer(
            jbController,
            jbDirectory,
            jbEthTerminal
        );

        // 3. Launch the Revnet
        //    Parameters: projectId, name, symbol, reserveRate (80% = 8000), curveWeight (50% = 5000)
        (address clientCoinAddress, address clientCoinTreasury) =
            revnetDeployer.launchBasicRevnet(
                juiceboxProjectId,
                "clientCoin",
                "CLC",
                8000,
                5000
            );

        console.log("Revnet Deployer:      ", address(revnetDeployer));
        console.log("clientCoin (CLC) addr:", clientCoinAddress);
        console.log("CLC Treasury address: ", clientCoinTreasury);

        vm.stopBroadcast();
    }
}
