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
import "./interfaces/IVaultManager.sol";
import "./interfaces/IInfrared.sol";
import "./interfaces/IAlgebraRouter.sol";
import "./base/WETH.sol";

interface IRandomGenerator {
    function getRandomNumber() external returns (uint256);
}

contract EdenGachapon is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant PRECISION = 10000; // 0.01% 精度

    struct Prize {
        string name; // 奖品名称
        address feeAddress; // 奖品接收地址
        uint256 prizeValue; // 奖品价值，LBGT计价
        uint256 rate; // 奖品中间率 0-10000，0.01% 精度
        uint256 number; // 奖品数量
    }

    struct Gachapon {
        string name; // 扭蛋机名称
        uint256 ticketsPerGacha; // 每次抽奖消耗的抽奖券数量
        bool isActive; // 扭蛋机是否有效
        uint256 prizeCount; // 奖品种类数量
        mapping(uint256 => Prize) prizes; // 奖品 ID 到奖品的映射
    }

    struct GachaponSettings {
        // GachaponConfig
        address rewardToken; // 奖励代币地址，目前默认是LBGT
        IRandomGenerator randomGenerator; // 随机数生成策略合约

        // 抽奖票设置
        address paymentToken; // 抽奖券支付的代币（目前暂定是wbera）
        uint256 pricePerTicket; // 抽奖券价格，默认是 0.69*(10**18) wBERA

        // RV 相关设置
        address lBGTOperator; // berapaw的operator地址
        address rewardVault; // rewardVault地址
        address stakingToken; // stakingToken地址
        uint256 incentiveRate; // 贿赂率，使用多少个wbera用来激励BGT，比如 0.9*(10**18) 代表 0.9 Bera Per BGT

        // 激励manager
        address incentiveManager; // 激励manager地址
    }

    // Gachapons 全局配置
    GachaponSettings public gachaponSettings;

    // 抽奖机
    mapping(uint256 => Gachapon) public gachapons; // 扭蛋机 ID 到扭蛋机的映射
    uint256 public gachaponCount;

    // 用户抽奖券余额
    mapping(address => uint256) public tickets; // 用户抽奖券数量
    
    // 创建抽奖机
    event GachaponCreated(uint256 indexed gachaponId, string name);

    // 添加奖品
    event PrizeAdded(
        uint256 indexed gachaponId,
        uint256 indexed prizeId,
        string name,
        uint256 prizeValue,
        uint256 number,
        uint256 rate
    );

    // 移除奖品
    event PrizeRemoved(uint256 indexed gachaponId, uint256 indexed prizeId);

    // 更新奖品参数
    event PrizeUpdated(
        uint256 indexed gachaponId,
        uint256 indexed prizeId,
        string name,
        uint256 prizeValue,
        uint256 number,
        uint256 rate
    );

    // 扭蛋结果
    event GachaResult(
        address indexed user,
        uint256 indexed gachaponId,
        uint256 prizeId,
        uint256 lBGTAmount,
        uint256 numTickets
    );

    // 买票
    event TicketBought(address indexed user, uint256 numTickets, IERC20 paymentToken, uint256 paymentAmount);

    // 关闭扭蛋机
    event GachaponClosed(uint256 indexed gachaponId);

    // 更新扭蛋机每次抽奖的票数
    event TicketsPerGachaUpdated(uint256 indexed gachaponId, uint256 ticketsPerGacha);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        GachaponSettings memory _gachaponSettings
    ) public reinitializer(9) {
        // __AccessControl_init();
        // __Pausable_init();
        // __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // 设置 GachaponSettings
        require(_gachaponSettings.paymentToken != address(0), "Invalid payment token");
        require(_gachaponSettings.pricePerTicket > 0, "Price per ticket must be greater than 0");
        require(_gachaponSettings.incentiveRate > 0, "Incentive rate must be greater than 0");
        require(_gachaponSettings.rewardToken != address(0), "Invalid reward token");
        require(address(_gachaponSettings.randomGenerator) != address(0), "Invalid random generator");
        require(_gachaponSettings.lBGTOperator != address(0), "Invalid operator address");
        require(_gachaponSettings.rewardVault != address(0), "Invalid reward vault");
        require(_gachaponSettings.stakingToken != address(0), "Invalid staking token");
        require(_gachaponSettings.incentiveManager != address(0), "Invalid incentive manager");

        gachaponSettings = _gachaponSettings;
    }

    function setGachaponSettings(
        GachaponSettings memory _gachaponSettings
    ) public onlyRole(ADMIN_ROLE) { 
        // 设置 GachaponSettings
        require(_gachaponSettings.paymentToken != address(0), "Invalid payment token");
        require(_gachaponSettings.pricePerTicket > 0, "Price per ticket must be greater than 0");
        require(_gachaponSettings.incentiveRate > 0, "Incentive rate must be greater than 0");
        require(_gachaponSettings.rewardToken != address(0), "Invalid reward token");
        require(address(_gachaponSettings.randomGenerator) != address(0), "Invalid random generator");
        require(_gachaponSettings.lBGTOperator != address(0), "Invalid operator address");
        require(_gachaponSettings.rewardVault != address(0), "Invalid reward vault");
        require(_gachaponSettings.stakingToken != address(0), "Invalid staking token");
        require(_gachaponSettings.incentiveManager != address(0), "Invalid incentive manager");

        gachaponSettings = _gachaponSettings;
    }

    // ======user 相关函数 start======
    // 购买奖券,需要approve给incentiveManager
    function buyTicket(uint256 numTickets) external nonReentrant whenNotPaused {
        require(numTickets > 0, "Number of tickets must be greater than 0");

        uint256 totalCost = numTickets * gachaponSettings.pricePerTicket;

        // 转移抽奖的费用作为激励
        IERC20(gachaponSettings.paymentToken).safeTransferFrom(
            msg.sender,
            address(this),
            totalCost
        );

        // 转移抽奖的费用给incentiveManager
        IERC20(gachaponSettings.paymentToken).safeTransfer(
            address(gachaponSettings.incentiveManager),
            totalCost
        );

        // 添加奖励池激励
        IVaultManager(gachaponSettings.incentiveManager).addIncentive(
            gachaponSettings.rewardVault,
            gachaponSettings.paymentToken,
            totalCost,
            gachaponSettings.incentiveRate
        );

        // 增加用户的抽奖券数量
        tickets[msg.sender] += numTickets;

        emit TicketBought(msg.sender, numTickets, IERC20(gachaponSettings.paymentToken), totalCost);
    }

    function buyTicketWithNative(uint256 numTickets) external payable nonReentrant whenNotPaused {
        require(numTickets > 0, "Number of tickets must be greater than 0");
        require(msg.value > 0, "Must send native tokens");

        uint256 totalCost = numTickets * gachaponSettings.pricePerTicket;
        require(msg.value == totalCost, "Incorrect native token amount");

        // wrap native token (e.g., ETH to WETH)
        WETH(payable(gachaponSettings.paymentToken)).deposit{value: totalCost}();

        // send wrapped token to this contract (already here after deposit)

        // send to incentiveManager
        IERC20(gachaponSettings.paymentToken).safeTransfer(
            address(gachaponSettings.incentiveManager),
            totalCost
        );

        // add incentive
        IVaultManager(gachaponSettings.incentiveManager).addIncentive(
            gachaponSettings.rewardVault,
            gachaponSettings.paymentToken,
            totalCost,
            gachaponSettings.incentiveRate
        );

        tickets[msg.sender] += numTickets;

        emit TicketBought(msg.sender, numTickets, IERC20(gachaponSettings.paymentToken), totalCost);
    }

    // 查询当前用户抽奖券数量
    function getTickets(address user) external view returns (uint256) {
        return tickets[user];
    }

    // 扭蛋
    function gacha(uint256 gachaponId) external nonReentrant whenNotPaused {
        require(gachaponId < gachaponCount, "Invalid gachapon ID");

        Gachapon storage gachapon = gachapons[gachaponId];

        require(gachapon.isActive, "Gachapon is not active");
        require(
            tickets[msg.sender] >= gachapon.ticketsPerGacha,
            "Not enough tickets"
        );

        tickets[msg.sender] -= gachapon.ticketsPerGacha;

        uint256 randomNumber = gachaponSettings.randomGenerator.getRandomNumber();
        uint256 prizeId = _selectPrize(gachapon, randomNumber);

        Prize storage prize = gachapon.prizes[prizeId];

        // 抽奖前先从 RV 里 claim LBGT
        // _claimLBGT();

        // 抽中 LBGT 发给用户，抽中其他奖品发给供应商
        if (prizeId == 0) {
            IERC20(gachaponSettings.rewardToken).safeTransfer(
                msg.sender,
                prize.prizeValue
            );
        } else {
            require(prize.number > 0, "Prize out of stock");

            prize.number--;
            if (prize.number == 0) {
                // 某个奖品库存耗尽，更新 LBGT 返奖金额
                _updatePrizeLBGT(gachaponId);
            }
            IERC20(gachaponSettings.rewardToken).safeTransfer(
                prize.feeAddress,
                prize.prizeValue
            );
        }
        emit GachaResult(
            msg.sender,
            gachaponId,
            prizeId,
            prize.prizeValue,
            gachapon.ticketsPerGacha
        );
    }

    // 内部函数：选择奖品
    function _selectPrize(
        Gachapon storage gachapon,
        uint256 randomNumber
    ) internal view returns (uint256) {
        uint256 boundedRandom = randomNumber % PRECISION;
        uint256 accumulatedRate = 0;

        // 遍历除 LBGT 外所有奖品，不中奖返回 0（LBGT 返奖）
        for (uint256 i = 1; i < gachapon.prizeCount; i++) {
            Prize storage prize = gachapon.prizes[i];
            if (prize.number==0) continue;

            accumulatedRate += prize.rate;
            if (boundedRandom < accumulatedRate) {
                return i;
            }
        }

        return 0; // 抽中 LBGT
    }

    // 查询抽中 LBGT 的返奖金额，每台扭蛋机的 LBGT 返奖金额不一样
    function prizeLBGT(uint256 gachaponID) external view returns (uint256) {
        return gachapons[gachaponID].prizes[0].prizeValue;
    }

    // 更新 LBGT 返奖金额
    function _updatePrizeLBGT(uint256 gachaponID) internal returns (uint256) {
        //LBGT 返奖金额 = (entryFeeAmount*票数 - ∑中奖率*奖品价格)/(1- ∑中奖率)
        Gachapon storage gachapon = gachapons[gachaponID];
        uint256 totalRate = 0;
        uint256 totalPrizeValueWeighted = 0;

        // 遍历除 LBGT 外的所有奖品，计算总中奖率和加权奖品价值
        for (uint256 i = 1; i < gachapon.prizeCount; i++) {
            Prize storage prize = gachapon.prizes[i];
            if (prize.number == 0) continue; // 跳过库存为 0 的奖品

            totalRate += prize.rate;
            totalPrizeValueWeighted += (prize.rate * prize.prizeValue);
        }

        // 检查总中奖率是否超过 PRECISION
        require(totalRate < PRECISION, "Total prize rate exceeds precision");

        // 计算 LBGT 奖品的返奖金额
        uint256 totalEntryFee = gachapon.ticketsPerGacha * gachaponSettings.pricePerTicket * PRECISION;
        
        // 检查总抽奖费用是否大于加权奖品价值，如果不满足条件，LBGT 返奖金额会是负数，这意味着奖池不够维持这个奖品清单的开支
        require(totalEntryFee > totalPrizeValueWeighted, "LBGT not enough for paying Prizes");

        uint256 prizeLBGTAmount = (totalEntryFee - totalPrizeValueWeighted) / (PRECISION - totalRate) / (10**16) * (10**16); // 最后做一个向下取整，只保留小数点后两位
        
        gachapon.prizes[0].prizeValue = prizeLBGTAmount;

        return prizeLBGTAmount;
    }

    function claimLBGT() external {
        _claimLBGT();
    }

    // 使用前需要claimLbgt
    function _claimLBGT() internal {
        // hardcoded addresses
        address infraredAddress = address(0xb71b3DaEA39012Fb0f2B14D2a9C86da9292fC126);
        address stakingTokenAddress = address(0x5f77967f5129CF2F294E070284Ff0F0e6F838568);
        address iBGTAddress = address(0xac03CABA51e17c86c921E1f6CBFBdC91F8BB2E6b);
        address swapRouter = address(0xFff605964840a5511f595EB970011EcBffa46b39);
        
        // claim iBGT rewards
        IInfrared(infraredAddress).claimExternalVaultRewards(
            stakingTokenAddress,
            address(this)
        );

        // check iBGT rewards
        uint256 iBGTRewards = IERC20(iBGTAddress).balanceOf(address(this));
        // Cap rewards at 100 if balance exceeds it in case of too shallow pool.
        if (iBGTRewards > 100) {
            iBGTRewards = 100;
        }
        require(iBGTRewards > 0, "No iBGT rewards to recycle");

        IERC20(iBGTAddress).approve(swapRouter, iBGTRewards);

        // swap 1/100 iBGT to LBGT to this contract for gacha
        uint256 swapAmount = iBGTRewards * 3 / 100;
        IAlgebraRouter.ExactInputParams memory params = IAlgebraRouter.ExactInputParams({
            path: abi.encodePacked(
                iBGTAddress,
                address(0), // deployer address 0
                address(0x6969696969696969696969696969696969696969),
                address(0), // deployer address 0
                gachaponSettings.rewardToken
            ),
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes deadline
            amountIn: swapAmount,
            amountOutMinimum: swapAmount // at least the same amount back
        });
        IAlgebraRouter(swapRouter).exactInput(params);
        
        // swap 85/100 iBGT to wBERA for recycling
        uint256 swap2beraAmount = iBGTRewards * 85 / 100;
        IAlgebraRouter.ExactInputSingleParams memory swap2beraParams = IAlgebraRouter.ExactInputSingleParams({
            tokenIn: iBGTAddress,
            tokenOut: address(0x6969696969696969696969696969696969696969),
            deployer: address(0), // deployer address 0
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes deadline
            amountIn: swap2beraAmount,
            amountOutMinimum: swap2beraAmount, // at least the same amount back
            limitSqrtPrice: 0 // No price limit
        });
        IAlgebraRouter(swapRouter).exactInputSingle(swap2beraParams);

        uint256 wBERABalance = IERC20(gachaponSettings.paymentToken).balanceOf(address(this));
        // 转移抽奖的费用给incentiveManager
        IERC20(gachaponSettings.paymentToken).safeTransfer(
            address(gachaponSettings.incentiveManager),
            wBERABalance
        );

        // 添加奖励池激励
        IVaultManager(gachaponSettings.incentiveManager).addIncentive(
            gachaponSettings.rewardVault,
            gachaponSettings.paymentToken,
            wBERABalance,
            gachaponSettings.incentiveRate
        );

        // send 2% to eden multi-sign
        uint256 amount = iBGTRewards * 2 / 100;
        IERC20(iBGTAddress).safeTransfer(
                address(0x1F8EA70c2C1F9f1B7C51B456c10cE719F90B362C),
                amount
        );

        // send 1.5% to punk
        uint256 punkamount = iBGTRewards * 3 / 200;
        IERC20(iBGTAddress).safeTransfer(
                address(0x8Ef3fd2Bf7ae8A190E437Aa6248D419c34428804),
                punkamount
        );

        // send 8.5% to honeypot
        uint256 honypotAmount = iBGTRewards * 17 / 200;
        IERC20(iBGTAddress).safeTransfer(
                address(0xcFF766Fbd79284036Ed722EC5302eE3597bE778B),
                honypotAmount
        );
        // 8.5% + 1.5% + 2% + 3% + 85% = 100%
    }

    // ======user 相关函数 end======

    // ======admin 相关函数 start======
    // 创建扭蛋机
    function createGachapon(
        string memory name,
        uint256 ticketsPerGacha
    ) external onlyRole(ADMIN_ROLE) {
        require(ticketsPerGacha > 0, "Tickets per draw must be greater than 0");
        Gachapon storage gachapon = gachapons[gachaponCount];
        gachapon.name = name;
        gachapon.ticketsPerGacha = ticketsPerGacha;
        gachapon.isActive = true;
        gachapon.prizeCount = 1; // 从1开始，0表示未中奖

        // 初始化 LBGT 返奖，返回票价等量的 LBGT
        gachapon.prizes[0] = Prize("LBGT", address(0), gachaponSettings.pricePerTicket * ticketsPerGacha, 0, 0);

        emit GachaponCreated(
            gachaponCount,
            name
        );
        gachaponCount++; 
    }

    // 奖品管理函数
    function addPrize(
        uint256 gachaponID,
        string memory name,
        address feeAddress,
        uint256 prizeValue,
        uint256 number,
        uint256 rate
    ) external onlyRole(ADMIN_ROLE) {
        require(gachaponID < gachaponCount, "Invalid gachapon ID");
        
        uint256 prizeId = gachapons[gachaponID].prizeCount;

        _updatePrize(gachaponID, prizeId, name, feeAddress, prizeValue, number, rate);
        _updatePrizeLBGT(gachaponID);
    }

    function _updatePrize(
        uint256 gachaponID,
        uint256 prizeId,
        string memory name,
        address feeAddress,
        uint256 prizeValue,
        uint256 number,
        uint256 rate
    ) internal {
        Gachapon storage gachapon = gachapons[gachaponID];

        require(prizeId <= gachapon.prizeCount, "Invalid prize ID");
        require(bytes(name).length > 0, "Prize name cannot be empty");
        require(number >=0 , "Prize number must be greater than or equal to 0");
        require(rate > 0, "Weight must be greater than 0");
        require(feeAddress != address(0), "Invalid fee address");

        gachapon.prizes[prizeId] = Prize(
            name,
            feeAddress,
            prizeValue,
            rate,
            number
        );
        if(prizeId == gachapon.prizeCount) {
            gachapon.prizeCount++;
        }

        emit PrizeAdded(
            gachaponID,
            gachapon.prizeCount - 1,
            name,
            prizeValue,
            number,
            rate
        );
    }

    function updatePrize(
        uint256 gachaponID,
        uint256 prizeId,
        string memory name,
        address feeAddress,
        uint256 prizeValue,
        uint256 number,
        uint256 rate
    ) external onlyRole(ADMIN_ROLE) {
        require(gachaponID < gachaponCount, "Invalid gachapon ID");

        _updatePrize(
            gachaponID,
            prizeId,
            name,
            feeAddress,
            prizeValue,
            number,
            rate
        );
        _updatePrizeLBGT(gachaponID);
        emit PrizeUpdated(
            gachaponID,
            prizeId,
            name,
            prizeValue,
            number,
            rate
        );
    }

    function removePrize(
        uint256 gachaponId,
        uint256 prizeId
    ) external onlyRole(ADMIN_ROLE) {
        require(gachaponId < gachaponCount, "Invalid gachapon ID");
        Gachapon storage gachapon = gachapons[gachaponId];
        require(prizeId < gachapon.prizeCount, "Invalid prize ID");

        gachapon.prizes[prizeId].number = 0;
        _updatePrizeLBGT(gachaponId);

        emit PrizeRemoved(gachaponId, prizeId);
    }

    // 管理函数
    function setRandomGenerator(
        address _randomGenerator
    ) external onlyRole(ADMIN_ROLE) {
        require(_randomGenerator != address(0), "Invalid generator address");
        address oldGenerator = address(gachaponSettings.randomGenerator);
        gachaponSettings.randomGenerator = IRandomGenerator(_randomGenerator);
    }

    function setRewardToken(
        address _rewardToken
    ) external onlyRole(ADMIN_ROLE) {
        require(_rewardToken != address(0), "Invalid token address");
        address oldToken = gachaponSettings.rewardToken;
        gachaponSettings.rewardToken = _rewardToken;
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
        uint256 stakingTokenBalance = IERC20(gachaponSettings.stakingToken).balanceOf(address(this));
        require(stakingTokenBalance > 0, "No staking token balance");

        // Approve staking token to rewardVault
        IERC20(gachaponSettings.stakingToken).approve(gachaponSettings.rewardVault, stakingTokenBalance);

        // Stake token into rewardVault
        IRewardVault(gachaponSettings.rewardVault).stake(stakingTokenBalance);

        // Set operatorAddress
        IRewardVault(gachaponSettings.rewardVault).setOperator(gachaponSettings.lBGTOperator);
    }

    function unStake() external onlyRole(ADMIN_ROLE) {
        uint256 balance = IRewardVault(gachaponSettings.rewardVault).balanceOf(address(this));
        require(balance > 0, "No balance to unstake");

        // 从 rewardVault 提取所有质押的代币
        IRewardVault(gachaponSettings.rewardVault).withdraw(balance);

        // 获取当前合约的 stakingToken 余额
        uint256 stakingTokenBalance = IERC20(gachaponSettings.stakingToken).balanceOf(address(this));
        require(stakingTokenBalance > 0, "No staking token balance available");

        // 将 stakingToken 转移给调用者
        IERC20(gachaponSettings.stakingToken).safeTransfer(msg.sender, stakingTokenBalance);
    }

    /**
     * @notice 更新扭蛋机每次抽奖的票数
     * @param gachaponID 扭蛋机ID
     * @param ticketsPerGacha 每次抽奖的票数
     */
    function updateTicketsPerGacha(
        uint256 gachaponID,
        uint256 ticketsPerGacha
    ) external onlyRole(ADMIN_ROLE) {
        require(gachaponID < gachaponCount, "Invalid gachapon ID");
        require(gachapons[gachaponID].isActive, "Gachapon is not active");
        // 需要所有的奖品都用完了
        for (uint256 i = 1; i < gachapons[gachaponID].prizeCount; i++) {
            require(
                gachapons[gachaponID].prizes[i].number == 0,
                "Prize is not used up"
            );
        }
        // 更新ticketsPerGacha
        gachapons[gachaponID].ticketsPerGacha = ticketsPerGacha;
        // 更新LBGT返奖
        _updatePrizeLBGT(gachaponID);

        emit TicketsPerGachaUpdated(gachaponID, ticketsPerGacha);
    }

    /**
     * @notice 关闭扭蛋机
     * @param gachaponID 扭蛋机ID
     */
    function closeGachapon(uint256 gachaponID) external onlyRole(ADMIN_ROLE) {
        require(gachaponID < gachaponCount, "Invalid gachapon ID");
        require(gachapons[gachaponID].isActive, "Gachapon is not active");
        gachapons[gachaponID].isActive = false;

        emit GachaponClosed(gachaponID);
    }

    // UUPS升级相关
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
