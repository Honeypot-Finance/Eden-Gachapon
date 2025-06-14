// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EdenGachapon.sol";
import "forge-std/console2.sol";

contract ProcessEdenGachapon is Script {
    function run() external {
        vm.startBroadcast();    

        // 获取代理合约的 EdenGachapon 实例
        EdenGachapon edenGachapon = EdenGachapon(address(0x73C7677A8bC73178aE36aD97C984df79E99A18CE));

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

        // edenGachapon.setGachaponSettings(
        //     EdenGachapon.GachaponSettings({
        //         rewardToken: rewardToken,
        //         randomGenerator: randomGenerator,
        //         paymentToken: paymentToken,
        //         pricePerTicket: pricePerTicket,
        //         lBGTOperator: lBGTOperator,
        //         rewardVault: address(0xc6E20D1CDc93A854ce373AEd93653093DDb12E13),
        //         stakingToken: address(0x5f77967f5129CF2F294E070284Ff0F0e6F838568),
        //         incentiveRate: incentiveRate,
        //         incentiveManager: address(0xbFf63221C88d332352137517A95495f95BaD0D8B)
        //     })
        // );


        console2.log("tickets:", edenGachapon.getTickets(address(0x73C7677A8bC73178aE36aD97C984df79E99A18CE)));

        // IERC20(paymentToken).approve(address(edenGachapon), 0.69*10**18);
        // edenGachapon.buyTicket(1);

        // 启动前，要把stakingtoken存入到eden里面，然后stakeAndSetupOperator

        vm.stopBroadcast();
    }
} 