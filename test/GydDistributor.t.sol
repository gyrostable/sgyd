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
import {L2GydDistributor} from "../src/L2GydDistributor.sol";
import {IGydDistributor} from "../src/interfaces/IGydDistributor.sol";

contract GydDistributorTest is UnitTest {
    L2GydDistributor public l2GydDistributor;
    MockGauge public mockGauge;
    MockGauge public mockL2Gauge;
    sGYD public l2Sgyd;

    function setUp() public override {
        super.setUp();
        mockGauge = new MockGauge();
        mockL2Gauge = new MockGauge();

        l2GydDistributor = new L2GydDistributor(l2Gyd, owner);
        bytes memory initData =
            abi.encodeWithSelector(sGYD.initialize.selector, address(l2Gyd), owner, address(l2GydDistributor));
        l2Sgyd = sGYD(address(new ERC1967Proxy(address(new sGYD()), initData)));
    }

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
        gydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.SGyd,
                recipient: address(sgyd),
                amount: 1e18,
                data: abi.encode(address(this), block.number)
            })
        );
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
        vm.startPrank(distributionManager);
        gydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.SGyd,
                recipient: address(sgyd),
                amount: 1e18,
                data: abi.encode(block.timestamp, block.timestamp + 1 days)
            })
        );
        bytes32 key = keccak256(abi.encodePacked(IGydDistributor.DestinationType.SGyd, address(sgyd)));
        skip(1 hours);
        vm.expectRevert(abi.encodeWithSelector(GydDistributor.DistributionTooSoon.selector, key));
        gydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.SGyd,
                recipient: address(sgyd),
                amount: 1e18,
                data: abi.encode(block.timestamp, block.timestamp + 1 days)
            })
        );
    }

    function test_distributeGyd_overRate() public {
        vm.prank(distributionManager);
        vm.expectRevert(GydDistributor.MaxRateExceeded.selector);
        gydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.SGyd,
                recipient: address(sgyd),
                amount: 500e18,
                data: abi.encode(block.timestamp, block.timestamp + 1 days)
            })
        );
    }

    function test_distributeGyd_toSgydWrongArguments() public {
        vm.prank(distributionManager);
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

    function test_distributeGyd_toSgyd() public {
        vm.prank(distributionManager);
        gydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.SGyd,
                recipient: address(sgyd),
                amount: 1e18,
                data: abi.encode(block.timestamp, block.timestamp + 1 days)
            })
        );
        assertEq(gyd.balanceOf(address(sgyd)), 1e18);
        assertEq(sgyd.totalAssets(), 0);
        skip(1 days / 2);
        assertEq(sgyd.totalAssets(), 0.5e18);
        skip(1 days / 2);
        assertEq(sgyd.totalAssets(), 1e18);
    }

    function test_distributeGyd_toGauge() public {
        vm.prank(distributionManager);
        gydDistributor.distributeGYD(
            IGydDistributor.Distribution({
                destinationType: IGydDistributor.DestinationType.Gauge,
                recipient: address(mockGauge),
                amount: 5e18,
                data: ""
            })
        );
        assertEq(gyd.balanceOf(address(mockGauge)), 5e18);
    }

    function test_distributeGyd_l2Gauge() public {
        vm.prank(distributionManager);
        IGydDistributor.Distribution memory l2Distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.Gauge,
            recipient: address(mockL2Gauge),
            amount: 1e18,
            data: ""
        });
        IGydDistributor.Distribution memory distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.L2,
            recipient: address(l2GydDistributor),
            amount: 1e18,
            data: abi.encode(42, l2Distribution)
        });
        uint256 fee = gydDistributor.getL2DistributionFee(distribution);
        deal(distributionManager, fee);
        vm.prank(distributionManager);
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

    function test_distributeGyd_l2Sgyd() public {
        vm.prank(distributionManager);
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
        uint256 fee = gydDistributor.getL2DistributionFee(distribution);
        deal(distributionManager, fee);
        vm.prank(distributionManager);
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
}
