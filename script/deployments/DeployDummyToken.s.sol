// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {MintableERC20} from "../../test/support/MintableERC20.sol";
import {Deployment} from "./Deployment.sol";

contract DeployDummyToken is Deployment {
    function run() public {
        MintableERC20 token = new MintableERC20("Dummy Test Token", "DTT");
    }
}
