// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";

import {L2Gyd} from "./L2Gyd.sol";
import {MintableERC20} from "./MintableERC20.sol";
import {MockL1Escrow} from "./MockL1Escrow.sol";
import {MockGauge} from "./MockGauge.sol";

import {sGYD} from "../../src/sGYD.sol";
import {GydDistributor, IGydDistributor} from "../../src/GydDistributor.sol";
import {L2GydDistributor} from "../../src/L2GydDistributor.sol";

contract UnitTest is Test {
    address public eoaDistributor = makeAddr("distributor");
    address public owner = makeAddr("owner");
    uint256 public maxRate = 0.1e18;

    MintableERC20 public gyd;
    L2Gyd public l2Gyd;
    sGYD public sgyd;
    GydDistributor public gydDistributor;
    address public distributor;
    MockL1Escrow public l1Escrow;
    L2GydDistributor public l2GydDistributor;
    MockGauge public mockGauge;
    MockGauge public mockL2Gauge;
    sGYD public l2Sgyd;

    function setUp() public virtual {
        vm.warp(1718998010);
        gyd = new MintableERC20("GYD", "GYD");
        gyd.mint(owner, 1000e18);

        l2Gyd = new L2Gyd("GYD L2", "GYD L2");

        l1Escrow = new MockL1Escrow(gyd, l2Gyd);
        gydDistributor = new GydDistributor(gyd, owner, eoaDistributor, maxRate, 1 days, l1Escrow);
        distributor = address(gydDistributor);

        bytes memory initData = abi.encodeWithSelector(sGYD.initialize.selector, address(gyd), owner, distributor);
        sgyd = sGYD(address(new ERC1967Proxy(address(new sGYD()), initData)));
        mockGauge = new MockGauge();
        mockL2Gauge = new MockGauge();

        l2GydDistributor = new L2GydDistributor(l2Gyd, owner);
        initData = abi.encodeWithSelector(sGYD.initialize.selector, address(l2Gyd), owner, address(l2GydDistributor));
        l2Sgyd = sGYD(address(new ERC1967Proxy(address(new sGYD()), initData)));
    }

    function _getSgydDistribution(uint256 amount)
        internal
        view
        returns (IGydDistributor.Distribution memory distribution)
    {
        distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.SGyd,
            recipient: address(sgyd),
            amount: amount,
            data: abi.encode(block.timestamp, block.timestamp + 1 days)
        });
    }

    function _getL2GaugeDistribution()
        internal
        view
        returns (IGydDistributor.Distribution memory l1Distribution, IGydDistributor.Distribution memory l2Distribution)
    {
        l2Distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.Gauge,
            recipient: address(mockL2Gauge),
            amount: 1e18,
            data: ""
        });
        l1Distribution = IGydDistributor.Distribution({
            destinationType: IGydDistributor.DestinationType.L2,
            recipient: address(l2GydDistributor),
            amount: 1e18,
            data: abi.encode(42, l2Distribution)
        });
    }

    function _whitelistKey(IGydDistributor.Distribution memory distribution) internal {
        bytes32 key = gydDistributor.getDistributionKey(distribution);
        vm.prank(owner);
        gydDistributor.addWhitelistedDistributionKey(key);
    }
}
