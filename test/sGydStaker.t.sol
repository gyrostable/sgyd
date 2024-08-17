// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {UnitTest} from "./support/UnitTest.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";
import {MintableERC20} from "./support/MintableERC20.sol";

import {sGydStaker} from "../src/sGydStaker.sol";

contract sGydStakerTest is UnitTest {
    sGydStaker sgydStaker;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");
    MintableERC20 public rewardToken;

    function setUp() public override {
        super.setUp();
        vm.prank(distributor);
        rewardToken = new MintableERC20("Reward Token", "RWT");
        sgydStaker = new sGydStaker();
        bytes memory initData =
            abi.encodeWithSelector(sGydStaker.initialize.selector, address(sgyd), address(rewardToken), treasury, admin);
        sgydStaker = sGydStaker(address(new ERC1967Proxy(address(new sGydStaker()), initData)));
    }

    function test_deposit() public {
        uint256 amount = 1000e18;
        _deposit(amount);
        assertEq(sgydStaker.balanceOf(alice), amount);
    }

    function test_withdraw() public {
        uint256 amount = 1000e18;
        _deposit(amount);
        vm.prank(alice);
        sgydStaker.withdraw(amount, alice, alice);
        assertEq(sgydStaker.balanceOf(alice), 0);
        assertEq(sgyd.balanceOf(alice), amount);
    }

    function test_startMining() public {
        uint256 rewardAmount = 100e18;
        uint256 amount = 1000e18;
        _deposit(amount);

        _startMining(rewardAmount);
        assertEq(rewardToken.balanceOf(address(sgydStaker)), rewardAmount);
    }

    function test_claimRewards() public {
        uint256 aliceAmount = 1000e18;
        uint256 bobAmount = 250e18;
        uint256 rewardAmount = 100e18;

        _deposit(alice, aliceAmount);
        _deposit(bob, bobAmount);
        _startMining(rewardAmount);

        skip(6 hours);

        uint256 claimableAlice = sgydStaker.claimableRewards(alice);
        assertApproxEqRel(claimableAlice, rewardAmount / 5, 0.001e18);
        assertApproxEqRel(sgydStaker.claimableRewards(bob), rewardAmount / 5 / 4, 0.001e18);

        vm.prank(alice);
        sgydStaker.claimRewards();
        assertEq(rewardToken.balanceOf(alice), claimableAlice);

        skip(18 hours);
        assertApproxEqRel(sgydStaker.claimableRewards(alice), rewardAmount * 3 / 5, 0.001e18);
        assertApproxEqRel(sgydStaker.claimableRewards(bob), rewardAmount / 5, 0.001e18);

        vm.prank(alice);
        sgydStaker.claimRewards();
        vm.prank(bob);
        sgydStaker.claimRewards();
        assertApproxEqRel(rewardToken.balanceOf(alice), rewardAmount * 4 / 5, 0.001e18);
        assertApproxEqRel(rewardToken.balanceOf(bob), rewardAmount / 5, 0.001e18);
    }

    function test_claimRewards_multiphase() public {
        uint256 aliceAmount = 1000e18;
        uint256 bobAmount = 250e18;
        uint256 rewardAmount = 100e18;

        _deposit(alice, aliceAmount);
        _deposit(bob, bobAmount);
        _startMining(rewardAmount);

        skip(6 hours);
        vm.prank(alice);
        sgydStaker.claimRewards();

        skip(18 hours);
        vm.prank(admin);
        sgydStaker.stopMining();
        _startMining(rewardAmount * 2);
        skip(24 hours);

        vm.prank(bob);
        sgydStaker.claimRewards();
        vm.prank(alice);
        sgydStaker.claimRewards();
        assertApproxEqRel(rewardToken.balanceOf(alice), rewardAmount * 3 * 4 / 5, 0.001e18);
        assertApproxEqRel(rewardToken.balanceOf(bob), rewardAmount * 3 / 5, 0.001e18);
    }

    function _deposit(uint256 amount) internal {
        _deposit(alice, amount);
    }

    function _deposit(address account, uint256 amount) internal {
        gyd.mint(account, amount);
        vm.startPrank(account);
        gyd.approve(address(sgyd), amount);
        sgyd.deposit(amount, account);
        sgyd.approve(address(sgydStaker), amount);
        sgydStaker.deposit(amount, account);
        vm.stopPrank();
    }

    function _startMining(uint256 rewardAmount) internal {
        rewardToken.mint(treasury, rewardAmount);
        vm.prank(treasury);
        rewardToken.approve(address(sgydStaker), rewardAmount);
        vm.prank(admin);
        sgydStaker.startMining(treasury, rewardAmount, block.timestamp + 1 days);
    }
}
