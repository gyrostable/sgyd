// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {DistributionManager} from "../../src/DistributionManager.sol";
import {IL1GydDistributor} from "../../src/interfaces/IL1GydDistributor.sol";
import {Deployment} from "./Deployment.sol";

contract DeployDistributionManager is Deployment {
    uint256 public minExecutionDelay = 5 minutes;

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        IL1GydDistributor distributor = IL1GydDistributor(_getDeployed(GYD_DISTRIBUTOR));

        bytes memory args =
            abi.encode(governance, distributor, distributionSubmitter, distributionExecutor, minExecutionDelay);
        bytes memory creationCode = abi.encodePacked(type(DistributionManager).creationCode, args);
        address distributionManager = _deploy(DISTRIBUTION_MANAGER, creationCode);

        console.log("DistributionManager:", distributionManager);
    }
}
