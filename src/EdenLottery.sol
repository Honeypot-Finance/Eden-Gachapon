// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

interface IRandomGenerator {
    function getRandomNumber() external returns (uint256);
}

contract EdenLottery is 
    Initializable, 
    AccessControl, 
    Pausable, 
    ReentrancyGuard, 
    UUPSUpgradeable 
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct Prize {
        string name;
        address feeAddress;
        uint256 tokenValue;
        uint256 weight;
        bool isActive;
    }

    // 状态变量
    mapping(uint256 => Prize) public prizes;
    uint256 public prizeCount;
    uint256 public totalWeight;
    uint256 public entryFee;
    uint256 public refundRate;
    address public rewardToken;
    uint256 public minPoolBalance;
    IRandomGenerator public randomGenerator;

    // 事件
    event PrizeAdded(uint256 indexed prizeId, string name, uint256 tokenValue, uint256 weight);
    event PrizeRemoved(uint256 indexed prizeId);
    event PrizeUpdated(uint256 indexed prizeId, string name, uint256 tokenValue, uint256 weight);
    event LotteryResult(address indexed user, uint256 prizeId, bool won, uint256 amount);
    event TokenAddressUpdated(address oldAddress, address newAddress);
    event EntryFeeUpdated(uint256 oldFee, uint256 newFee);
    event RefundRateUpdated(uint256 oldRate, uint256 newRate);
    event MinPoolBalanceUpdated(uint256 oldBalance, uint256 newBalance);
    event RandomGeneratorUpdated(address oldGenerator, address newGenerator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _rewardToken,
        uint256 _entryFee,
        uint256 _refundRate,
        uint256 _minPoolBalance,
        address _randomGenerator
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        rewardToken = _rewardToken;
        entryFee = _entryFee;
        refundRate = _refundRate;
        minPoolBalance = _minPoolBalance;
        randomGenerator = IRandomGenerator(_randomGenerator);
    }

    // 奖品管理函数
    function addPrize(
        string memory name,
        address feeAddress,
        uint256 tokenValue,
        uint256 weight
    ) external onlyRole(ADMIN_ROLE) {
        require(weight > 0, "Weight must be greater than 0");
        require(feeAddress != address(0), "Invalid fee address");
        
        prizes[prizeCount] = Prize(name, feeAddress, tokenValue, weight, true);
        totalWeight = totalWeight.add(weight);
        
        emit PrizeAdded(prizeCount, name, tokenValue, weight);
        prizeCount++;
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
        totalWeight = totalWeight.sub(prize.weight).add(weight);
        
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

        totalWeight = totalWeight.sub(prize.weight);
        prize.isActive = false;

        emit PrizeRemoved(prizeId);
    }

    // 抽奖函数
    function lottery() external nonReentrant whenNotPaused {
        require(address(randomGenerator) != address(0), "Random generator not set");
        require(IERC20(rewardToken).balanceOf(address(this)) >= minPoolBalance, "Insufficient pool balance");

        // 转移抽奖费用
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), entryFee);

        // 获取随机数并选择奖品
        uint256 randomNumber = randomGenerator.getRandomNumber();
        uint256 prizeId = _selectPrize(randomNumber);

        if (prizeId == type(uint256).max) {
            // 未中奖，返还代币
            uint256 refundAmount = entryFee.mul(refundRate).div(100);
            IERC20(rewardToken).safeTransfer(msg.sender, refundAmount);
            emit LotteryResult(msg.sender, prizeId, false, refundAmount);
        } else {
            // 中奖，发送奖品
            Prize memory prize = prizes[prizeId];
            IERC20(rewardToken).safeTransfer(prize.feeAddress, prize.tokenValue);
            emit LotteryResult(msg.sender, prizeId, true, prize.tokenValue);
        }
    }

    // 内部函数
    function _selectPrize(uint256 randomNumber) internal view returns (uint256) {
        uint256 accumulatedWeight = 0;
        for (uint256 i = 0; i < prizeCount; i++) {
            if (!prizes[i].isActive) continue;
            accumulatedWeight = accumulatedWeight.add(prizes[i].weight);
            if (randomNumber < accumulatedWeight) {
                return i;
            }
        }
        return type(uint256).max; // 表示未中奖
    }

    // 管理函数
    function setRandomGenerator(address _randomGenerator) external onlyRole(ADMIN_ROLE) {
        require(_randomGenerator != address(0), "Invalid generator address");
        address oldGenerator = address(randomGenerator);
        randomGenerator = IRandomGenerator(_randomGenerator);
        emit RandomGeneratorUpdated(oldGenerator, _randomGenerator);
    }

    function setEntryFee(uint256 _entryFee) external onlyRole(ADMIN_ROLE) {
        require(_entryFee > 0, "Fee must be greater than 0");
        uint256 oldFee = entryFee;
        entryFee = _entryFee;
        emit EntryFeeUpdated(oldFee, _entryFee);
    }

    function setRefundRate(uint256 _refundRate) external onlyRole(ADMIN_ROLE) {
        require(_refundRate <= 100, "Refund rate must be <= 100");
        uint256 oldRate = refundRate;
        refundRate = _refundRate;
        emit RefundRateUpdated(oldRate, _refundRate);
    }

    function setMinPoolBalance(uint256 _minPoolBalance) external onlyRole(ADMIN_ROLE) {
        uint256 oldBalance = minPoolBalance;
        minPoolBalance = _minPoolBalance;
        emit MinPoolBalanceUpdated(oldBalance, _minPoolBalance);
    }

    function setRewardToken(address _rewardToken) external onlyRole(ADMIN_ROLE) {
        require(_rewardToken != address(0), "Invalid token address");
        address oldToken = rewardToken;
        rewardToken = _rewardToken;
        emit TokenAddressUpdated(oldToken, _rewardToken);
    }

    // 紧急函数
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // UUPS升级相关
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
