// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "oz/access/AccessControl.sol";
import {MintableERC20} from "./support/MintableERC20.sol";
import {Stream} from "../src/libraries/Stream.sol";

import {SGYD} from "../src/SGYD.sol";

contract SGYDTest is Test {
    MintableERC20 public gyd;
    SGYD public sgyd;

    uint64 public streamDuration = 7 days;

    address public distributor = makeAddr("distributor");
    address public owner = makeAddr("owner");

    function setUp() public {
        gyd = new MintableERC20("GYD", "GYD");
        sgyd = new SGYD(gyd, owner, distributor);
        vm.prank(distributor);
        gyd.approve(address(sgyd), type(uint256).max);
        gyd.mint(address(distributor), 1_000_000_000e18);
    }

    function test_initialization() public view {
        assertEq(sgyd.totalStreaming(), 0);
        assertEq(sgyd.owner(), owner);
        assertTrue(sgyd.hasRole("DISTRIBUTOR_ROLE", distributor));
    }

    function test_addStream_invalidSender() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(abi.encodeWithSelector(err, address(this), bytes32("DISTRIBUTOR_ROLE")));
        sgyd.addStream(_makeStream(100));
    }

    function test_addStream_tooManyStream() public {
        vm.startPrank(distributor);
        for (uint256 i; i < 10; i++) {
            sgyd.addStream(_makeStream(100));
        }
        vm.expectRevert(SGYD.TooManyStreams.selector);
        sgyd.addStream(_makeStream(100));
    }

    function test_addStream_validSender() public {
        uint256 amount = 1000e18;

        vm.prank(distributor);
        sgyd.addStream(_makeStream(amount));

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
        sgyd.addStream(_makeStream(firstAmount));
        assertEq(sgyd.streams().length, 1);

        assertEq(sgyd.totalStreaming(), firstAmount, "totalStreaming [1]");
        assertEq(sgyd.totalAssets(), amountDonated, "totalAssets [1]");

        skip(7 days / 10);
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount / 10, "totalAssets [2]");

        skip(7 days / 10);
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount / 5, "totalAssets [3]");

        vm.prank(distributor);
        sgyd.addStream(_makeStream(secondAmount));
        assertEq(sgyd.streams().length, 2);

        uint256 streaming = firstAmount * 4 / 5 + secondAmount;
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount / 5, "totalAssets [4]");
        assertEq(sgyd.totalStreaming(), streaming, "totalStreaming [2]");

        skip(7 days / 5);
        assertEq(sgyd.totalAssets(), amountDonated + firstAmount * 2 / 5 + secondAmount / 5, "totalAssets [5]");
    }

    function _makeStream(uint256 amount) internal view returns (Stream.T memory) {
        return Stream.T({
            amount: uint128(amount),
            start: uint64(block.timestamp),
            end: uint64(block.timestamp + streamDuration)
        });
    }
}
