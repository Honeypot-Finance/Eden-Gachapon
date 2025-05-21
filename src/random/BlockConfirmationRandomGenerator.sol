// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IRandomGenerator.sol";

contract BlockConfirmationRandomGenerator is IRandomGenerator {
    uint256 public requiredConfirmations;
    
    constructor(uint256 _requiredConfirmations) {
        require(_requiredConfirmations > 0, "Confirmations must be greater than 0");
        requiredConfirmations = _requiredConfirmations;
    }
    
    function getRandomNumber() external override returns (uint256) {
        require(block.number >= requiredConfirmations, "Need more confirmations");
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - requiredConfirmations),
            block.timestamp,
            block.difficulty,
            msg.sender
        )));
    }
} 