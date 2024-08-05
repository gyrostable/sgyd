// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from "oz/access/extensions/AccessControlDefaultAdminRules.sol";
import {EnumerableSet} from "oz/utils/structs/EnumerableSet.sol";
import {Address} from "oz/utils/Address.sol";

import {BaseDistributor} from "./BaseDistributor.sol";
import {IGydDistributor} from "./interfaces/IGydDistributor.sol";
import {IL1GydDistributor} from "./interfaces/IL1GydDistributor.sol";
import {IGYD} from "./interfaces/IGYD.sol";
import {IsGYD} from "./interfaces/IsGYD.sol";
import {IL1GydEscrow} from "./interfaces/IL1GydEscrow.sol";
import {ICurveLiquidityGauge} from "./interfaces/ICurveLiquidityGauge.sol";
import {ScaledMath} from "./libraries/ScaledMath.sol";
import {Stream} from "./libraries/Stream.sol";

contract GydDistributor is BaseDistributor, IL1GydDistributor {
    using Address for address payable;
    using ScaledMath for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    error FeeNotCovered(uint256 fee, uint256 value);
    error DistributionTooSoon(bytes32 key);
    error MaxRateExceeded();
    error MismatchingAmounts(uint256 l1Amount, uint256 l2Amount);
    error NotWhitelistedKey(bytes32 key);

    event GydDistributed(Distribution distribution);
    event MaxRateChanged(uint256 maxRate);
    event MinimumDistributionIntervalChanged(
        uint256 minimumDistributionInterval
    );
    event DistributionKeyWhitelisted(bytes32 indexed key, bool whitelisted);

    IL1GydEscrow public immutable l1GydEscrow;
    uint256 public maxRate;
    uint256 public minimumDistributionInterval;
    EnumerableSet.Bytes32Set internal _whitelistedDistributionKeys;

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

    /// @notice Adds a distribution key to the whitelist
    function addWhitelistedDistributionKey(
        bytes32 key
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_whitelistedDistributionKeys.add(key)) {
            emit DistributionKeyWhitelisted(key, true);
        }
    }

    /// @notice Removes a distribution key from the whitelist
    function removeWhitelistedDistributionKey(
        bytes32 key
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_whitelistedDistributionKeys.remove(key)) {
            emit DistributionKeyWhitelisted(key, false);
        }
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

    function getBatchDistributionFee(
        Distribution[] memory distributions
    ) external view returns (uint256 totalFee) {
        for (uint256 i; i < distributions.length; i++) {
            if (distributions[i].destinationType == DestinationType.L2) {
                totalFee += getL2DistributionFee(distributions[i]);
            }
        }
    }

    function getL2DistributionFee(
        Distribution memory distribution
    ) public view returns (uint256) {
        if (distribution.destinationType != DestinationType.L2) {
            revert InvalidDestinationType();
        }

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
        uint256 balanceBefore = address(this).balance;
        _distributeGYD(distribution);
        _reimburseUnusedBalance(balanceBefore);
    }

    /// @notice same as distributeGYD but can create multiple distributions in a single transaction
    function batchDistributeGYD(
        Distribution[] memory distributions
    ) external payable onlyDistributionManager {
        uint256 balanceBefore = address(this).balance;
        for (uint256 i; i < distributions.length; i++) {
            _distributeGYD(distributions[i]);
        }
        _reimburseUnusedBalance(balanceBefore);
    }

    function _distributeGYD(Distribution memory distribution) internal {
        bytes32 distributionKey_ = getDistributionKey(distribution);
        if (!_whitelistedDistributionKeys.contains(distributionKey_)) {
            revert NotWhitelistedKey(distributionKey_);
        }

        uint256 lastTime = lastDistributionTime[distributionKey_];
        if (lastTime + minimumDistributionInterval > block.timestamp) {
            revert DistributionTooSoon(distributionKey_);
        }

        uint256 gydSupply = gyd.totalSupply();
        uint256 maxAmount = gydSupply.mul(maxRate);
        if (distribution.amount > maxAmount) revert MaxRateExceeded();

        lastDistributionTime[distributionKey_] = block.timestamp;

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

        emit GydDistributed(distribution);
    }

    function getDistributionKey(
        Distribution memory distribution
    ) public pure returns (bytes32) {
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

    function getWhitelistedDistributionKeys()
        public
        view
        returns (bytes32[] memory)
    {
        return _whitelistedDistributionKeys.values();
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
    }

    function _reimburseUnusedBalance(uint256 previousBalance) internal {
        uint256 usedBalance = previousBalance - address(this).balance;
        if (usedBalance < msg.value) {
            payable(msg.sender).sendValue(msg.value - usedBalance);
        }
    }
}
