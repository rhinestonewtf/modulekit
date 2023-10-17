// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC4626 } from "../../integrations/interfaces/IERC4626.sol";
import "../ERC20Actions.sol";
import "../../IExecutor.sol";

struct ModuleKitParam {
    IExecutorManager manager;
    address account;
}

library ERC4626Withdraw {
    using ModuleExecLib for IExecutorManager;

    function _withdrawAction(
        IERC4626 vault,
        address owner,
        address receiver,
        uint256 amount
    )
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(vault)),
            value: 0,
            data: abi.encodeWithSelector(vault.withdraw.selector, amount, receiver, owner)
        });
    }

    function _redeemAction(
        IERC4626 vault,
        address owner,
        address receiver,
        uint256 shares
    )
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(vault)),
            value: 0,
            data: abi.encodeWithSelector(vault.redeem.selector, shares, receiver, owner)
        });
    }

    function withdraw(
        IERC4626 vault,
        IExecutorManager manager,
        address account,
        address receiver,
        uint256 amount
    )
        internal
        returns (uint256 totalAmountReceived)
    {
        ExecutorAction memory action = _withdrawAction(vault, account, receiver, amount);

        totalAmountReceived = vault.balanceOf(account);
        if (totalAmountReceived < amount) revert();

        manager.exec(account, action);

        totalAmountReceived = totalAmountReceived - vault.balanceOf(account);
    }

    function redeem(
        IERC4626 vault,
        IExecutorManager manager,
        address account,
        address receiver,
        uint256 shares
    )
        internal
        returns (uint256 assets)
    {
        ExecutorAction memory action = _redeemAction(vault, account, receiver, shares);

        assets = vault.balanceOf(account);
        manager.exec(account, action);
        assets = vault.balanceOf(account) - assets;
    }
}
