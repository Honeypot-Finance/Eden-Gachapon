// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IBeraPawForge.sol";
import "./interfaces/IRewardVault.sol";

interface IRandomGenerator {
    function getRandomNumber() external returns (uint256);
}

contract EdenLottery is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct Prize {
        string name; // 奖品名称
        address feeAddress; // 奖品接收地址
        uint256 tokenValue; // 奖品价值，LBGT计价
        uint256 weight; // 奖品权重
        bool isActive; // 奖品是否有效
    }

    struct LotteryConfig {
        address rewardToken; // 奖励代币地址 目前默认是LBGT
        uint256 minPoolBalance;
        address randomGenerator; // 随机数生成策略合约
    }

    struct EntryFeeConfig {
        address token; // 抽奖券支付的代币（目前暂定是wbera）
        uint256 amount; // 抽奖券价格，默认是0.69wbera
    }

    struct RewardConfig {
        address operatorAddress; // berapaw的operator地址
        address rewardVault; // rewardVault地址
        address stakingToken; // stakingToken地址
        uint256 incentiveRate; // 激励比例，使用多少个wbera用来激励BGT，比如 0.7*10**18 代表 0.7Bera Per BGT
    }

    uint256 public constant PRECISION = 10000; // 0.01% 精度

    // 状态变量
    mapping(uint256 => Prize) public prizes;
    uint256 public prizeCount;
    EntryFeeConfig public entryFeeConfig;
    address public rewardToken; // 奖励代币地址 目前默认是LBGT
    uint256 public minPoolBalance;
    IRandomGenerator public randomGenerator;
    mapping(address => uint256) public ticketCount; // 用户抽奖券数量
    uint256 public totalTicketCount; // 总抽奖券数量

    // rewardValut相关配置信息
    address public operatorAddress;
    address public rewardVault;
    address public stakingToken;
    uint256 public incentiveRate; // 激励比例，使用多少个wbera用来激励BGT，比如 0.7*10**18 代表 0.7Bera Per BGT

    // 添加未中奖权重
    uint256 public totalWeight; // 奖品总权重，不包含未中奖权重
    uint256 public noPrizeWeight; // 未中奖的权重

    // 事件
    event PrizeAdded(
        uint256 indexed prizeId,
        string name,
        uint256 tokenValue,
        uint256 weight
    );
    event PrizeRemoved(uint256 indexed prizeId);
    event PrizeUpdated(
        uint256 indexed prizeId,
        string name,
        uint256 tokenValue,
        uint256 weight
    );
    event LotteryResult(
        address indexed user,
        uint256 prizeId,
        bool won,
        uint256 amount
    );
    event TokenAddressUpdated(address oldAddress, address newAddress);
    event EntryFeeConfigUpdated(address token, uint256 amount);
    event MinPoolBalanceUpdated(uint256 oldBalance, uint256 newBalance);
    event RandomGeneratorUpdated(address oldGenerator, address newGenerator);
    event RewardConfigUpdated(
        address operatorAddress,
        address rewardVault,
        address stakingToken,
        uint256 incentiveRate
    );
    event TicketBought(address indexed user, uint256 ticketCount);
    event TicketUsed(address indexed user, uint256 ticketCount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        LotteryConfig memory _lotteryConfig,
        EntryFeeConfig memory _entryFeeConfig,
        RewardConfig memory _rewardConfig
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // 设置抽奖配置
        rewardToken = _lotteryConfig.rewardToken;
        minPoolBalance = _lotteryConfig.minPoolBalance;
        randomGenerator = IRandomGenerator(_lotteryConfig.randomGenerator);

        // 设置入场费配置
        require(_entryFeeConfig.token != address(0), "Invalid entry fee token");
        require(_entryFeeConfig.amount > 0, "Entry fee must be greater than 0");
        entryFeeConfig = _entryFeeConfig;

        // 设置奖励配置
        operatorAddress = _rewardConfig.operatorAddress;
        rewardVault = _rewardConfig.rewardVault;
        stakingToken = _rewardConfig.stakingToken;
        incentiveRate = _rewardConfig.incentiveRate;
    }

    // ======user 相关函数 start======

    // 购买奖券
    function buyTicket() external nonReentrant whenNotPaused {
        // 转移抽奖费用
        IERC20(entryFeeConfig.token).safeTransferFrom(
            msg.sender,
            address(this),
            entryFeeConfig.amount
        );

        // 添加incentive
        _addRewardVaultIncentive(entryFeeConfig.amount);

        // 增加抽奖券数量
        ticketCount[msg.sender]++;
        totalTicketCount++;
        emit TicketBought(msg.sender, ticketCount[msg.sender]);
    }

    // 查询当前用户抽奖券数量
    function getTicketCount(address user) external view returns (uint256) {
        return ticketCount[user];
    }

    // 抽奖函数
    function lottery() external nonReentrant whenNotPaused {
        require(
            address(randomGenerator) != address(0),
            "Random generator not set"
        );
        require(ticketCount[msg.sender] > 0, "No tickets available");
        // 需要保证当前已经配置好奖品
        require(prizeCount > 1, "No prizes available");

        // 扣除抽奖券数量
        ticketCount[msg.sender]--;
        totalTicketCount--;
        emit TicketUsed(msg.sender, ticketCount[msg.sender]);

        // hook操作，claim lbgt
        _beforeLottery();

        require(
            IERC20(rewardToken).balanceOf(address(this)) >= minPoolBalance,
            "Insufficient pool balance"
        );

        // 获取随机数并选择奖品
        uint256 randomNumber = randomGenerator.getRandomNumber();
        uint256 prizeId = _selectPrize(randomNumber);

        if (prizeId == type(uint256).max) {
            // 未中奖，返还代币
            uint256 refundAmount = _calculateRefundAmount();
            emit LotteryResult(msg.sender, prizeId, false, refundAmount);
        } else {
            // 中奖，发送奖品
            Prize memory prize = prizes[prizeId];
            IERC20(rewardToken).safeTransfer(
                prize.feeAddress,
                prize.tokenValue
            );
            emit LotteryResult(msg.sender, prizeId, true, prize.tokenValue);
        }
    }

    // 查询当前支持退款的金额
    function refundAmountAvailable() external view returns (uint256) {
        return _calculateRefundAmount();
    }

    function _calculateRefundAmount() internal view returns (uint256) {
        //（entryFeeConfig.amount - ∑中奖率*奖品价格）/（1- ∑中奖率）
        // 计算总中奖率
        uint256 totalWinRate = 0; // 精度为0.01%
        uint256 totalPrizeValue = 0;
        uint256 totalWeightWithoutNoPrize = totalWeight + noPrizeWeight;

        // 遍历所有奖品计算中奖率和奖品价值
        for (uint256 i = 0; i < prizeCount; i++) {
            if (!prizes[i].isActive) continue;

            // 计算单个奖品的中奖率 (weight / totalWeightWithoutNoPrize)
            uint256 winRate = (prizes[i].weight * PRECISION) /
                totalWeightWithoutNoPrize;
            totalWinRate += winRate;

            // 计算中奖率 * 奖品价格
            totalPrizeValue += (winRate * prizes[i].tokenValue) / PRECISION;
        }

        require(
            totalPrizeValue < entryFeeConfig.amount,
            "Total prize value is greater than entry fee"
        );

        // 计算未中奖率
        uint256 loseRate = PRECISION - totalWinRate;
        require(loseRate > 0, "No lose rate");

        // 计算退款amount
        // (entry.amount - totalPrizeValue) / loseRate
        uint256 numerator = entryFeeConfig.amount - totalPrizeValue;

        uint256 refundAmount = (numerator * PRECISION) / loseRate;
        require(refundAmount > 0, "Refund amount must be greater than 0");
        return refundAmount;
    }

    // 内部函数
    function _selectPrize(
        uint256 randomNumber
    ) internal view returns (uint256) {
        // 确保随机数在总权重范围内
        uint256 boundedRandom = randomNumber % (totalWeight + noPrizeWeight);

        // 如果随机数落在未中奖权重范围内
        if (boundedRandom < noPrizeWeight) {
            return type(uint256).max; // 表示未中奖
        }

        // 否则在奖品中随机选择
        boundedRandom = boundedRandom - noPrizeWeight;

        uint256 accumulatedWeight = 0;
        for (uint256 i = 0; i < prizeCount; i++) {
            if (!prizes[i].isActive) continue;
            accumulatedWeight = accumulatedWeight + prizes[i].weight;
            if (boundedRandom < accumulatedWeight) {
                return i;
            }
        }
        return type(uint256).max; // 表示未中奖
    }

    // 使用前需要claimLbgt
    function _beforeLottery() internal {
        // claim lbgt
        IBeraPawForge(operatorAddress).mint(
            address(this),
            rewardVault,
            address(this)
        );
    }

    // ======user 相关函数 end======

    // ======admin 相关函数 start======
    // 奖品管理函数
    function addPrize(
        string memory name,
        address feeAddress,
        uint256 tokenValue,
        uint256 weight
    ) external onlyRole(ADMIN_ROLE) {
        require(weight > 0, "Weight must be greater than 0");
        require(feeAddress != address(0), "Invalid fee address");
        _addPrize(name, feeAddress, tokenValue, weight);
    }

    function _addPrize(
        string memory name,
        address feeAddress,
        uint256 tokenValue,
        uint256 weight
    ) internal {
        prizes[prizeCount] = Prize(name, feeAddress, tokenValue, weight, true);
        totalWeight = totalWeight + weight;
        prizeCount++;
        emit PrizeAdded(prizeCount, name, tokenValue, weight);
    }

    function updatePrize(
        uint256 prizeId,
        string memory name,
        address feeAddress,
        uint256 tokenValue,
        uint256 weight
    ) external onlyRole(ADMIN_ROLE) {
        require(prizeId < prizeCount, "Invalid prize ID");
        require(weight > 0, "Weight must be greater than 0");
        require(feeAddress != address(0), "Invalid fee address");

        Prize storage prize = prizes[prizeId];
        totalWeight = totalWeight - prize.weight + weight;

        prize.name = name;
        prize.feeAddress = feeAddress;
        prize.tokenValue = tokenValue;
        prize.weight = weight;

        emit PrizeUpdated(prizeId, name, tokenValue, weight);
    }

    function removePrize(uint256 prizeId) external onlyRole(ADMIN_ROLE) {
        require(prizeId < prizeCount, "Invalid prize ID");
        Prize storage prize = prizes[prizeId];
        require(prize.isActive, "Prize already removed");

        totalWeight = totalWeight - prize.weight;
        prize.isActive = false;

        emit PrizeRemoved(prizeId);
    }

    function setEntryFeeConfig(
        EntryFeeConfig memory _entryFeeConfig
    ) external onlyRole(ADMIN_ROLE) {
        require(_entryFeeConfig.token != address(0), "Invalid entry fee token");
        require(_entryFeeConfig.amount > 0, "Entry fee must be greater than 0");

        EntryFeeConfig memory oldConfig = entryFeeConfig;
        entryFeeConfig = _entryFeeConfig;

        emit EntryFeeConfigUpdated(
            _entryFeeConfig.token,
            _entryFeeConfig.amount
        );
    }

    // 更新RewardConfig
    function setRewardConfig(
        RewardConfig memory _rewardConfig
    ) external onlyRole(ADMIN_ROLE) {
        require(
            _rewardConfig.incentiveRate > 0,
            "Incentive rate must be greater than 0"
        );
        operatorAddress = _rewardConfig.operatorAddress;
        rewardVault = _rewardConfig.rewardVault;
        stakingToken = _rewardConfig.stakingToken;
        incentiveRate = _rewardConfig.incentiveRate;

        emit RewardConfigUpdated(
            _rewardConfig.operatorAddress,
            _rewardConfig.rewardVault,
            _rewardConfig.stakingToken,
            _rewardConfig.incentiveRate
        );
    }

    function setMinPoolBalance(
        uint256 _minPoolBalance
    ) external onlyRole(ADMIN_ROLE) {
        uint256 oldBalance = minPoolBalance;
        minPoolBalance = _minPoolBalance;
        emit MinPoolBalanceUpdated(oldBalance, _minPoolBalance);
    }

    // 管理函数
    function setRandomGenerator(
        address _randomGenerator
    ) external onlyRole(ADMIN_ROLE) {
        require(_randomGenerator != address(0), "Invalid generator address");
        address oldGenerator = address(randomGenerator);
        randomGenerator = IRandomGenerator(_randomGenerator);
        emit RandomGeneratorUpdated(oldGenerator, _randomGenerator);
    }

    function setRewardToken(
        address _rewardToken
    ) external onlyRole(ADMIN_ROLE) {
        require(_rewardToken != address(0), "Invalid token address");
        address oldToken = rewardToken;
        rewardToken = _rewardToken;
        emit TokenAddressUpdated(oldToken, _rewardToken);
    }

    // 紧急函数
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function stakeAndSetupOperator() external onlyRole(ADMIN_ROLE) {
        uint256 stakingTokenBalance = IERC20(stakingToken).balanceOf(
            address(this)
        );
        require(stakingTokenBalance > 0, "No staking token balance");
        // approve staking token to rewardVault
        IERC20(stakingToken).approve(rewardVault, stakingTokenBalance);

        // stake token into rewardVault
        IRewardVault(rewardVault).stake(stakingTokenBalance);

        // set operatorAddress
        IRewardVault(rewardVault).setOperator(operatorAddress);
    }

    function unStake() external onlyRole(ADMIN_ROLE) {
        uint256 balance = IRewardVault(rewardVault).balanceOf(address(this));
        require(balance > 0, "No balance to unstake");

        IRewardVault(rewardVault).withdraw(balance);

        // get stakingToken balance
        uint256 stakingTokenBalance = IERC20(stakingToken).balanceOf(
            address(this)
        );

        // transfer stakingToken to msg.sender
        bool success = IERC20(stakingToken).transfer(
            msg.sender,
            stakingTokenBalance
        );
        require(success, "Staking token transfer failed");
    }

    // TODO: 添加激励
    function _addRewardVaultIncentive(uint256 amount) internal {
        // 添加incentive
        IRewardVault(rewardVault).addIncentive(
            entryFeeConfig.token,
            amount,
            incentiveRate
        );
    }

    // withdraw当前合约的token
    function withdrawToken(
        address token,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "Insufficient token balance");

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    // UUPS升级相关
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
