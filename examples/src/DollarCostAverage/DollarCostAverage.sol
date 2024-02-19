// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@rhinestone/sessionkeymanager/src/ISessionValidationModule.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { UniswapV3Integration } from "@rhinestone/modulekit/src/integrations/uniswap/v3/Uniswap.sol";
import { Execution, IERC7579Account } from "@rhinestone/modulekit/src/Accounts.sol";
import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { EncodedModuleTypes, ModuleTypeLib, ModuleType } from "erc7579/lib/ModuleTypeLib.sol";

contract DollarCostAverage is ERC7579ExecutorBase, ISessionValidationModule {
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

    error InvalidMethod(bytes4);
    error InvalidValue();
    error InvalidAmount();
    error InvalidTarget();
    error InvalidRecipient();
    error InvalidParams();

    mapping(address account => mapping(address token => SpentLog)) internal _log;

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

    function onInstall(bytes calldata data) external override {
        (address[] memory tokens, SpentLog[] memory log) = abi.decode(data, (address[], SpentLog[]));

        for (uint256 i; i < tokens.length; i++) {
            _log[msg.sender][tokens[i]] = log[i];
        }
    }

    function onUninstall(bytes calldata data) external override { }

    modifier onlyThis(address destinationContract) {
        if (destinationContract != address(this)) revert InvalidTarget();
        _;
    }

    modifier onlyFunctionSig(bytes4 allowed, bytes4 received) {
        if (allowed != received) revert InvalidMethod(received);
        _;
    }

    modifier onlyZeroValue(uint256 callValue) {
        if (callValue != 0) revert InvalidValue();
        _;
    }

    function encode(ScopedAccess memory transaction) public pure returns (bytes memory) {
        return abi.encode(transaction);
    }

    function getSpentLog(address account, address token) public view returns (SpentLog memory) {
        return _log[account][token];
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function getModuleTypes() external view returns (EncodedModuleTypes) { }

    function isInitialized(address smartAccount) external view returns (bool) { }

    function name() external pure virtual returns (string memory) {
        return "DollarCostAverage";
    }

    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }
}
