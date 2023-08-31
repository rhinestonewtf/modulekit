// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../executors/IExecutorBase.sol";

import "forge-std/interfaces/IERC20.sol";

function _payFee(address vault, address token, address amount) view returns (ExecutorAction memory action) {
    action.to = payable(token);
    action.data = abi.encodeWithSelector(IERC20.transfer.selector, vault, amount);
}
