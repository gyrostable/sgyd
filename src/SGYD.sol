// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRules} from "oz/access/extensions/AccessControlDefaultAdminRules.sol";
import {ERC4626, ERC20, IERC20} from "oz/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "./libraries/Errors.sol";
import {Stream} from "./libraries/Stream.sol";

contract SGYD is ERC4626, AccessControlDefaultAdminRules {
    using Stream for Stream.T;
    using SafeERC20 for IERC20;

    bytes32 internal constant _DISTRIBUTOR_ROLE = "DISTRIBUTOR_ROLE";

    Stream.T internal _incomingStream;

    uint256 public totalStreaming;
    uint64 public streamDuration;

    modifier onlyDistributor() {
        _checkRole(_DISTRIBUTOR_ROLE, msg.sender);
        _;
    }

    constructor(IERC20 gyd, address owner_, address distributor_, uint64 streamDuration_)
        ERC20("Savings GYD", "sGYD")
        ERC4626(gyd)
        AccessControlDefaultAdminRules(0, owner_)
    {
        streamDuration = streamDuration_;
        _grantRole(_DISTRIBUTOR_ROLE, distributor_);
    }

    function receiveYield(uint256 amount) external onlyDistributor {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        Stream.T memory newStream = Stream.create(amount, streamDuration);
        uint256 streamed = _incomingStream.update(newStream);
        totalStreaming = totalStreaming + amount - streamed;
    }

    function totalAssets() public view override returns (uint256 assets) {
        assets = IERC20(asset()).balanceOf(address(this)) - totalStreaming + _incomingStream.streamed();
    }

    function streamingEnd() public view returns (uint64) {
        return _incomingStream.end;
    }
}
