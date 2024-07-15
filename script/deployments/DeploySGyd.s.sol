// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

import {sGYD} from "../../src/sGYD.sol";
import {Deployment} from "./Deployment.sol";

contract DeploySGyd is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log(block.chainid);

        address gyd;
        address distributor;
        if (block.chainid == 1) {
            gyd = _getDeployed("DummyGydTestToken");
            distributor = _getDeployed("DummyGydDistributor");
        } else {
            gyd = _getDeployed("DummyL2Gyd");
            distributor = _getDeployed("DummyL2GydDistributor");
        }
        console.log("gyd", gyd);
        console.log("distributor", distributor);

        sGYD sgyd = new sGYD();

        bytes memory data = abi.encodeWithSelector(
            sGYD.initialize.selector,
            gyd,
            deployer,
            distributor
        );
        bytes memory creationCode = abi.encodePacked(
            type(UUPSProxy).creationCode,
            abi.encode(address(sgyd), data)
        );
        console.log(_deploy("DummySGYD", creationCode));
    }
}
