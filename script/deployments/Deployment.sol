// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ICREATE3Factory} from "../../src/interfaces/ICREATE3Factory.sol";

contract Deployment is Script {
    // https://etherscan.io/address/0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1
    ICREATE3Factory public factory = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

    // https://etherscan.io/address/0xa1886c8d748DeB3774225593a70c79454B1DA8a6
    address public l1EscrowAddress = 0xa1886c8d748DeB3774225593a70c79454B1DA8a6;

    // https://arbiscan.io/address/0xCA5d8F8a8d49439357d3CF46Ca2e720702F132b8;
    address public l2Gyd = 0xCA5d8F8a8d49439357d3CF46Ca2e720702F132b8;

    // https://etherscan.io/address/0x8bc920001949589258557412a32f8d297a74f244
    address public deployer = 0x8bc920001949589258557412A32F8d297A74F244;

    uint256 public deployerPrivateKey;

    function setUp() public virtual {
        deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
    }
}
