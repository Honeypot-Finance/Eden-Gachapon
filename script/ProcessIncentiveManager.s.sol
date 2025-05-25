// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/incentives/IncentiveManager.sol";
import "forge-std/console2.sol";

contract ProcessIncentiveManager is Script {
    function run() external {
        vm.startBroadcast();    

        IncentiveManager incentiveManager = IncentiveManager(address(0x404453FAc3372e1d3Cdd8a50d1175Eb884F074dF));
        incentiveManager.grantRole(incentiveManager.INCENTIVE_ADMIN_ROLE(), address(0x5e1d83147B4C03e6F718853DfF69058071e11b94));

        vm.stopBroadcast();
    }
} 