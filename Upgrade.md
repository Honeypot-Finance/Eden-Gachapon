# EdenGachapon 升级操作指南

本指南将指导你如何通过 `UpgradeEdenGachapon.s.sol` 脚本对 EdenGachapon 合约进行 UUPS 升级。

---

## 1. 升级脚本简介

`UpgradeEdenGachapon.s.sol` 是一个基于 Foundry 的脚本，用于将 EdenGachapon 合约实现进行升级，并初始化新实现的参数。脚本主要流程如下：

- 部署新的 EdenGachapon 实现合约
- 构造初始化参数
- 调用代理合约的 `upgradeToAndCall` 完成升级和初始化
- 输出升级后合约地址

---

## 2. 环境准备

### 依赖

- [Foundry](https://book.getfoundry.sh/)
- 已部署的 EdenGachapon 代理合约地址
- 新实现合约的初始化参数

### 环境变量

脚本依赖以下环境变量，请提前配置好：

| 变量名                    | 说明                       |
|---------------------------|----------------------------|
| REWARD_TOKEN_ADDRESS      | 奖励代币地址（LBGT）       |
| RANDOM_GENERATOR_ADDRESS  | 随机数生成合约地址         |
| PAYMENT_TOKEN_ADDRESS     | 支付抽奖券的代币地址       |
| PRICE_PER_TICKET          | 抽奖券单价（uint）         |
| LBGT_OPERATOR_ADDRESS     | berapaw operator 地址      |
| REWARD_VAULT_ADDRESS      | rewardVault 地址           |
| STAKING_TOKEN_ADDRESS     | 质押代币地址               |
| INCENTIVE_RATE            | 激励率（uint）             |
| INCENTIVE_MANAGER_ADDRESS | 激励管理合约地址           |

可通过 `.env` 文件或命令行参数设置。

---

## 3. 升级步骤

### 1. 配置环境变量

在项目根目录下创建 `.env` 文件，内容示例：

```env
REWARD_TOKEN_ADDRESS=0x...
RANDOM_GENERATOR_ADDRESS=0x...
PAYMENT_TOKEN_ADDRESS=0x...
PRICE_PER_TICKET=690000000000000000
LBGT_OPERATOR_ADDRESS=0x...
REWARD_VAULT_ADDRESS=0x...
STAKING_TOKEN_ADDRESS=0x...
INCENTIVE_RATE=900000000000000000
INCENTIVE_MANAGER_ADDRESS=0x...
```

### 2. 检查代理合约地址

确认脚本中的 `edenGachaponProxy` 地址为当前主网/测试网已部署的 EdenGachapon 代理合约地址。

```solidity
address edenGachaponProxy = address(0x73C7677A8bC73178aE36aD97C984df79E99A18CE);
```

如需更换，请修改为实际地址。

### 3. 执行升级脚本

使用 Foundry 的 `forge script` 命令执行升级：

```bash
forge script script/UpgradeEdenGachapon.s.sol:UpgradeEdenGachapon --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

- `<RPC_URL>`：链节点 RPC 地址
- `<PRIVATE_KEY>`：拥有升级权限的管理员私钥

### 4. 升级过程说明

- 脚本会自动部署新的 EdenGachapon 实现合约
- 构造初始化参数（GachaponSettings）
- 调用代理合约的 `upgradeToAndCall` 完成升级和初始化
- 控制台输出新实现和升级后合约地址

---

## 4. 注意事项

- 升级操作需由拥有 `UPGRADER_ROLE` 权限的账户执行
- 升级前请备份好合约数据，确保参数配置正确
- 升级后建议进行功能验证，确保新实现正常工作

---

## 5. 常见问题

- **环境变量未配置或错误**：请检查 `.env` 文件或命令行参数
- **权限不足**：确保使用的私钥拥有代理合约的升级权限
- **参数类型不匹配**：请严格按照脚本要求填写参数类型

---

## 6. 参考

- [Foundry 官方文档](https://book.getfoundry.sh/)
- [UUPS 升级模式说明](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)

---

