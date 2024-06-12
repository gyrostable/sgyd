// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from "oz/access/extensions/AccessControlDefaultAdminRules.sol";

import {BaseDistributor} from "./BaseDistributor.sol";
import {IGydDistributor} from "./interfaces/IGydDistributor.sol";
import {IGYD} from "./interfaces/IGYD.sol";
import {IsGYD} from "./interfaces/IsGYD.sol";
import {ICurveLiquidityGauge} from "./interfaces/ICurveLiquidityGauge.sol";
import {ScaledMath} from "./libraries/ScaledMath.sol";
import {Stream} from "./libraries/Stream.sol";

contract GydDistributor is BaseDistributor, AccessControlDefaultAdminRules {
    using ScaledMath for uint256;

    error DistributionTooSoon(bytes32 key);
    error MaxRateExceeded();

    event GydDistributed(Distribution distribution);
    event MaxRateChanged(uint256 maxRate);
    event MinimumDistributionIntervalChanged(
        uint256 minimumDistributionInterval
    );

    bytes32 internal constant _DISTRIBUTION_MANAGER_ROLE =
        "DISTRIBUTION_MANAGER";

    uint256 public maxRate;
    uint256 public minimumDistributionInterval;

    mapping(bytes32 => uint256) public lastDistributionTime;

    constructor(
        IGYD gyd_,
        address admin,
        address distributionManager,
        uint256 maxRate_,
        uint256 minimumDistributionInterval_
    ) BaseDistributor(gyd_) AccessControlDefaultAdminRules(0, admin) {
        maxRate = maxRate_;
        minimumDistributionInterval = minimumDistributionInterval_;
        _grantRole(_DISTRIBUTION_MANAGER_ROLE, distributionManager);

        emit MaxRateChanged(maxRate_);
    }

    function setMaxRate(
        uint256 maxRate_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxRate = maxRate_;

        emit MaxRateChanged(maxRate_);
    }

    function setMinimumDistributionInterval(
        uint256 minimumDistributionInterval_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minimumDistributionInterval = minimumDistributionInterval_;
        emit MinimumDistributionIntervalChanged(minimumDistributionInterval_);
    }

    function distributeGYD(
        Distribution memory distribution
    ) external onlyRole(_DISTRIBUTION_MANAGER_ROLE) {
        _distributeGYD(distribution);
    }

    function _distributeGYD(Distribution memory distribution) internal {
        bytes32 distributionKey = _distributionKey(distribution);
        uint256 lastTime = lastDistributionTime[distributionKey];
        if (lastTime + minimumDistributionInterval > block.timestamp) {
            revert DistributionTooSoon(distributionKey);
        }

        uint256 gydSupply = gyd.totalSupply();
        uint256 maxAmount = gydSupply.mul(maxRate);
        if (distribution.amount > maxAmount) revert MaxRateExceeded();

        gyd.mint(address(this), distribution.amount);
        if (distribution.destinationType == DestinationType.L1SGyd) {
            _distributeTosGYD(distribution);
        } else if (distribution.destinationType == DestinationType.L1Gauge) {
            _distributeToGauge(distribution);
        } else {
            revert InvalidDestinationType();
        }

        lastDistributionTime[distributionKey] = block.timestamp;

        emit GydDistributed(distribution);
    }

    function _distributionKey(
        Distribution memory distribution
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    distribution.destinationType,
                    distribution.recipient,
                    distribution.data
                )
            );
    }
}
