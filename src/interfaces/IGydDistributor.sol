// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

interface IGydDistributor {
    enum DestinationType {
        SGyd,
        Gauge,
        L2
    }

    struct Distribution {
        DestinationType destinationType;
        address recipient;
        uint256 amount;
        bytes data;
    }

    function distributeGYD(Distribution memory distribution) external payable;
}
