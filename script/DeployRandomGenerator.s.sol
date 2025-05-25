// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/random/BlockConfirmationRandomGenerator.sol";
import "forge-std/console2.sol";

contract DeployRandomGenerator is Script {
    function run() external {
        vm.startBroadcast();

        // 从环境变量获取所需的确认数
        uint256 requiredConfirmations = vm.envUint("REQUIRED_CONFIRMATIONS");
        
        // 部署 BlockConfirmationRandomGenerator 合约
        BlockConfirmationRandomGenerator randomGenerator = new BlockConfirmationRandomGenerator(
            requiredConfirmations
        );

        vm.stopBroadcast();

        // 输出部署的合约地址
        console2.log("BlockConfirmationRandomGenerator deployed at:", address(randomGenerator));
    }
} 