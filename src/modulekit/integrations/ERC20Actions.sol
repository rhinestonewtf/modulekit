// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.18;

import "forge-std/interfaces/IERC20.sol";
import "../IExecutor.sol";
import "./interfaces/IWETH.sol";

library ERC20ModuleKit {
    address public constant WSTETH_ADDR = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH_ADDR = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function approveAction(
        IERC20 token,
        address to,
        uint256 amount
    )
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(token)),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, to, amount)
        });
    }

    function transferAction(
        IERC20 token,
        address to,
        uint256 amount
    )
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(token)),
            value: 0,
            data: abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        });
    }

    function transferFromAction(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    )
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(token)),
            value: 0,
            data: abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        });
    }

    function depositWethAction(uint256 amount)
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(WETH_ADDR)),
            value: amount,
            data: abi.encodeWithSelector(IWETH.deposit.selector)
        });
    }

    function withdrawWethAction(uint256 amount)
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(WETH_ADDR)),
            value: 0,
            data: abi.encodeWithSelector(IWETH.withdraw.selector, amount)
        });
    }

    function getBalance(address token, address account) internal view returns (uint256 balance) {
        if (token == ETH_ADDR) {
            balance = account.balance;
        } else {
            balance = IERC20(token).balanceOf(account);
        }
    }
}
