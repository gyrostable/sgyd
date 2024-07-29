// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IGydDistributor} from "./IGydDistributor.sol";

interface IL1GydDistributor is IGydDistributor {
    function batchDistributeGYD(Distribution[] memory distributions) external payable;
}
