// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/incentives/VaultManager.sol";
import "forge-std/console2.sol";

contract ProcessIncentiveManager is Script {
    function run() external {
        vm.startBroadcast();    

        VaultManager vaultManager = VaultManager(address(0xbFf63221C88d332352137517A95495f95BaD0D8B));
        vaultManager.grantRole(vaultManager.INCENTIVE_ADMIN_ROLE(), address(0x73C7677A8bC73178aE36aD97C984df79E99A18CE));
        // vaultManager.accountIncentive(address(0xfB8B5495a83716DAd89944919aA1090a21884ab3), address(0x6969696969696969696969696969696969696969), 0 ether);



        vm.stopBroadcast();
    }
} 