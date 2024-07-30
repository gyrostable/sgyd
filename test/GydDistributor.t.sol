// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {IAccessControl} from "oz/access/AccessControl.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";

import {UnitTest} from "./support/UnitTest.sol";
import {MockGauge} from "./support/MockGauge.sol";
import {MockL1Escrow} from "./support/MockL1Escrow.sol";

import {sGYD} from "../src/sGYD.sol";
import {GydDistributor} from "../src/GydDistributor.sol";
import {IGydDistributor} from "../src/interfaces/IGydDistributor.sol";

contract GydDistributorTest is UnitTest {
    function test_setMaxRate_unauthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), gydDistributor.DEFAULT_ADMIN_ROLE()));
        gydDistributor.setMaxRate(0.5e18);
    }

    function test_setMaxRate() public {
        vm.prank(owner);
        gydDistributor.setMaxRate(0.5e18);
        assertEq(gydDistributor.maxRate(), 0.5e18);
    }

    function test_setMinimumDistributionInterval_unauthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), gydDistributor.DEFAULT_ADMIN_ROLE()));
        gydDistributor.setMinimumDistributionInterval(7 days);
    }

    function test_setMinimumDistributionInterval() public {
        vm.prank(owner);
        gydDistributor.setMinimumDistributionInterval(7 days);
        assertEq(gydDistributor.minimumDistributionInterval(), 7 days);
    }

    function test_distributeGyd_unauthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), gydDistributor.DISTRIBUTION_MANAGER_ROLE()));
        gydDistributor.distributeGYD(_getSgydDistribution(1e18));
    }

    function test_distributeGydL2_unauthorized() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), gydDistributor.DISTRIBUTION_MANAGER_ROLE()));
        l2GydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.SGyd,
                recipient: address(sgyd),
                amount: 1e18,
                data: abi.encode(address(this), block.number)
            })
        );
    }

    function test_distributeGyd_tooSoon() public {
        IGydDistributor.Distribution memory distribution = _getSgydDistribution(1e18);
        _whitelistKey(distribution);
        vm.startPrank(eoaDistributor);
        gydDistributor.distributeGYD(distribution);
        bytes32 key = gydDistributor.getDistributionKey(distribution);
        skip(1 hours);
        vm.expectRevert(abi.encodeWithSelector(GydDistributor.DistributionTooSoon.selector, key));
        gydDistributor.distributeGYD(distribution);
    }

    function test_distributeGyd_overRate() public {
        IGydDistributor.Distribution memory distribution = _getSgydDistribution(500e18);
        _whitelistKey(distribution);
        vm.prank(eoaDistributor);
        vm.expectRevert(GydDistributor.MaxRateExceeded.selector);
        gydDistributor.distributeGYD(distribution);
    }

    function test_distributeGyd_toSgydWrongArguments() public {
        vm.prank(eoaDistributor);
        vm.expectRevert();
        gydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.SGyd,
                recipient: address(sgyd),
                amount: 1e18,
                data: abi.encode(block.timestamp)
            })
        );
    }

    function test_distributeGyd_toNonWhitelisted() public {
        IGydDistributor.Distribution memory distribution = _getSgydDistribution(1e18);
        bytes32 key = gydDistributor.getDistributionKey(distribution);
        vm.prank(eoaDistributor);
        vm.expectRevert(abi.encodeWithSelector(GydDistributor.NotWhitelistedKey.selector, key));
        gydDistributor.distributeGYD(distribution);
    }

    function test_distributeGyd_toSgyd() public {
        IGydDistributor.Distribution memory distribution = _getSgydDistribution(1e18);
        _whitelistKey(distribution);
        vm.prank(eoaDistributor);
        gydDistributor.distributeGYD(distribution);
        assertEq(gyd.balanceOf(address(sgyd)), 1e18);
        assertEq(sgyd.totalAssets(), 0);
        skip(1 days / 2);
        assertEq(sgyd.totalAssets(), 0.5e18);
        skip(1 days / 2);
        assertEq(sgyd.totalAssets(), 1e18);
    }

    function test_distributeGyd_toGauge() public {
        IGydDistributor.Distribution memory distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.Gauge,
            recipient: address(mockGauge),
            amount: 5e18,
            data: ""
        });
        _whitelistKey(distribution);

        vm.prank(eoaDistributor);
        gydDistributor.distributeGYD(distribution);

        assertEq(gyd.balanceOf(address(mockGauge)), 5e18);
    }

    function test_distributeGyd_l2Gauge() public {
        (IGydDistributor.Distribution memory distribution, IGydDistributor.Distribution memory l2Distribution) =
            _getL2GaugeDistribution();
        _whitelistKey(distribution);
        uint256 fee = gydDistributor.getL2DistributionFee(distribution);
        deal(eoaDistributor, fee);
        vm.prank(eoaDistributor);
        gydDistributor.distributeGYD{value: fee}(distribution);

        (uint64 destinationChainSelector, address recipient, uint256 amount, bytes memory calldata_) =
            l1Escrow.messages(0);
        assertEq(destinationChainSelector, 42);
        assertEq(recipient, address(l2GydDistributor));
        assertEq(amount, 1e18);
        assertEq(calldata_, abi.encodeWithSelector(IGydDistributor.distributeGYD.selector, l2Distribution));

        assertEq(gyd.balanceOf(address(l1Escrow)), 1e18);
        assertEq(l2Gyd.balanceOf(address(mockL2Gauge)), 1e18);
    }

    function test_distributeGydL2_extraFee() public {
        (IGydDistributor.Distribution memory distribution,) = _getL2GaugeDistribution();
        _whitelistKey(distribution);

        uint256 fee = gydDistributor.getL2DistributionFee(distribution);
        uint256 msgValue = fee + 10e18;
        deal(eoaDistributor, msgValue);
        vm.prank(eoaDistributor);
        gydDistributor.distributeGYD{value: msgValue}(distribution);
        assertEq(eoaDistributor.balance, 10e18);
    }

    function test_distributeGydL2_feesNotCovered() public {
        (IGydDistributor.Distribution memory distribution,) = _getL2GaugeDistribution();
        _whitelistKey(distribution);

        uint256 fee = gydDistributor.getL2DistributionFee(distribution);
        uint256 msgValue = fee - 5;
        deal(eoaDistributor, msgValue);
        vm.prank(eoaDistributor);
        vm.expectRevert(abi.encodeWithSelector(GydDistributor.FeeNotCovered.selector, fee, msgValue));
        gydDistributor.distributeGYD{value: msgValue}(distribution);
    }

    function test_distributeGydL2_invalidAmounts() public {
        (IGydDistributor.Distribution memory distribution, IGydDistributor.Distribution memory l2Distribution) =
            _getL2GaugeDistribution();
        distribution.amount += 100;
        _whitelistKey(distribution);

        uint256 fee = gydDistributor.getL2DistributionFee(distribution);
        deal(eoaDistributor, fee);
        vm.prank(eoaDistributor);
        vm.expectRevert(
            abi.encodeWithSelector(
                GydDistributor.MismatchingAmounts.selector, distribution.amount, l2Distribution.amount
            )
        );
        gydDistributor.distributeGYD{value: fee}(distribution);
    }

    function test_distributeGyd_l2Sgyd() public {
        vm.prank(eoaDistributor);
        IGydDistributor.Distribution memory l2Distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.SGyd,
            recipient: address(l2Sgyd),
            amount: 1e18,
            data: abi.encode(block.timestamp, block.timestamp + 1 days)
        });
        IGydDistributor.Distribution memory distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.L2,
            recipient: address(l2GydDistributor),
            amount: 1e18,
            data: abi.encode(42, l2Distribution)
        });
        _whitelistKey(distribution);
        uint256 fee = gydDistributor.getL2DistributionFee(distribution);
        deal(eoaDistributor, fee);
        vm.prank(eoaDistributor);
        gydDistributor.distributeGYD{value: fee}(distribution);

        (uint64 destinationChainSelector, address recipient, uint256 amount, bytes memory calldata_) =
            l1Escrow.messages(0);
        assertEq(destinationChainSelector, 42);
        assertEq(recipient, address(l2GydDistributor));
        assertEq(amount, 1e18);
        assertEq(calldata_, abi.encodeWithSelector(IGydDistributor.distributeGYD.selector, l2Distribution));

        assertEq(gyd.balanceOf(address(l1Escrow)), 1e18);
        assertEq(l2Gyd.balanceOf(address(l2Sgyd)), 1e18);
        assertEq(l2Sgyd.totalAssets(), 0);
        skip(1 days);
        assertEq(l2Sgyd.totalAssets(), 1e18);
    }

    function test_batchDistributeGyd_multipleL1s() public {
        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](2);
        distributions[0] = _getSgydDistribution(1e18);
        distributions[1] = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.Gauge,
            recipient: address(mockGauge),
            amount: 5e18,
            data: ""
        });
        for (uint256 i = 0; i < distributions.length; i++) {
            _whitelistKey(distributions[i]);
        }
        vm.prank(eoaDistributor);
        gydDistributor.batchDistributeGYD(distributions);

        assertEq(gyd.balanceOf(address(sgyd)), 1e18);
        assertEq(sgyd.totalAssets(), 0);
        skip(1 days / 2);
        assertEq(sgyd.totalAssets(), 0.5e18);
        skip(1 days / 2);
        assertEq(sgyd.totalAssets(), 1e18);

        assertEq(gyd.balanceOf(address(mockGauge)), 5e18);
    }

    function test_batchDistributeGyd_L1sL2s() public {
        vm.prank(eoaDistributor);
        IGydDistributor.Distribution memory l2Distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.SGyd,
            recipient: address(l2Sgyd),
            amount: 1e18,
            data: abi.encode(block.timestamp, block.timestamp + 1 days)
        });
        IGydDistributor.Distribution memory l2SgydDistribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.L2,
            recipient: address(l2GydDistributor),
            amount: 1e18,
            data: abi.encode(42, l2Distribution)
        });

        IGydDistributor.Distribution[] memory distributions = new IGydDistributor.Distribution[](3);
        distributions[0] = _getSgydDistribution(1e18);
        distributions[1] = l2SgydDistribution;
        (distributions[2],) = _getL2GaugeDistribution();
        for (uint256 i = 0; i < distributions.length; i++) {
            _whitelistKey(distributions[i]);
        }

        uint256 fee = gydDistributor.getBatchDistributionFee(distributions);
        deal(eoaDistributor, fee);
        vm.prank(eoaDistributor);
        gydDistributor.batchDistributeGYD{value: fee}(distributions);

        assertEq(gyd.balanceOf(address(sgyd)), 1e18);
        assertEq(l2Gyd.balanceOf(address(l2Sgyd)), 1e18);
        assertEq(l2Gyd.balanceOf(address(mockL2Gauge)), 1e18);
    }
}
