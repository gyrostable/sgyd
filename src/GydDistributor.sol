// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from "oz/access/extensions/AccessControlDefaultAdminRules.sol";

import {IGYD} from "./interfaces/IGYD.sol";
import {ICurveLiquidityGauge} from "./interfaces/ICurveLiquidityGauge.sol";
import {IsGYD} from "./interfaces/IsGYD.sol";
import {ScaledMath} from "./libraries/ScaledMath.sol";
import {Stream} from "./libraries/Stream.sol";

contract GydDistributor is AccessControlDefaultAdminRules {
    using ScaledMath for uint256;

    enum DestinationType {
        L1SGyd,
        L1Gauge,
        CCIPSgyd,
        CCIPGauge
    }

    struct Distribution {
        DestinationType destinationType;
        address recipient;
        uint256 amount;
        bytes data;
    }

    error DistributionTooSoon(bytes32 key);
    error MaxRateExceeded();

    event GydDistributed(Distribution distribution);
    event MaxRateChanged(uint256 maxRate);
    event MinimumDistributionIntervalChanged(
        uint256 minimumDistributionInterval
    );

    bytes32 internal constant _DISTRIBUTION_MANAGER_ROLE =
        "DISTRIBUTION_MANAGER";

    IGYD public immutable gyd;
    uint256 public maxRate;
    uint256 public minimumDistributionInterval;

    mapping(bytes32 => uint256) public lastDistributionTime;

    constructor(
        IGYD gyd_,
        address admin,
        address distributionManager,
        uint256 maxRate_,
        uint256 minimumDistributionInterval_
    ) AccessControlDefaultAdminRules(0, admin) {
        gyd = gyd_;
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

    function batchDistributeGYD(
        Distribution[] memory distribution
    ) external onlyRole(_DISTRIBUTION_MANAGER_ROLE) {
        for (uint256 i = 0; i < distribution.length; i++) {
            _distributeGYD(distribution[i]);
        }
    }

    function _distributeGYD(Distribution memory distribution) internal {
        bytes32 distributionKey = _distributionKey(distribution);
        uint256 lastTime = lastDistributionTime[distributionKey];
        if (lastTime + minimumDistributionInterval > block.timestamp) {
            revert DistributionTooSoon(distributionKey);
        }

        uint256 gydSupply = gyd.totalSupply();
        uint256 maxAmount = gydSupply.mul(maxRate);
        if (distribution.amount > maxAmount) {
            revert MaxRateExceeded();
        }

        gyd.mint(address(this), distribution.amount);
        if (distribution.destinationType == DestinationType.L1SGyd) {
            _distributeL1sGYD(distribution);
        } else if (distribution.destinationType == DestinationType.L1Gauge) {
            _distributeL1gauge(distribution);
        } else {
            revert("Unsupported destination type");
        }

        lastDistributionTime[distributionKey] = block.timestamp;

        emit GydDistributed(distribution);
    }

    function _distributeL1sGYD(Distribution memory distribution) internal {
        (uint256 start, uint256 end) = abi.decode(
            distribution.data,
            (uint256, uint256)
        );

        gyd.approve(distribution.recipient, distribution.amount);
        IsGYD(distribution.recipient).addStream(
            Stream.T({
                amount: uint128(distribution.amount),
                start: uint64(start),
                end: uint64(end)
            })
        );
    }

    function _distributeL1gauge(Distribution memory distribution) internal {
        gyd.approve(distribution.recipient, distribution.amount);
        ICurveLiquidityGauge(distribution.recipient).deposit_reward_token(
            address(gyd),
            distribution.amount
        );
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
