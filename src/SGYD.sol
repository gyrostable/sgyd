// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "ozu/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";
import {ERC4626Upgradeable} from "ozu/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {UUPSUpgradeable} from "ozu/proxy/utils/UUPSUpgradeable.sol";

import {Stream} from "./libraries/Stream.sol";

contract SGYD is ERC4626Upgradeable, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {
    using Stream for Stream.T;
    using SafeERC20 for IERC20;

    event StreamAdded(address indexed distributor, Stream.T stream);

    error TooManyStreams();

    /// @dev We are not expecting that many streams at once
    /// but this is a safe guard to avoid locking the contract because of gas usage
    uint256 internal constant _MAX_STREAMS = 10;
    bytes32 internal constant _DISTRIBUTOR_ROLE = "DISTRIBUTOR_ROLE";

    Stream.T[] internal _streams;

    modifier onlyDistributor() {
        _checkRole(_DISTRIBUTOR_ROLE, msg.sender);
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(IERC20 gyd, address owner_, address distributor) external initializer {
        __UUPSUpgradeable_init();
        __ERC4626_init(gyd);
        __ERC20_init("Savings GYD", "sGYD");
        __AccessControlDefaultAdminRules_init(0, owner_);
        _grantRole(_DISTRIBUTOR_ROLE, distributor);
    }

    /// @notice Can only be upgraded by the owner
    function _authorizeUpgrade(address v) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Adds a GYD reward stream to the contract
    /// @param stream Stream to add
    function addStream(Stream.T memory stream) external onlyDistributor {
        _cleanStreams();
        if (_streams.length >= _MAX_STREAMS) revert TooManyStreams();

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), stream.amount);
        _streams.push(stream);
        emit StreamAdded(msg.sender, stream);
    }

    /// @notice Returns the total assets currently available
    /// this does not include the GYD that is still streaming
    function totalAssets() public view override returns (uint256 assets) {
        assets = IERC20(asset()).balanceOf(address(this)) - totalStreaming();
    }

    /// @dev some of the streams might not be started or might already have ended
    /// @return streams_ all the current streams
    function streams() external view returns (Stream.T[] memory streams_) {
        streams_ = _streams;
    }

    /// @notice Returns the total amount of GYD still streaming
    function totalStreaming() public view returns (uint256 streaming) {
        for (uint256 i; i < _streams.length; i++) {
            streaming += _streams[i].streaming();
        }
    }

    function _cleanStreams() internal {
        for (uint256 i = _streams.length; i > 0; i--) {
            if (_streams[i - 1].hasEnded()) {
                _streams[i - 1] = _streams[_streams.length - 1];
                _streams.pop();
            }
        }
    }
}
