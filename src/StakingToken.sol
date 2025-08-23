// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// the placeholder token for Eden Gachapon Staking
contract XOXO is ERC20 {
    constructor() ERC20("XOXO", "XO") {
        // 总供应量为 80094，分配给部署者
        _mint(msg.sender, 80094 * 10 ** decimals());
    }
}