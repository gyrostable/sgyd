// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "oz/access/AccessControl.sol";
import {MintableERC20} from "./support/MintableERC20.sol";

import {SGYD} from "../src/SGYD.sol";

contract SGYDTest is Test {
    MintableERC20 public gyd;
    SGYD public sgyd;

    uint64 public streamDuration = 7 days;

    address public distributor = makeAddr("distributor");
    address public owner = makeAddr("owner");

    function setUp() public {
        gyd = new MintableERC20("GYD", "GYD");
        sgyd = new SGYD(gyd, owner, distributor, streamDuration);
        vm.prank(distributor);
        gyd.approve(address(sgyd), type(uint256).max);
        gyd.mint(address(distributor), 1_000_000_000e18);
    }

    function test_initialization() public view {
        assertEq(sgyd.totalStreaming(), 0);
        assertEq(sgyd.streamDuration(), 7 days);
        assertEq(sgyd.owner(), owner);
        assertTrue(sgyd.hasRole("DISTRIBUTOR_ROLE", distributor));
    }

    function test_receiveYield_invalidSender() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), bytes32("DISTRIBUTOR_ROLE")));
        sgyd.receiveYield(100);
    }

    function test_receiveYield_validSender() public {
        uint256 amount = 1000e18;

        vm.prank(distributor);
        sgyd.receiveYield(amount);

        assertEq(sgyd.totalStreaming(), amount);
        assertEq(sgyd.totalAssets(), 0);
    }

    function test_totalAssets() public {
        uint256 amountDonated = 100e18;
        uint256 firstAmount = 1000e18;
        uint256 secondAmount = 10e18;

        // donate amount bypassing streaming
        gyd.mint(address(sgyd), amountDonated);

        vm.prank(distributor);
        sgyd.receiveYield(firstAmount);

        assertEq(sgyd.totalStreaming(), firstAmount, "totalStreaming [1]");
        assertEq(sgyd.totalAssets(), amountDonated, "totalAssets [1]");

        skip(7 days / 10);
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount / 10, "totalAssets [2]");

        skip(7 days / 10);
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount / 5, "totalAssets [3]");

        vm.prank(distributor);
        sgyd.receiveYield(secondAmount);

        uint256 streaming = firstAmount * 4 / 5 + secondAmount;
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount / 5, "totalAssets [4]");
        assertEq(sgyd.totalStreaming(), streaming, "totalStreaming [2]");
        assertEq(sgyd.streamingEnd(), block.timestamp + 7 days, "streamingEnd");

        skip(7 days / 3);
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount / 5 + streaming / 3, "totalAssets [5]");
    }
}
