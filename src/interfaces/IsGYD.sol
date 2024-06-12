// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IERC4626} from "oz/interfaces/IERC4626.sol";

import {Stream} from "../libraries/Stream.sol";

interface IsGYD is IERC4626 {
    function addStream(Stream.T memory stream) external;
}
