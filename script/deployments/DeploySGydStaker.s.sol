// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

import {sGydStaker} from "../../src/sGydStaker.sol";
import {Deployment} from "./Deployment.sol";

contract DeploySGyd is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address gyd_;
        address distributor;
        address governance;
        address treasury;
        address sgyd = _getDeployed(SGYD);
        if (block.chainid == 1) {
            gyd_ = gyd;
            distributor = _getDeployed(GYD_DISTRIBUTOR);
            governance = l1Governance;
            revert("add treasury address");
        } else {
            gyd_ = l2Gyd;
            distributor = _getDeployed(L2_GYD_DISTRIBUTOR);
            governance = l2Governance;
            treasury = 0x391714d83db20fde7110Cb80DC3857637c14E251;
        }
        console.log("gyd", gyd_);
        console.log("distributor", distributor);
        console.log("governance", governance);
        console.log("treasury", treasury);

        sGydStaker sgydStaker = new sGydStaker();

        bytes memory data = abi.encodeWithSelector(sGydStaker.initialize.selector, sgyd, gyd_, treasury, governance);
        bytes memory creationCode =
            abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(sgydStaker), data));
        console.log("sGydStaker", _deploy(SGYD_STAKER, creationCode));
    }
}
