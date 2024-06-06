// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

library Stream {
    using Stream for T;

    struct T {
        uint128 amount;
        uint64 start;
        uint64 end;
    }

    function create(uint256 amount, uint64 duration) internal view returns (T memory stream) {
        uint64 start = uint64(block.timestamp);
        return T(uint128(amount), start, start + duration);
    }

    function hasEnded(T memory self) internal view returns (bool) {
        return block.timestamp > self.end;
    }

    function streamed(T memory self) internal view returns (uint256 streamed_) {
        if (block.timestamp < self.start) return 0;
        if (self.hasEnded()) return self.amount;
        uint256 duration = self.end - self.start;
        uint256 elapsed = block.timestamp - self.start;
        streamed_ = uint256(self.amount) * elapsed / duration;
    }

    function streaming(T memory self) internal view returns (uint256 streaming_) {
        streaming_ = self.amount - self.streamed();
    }

    function update(T storage self, T memory newStream) internal returns (uint256 streamed_) {
        streamed_ = self.streamed();
        self.amount = uint128(self.amount + newStream.amount - streamed_);
        self.start = newStream.start;
        self.end = newStream.end;
    }
}
