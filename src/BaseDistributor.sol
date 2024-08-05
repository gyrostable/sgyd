// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from "oz/access/extensions/AccessControlDefaultAdminRules.sol";

import {IGYD} from "./interfaces/IGYD.sol";
import {IsGYD} from "./interfaces/IsGYD.sol";
import {IGydDistributor} from "./interfaces/IGydDistributor.sol";
import {ICurveLiquidityGauge} from "./interfaces/ICurveLiquidityGauge.sol";
import {Stream} from "./libraries/Stream.sol";

abstract contract BaseDistributor is
    IGydDistributor,
    AccessControlDefaultAdminRules
{
    error InvalidDestinationType();
    error NonZeroValue();

    bytes32 public constant DISTRIBUTION_MANAGER_ROLE = "DISTRIBUTION_MANAGER";

    IGYD public immutable gyd;

    modifier onlyDistributionManager() {
        _checkRole(DISTRIBUTION_MANAGER_ROLE, msg.sender);
        _;
    }

    constructor(
        IGYD gyd_,
        address admin
    ) AccessControlDefaultAdminRules(0, admin) {
        gyd = gyd_;
    }

    /// @notice Changes the reward distributor for the given gauge
    /// This should only be done if we are not planning to distribute GYD to the gauge using this contract's instance
    function setRewardDistributor(
        ICurveLiquidityGauge gauge,
        address rewardDistributor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        gauge.set_reward_distributor(address(gyd), rewardDistributor);
    }

    function _distributeTosGYD(Distribution memory distribution) internal {
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

    function _distributeToGauge(Distribution memory distribution) internal {
        gyd.approve(distribution.recipient, distribution.amount);
        ICurveLiquidityGauge(distribution.recipient).deposit_reward_token(
            address(gyd),
            distribution.amount
        );
    }
}
