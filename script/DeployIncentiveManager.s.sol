// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/incentives/IncentiveManager.sol";
import "forge-std/console2.sol";

contract DeployIncentiveManager is Script {
    function run() external {
        vm.startBroadcast();

        // 部署 IncentiveManager 合约
        IncentiveManager incentiveManager = new IncentiveManager();

        vm.stopBroadcast();

        // 输出部署的合约地址
        console2.log("IncentiveManager deployed at:", address(incentiveManager));
    }
}
