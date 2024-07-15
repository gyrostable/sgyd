// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {L2GydDistributor} from "../../src/L2GydDistributor.sol";
import {Deployment} from "./Deployment.sol";

contract DeployL2GydDistributor is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address token = _getDeployed("DummyL2Gyd");
        console.log(token);
        bytes memory creationCode = abi.encodePacked(
            type(L2GydDistributor).creationCode,
            abi.encode(token, deployer)
        );
        _deploy("DummyL2GydDistributor", creationCode);
    }
}
