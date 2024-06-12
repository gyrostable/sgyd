// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

library ScaledMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / 1e18;
    }
}
