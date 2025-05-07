// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IBeraPawForge {
    /// @notice Mints LBGT for a user.
    /// @param user The user for whom rewards are claimed.
    /// @param rewardVault The rewards vault from which rewards are claimed.
    /// @param recipient The address receiving the minted LBGT.
    /// @return The amount of LBGT minted.
    function mint(
        address user,
        address rewardVault,
        address recipient
    ) external returns (uint256);
}
