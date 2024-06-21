// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";

import {MintableERC20} from "./MintableERC20.sol";
import {MockL1Escrow} from "./MockL1Escrow.sol";

import {sGYD} from "../../src/sGYD.sol";
import {GydDistributor} from "../../src/GydDistributor.sol";

contract UnitTest is Test {
    address public distributionManager = makeAddr("distributor");
    address public owner = makeAddr("owner");
    uint256 public maxRate = 0.1e18;

    MintableERC20 public gyd;
    MintableERC20 public l2Gyd;
    sGYD public sgyd;
    GydDistributor public gydDistributor;
    address public distributor;
    MockL1Escrow public l1Escrow;

    function setUp() public virtual {
        vm.warp(1718998010);
        gyd = new MintableERC20("GYD", "GYD");
        gyd.mint(owner, 1000e18);

        l2Gyd = new MintableERC20("GYD L2", "GYD L2");

        l1Escrow = new MockL1Escrow(gyd, l2Gyd);
        gydDistributor = new GydDistributor(gyd, owner, distributionManager, maxRate, 1 days, l1Escrow);
        distributor = address(gydDistributor);

        bytes memory initData = abi.encodeWithSelector(sGYD.initialize.selector, address(gyd), owner, distributor);
        sgyd = sGYD(address(new ERC1967Proxy(address(new sGYD()), initData)));
    }
}
