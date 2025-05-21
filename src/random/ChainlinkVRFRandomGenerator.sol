// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IRandomGenerator.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract ChainlinkVRFRandomGenerator is IRandomGenerator, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface public immutable vrfCoordinator;
    bytes32 public immutable keyHash;
    uint64 public immutable subscriptionId;
    uint32 public immutable callbackGasLimit;
    uint16 public immutable requestConfirmations;
    uint32 public immutable numWords;
    
    uint256 public randomResult;
    mapping(uint256 => bool) public requestIdToFulfilled;
    
    event RandomNumberRequested(uint256 requestId);
    event RandomNumberReceived(uint256 requestId, uint256 randomNumber);
    
    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        numWords = _numWords;
    }
    
    function getRandomNumber() external override returns (uint256) {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestIdToFulfilled[requestId] = false;
        emit RandomNumberRequested(requestId);
        return requestId;
    }
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(!requestIdToFulfilled[requestId], "Request already fulfilled");
        randomResult = randomWords[0];
        requestIdToFulfilled[requestId] = true;
        emit RandomNumberReceived(requestId, randomResult);
    }
} 