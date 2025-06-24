// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultManager {
    function addIncentive(address rewardVault, address paymentToken, uint256 amount, uint256 incentiveRate) external;
    function setRewardsDuration(address rewardVault, uint256 _rewardsDuration) external;
}