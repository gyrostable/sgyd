// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {MintableERC20} from "../../test/support/MintableERC20.sol";
import {Deployment} from "./Deployment.sol";

contract DeployDummyToken is Deployment {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        bytes memory creationCode = abi.encodePacked(
            type(MintableERC20).creationCode,
            abi.encode("Dummy GYD Test Token", "DTT")
        );
        console.log(_deploy("DummyGydTestToken", creationCode));
    }
}
