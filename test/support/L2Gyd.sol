// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";

import {MintableERC20} from "./MintableERC20.sol";

contract L2Gyd is MintableERC20 {
    using Address for address;

    constructor(string memory name_, string memory symbol_) MintableERC20(name_, symbol_) {}

    function onReceive(address recipient, uint256 amount, bytes calldata data) external {
        _mint(recipient, amount);
        recipient.functionCall(data);
    }
}
