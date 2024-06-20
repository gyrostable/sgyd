// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

interface IL1GydEscrow {
    function bridgeToken(uint64 destinationChainSelector, address recipient, uint256 amount, bytes memory data)
        external
        payable;

    function getFee(uint64 destinationChainSelector, address recipient, uint256 amount, bytes memory data)
        external
        view
        returns (uint256);
}
