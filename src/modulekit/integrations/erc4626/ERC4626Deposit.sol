// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC4626 } from "../../integrations/interfaces/IERC4626.sol";
import "../ERC20Actions.sol";
import "../../IExecutor.sol";

struct ModuleKitParam {
    IExecutorManager manager;
    address account;
}

library ERC4626Deposit {
    using ModuleExecLib for IExecutorManager;

    error InvalidExec();
    error InvalidAmount();

    function _depositAction(
        IERC4626 vault,
        address receiver,
        uint256 amount
    )
        internal
        pure
        returns (ExecutorAction memory depositAction)
    {
        depositAction = ExecutorAction({
            to: payable(address(vault)),
            value: 0,
            data: abi.encodeWithSelector(vault.deposit.selector, amount, receiver)
        });
    }

    function _mintAction(
        IERC4626 vault,
        address receiver,
        uint256 shares
    )
        internal
        pure
        returns (ExecutorAction memory mintAction)
    {
        mintAction = ExecutorAction({
            to: payable(address(vault)),
            value: 0,
            data: abi.encodeWithSelector(vault.mint.selector, shares, receiver)
        });
    }

    function approveAndDeposit(
        IERC4626 vault,
        IExecutorManager manager,
        address account,
        address receiver,
        uint256 amount
    )
        internal
        returns (uint256 totalAmountSent)
    {
        ExecutorAction[] memory depositActions = new ExecutorAction[](2);

        address underlying = vault.asset();
        depositActions[0] = ERC20ModuleKit.approveAction(IERC20(underlying), address(vault), amount);
        depositActions[1] = _depositAction(vault, receiver, amount);

        totalAmountSent = vault.balanceOf(receiver);
        ExecutorTransaction memory transaction =
            ExecutorTransaction({ actions: depositActions, nonce: 0, metadataHash: "" });

        bytes[] memory ret = manager.executeTransaction(account, transaction);
        if (ret.length != 2) revert InvalidExec();

        totalAmountSent = vault.balanceOf(receiver) - totalAmountSent;
    }

    function deposit(
        IERC4626 vault,
        IExecutorManager manager,
        address account,
        uint256 amount
    )
        internal
        returns (uint256 totalAmountSent)
    {
        return deposit(vault, manager, account, account, amount);
    }

    function deposit(
        IERC4626 vault,
        IExecutorManager manager,
        address account,
        address receiver,
        uint256 amount
    )
        internal
        returns (uint256 totalAmountSent)
    {
        ExecutorAction[] memory depositActions = new ExecutorAction[](1);
        depositActions[0] = _depositAction(vault, receiver, amount);
        totalAmountSent = vault.balanceOf(receiver);
        ExecutorTransaction memory transaction =
            ExecutorTransaction({ actions: depositActions, nonce: 0, metadataHash: "" });

        manager.executeTransaction(account, transaction);

        totalAmountSent = vault.balanceOf(receiver) - totalAmountSent;
    }

    function mint(
        IERC4626 vault,
        IExecutorManager manager,
        address account,
        address receiver,
        uint256 shares
    )
        internal
        returns (uint256 totalAssets)
    {
        ExecutorAction[] memory mintActions = new ExecutorAction[](1);
        mintActions[0] = _mintAction(vault, receiver, shares);

        totalAssets = vault.balanceOf(receiver);
        ExecutorTransaction memory transaction =
            ExecutorTransaction({ actions: mintActions, nonce: 0, metadataHash: "" });

        manager.executeTransaction(account, transaction);

        totalAssets = vault.balanceOf(receiver) - totalAssets;
    }
}
