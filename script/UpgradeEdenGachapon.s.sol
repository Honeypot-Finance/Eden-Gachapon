// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EdenGachapon.sol";
import "forge-std/console2.sol";

contract UpgradeEdenGachapon is Script {
    function run() external {
        vm.startBroadcast();

        address edenGachaponProxy = address(
            0x73C7677A8bC73178aE36aD97C984df79E99A18CE
        );

        EdenGachapon implementation = new EdenGachapon();
        console2.log(
            "EdenGachapon implementation deployed at:",
            address(implementation)
        );

        bytes memory initData = abi.encodeWithSelector(
            EdenGachapon.initialize.selector,
            EdenGachapon.GachaponSettings({
                rewardToken: vm.envAddress("REWARD_TOKEN_ADDRESS"),
                randomGenerator: IRandomGenerator(
                    vm.envAddress("RANDOM_GENERATOR_ADDRESS")
                ),
                paymentToken: vm.envAddress("PAYMENT_TOKEN_ADDRESS"),
                pricePerTicket: vm.envUint("PRICE_PER_TICKET"),
                lBGTOperator: vm.envAddress("LBGT_OPERATOR_ADDRESS"),
                rewardVault: vm.envAddress("REWARD_VAULT_ADDRESS"),
                stakingToken: vm.envAddress("STAKING_TOKEN_ADDRESS"),
                incentiveRate: vm.envUint("INCENTIVE_RATE"),
                incentiveManager: vm.envAddress("INCENTIVE_MANAGER_ADDRESS")
            })
        );

        // upgrade
        UUPSUpgradeable(edenGachaponProxy).upgradeToAndCall(
            address(implementation),
            initData
        );

        // 获取升级后的EdenGachapon实例
        EdenGachapon upgradedEdenGachapon = EdenGachapon(edenGachaponProxy);
        console2.log(
            "EdenGachapon upgraded at:",
            address(upgradedEdenGachapon)
        );

        vm.stopBroadcast();
    }
}
