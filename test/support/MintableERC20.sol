// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from "oz/token/ERC20/ERC20.sol";
import {IGYD} from "../../src/interfaces/IGYD.sol";

contract MintableERC20 is ERC20, IGYD {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
