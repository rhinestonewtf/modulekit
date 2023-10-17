// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/yearn/IYVault.sol";
import "../ERC20Actions.sol";
import "../../IExecutor.sol";

/// @title YearnWithdraw
/// @author zeroknots

library YearnWithdraw {
    using ModuleExecLib for IExecutorManager;
    using ERC20ModuleKit for address;

    function _withdrawAction(
        address vault,
        uint256 amount
    )
        internal
        pure
        returns (ExecutorAction memory withdrawAction)
    {
        withdrawAction = ExecutorAction({
            to: payable(address(vault)),
            value: 0,
            data: abi.encodeWithSelector(IYVault.withdraw.selector, amount)
        });
    }

    function withdraw(
        IExecutorManager manager,
        address account,
        address yToken
    )
        internal
        returns (uint256 underlyingTokenBalance)
    {
        IYVault vault = IYVault(yToken);
        address underlyingToken = vault.token();

        underlyingTokenBalance = underlyingToken.getBalance(account);

        manager.exec({ account: account, action: _withdrawAction(yToken, underlyingTokenBalance) });

        underlyingTokenBalance = underlyingTokenBalance - underlyingToken.getBalance(account);
    }
}
