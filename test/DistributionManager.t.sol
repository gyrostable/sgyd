// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IAccessControl} from "oz/access/AccessControl.sol";

import {UnitTest} from "./support/UnitTest.sol";

import {IGydDistributor} from "../src/interfaces/IGydDistributor.sol";
import {IL1GydDistributor} from "../src/interfaces/IL1GydDistributor.sol";
import {DistributionManager} from "../src/DistributionManager.sol";

contract DistributionManagerTest is UnitTest {
    DistributionManager public distributionManager;

    address public submitter = makeAddr("submitter");
    address public executor = makeAddr("executor");

    function setUp() public override {
        super.setUp();
        distributionManager = new DistributionManager(owner, gydDistributor, submitter, executor, 1 days);
        bytes32 managerRole = gydDistributor.DISTRIBUTION_MANAGER_ROLE();
        vm.prank(owner);
        gydDistributor.grantRole(managerRole, address(distributionManager));
    }

    function test_enqueueDistribution_nonAuthorized() public {
        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](1);
        distributions[0] = _getSgydDistribution(1e18);

        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), distributionManager.DISTRIBUTION_SUBMITTER_ROLE()));
        distributionManager.enqueueDistribution(distributions);
    }

    function test_enqueueDistribution() public {
        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](1);
        distributions[0] = _getSgydDistribution(1e18);

        vm.prank(submitter);
        distributionManager.enqueueDistribution(distributions);

        assertEq(distributionManager.distributionQueuedAt(), block.timestamp);
        IGydDistributor.Distribution[] memory pendingDistributions = distributionManager.getPendingDistributionsBatch();
        assertEq(pendingDistributions.length, 1);
        assertEq(pendingDistributions[0].recipient, distributions[0].recipient);
        assertEq(pendingDistributions[0].amount, distributions[0].amount);
    }

    function test_rejectDistribution_nonAuthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), distributionManager.DISTRIBUTION_EXECUTOR_ROLE()));
        distributionManager.rejectDistribution();
    }

    function test_rejectDistribution_noPendingDistribution() public {
        vm.expectRevert(DistributionManager.NoPendingDistribution.selector);
        vm.prank(executor);
        distributionManager.rejectDistribution();
    }

    function test_rejectDistribution() public {
        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](1);
        distributions[0] = _getSgydDistribution(1e18);
        vm.prank(submitter);
        distributionManager.enqueueDistribution(distributions);

        vm.prank(executor);
        distributionManager.rejectDistribution();
        IGydDistributor.Distribution[] memory pendingDistributions = distributionManager.getPendingDistributionsBatch();
        assertEq(pendingDistributions.length, 0);
    }

    function test_executeDistribution_nonAuthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), distributionManager.DISTRIBUTION_EXECUTOR_ROLE()));
        distributionManager.executeDistribution();
    }

    function test_executeDistribution_noPendingDistribution() public {
        vm.expectRevert(DistributionManager.NoPendingDistribution.selector);
        vm.prank(executor);
        distributionManager.executeDistribution();
    }

    function test_executeDistribution_tooSoon() public {
        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](1);
        distributions[0] = _getSgydDistribution(1e18);
        vm.prank(submitter);
        distributionManager.enqueueDistribution(distributions);

        bytes4 err = DistributionManager.DistributionNotExecutable.selector;
        vm.expectRevert(
            abi.encodeWithSelector(err, block.timestamp, block.timestamp + distributionManager.minExecutionDelay())
        );
        vm.prank(executor);
        distributionManager.executeDistribution();
    }

    function test_executeDistribution_l1Only() public {
        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](1);
        distributions[0] = _getSgydDistribution(1e18);
        _whitelistKey(distributions[0]);
        vm.prank(submitter);
        distributionManager.enqueueDistribution(distributions);

        skip(distributionManager.minExecutionDelay() + 1);

        vm.prank(executor);
        distributionManager.executeDistribution();
        assertEq(gyd.balanceOf(address(sgyd)), 1e18);
    }

    function test_executeDistribution_l1L2() public {
        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](2);
        distributions[0] = _getSgydDistribution(1e18);
        (distributions[1],) = _getL2GaugeDistribution();
        _whitelistKey(distributions[0]);
        _whitelistKey(distributions[1]);
        vm.prank(submitter);
        distributionManager.enqueueDistribution(distributions);

        skip(distributionManager.minExecutionDelay() + 1);

        uint256 fee = gydDistributor.getBatchDistributionFee(distributions);
        // check the case where we send too much
        uint256 extraFee = 0.2e18;
        vm.deal(executor, fee + extraFee);

        vm.prank(executor);
        distributionManager.executeDistribution{value: fee + extraFee}();

        assertEq(address(distributionManager).balance, extraFee);
        assertEq(gyd.balanceOf(address(sgyd)), 1e18);
        assertEq(l2Gyd.balanceOf(address(mockL2Gauge)), 1e18);

        uint256 executorBalance = address(executor).balance;
        vm.prank(executor);
        distributionManager.recoverETH();
        assertEq(address(executor).balance, executorBalance + extraFee);
    }

    function test_setMinExecutionDelay_nonAuthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), distributionManager.DEFAULT_ADMIN_ROLE()));
        distributionManager.setMinExecutionDelay(1 days);
    }

    function test_setMinExecutionDelay() public {
        vm.prank(owner);

        distributionManager.setMinExecutionDelay(1 days);
        assertEq(distributionManager.minExecutionDelay(), 1 days);
    }

    function test_setDistributor_nonAuthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), distributionManager.DEFAULT_ADMIN_ROLE()));
        distributionManager.setDistributor(IL1GydDistributor(address(0)));
    }

    function test_setDistributor() public {
        address distributor = makeAddr("newDistributor");
        vm.prank(owner);
        distributionManager.setDistributor(IL1GydDistributor(distributor));
        assertEq(address(distributionManager.distributor()), distributor);
    }
}
