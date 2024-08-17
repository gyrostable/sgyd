// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "ozu/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {LiquidityMining} from "./LiquidityMining.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "ozu/proxy/utils/UUPSUpgradeable.sol";
import {ERC4626Upgradeable} from "ozu/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract sGydStaker is
    ERC4626Upgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    LiquidityMining,
    UUPSUpgradeable
{
    error NotAuthorized();

    modifier onlyTreasury() {
        if (msg.sender != daoTreasury) revert NotAuthorized();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(IERC20 _depositToken, IERC20 _rewardToken, address _daoTreasury, address _initialAdmin)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __ERC20_init("Staked sGYD", "st-sGYD");
        __ERC4626_init(_depositToken);
        __AccessControlDefaultAdminRules_init(0, _initialAdmin);
        __LiquidityMining_init(address(_rewardToken), _daoTreasury);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        _stake(receiver, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        super._withdraw(caller, receiver, owner, assets, shares);
        _unstake(receiver, shares);
    }

    function startMining(address rewardsFrom, uint256 amount, uint256 endTime) external override onlyTreasury {
        _startMining(rewardsFrom, amount, endTime);
    }

    function stopMining() external override onlyTreasury {
        _stopMining();
    }
}
