// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IRandomGenerator.sol";

contract BlockRandomGenerator is IRandomGenerator {
    function getRandomNumber() external override returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            block.difficulty,
            msg.sender
        )));
    }
} 