// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "oz/access/AccessControl.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";

import {MintableERC20} from "./support/MintableERC20.sol";
import {Stream} from "../src/libraries/Stream.sol";
import {sGYD} from "../src/sGYD.sol";

contract SGYDTest is Test {
    MintableERC20 public gyd;
    sGYD public sgyd;

    uint64 public streamDuration = 7 days;

    address public distributor = makeAddr("distributor");
    address public owner = makeAddr("owner");

    function setUp() public {
        gyd = new MintableERC20("GYD", "GYD");
        bytes memory initData = abi.encodeWithSelector(
            sGYD.initialize.selector,
            address(gyd),
            owner,
            distributor
        );
        sgyd = sGYD(address(new ERC1967Proxy(address(new sGYD()), initData)));
        vm.prank(distributor);
        gyd.approve(address(sgyd), type(uint256).max);
        gyd.mint(address(distributor), 1_000_000_000e18);
    }

    function test_initialization() public view {
        assertEq(sgyd.totalPendingAmount(), 0);
        assertEq(sgyd.owner(), owner);
        assertTrue(sgyd.hasRole("DISTRIBUTOR_ROLE", distributor));
    }

    function test_addStream_invalid() public {
        vm.startPrank(distributor);

        vm.expectRevert(sGYD.InvalidStream.selector);
        sgyd.addStream(_makeStream(100));

        Stream.T memory stream = Stream.T({
            amount: uint128(10 ** 18),
            start: uint64(block.timestamp),
            end: uint64(block.timestamp + 1 days * 365 * 10)
        });
        vm.expectRevert(sGYD.InvalidStream.selector);
        sgyd.addStream(stream);

        vm.stopPrank();
    }

    function test_addStream_invalidSender() public {
        bytes4 err = IAccessControl.AccessControlUnauthorizedAccount.selector;
        vm.expectRevert(
            abi.encodeWithSelector(
                err,
                address(this),
                bytes32("DISTRIBUTOR_ROLE")
            )
        );
        sgyd.addStream(_makeStream(1e18));
    }

    function test_addStream_tooManyStream() public {
        vm.startPrank(distributor);
        for (uint256 i; i < 10; i++) {
            sgyd.addStream(_makeStream(1e18));
        }
        vm.expectRevert(sGYD.TooManyStreams.selector);
        sgyd.addStream(_makeStream(1e18));
    }

    function test_addStream_validSender() public {
        uint256 amount = 1000e18;

        vm.prank(distributor);
        sgyd.addStream(_makeStream(amount));

        assertEq(sgyd.totalPendingAmount(), amount);
        assertEq(sgyd.totalAssets(), 0);
    }

    function test_addStream_withCleanup() public {
        vm.startPrank(distributor);
        for (uint256 i; i < 15; i++) {
            skip(1 days);
            sgyd.addStream(_makeStream(1e18));
        }
        vm.assertEq(sgyd.streams().length, 8);
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

        assertEq(sgyd.totalPendingAmount(), firstAmount, "totalStreaming [1]");
        assertEq(sgyd.totalAssets(), amountDonated, "totalAssets [1]");

        skip(7 days / 10);
        assertEq(
            sgyd.totalAssets(),
            amountDonated + firstAmount / 10,
            "totalAssets [2]"
        );

        skip(7 days / 10);
        assertEq(
            sgyd.totalAssets(),
            amountDonated + firstAmount / 5,
            "totalAssets [3]"
        );

        vm.prank(distributor);
        sgyd.addStream(_makeStream(secondAmount));
        assertEq(sgyd.streams().length, 2);

        uint256 streaming = (firstAmount * 4) / 5 + secondAmount;
        assertEq(
            sgyd.totalAssets(),
            amountDonated + firstAmount / 5,
            "totalAssets [4]"
        );
        assertEq(sgyd.totalPendingAmount(), streaming, "totalStreaming [2]");

        skip(7 days / 5);
        assertEq(
            sgyd.totalAssets(),
            amountDonated + (firstAmount * 2) / 5 + secondAmount / 5,
            "totalAssets [5]"
        );
    }

    function _makeStream(
        uint256 amount
    ) internal view returns (Stream.T memory) {
        return
            Stream.T({
                amount: uint128(amount),
                start: uint64(block.timestamp),
                end: uint64(block.timestamp + streamDuration)
            });
    }
}
