// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Address} from "oz/utils/Address.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";

import {MintableERC20} from "./MintableERC20.sol";

import {IL1GydEscrow} from "../../src/interfaces/IL1GydEscrow.sol";

contract MockL1Escrow is IL1GydEscrow {
    using Address for address;

    struct Message {
        uint64 destinationChainSelector;
        address recipient;
        uint256 amount;
        bytes data;
    }

    IERC20 public l1Gyd;
    MintableERC20 public l2Gyd;

    constructor(IERC20 l1Gyd_, MintableERC20 l2Gyd_) {
        l1Gyd = l1Gyd_;
        l2Gyd = l2Gyd_;
    }

    Message[] public messages;

    function bridgeToken(uint64 destinationChainSelector, address recipient, uint256 amount, bytes memory data)
        external
        payable
        override
    {
        require(msg.value == _getFee(destinationChainSelector, recipient, amount, data), "Invalid fee");
        messages.push(Message(destinationChainSelector, recipient, amount, data));
        l1Gyd.transferFrom(msg.sender, address(this), amount);
        l2Gyd.mint(recipient, amount);
        recipient.functionCall(data);
    }

    function getFee(uint64 destinationChainSelector, address recipient, uint256 amount, bytes memory data)
        external
        pure
        override
        returns (uint256)
    {
        return _getFee(destinationChainSelector, recipient, amount, data);
    }

    function _getFee(uint64 destinationChainSelector, address recipient, uint256 amount, bytes memory data)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(destinationChainSelector, recipient, amount, data))) % 1e18;
    }
}
