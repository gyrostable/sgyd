// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

import {sGYD} from "../../src/sGYD.sol";
import {Deployment} from "./Deployment.sol";

contract DeploySGyd is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address gyd_;
        address distributor;
        if (block.chainid == 1) {
            gyd_ = gyd;
            distributor = _getDeployed(GYD_DISTRIBUTOR);
        } else {
            gyd_ = l2Gyd;
            distributor = _getDeployed(L2_GYD_DISTRIBUTOR);
        }
        console.log("gyd", gyd_);
        console.log("distributor", distributor);

        sGYD sgyd = new sGYD();

        bytes memory data = abi.encodeWithSelector(sGYD.initialize.selector, gyd_, governance, distributor);
        bytes memory creationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(sgyd), data));
        console.log("sgyd", _deploy(SGYD, creationCode));
    }
}
