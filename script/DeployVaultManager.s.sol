// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/incentives/VaultManager.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployVaultManager is Script {
    function run() external {
        vm.startBroadcast();

        // 部署 VaultManager 实现合约
        VaultManager implementation = new VaultManager();
        console2.log("VaultManager implementation deployed at:", address(implementation));

        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            VaultManager.initialize.selector
        );

        // 部署 UUPS 代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // 获取代理合约的 VaultManager 实例
        VaultManager vaultManager = VaultManager(address(proxy));

        vm.stopBroadcast();

        // 输出部署的合约地址
        console2.log("VaultManager proxy deployed at:", address(vaultManager));
    }
}
