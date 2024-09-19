// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {L2GydDistributor} from "../../src/L2GydDistributor.sol";
import {Deployment} from "./Deployment.sol";

contract DeployL2GydDistributor is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        bytes memory args = abi.encode(l2Gyd, l2Governance);
        bytes memory creationCode = abi.encodePacked(type(L2GydDistributor).creationCode, args);
        address l2GydDistributor = _deploy(L2_GYD_DISTRIBUTOR, creationCode);
        console.log("L2GydDistributor: ", l2GydDistributor);
    }
}
