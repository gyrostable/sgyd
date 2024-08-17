// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

import {sGydStaker} from "../../src/sGydStaker.sol";
import {Deployment} from "./Deployment.sol";

contract DeploySGyd is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address arb;
        address governance;
        address treasury;
        address sgyd = _getDeployed(SGYD);
        if (block.chainid == 1) {
            governance = l1Governance;
            arb = 0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1;
            revert("add treasury address");
        } else {
            arb = 0x912CE59144191C1204E64559FE8253a0e49E6548;
            governance = l2Governance;
            treasury = 0x391714d83db20fde7110Cb80DC3857637c14E251;
        }
        console.log("arb", arb);
        console.log("governance", governance);
        console.log("treasury", treasury);

        sGydStaker sgydStaker = new sGydStaker();

        bytes memory data = abi.encodeWithSelector(sGydStaker.initialize.selector, sgyd, arb, treasury, governance);
        bytes memory creationCode =
            abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(sgydStaker), data));
        console.log("sGydStaker", _deploy(SGYD_STAKER, creationCode));
    }
}
