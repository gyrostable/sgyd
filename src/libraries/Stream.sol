// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

library Stream {
    using Stream for T;

    uint256 internal constant _MINIMUM_STREAM_AMOUNT = 10**18;
    uint256 internal constant _MINIMUM_DURATION = 1 hours;
    uint256 internal constant _MAXIMUM_DURATION = 1 days * 365 * 5; // 5 years

    struct T {
        uint128 amount;
        uint64 start;
        uint64 end;
    }

    function isValid(T memory self) internal pure returns (bool) {
        if (self.amount < _MINIMUM_STREAM_AMOUNT) return false;
        if (self.start >= self.end) return false;
        uint256 duration = self.end - self.start;
        return duration >= _MINIMUM_DURATION && duration <= _MAXIMUM_DURATION;

    }

    function hasEnded(T memory self) internal view returns (bool) {
        return block.timestamp > self.end;
    }

    function distributedAmount(T memory self) internal view returns (uint256 distributed_) {
        if (block.timestamp < self.start) return 0;
        if (self.hasEnded()) return self.amount;
        uint256 duration = self.end - self.start;
        uint256 elapsed = block.timestamp - self.start;
        distributed_ = (uint256(self.amount) * elapsed) / duration;
    }

    function pendingAmount(
        T memory self
    ) internal view returns (uint256 pending_) {
        pending_ = self.amount - self.distributedAmount();
    }
}
