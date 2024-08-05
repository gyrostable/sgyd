// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

interface ICurveLiquidityGauge {
    function deposit_reward_token(
        address _reward_token,
        uint256 _amount
    ) external;

    function set_reward_distributor(
        address _reward_token,
        address _distributor
    ) external;
}
