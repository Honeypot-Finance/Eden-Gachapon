// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/incentives/VaultManager.sol";
import "forge-std/console2.sol";

contract UpgradeVaultManager is Script {
    function run() external {
        vm.startBroadcast();

        address vaultManagerProxy = address(0xbFf63221C88d332352137517A95495f95BaD0D8B);

        VaultManager implementation = new VaultManager();
        console2.log("VaultManager implementation deployed at:", address(implementation));

        bytes memory initData = abi.encodeWithSelector(
            VaultManager.initialize.selector
        );

        // upgrade
        UUPSUpgradeable(vaultManagerProxy).upgradeToAndCall(
            address(implementation),
            initData
        );

        // 获取升级后的VaultManager实例
        VaultManager upgradedVaultManager = VaultManager(vaultManagerProxy);
        console2.log("VaultManager upgraded at:", address(upgradedVaultManager));

        upgradedVaultManager.grantRole(upgradedVaultManager.INCENTIVE_ADMIN_ROLE(), address(0x5e1d83147B4C03e6F718853DfF69058071e11b94));

        

        vm.stopBroadcast();
    }
} 