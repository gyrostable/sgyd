// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {BaseDistributor} from "./BaseDistributor.sol";
import {IGYD} from "./interfaces/IGYD.sol";

contract L2GydDistributor is BaseDistributor {
    constructor(IGYD gyd_) BaseDistributor(gyd_) {}

    function distributeGYD(Distribution memory distribution) external {
        if (distribution.destinationType == DestinationType.CCIPSgyd) {
            _distributeTosGYD(distribution);
        } else if (distribution.destinationType == DestinationType.CCIPGauge) {
            _distributeToGauge(distribution);
        } else {
            revert InvalidDestinationType();
        }
    }
}
