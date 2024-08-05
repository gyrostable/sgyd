// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Strings} from "oz/utils/Strings.sol";

import {Script} from "forge-std/Script.sol";
import {ICREATE3Factory} from "../../src/interfaces/ICREATE3Factory.sol";

contract Deployment is Script {
    string public constant GYD_DISTRIBUTOR = "GydDistributorV1";
    string public constant L2_GYD_DISTRIBUTOR = "L2GydDistributorV1";
    string public constant SGYD = "sGYD";
    string public constant DISTRIBUTION_MANAGER = "GydDistributionManagerV1";

    // https://etherscan.io/address/0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1
    ICREATE3Factory public factory =
        ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

    // https://etherscan.io/address/0x78EcF97572c3890eD02221A611014F30219f6219
    address public l1Governance = 0x78EcF97572c3890eD02221A611014F30219f6219;

    // https://arbiscan.io/address/0xd62bb3c3D6C7BD5C6bA64aA4D7BF05aE6AD10568
    address public l2Governance = 0xd62bb3c3D6C7BD5C6bA64aA4D7BF05aE6AD10568;

    // https://etherscan.io/address/0xa1886c8d748DeB3774225593a70c79454B1DA8a6
    address public l1EscrowAddress = 0xa1886c8d748DeB3774225593a70c79454B1DA8a6;

    // https://etherscan.io/address/0xe07F9D810a48ab5c3c914BA3cA53AF14E4491e8A
    address public gyd = 0xe07F9D810a48ab5c3c914BA3cA53AF14E4491e8A;

    // https://arbiscan.io/address/0xCA5d8F8a8d49439357d3CF46Ca2e720702F132b8
    address public l2Gyd = 0xCA5d8F8a8d49439357d3CF46Ca2e720702F132b8;

    // https://etherscan.io/address/0x8bc920001949589258557412a32f8d297a74f244
    address public deployer = 0x8bc920001949589258557412A32F8d297A74F244;

    // https://etherscan.io/address/0xA8D612739354a4106072a91aA4Ca1458E1b5f9e9
    address public distributionExecutor =
        0xA8D612739354a4106072a91aA4Ca1458E1b5f9e9;

    // https://etherscan.io/address/0xb0307AB3e2C0886a70b2C84897Bca7Ee9b237a50
    address public distributionSubmitter =
        0xb0307AB3e2C0886a70b2C84897Bca7Ee9b237a50;

    uint256 public deployerPrivateKey;

    function setUp() public virtual {
        deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
    }

    function _deploy(
        string memory name,
        bytes memory creationCode
    ) internal returns (address) {
        bytes32 salt = keccak256(bytes(name));
        return factory.deploy(salt, creationCode);
    }

    function _getDeployed(string memory name) internal view returns (address) {
        bytes32 salt = keccak256(bytes(name));
        return factory.getDeployed(deployer, salt);
    }
}
