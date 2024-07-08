// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from "oz/access/extensions/AccessControlDefaultAdminRules.sol";

import {BaseDistributor} from "./BaseDistributor.sol";
import {IGYD} from "./interfaces/IGYD.sol";

contract L2GydDistributor is BaseDistributor {
    constructor(IGYD gyd_, address admin) BaseDistributor(gyd_, admin) {
        _grantRole(DISTRIBUTION_MANAGER_ROLE, address(gyd_));
    }

    function distributeGYD(Distribution memory distribution) external payable onlyDistributionManager {
        if (distribution.destinationType == DestinationType.SGyd) {
            _distributeTosGYD(distribution);
        } else if (distribution.destinationType == DestinationType.Gauge) {
            _distributeToGauge(distribution);
        } else {
            revert InvalidDestinationType();
        }
    }
}
