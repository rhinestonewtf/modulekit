// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/yearn/IYVault.sol";
import "../../IExecutor.sol";
import "../ERC20Actions.sol";

import "forge-std/interfaces/IERC20.sol";
import "forge-std/console2.sol";

library YearnDeposit {
    using ModuleExecLib for IExecutorManager;
    using ERC20ModuleKit for address;

    function _depositAction(
        address vault,
        uint256 amount,
        address recipient
    )
        internal
        pure
        returns (ExecutorAction memory withdrawAction)
    {
        withdrawAction = ExecutorAction({
            to: payable(address(vault)),
            value: 0,
            data: abi.encodeWithSelector(IYVault.deposit.selector, amount, recipient)
        });
    }

    function deposit(
        IExecutorManager manager,
        address account,
        address yToken,
        uint256 amount
    )
        internal
        returns (uint256 underlyingTokenBalance)
    {
        IYVault vault = IYVault(yToken);
        address underlyingToken = vault.token();

        underlyingTokenBalance = underlyingToken.getBalance(account);

        console2.log("underlyingTokenBalance: %s", underlyingTokenBalance);

        ExecutorAction[] memory approveAndDeposit = new ExecutorAction[](2);
        approveAndDeposit[0] =
            ERC20ModuleKit.approveAction(IERC20(underlyingToken), address(vault), amount);
        approveAndDeposit[1] = _depositAction(address(vault), amount, account);
        ExecutorTransaction memory transaction =
            ExecutorTransaction({ actions: approveAndDeposit, nonce: 0, metadataHash: "" });

        bytes[] memory ret = manager.executeTransaction(account, transaction);
        require(ret.length == 2, "YearnDeposit: deposit failed");
        underlyingTokenBalance = underlyingTokenBalance - underlyingToken.getBalance(account);
        require(underlyingTokenBalance == amount, "YearnDeposit: deposit failed");
    }
}
