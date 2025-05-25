// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EdenGachapon.sol";
import "forge-std/console2.sol";

contract ProcessEdenGachapon is Script {
    function run() external {
        vm.startBroadcast();    

        // 获取代理合约的 EdenGachapon 实例
        EdenGachapon edenGachapon = EdenGachapon(address(0x5e1d83147B4C03e6F718853DfF69058071e11b94));

        // 获取设置
        (
            address rewardToken,
            IRandomGenerator randomGenerator,
            address paymentToken,
            uint256 pricePerTicket,
            address lBGTOperator,
            address rewardVault,
            address stakingToken,
            uint256 incentiveRate,
            address incentiveManager
        ) = edenGachapon.gachaponSettings();

        console2.log("rewardToken:", rewardToken);
        console2.log("randomGenerator:", address(randomGenerator));
        console2.log("paymentToken:", paymentToken);
        console2.log("pricePerTicket:", pricePerTicket);
        console2.log("lBGTOperator:", lBGTOperator);
        console2.log("rewardVault:", rewardVault);
        console2.log("stakingToken:", stakingToken);
        console2.log("incentiveRate:", incentiveRate);
        console2.log("incentiveManager:", incentiveManager);

        // edenGachapon.unStake();

        // IERC20(paymentToken).approve(address(edenGachapon), 0.69*10**18);
        edenGachapon.buyTicket(1);

        vm.stopBroadcast();
    }
} 