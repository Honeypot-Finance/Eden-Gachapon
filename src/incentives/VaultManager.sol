// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRewardVault.sol";
import "../interfaces/IVaultManager.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VaultManager
 * @author Eden Protocol
 * @notice Incentive manager contract for managing incentive additions
 */
contract VaultManager is
    IVaultManager,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // Role definitions
    bytes32 public constant INCENTIVE_ADMIN_ROLE =
        keccak256("INCENTIVE_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address[] public supportedTokenList;
    mapping(address => bool) public supportedTokens;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public reinitializer(8) {
        // __AccessControl_init();
        // __UUPSUpgradeable_init();

        // Set deployer as default admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Set deployer as incentive admin
        _grantRole(INCENTIVE_ADMIN_ROLE, msg.sender);
        // Set deployer as upgrader
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    /**
     * @notice Adds a new incentive to the reward vault
     * @param rewardVault The address of the reward vault contract
     * @param paymentToken The address of the token used for payment
     * @param amount The amount of tokens to be used as incentive
     * @param incentiveRate The rate at which the incentive will be distributed
     * @dev Only callable by accounts with INCENTIVE_ADMIN_ROLE
     * @dev Requires sufficient token balance in the contract
     * @dev Approves the reward vault to spend the incentive tokens
     */
    function addIncentive(
        address rewardVault,
        address paymentToken,
        uint256 amount,
        uint256 incentiveRate
    ) external override onlyRole(INCENTIVE_ADMIN_ROLE) {
        require(rewardVault != address(0), "Invalid reward vault");
        require(paymentToken != address(0), "Invalid payment token");
        require(amount > 0, "Invalid amount");
        require(incentiveRate > 0, "Invalid incentive rate");
        uint256 balance = IERC20(paymentToken).balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");

        // transfer paymentToken to rewardVault
        IERC20(paymentToken).safeTransfer(rewardVault, amount);

        // account incentive
        IRewardVault(rewardVault).accountIncentives(paymentToken, amount);

        // account supported tokens
        for (uint256 i = 0; i < supportedTokenList.length; i++) {
            address token = supportedTokenList[i];
            if (supportedTokens[token]) {
                uint256 tokenBalance = IERC20(token).balanceOf(
                    address(rewardVault)
                );
                if (tokenBalance == 0) {
                    continue;
                }

                (
                    uint256 minIncentiveRate,
                    uint256 incentiveRate,
                    uint256 remaining,
                    address manager
                ) = IRewardVault(rewardVault).incentives(token);

                if (tokenBalance <= remaining) {
                    continue;
                }

                if (tokenBalance > remaining) {
                    IRewardVault(rewardVault).accountIncentives(
                        token,
                        tokenBalance - remaining
                    );
                } else {
                    continue;
                }
            }
        }
    }

    function accountIncentive(
        address rewardVault,
        address paymentToken,
        uint256 amount
    ) external onlyRole(INCENTIVE_ADMIN_ROLE) {
        require(rewardVault != address(0), "Invalid reward vault");
        require(paymentToken != address(0), "Invalid payment token");
        require(amount > 0, "Invalid amount");

        // account incentive
        IRewardVault(rewardVault).accountIncentives(paymentToken, amount);
    }

    function setUpIncentive(
        address rewardVault,
        address paymentToken,
        uint256 amount,
        uint256 incentiveRate
    ) external onlyRole(INCENTIVE_ADMIN_ROLE) {
        require(rewardVault != address(0), "Invalid reward vault");
        require(paymentToken != address(0), "Invalid payment token");
        require(amount > 0, "Invalid amount");

        IERC20(paymentToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Approve incentive tokens
        IERC20(paymentToken).approve(rewardVault, amount);

        // Add incentive
        IRewardVault(rewardVault).addIncentive(
            paymentToken,
            amount,
            incentiveRate
        );
    }

    function setRewardsDuration(
        address rewardVault,
        uint256 _rewardsDuration
    ) external override onlyRole(INCENTIVE_ADMIN_ROLE) {
        require(rewardVault != address(0), "Invalid reward vault");
        require(_rewardsDuration > 0, "Invalid rewards duration");

        IRewardVault(rewardVault).setRewardsDuration(_rewardsDuration);
    }

    function addSupportedToken(
        address token
    ) external onlyRole(INCENTIVE_ADMIN_ROLE) {
        require(token != address(0), "Invalid token");
        require(!supportedTokens[token], "Token already supported");
        supportedTokens[token] = true;
        supportedTokenList.push(token);
    }

    function removeSupportedToken(
        address token
    ) external onlyRole(INCENTIVE_ADMIN_ROLE) {
        require(token != address(0), "Invalid token");
        require(supportedTokens[token], "Token not supported");
        supportedTokens[token] = false;
    }

    /**
     * @notice Function that should revert when msg.sender is not authorized to upgrade the contract
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
