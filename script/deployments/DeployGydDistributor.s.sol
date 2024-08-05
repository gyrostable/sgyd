// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {GydDistributor} from "../../src/GydDistributor.sol";
import {Deployment} from "./Deployment.sol";

contract DeployGydDistributor is Deployment {
    uint256 public constant maxRate = 0.01e18;
    uint256 public constant minimumDistributionInterval = 1 days;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address distributionManager = _getDeployed(DISTRIBUTION_MANAGER);
        bytes memory args = abi.encode(
            gyd,
            l1Governance,
            distributionManager,
            maxRate,
            minimumDistributionInterval,
            l1EscrowAddress
        );
        bytes memory creationCode = abi.encodePacked(
            type(GydDistributor).creationCode,
            args
        );
        address gydDistributor = _deploy(GYD_DISTRIBUTOR, creationCode);
        console.log("GydDistributor:", gydDistributor);
    }
}
