// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { UniswapV3Integration } from "modulekit/src/integrations/uniswap/v3/Uniswap.sol";
import { Execution, IERC7579Account } from "modulekit/src/Accounts.sol";
import { ERC7579ExecutorBase, SessionKeyBase } from "modulekit/src/Modules.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";

contract DollarCostAverage is ERC7579ExecutorBase, SessionKeyBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct ScopedAccess {
        address sessionKeySigner;
        address onlyTokenIn;
        address onlyTokenOut;
        uint256 maxAmount;
    }

    struct SpentLog {
        uint128 spent;
        uint128 maxAmount;
    }

    struct Params {
        address tokenIn;
        address tokenOut;
        uint128 amount;
    }

    error InvalidParams();

    mapping(address account => mapping(address token => SpentLog)) internal _log;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        (address[] memory tokens, SpentLog[] memory log) = abi.decode(data, (address[], SpentLog[]));

        for (uint256 i; i < tokens.length; i++) {
            _log[msg.sender][tokens[i]] = log[i];
        }
    }

    function onUninstall(bytes calldata data) external override {
        // Todo
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        // Todo
    }

    function encode(ScopedAccess memory transaction) public pure returns (bytes memory) {
        return abi.encode(transaction);
    }

    function getSpentLog(address account, address token) public view returns (SpentLog memory) {
        return _log[account][token];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function dca(Params calldata params) external {
        IERC7579Account smartAccount = IERC7579Account(msg.sender);

        Execution[] memory executions = UniswapV3Integration.approveAndSwap({
            smartAccount: msg.sender,
            tokenIn: IERC20(params.tokenIn),
            tokenOut: IERC20(params.tokenOut),
            amountIn: params.amount,
            sqrtPriceLimitX96: 0 // TODO fix this
         });

        _log[msg.sender][params.tokenIn].spent += params.amount;

        smartAccount.executeFromExecutor(
            ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions)
        );
    }

    function validateSessionParams(
        address destinationContract,
        uint256 callValue,
        bytes calldata callData,
        bytes calldata _sessionKeyData,
        bytes calldata /*_callSpecificData*/
    )
        public
        virtual
        override
        onlyFunctionSig(this.dca.selector, bytes4(callData[:4]))
        onlyZeroValue(callValue)
        onlyThis(destinationContract)
        returns (address)
    {
        ScopedAccess memory access = abi.decode(_sessionKeyData, (ScopedAccess));
        Params memory params = abi.decode(callData[4:], (Params));

        if (params.tokenIn != access.onlyTokenIn) revert InvalidParams();
        if (params.tokenOut != access.onlyTokenOut) revert InvalidParams();
        if (params.amount > access.maxAmount) revert InvalidParams();

        return access.sessionKeySigner;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function name() external pure virtual returns (string memory) {
        return "DollarCostAverage";
    }

    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }
}
