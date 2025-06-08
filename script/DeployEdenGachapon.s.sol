// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EdenGachapon.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEdenGachapon is Script {
    function run() external {
        vm.startBroadcast();

        // 部署 EdenGachapon 实现合约
        EdenGachapon implementation = new EdenGachapon();
        console2.log("EdenGachapon implementation deployed at:", address(implementation));

        // 初始化合约
        EdenGachapon.GachaponSettings memory settings = EdenGachapon.GachaponSettings({
            rewardToken: vm.envAddress("REWARD_TOKEN_ADDRESS"), // LBGT token address
            randomGenerator: IRandomGenerator(vm.envAddress("RANDOM_GENERATOR_ADDRESS")),
            paymentToken: vm.envAddress("PAYMENT_TOKEN_ADDRESS"), // wBERA token address
            pricePerTicket: vm.envUint("PRICE_PER_TICKET"), // 0.69 * 10^18
            lBGTOperator: vm.envAddress("LBGT_OPERATOR_ADDRESS"),
            rewardVault: vm.envAddress("REWARD_VAULT_ADDRESS"),
            stakingToken: vm.envAddress("STAKING_TOKEN_ADDRESS"),
            incentiveRate: vm.envUint("INCENTIVE_RATE"), // 0.9 * 10^18
            incentiveManager: vm.envAddress("INCENTIVE_MANAGER_ADDRESS")
        });

        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            EdenGachapon.initialize.selector,
            settings
        );

        // 部署 UUPS 代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        // 获取代理合约的 EdenGachapon 实例
        EdenGachapon edenGachapon = EdenGachapon(address(proxy));

        // 设置质押和操作者
        // edenGachapon.stakeAndSetupOperator();

        vm.stopBroadcast();

        // 输出部署的合约地址
        console2.log("EdenGachapon proxy deployed at:", address(edenGachapon));
    }
} 