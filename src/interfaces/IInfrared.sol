// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IInfrared {
    // Infrared contract address 0xb71b3DaEA39012Fb0f2B14D2a9C86da9292fC126
    function claimExternalVaultRewards(address _asset, address user) external;

    function externalVaultRewards(
        address _asset,
        address user
    ) external view returns (uint256 iBgtAmount);
}