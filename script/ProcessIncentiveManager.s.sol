// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/incentives/VaultManager.sol";
import "forge-std/console2.sol";

contract ProcessIncentiveManager is Script {
    function run() external {
        vm.startBroadcast();    

        VaultManager vaultManager = VaultManager(address(0xbFf63221C88d332352137517A95495f95BaD0D8B));
        vaultManager.grantRole(vaultManager.INCENTIVE_ADMIN_ROLE(), address(0x5e1d83147B4C03e6F718853DfF69058071e11b94));

        vm.stopBroadcast();
    }
} 