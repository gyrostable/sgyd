// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {IGydDistributor, IL1GydDistributor} from "./interfaces/IL1GydDistributor.sol";
import {AccessControlEnumerable} from "oz/access/extensions/AccessControlEnumerable.sol";
import {AccessControl, IAccessControl} from "oz/access/AccessControl.sol";

contract DistributionManager is AccessControlEnumerable {
    using Address for address payable;

    error NoPendingDistribution();
    error DistributionNotExecutable(uint256 distributionQueuedAt, uint256 distributionExecutableAt);
    error RoleAlreadyGranted(bytes32 role, address account);
    error CannotRekoveAdminRole();
    error EmptyDistribution();

    event DistributionsQueued(IGydDistributor.Distribution[] distributions);
    event DistributionsAccepted(IGydDistributor.Distribution[] distributions);
    event DistributionsRejected(IGydDistributor.Distribution[] distributions);
    event MinExecutionDelaySet(uint256 minExecutionDelay);
    event DistributorSet(address distributor);

    /// @notice The distributions that should be executed next
    /// this should be a batch that is distributed at once
    IGydDistributor.Distribution[] internal _pendingDistributionsBatch;

    /// @notice The timestamp at which the distributions were queued
    uint256 public distributionQueuedAt;

    /// @notice The distributor that will execute the distributions
    IL1GydDistributor public distributor;

    /// @notice The minimum delay that will be waited before a distribution batch can be executed
    uint256 public minExecutionDelay;

    /// @notice This should be set to an address controlled by the script that computes the distribution
    bytes32 public constant DISTRIBUTION_SUBMITTER_ROLE = "DISTRIBUTION_SUBMITTER";

    /// @notice This should be set to a multisig in charge of approving distributions
    bytes32 public constant DISTRIBUTION_EXECUTOR_ROLE = "DISTRIBUTION_EXECUTOR";

    constructor(
        address admin,
        IL1GydDistributor distributor_,
        address distributionSubmitter,
        address distributionExecutor,
        uint256 minExecutionDelay_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        distributor = distributor_;
        minExecutionDelay = minExecutionDelay_;
        _grantRole(DISTRIBUTION_SUBMITTER_ROLE, distributionSubmitter);
        _grantRole(DISTRIBUTION_EXECUTOR_ROLE, distributionExecutor);
    }

    /// @notice Enqueues a batch of distributions to be executed
    function enqueueDistribution(IGydDistributor.Distribution[] memory distributions)
        external
        onlyRole(DISTRIBUTION_SUBMITTER_ROLE)
    {
        if (distributions.length == 0) revert EmptyDistribution();

        delete _pendingDistributionsBatch;
        for (uint256 i = 0; i < distributions.length; i++) {
            _pendingDistributionsBatch.push(distributions[i]);
        }
        distributionQueuedAt = block.timestamp;

        emit DistributionsQueued(distributions);
    }

    /// @notice Execute the pending distributions batch and executes them
    function executeDistribution() external payable onlyRole(DISTRIBUTION_EXECUTOR_ROLE) {
        if (_pendingDistributionsBatch.length == 0) {
            revert NoPendingDistribution();
        }
        uint256 distributionExecutableAt = distributionQueuedAt + minExecutionDelay;
        if (block.timestamp < distributionExecutableAt) {
            revert DistributionNotExecutable(distributionQueuedAt, distributionExecutableAt);
        }

        IGydDistributor.Distribution[] memory distributions = _pendingDistributionsBatch;
        delete _pendingDistributionsBatch;

        distributor.batchDistributeGYD{value: msg.value}(distributions);

        emit DistributionsAccepted(distributions);
    }

    /// @notice Rejects the pending distributions
    function rejectDistribution() external onlyRole(DISTRIBUTION_EXECUTOR_ROLE) {
        if (_pendingDistributionsBatch.length == 0) {
            revert NoPendingDistribution();
        }
        delete _pendingDistributionsBatch;
        emit DistributionsRejected(_pendingDistributionsBatch);
    }

    /// @notice We only support a single executor and validator
    /// so we override the default behavior to prevent adding more
    function grantRole(bytes32 role, address account) public override(AccessControl, IAccessControl) {
        if (getRoleMemberCount(role) > 0) {
            revert RoleAlreadyGranted(role, getRoleMember(role, 0));
        }
        return super.grantRole(role, account);
    }

    /// @notice Our admin is immutable
    function revokeRole(bytes32 role, address account) public override(AccessControl, IAccessControl) {
        if (role == DEFAULT_ADMIN_ROLE) {
            revert CannotRekoveAdminRole();
        }
        super.revokeRole(role, account);
    }

    /// @notice Returns the pending distributions batch
    function getPendingDistributionsBatch() external view returns (IGydDistributor.Distribution[] memory) {
        return _pendingDistributionsBatch;
    }

    /// @notice Sets the minimum execution delay
    function setMinExecutionDelay(uint256 minExecutionDelay_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (minExecutionDelay_ == minExecutionDelay) return;
        minExecutionDelay = minExecutionDelay_;
        emit MinExecutionDelaySet(minExecutionDelay);
    }

    /// @notice Sets the minimum execution delay
    function setDistributor(IL1GydDistributor distributor_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        distributor = distributor_;
        emit DistributorSet(address(distributor_));
    }

    /// @notice allow the executor to recover any ETH left over from the bridge fees
    /// this should typically be very low so we do not do it automatically on every execution
    function recoverETH() external onlyRole(DISTRIBUTION_EXECUTOR_ROLE) {
        address executor = getRoleMember(DISTRIBUTION_EXECUTOR_ROLE, 0);
        payable(executor).sendValue(address(this).balance);
    }

    /// @notice might be reimbursed if the passed value to cover bridge fees was too high
    receive() external payable {}
}
