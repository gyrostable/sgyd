// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from "oz/access/extensions/AccessControlDefaultAdminRules.sol";

import {BaseDistributor} from "./BaseDistributor.sol";
import {IGydDistributor} from "./interfaces/IGydDistributor.sol";
import {IGYD} from "./interfaces/IGYD.sol";
import {IsGYD} from "./interfaces/IsGYD.sol";
import {IL1GydEscrow} from "./interfaces/IL1GydEscrow.sol";
import {ICurveLiquidityGauge} from "./interfaces/ICurveLiquidityGauge.sol";
import {ScaledMath} from "./libraries/ScaledMath.sol";
import {Stream} from "./libraries/Stream.sol";

contract GydDistributor is BaseDistributor {
    using ScaledMath for uint256;

    error FeeNotCovered(uint256 fee, uint256 value);
    error DistributionTooSoon(bytes32 key);
    error MaxRateExceeded();
    error MismatchingAmounts(uint256 l1Amount, uint256 l2Amount);

    event GydDistributed(Distribution distribution);
    event MaxRateChanged(uint256 maxRate);
    event MinimumDistributionIntervalChanged(
        uint256 minimumDistributionInterval
    );

    IL1GydEscrow public immutable l1GydEscrow;
    uint256 public maxRate;
    uint256 public minimumDistributionInterval;

    mapping(bytes32 => uint256) public lastDistributionTime;

    constructor(
        IGYD gyd_,
        address admin,
        address distributionManager,
        uint256 maxRate_,
        uint256 minimumDistributionInterval_,
        IL1GydEscrow l1GydEscrow_
    ) BaseDistributor(gyd_, admin) {
        maxRate = maxRate_;
        minimumDistributionInterval = minimumDistributionInterval_;
        _grantRole(DISTRIBUTION_MANAGER_ROLE, distributionManager);
        l1GydEscrow = l1GydEscrow_;

        emit MaxRateChanged(maxRate_);
    }

    /// @notice Sets the maximum rate of GYD that can be distributed
    /// this is a percentage of the total supply of GYD
    /// The rate is designed as a very basic protection against a bug in the distribution logic
    /// but is not designed to be a security feature in the case where `distributeGYD` would be called by a malicious party
    function setMaxRate(
        uint256 maxRate_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxRate = maxRate_;

        emit MaxRateChanged(maxRate_);
    }

    /// @notice Sets the minimum time between distributions to the same recipient
    function setMinimumDistributionInterval(
        uint256 minimumDistributionInterval_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minimumDistributionInterval = minimumDistributionInterval_;
        emit MinimumDistributionIntervalChanged(minimumDistributionInterval_);
    }

    function getL2DistributionFee(
        Distribution memory distribution
    ) public view returns (uint256) {
        if (distribution.destinationType != DestinationType.L2)
            revert InvalidDestinationType();

        (uint256 chainSelector, Distribution memory data) = abi.decode(
            distribution.data,
            (uint256, Distribution)
        );
        bytes memory calldata_ = abi.encodeWithSelector(
            IGydDistributor.distributeGYD.selector,
            data
        );
        return
            l1GydEscrow.getFee(
                uint64(chainSelector),
                distribution.recipient,
                distribution.amount,
                calldata_
            );
    }

    /// @notice Mints GYD and distributes it to the recipient
    /// There are three types of destinations, which changes the way the distribution is done and the data should be encoded:
    /// ## SGyd
    ///   * recipient must be the sGYD contract
    ///   * data must be the start and end of the stream ABI encoded as (uint256, uint256)
    /// ## Gauge
    ///  * recipient must be a Balancer gauge contract
    ///  * data is ignored
    /// ## L2
    ///   * transaction will be sent to the L1GydEscrow
    ///   * recipient must be the L2 distributor contract of the target chain
    ///   * data must the CCIP chain selector and the L2 Distribution ABI-encoded (uint256, Distribution)
    ///     The `distributeGYD` function of the L2 distributor contract will be called with the encoded Distribution data
    ///     when the GYD is bridged to the target chain
    /// @dev The function is payable to allow the contract to send the required amount of ETH to the L1GydEscrow
    function distributeGYD(
        Distribution memory distribution
    ) external payable onlyDistributionManager {
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

        if (distribution.destinationType == DestinationType.SGyd) {
            _distributeTosGYD(distribution);
        } else if (distribution.destinationType == DestinationType.Gauge) {
            _distributeToGauge(distribution);
        } else if (distribution.destinationType == DestinationType.L2) {
            _distributeToL2(distribution);
        } else {
            revert InvalidDestinationType();
        }

        lastDistributionTime[distributionKey] = block.timestamp;

        emit GydDistributed(distribution);
    }

    function _distributeToL2(Distribution memory distribution) internal {
        (uint256 chainSelector, Distribution memory data) = abi.decode(
            distribution.data,
            (uint256, Distribution)
        );
        bytes memory calldata_ = abi.encodeWithSelector(
            IGydDistributor.distributeGYD.selector,
            data
        );
        if (distribution.amount != data.amount) {
            revert MismatchingAmounts(distribution.amount, data.amount);
        }

        uint256 balanceBefore = address(this).balance;

        uint256 fee = getL2DistributionFee(distribution);
        if (msg.value < fee) {
            revert FeeNotCovered(fee, msg.value);
        }

        gyd.approve(address(l1GydEscrow), distribution.amount);
        l1GydEscrow.bridgeToken{value: fee}(
            uint64(chainSelector),
            distribution.recipient,
            distribution.amount,
            calldata_
        );

        uint256 usedBalance = balanceBefore - address(this).balance;
        if (usedBalance < msg.value) {
            payable(msg.sender).transfer(msg.value - usedBalance);
        }
    }

    function _distributionKey(
        Distribution memory distribution
    ) internal pure returns (bytes32) {
        if (distribution.destinationType == DestinationType.L2) {
            (uint256 chainSelector, Distribution memory data) = abi.decode(
                distribution.data,
                (uint256, Distribution)
            );
            return
                keccak256(
                    abi.encodePacked(
                        chainSelector,
                        data.destinationType,
                        data.recipient
                    )
                );
        }
        return
            keccak256(
                abi.encodePacked(
                    distribution.destinationType,
                    distribution.recipient
                )
            );
    }
}
