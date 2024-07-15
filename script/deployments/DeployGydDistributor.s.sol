// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {GydDistributor} from "../../src/GydDistributor.sol";
import {Deployment} from "./Deployment.sol";

contract DeployGydDistributor is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address token = _getDeployed("DummyGydTestToken");
        address escrow = _getDeployed("DummyGydL1CCIPEscrow");
        bytes memory creationCode = abi.encodePacked(
            type(GydDistributor).creationCode,
            abi.encode(token, deployer, deployer, 0.5e18, 1 days, escrow)
        );
        _deploy("DummyGydDistributor", creationCode);
    }
}
