# EdenGachapon 合约文档

## 简介

`EdenGachapon` 是一个基于抽奖券的扭蛋（Gachapon）抽奖合约，支持多奖品、多扭蛋机、奖池激励、LBGT 返奖等功能。合约支持升级（UUPSUpgradeable），并集成了权限管理、暂停、重入保护等安全机制。

---

## 主要数据结构

### Prize（奖品）

| 字段         | 类型      | 说明                   |
| ------------ | --------- | ---------------------- |
| name         | string    | 奖品名称               |
| feeAddress   | address   | 奖品接收地址           |
| prizeValue   | uint256   | 奖品价值（LBGT 计价）  |
| rate         | uint256   | 奖品中奖率（0.01% 精度，0-10000）|
| number       | uint256   | 奖品数量               |

### Gachapon（扭蛋机）

| 字段             | 类型                | 说明                   |
| ---------------- | ------------------- | ---------------------- |
| name             | string              | 扭蛋机名称             |
| ticketsPerGacha  | uint256             | 每次抽奖消耗的抽奖券数量|
| isActive         | bool                | 是否有效               |
| prizeCount       | uint256             | 奖品种类数量           |
| prizes           | mapping(uint256=>Prize) | 奖品ID到奖品的映射 |

### GachaponSettings（全局配置）

| 字段             | 类型                | 说明                   |
| ---------------- | ------------------- | ---------------------- |
| rewardToken      | address             | 奖励代币地址（LBGT）   |
| randomGenerator  | IRandomGenerator    | 随机数生成合约         |
| paymentToken     | address             | 支付抽奖券的代币（如wbera）|
| pricePerTicket   | uint256             | 抽奖券单价             |
| lBGTOperator     | address             | berapaw的operator地址  |
| rewardVault      | address             | rewardVault地址        |
| stakingToken     | address             | 质押代币地址           |
| incentiveRate    | uint256             | 激励率                 |
| incentiveManager | address             | 激励管理合约地址       |

---

## 主要功能

### 用户相关

- **购买抽奖券**
  - `buyTicket(uint256 numTickets)`：使用 paymentToken 购买抽奖券，需提前 approve 给 incentiveManager。
  - `buyTicketWithNative(uint256 numTickets)`：使用原生币购买抽奖券（自动 wrap 成 paymentToken）。

- **查询抽奖券数量**
  - `getTickets(address user)`：查询用户当前持有的抽奖券数量。

- **抽奖**
  - `gacha(uint256 gachaponId)`：消耗抽奖券进行抽奖，奖品自动发放。

- **查询 LBGT 返奖金额**
  - `prizeLBGT(uint256 gachaponID)`：查询指定扭蛋机当前 LBGT 返奖金额。

- **手动领取 LBGT**
  - `claimLBGT()`：调用 berapaw operator 合约领取 LBGT。

---

### 管理员相关

- **创建扭蛋机**
  - `createGachapon(string name, uint256 ticketsPerGacha)`：创建新扭蛋机。

- **奖品管理**
  - `addPrize(...)`：添加奖品。
  - `updatePrize(...)`：更新奖品信息。
  - `removePrize(...)`：移除奖品（将奖品数量设为0）。

- **扭蛋机管理**
  - `updateTicketsPerGacha(uint256 gachaponID, uint256 ticketsPerGacha)`：所有奖品用完后可调整每次抽奖所需票数。
  - `closeGachapon(uint256 gachaponID)`：关闭扭蛋机。

- **全局配置管理**
  - `setGachaponSettings(GachaponSettings)`：设置全局参数。
  - `setRandomGenerator(address)`：设置随机数生成合约。
  - `setRewardToken(address)`：设置奖励代币。

- **质押与奖励池管理**
  - `stakeAndSetupOperator()`：将 stakingToken 质押到 rewardVault 并设置 operator。
  - `unStake()`：从 rewardVault 赎回质押代币。

- **紧急操作**
  - `emergencyWithdraw(address token, uint256 amount)`：紧急提取合约内代币。

- **合约暂停/恢复**
  - `pause()` / `unpause()`：暂停/恢复合约。

---

## 事件

- `GachaponCreated(uint256, string)`：创建扭蛋机
- `PrizeAdded(uint256, uint256, string, uint256, uint256, uint256)`：添加奖品
- `PrizeRemoved(uint256, uint256)`：移除奖品
- `PrizeUpdated(uint256, uint256, string, uint256, uint256, uint256)`：更新奖品
- `GachaResult(address, uint256, uint256, uint256, uint256)`：抽奖结果
- `TicketBought(address, uint256, IERC20, uint256)`：购票
- `GachaponClosed(uint256)`：关闭扭蛋机
- `TicketsPerGachaUpdated(uint256, uint256)`：更新每次抽奖所需票数

---

## 权限说明

- `DEFAULT_ADMIN_ROLE`：合约部署者，拥有所有权限
- `ADMIN_ROLE`：管理全局参数、奖品、扭蛋机等
- `UPGRADER_ROLE`：合约升级权限

---

## 其他说明

- 奖品中奖率（rate）总和不能超过 10000（即 100%），剩余部分为 LBGT 返奖概率。
- LBGT 返奖金额根据奖品中奖率和奖品价值动态调整，确保奖池可持续。
- 合约支持 UUPS 升级模式，需通过 `_authorizeUpgrade` 授权。

---

## 接口依赖

- `IERC20`、`SafeERC20`：ERC20 代币操作
- `IRandomGenerator`：随机数生成接口
- `IVaultManager`、`IRewardVault`、`IBeraPawForge`：奖励池与激励相关接口
- `WETH`：原生币包装合约

---

## 版本信息

- Solidity: ^0.8.20
- OpenZeppelin Contracts: 4.x

---


