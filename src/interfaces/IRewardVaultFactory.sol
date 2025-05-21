// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IRewardVaultFactory {
    function createRewardVault(address stakingToken) external returns (address);
}
