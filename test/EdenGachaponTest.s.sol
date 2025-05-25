// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EdenGachapon.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// 模拟代币合约
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// 模拟随机数生成器
contract MockRandomGenerator is IRandomGenerator {
    uint256 private _randomNumber;

    function setRandomNumber(uint256 randomNumber) external {
        _randomNumber = randomNumber;
    }

    function getRandomNumber() external view override returns (uint256) {
        return _randomNumber;
    }
}

// 模拟 BeraPawForge
contract MockBeraPawForge is IBeraPawForge {

    address public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function mint(
        address user,
        address rewardVault,
        address recipient
    ) external override returns (uint256) {
        // TODO: 模拟铸造逻辑
        IERC20(rewardToken).transfer(recipient, 10 ether);
        return 0;
    }
}

// 模拟 RewardVault
contract MockRewardVault is IRewardVault {
    mapping(address => uint256) private _balances;

    function stake(uint256 amount) external override {
        _balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external override {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _balances[msg.sender] -= amount;
    }

    function setOperator(address operator) external override {
        // 模拟设置操作者
    }

    function addIncentive(
        address token,
        uint256 amount,
        uint256 incentiveRate
    ) external override {
        // TODO: 模拟添加激励
    }

   
    function balanceOf(address account) external view returns (uint256) {

    }


    function rewards(address account) external view returns (uint256) {

    }

  
    function userRewardPerTokenPaid(address account) external view returns (uint256) {

    }

    
    function earned(address account) external view returns (uint256) {

    }

  
    function getRewardForDuration() external view returns (uint256) {

    }


    function lastTimeRewardApplicable() external view returns (uint256) {

    }

    function rewardPerToken() external view returns (uint256) {

    }

    function totalSupply() external view returns (uint256) {

    }

    function periodFinish() external view returns (uint256) {

    }

    function rewardRate() external view returns (uint256) {

    }

    function rewardsDuration() external view returns (uint256) {

    }


   
   

    function lastUpdateTime() external view returns (uint256) {

    }

 
 
    function undistributedRewards() external view returns (uint256) {

    }

    
    
    function rewardPerTokenStored() external view returns (uint256) {

    }
}

// 模拟 IncentiveManager
contract MockIncentiveManager is IIncentiveManager {
    function addIncentive(
        address rewardVault,
        address token,
        uint256 amount,
        uint256 rate
    ) external override {
        // 模拟添加激励
    }
}

contract EdenGachaponTest is Test {
    EdenGachapon public gachapon;
    MockToken public paymentToken;
    MockToken public rewardToken;
    MockToken public stakingToken;
    MockRandomGenerator public randomGenerator;
    MockBeraPawForge public beraPawForge;
    MockRewardVault public rewardVault;
    MockIncentiveManager public incentiveManager;

    address public admin;
    address public user1;
    address public user2;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 部署模拟合约
        paymentToken = new MockToken("Payment Token", "PTK");
        rewardToken = new MockToken("Reward Token", "RTK");
        stakingToken = new MockToken("Staking Token", "STK");
        randomGenerator = new MockRandomGenerator();
        beraPawForge = new MockBeraPawForge(address(rewardToken));
        rewardVault = new MockRewardVault();
        incentiveManager = new MockIncentiveManager();

        // 部署主合约
        vm.startPrank(admin);

        // 部署 EdenGachapon 实现合约
        EdenGachapon implementation = new EdenGachapon();

        // 初始化合约
        EdenGachapon.GachaponSettings memory settings = EdenGachapon.GachaponSettings({
            rewardToken: address(rewardToken),
            randomGenerator: randomGenerator,
            paymentToken: address(paymentToken),
            pricePerTicket: 0.69 ether,
            lBGTOperator: address(beraPawForge),
            rewardVault: address(rewardVault),
            stakingToken: address(stakingToken),
            incentiveRate: 0.9 ether,
            incentiveManager: address(incentiveManager)
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
        gachapon = EdenGachapon(address(proxy));

        vm.stopPrank();

        // 给用户一些代币
        paymentToken.transfer(user1, 100 ether);
        paymentToken.transfer(user2, 100 ether);
        rewardToken.transfer(address(beraPawForge), 10000 ether);
    }

    function test_Initialize() public {
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
        ) = gachapon.gachaponSettings();
        assertEq(rewardToken, address(rewardToken));
        assertEq(paymentToken, address(paymentToken));
        assertEq(pricePerTicket, 0.69 ether);
    }

    function test_CreateGachapon() public {
        vm.startPrank(admin);
        gachapon.createGachapon("Test Gachapon", 1);
        assertEq(gachapon.gachaponCount(), 1);
        vm.stopPrank();
    }

    function test_BuyTicket() public {
        vm.startPrank(user1);    
        paymentToken.approve(address(gachapon), 0.69 ether);
        gachapon.buyTicket(1);
        assertEq(gachapon.getTickets(user1), 1);
        vm.stopPrank();
    }

    function test_Gacha() public {
        // 创建扭蛋机
        vm.startPrank(admin);
        gachapon.createGachapon("Test Gachapon", 1);
        
        // 添加奖品
        gachapon.addPrize(
            0, // gachaponId
            "Test Prize",
            user2, // feeAddress
            1 ether, // prizeValue
            10, // number
            1000 // rate (10%)
        );
        vm.stopPrank();

        // 购买票
        vm.startPrank(user1);
        paymentToken.approve(address(gachapon), 0.69 ether);
        gachapon.buyTicket(1);

        // 设置随机数
        randomGenerator.setRandomNumber(500); // 50% 概率

        // 执行抽奖
        gachapon.gacha(0);
        vm.stopPrank();
    }

    function testFail_UnauthorizedAccess() public {
        vm.startPrank(user1);
        gachapon.createGachapon("Test Gachapon", 1); // 应该失败
        vm.stopPrank();
    }

    function test_UpdatePrize() public {
        vm.startPrank(admin);
        gachapon.createGachapon("Test Gachapon", 1);
        
        // 添加奖品
        gachapon.addPrize(
            0,
            "Test Prize",
            user2,
            1 ether,
            10,
            1000
        );

        // 更新奖品
        gachapon.updatePrize(
            0,
            1,
            "Updated Prize",
            user2,
            2 ether,
            5,
            2000
        );
        vm.stopPrank();
    }

    function test_RemovePrize() public {
        vm.startPrank(admin);
        gachapon.createGachapon("Test Gachapon", 1);
        
        // 添加奖品
        gachapon.addPrize(
            0,
            "Test Prize",
            user2,
            1 ether,
            10,
            1000
        );

        // 移除奖品
        gachapon.removePrize(0, 1);
        vm.stopPrank();
    }

    function test_EmergencyWithdraw() public {
        // 给合约转一些代币
        rewardToken.transfer(address(gachapon), 1 ether);

        vm.startPrank(admin);
        uint256 balanceBefore = rewardToken.balanceOf(admin);
        gachapon.emergencyWithdraw(address(rewardToken), 1 ether);
        uint256 balanceAfter = rewardToken.balanceOf(admin);
        assertEq(balanceAfter - balanceBefore, 1 ether);
        vm.stopPrank();
    }

    function test_PauseUnpause() public {
        vm.startPrank(admin);
        gachapon.pause();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        gachapon.buyTicket(1);
        vm.stopPrank();

        vm.startPrank(admin);
        gachapon.unpause();
        vm.stopPrank();

        vm.startPrank(user1);
        paymentToken.approve(address(gachapon), 0.69 ether);
        gachapon.buyTicket(1); // 现在应该可以正常工作了
        vm.stopPrank();
    }
}