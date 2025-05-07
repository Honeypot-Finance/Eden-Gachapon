// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IBeraPawForge.sol";
import "./interfaces/IRewardVault.sol";
contract EdenPol {
    address public rewardVault;
    address public stakingToken;
    address public operatorAddress; // 0xfeedb9750d6ac77d2e52e0c9eb8fb79f9de5cafe
    address public lBGTAddress; // 0xbaadcc2962417c01af99fb2b7c75706b9bd6babe

    uint256 public incentiveRate; // recommend start from 0.2 LBGT per BGT, gradually add to 0.5 LBGT
    uint256 public bribeBackRate; // recommend start from 90 (90%), gradually decline to 50%

    uint256 public lotteryFee; // fee for lottery, recommend start from 1 BERA

    enum PrizeType {
        EMPTY, // means no prize
        EDEN_TOY // means eden toy
    }

    struct Prize {
        string name;
        address receiver;
        uint256 rate;
        PrizeType prizeType;
    }

    struct InitializeParams {
        address rewardVault; // address of the reward vault
        address stakingToken; // address of the staking token
        address operatorAddress; // address of the operator berapaw
        address lBGTAddress; // address of the LBGT token
        uint256 incentiveRate; // recommend start from 0.2 LBGT per BGT, gradually add to 0.5 LBGT
        uint256 bribeBackRate; // recommend start from 90 (90%), gradually decline to 50%
        address edenReceiver; // address of the eden receiver
        address honeypotReceiver; // address of the honeypot receiver
    }

    function initialize(InitializeParams memory params) public {
        rewardVault = params.rewardVault;
        stakingToken = params.stakingToken;
        operatorAddress = params.operatorAddress;
        lBGTAddress = params.lBGTAddress;
        incentiveRate = params.incentiveRate;
        bribeBackRate = params.bribeBackRate;
    }

    function stakeAndSetupOperator(uint256 amount) public {
        // approve staking token to rewardVault
        IERC20(stakingToken).approve(rewardVault, amount);

        // stake token into rewardVault
        IRewardVault(rewardVault).stake(amount);

        // set operatorAddress
        IRewardVault(rewardVault).setOperator(operatorAddress);
    }

    /// @notice Handle BGT token distribution
    /// @dev Mints BGT tokens and distributes them between fee vault and BeraFarm
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @dev very careful about the reward vaults addIncentive rules, this function may fail if break the rules.
    function addIncentive(uint amount) external {
        if (
            IERC20(lBGTAddress).balanceOf(address(this)) > amount &&
            amount > incentiveRate
        ) {
            IRewardVault(rewardVault).addIncentive(
                lBGTAddress,
                amount,
                incentiveRate
            );
        }
    }

    function addPrize(
        string memory name,
        address receiver,
        uint256 rate,
        PrizeType prizeType
    ) public {
        prizes.push(
            Prize({
                name: name,
                receiver: receiver,
                rate: rate,
                prizeType: prizeType
            })
        );
    }

    function lottery() public {
        // pay for lottery
        IERC20(beraToken).transferFrom(msg.sender, address(this), lotteryFee);

        uint256 random = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
            )
        ) % 100;

        uint256 sum = 0;
        for (uint i = 0; i < prizes.length; i++) {
            sum += prizes[i].rate;
            if (random < sum) {
                _sendPrize(prizes[i]);
                break;
            }
        }
    }

    function _sendPrize(Prize memory prize) internal {
        uint256 lbgtAmount = _claimBGT();
        if (prize.prizeType == PrizeType.EDEN_TOY) {
            // send lbgt to prize.receiver
            // TODO:

            IERC20(lBGTAddress).transfer(prize.receiver, lbgtAmount);
        } else if (prize.prizeType == PrizeType.EMPTY) {
            // TODO:
            IERC20(lBGTAddress).transfer(msg.sender, lbgtAmount);
        }
        emit PrizeSent(prize.name, prize.prizeType, msg.sender);
    }

    function _claimBGT() internal returns (uint256) {
        // lbgt mint
        uint256 mintAmount = IBeraPawForge(operatorAddress).mint(
            address(this),
            rewardVault,
            address(this)
        );

        return mintAmount;
    }
}
