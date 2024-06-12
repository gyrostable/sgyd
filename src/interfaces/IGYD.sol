// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IERC20} from "oz/token/ERC20/IERC20.sol";

interface IGYD is IERC20 {
    function mint(address to, uint256 amount) external;
}
