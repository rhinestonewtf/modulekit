// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { ERC7579ExecutorBase, SessionKeyBase } from "modulekit/src/Modules.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";

contract AutoSendSessionKey is ERC7579ExecutorBase, SessionKeyBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct ExecutorAccess {
        address sessionKeySigner;
        address token;
        address receiver;
    }

    struct SpentLog {
        uint128 spent;
        uint128 maxAmount;
    }

    struct Params {
        address token;
        address receiver;
        uint128 amount;
    }

    mapping(address account => mapping(address token => SpentLog)) internal _log;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function encode(ExecutorAccess memory transaction) public pure returns (bytes memory) {
        return abi.encode(transaction);
    }

    function getSpentLog(address account, address token) public view returns (SpentLog memory) {
        return _log[account][token];
    }

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

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function autoSend(Params calldata params) external {
        IERC7579Account smartAccount = IERC7579Account(msg.sender);

        SpentLog storage log = _log[msg.sender][params.token];

        uint128 newSpent = log.spent + params.amount;
        if (newSpent > log.maxAmount) {
            revert InvalidAmount();
        }
        log.spent = newSpent;

        smartAccount.executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(
                params.token, 0, abi.encodeCall(IERC20.transfer, (params.receiver, params.amount))
            )
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
        returns (address)
    {
        ExecutorAccess memory access = abi.decode(_sessionKeyData, (ExecutorAccess));

        bytes4 targetSelector = bytes4(callData[:4]);
        Params memory params = abi.decode(callData[4:], (Params));
        if (targetSelector != this.autoSend.selector) {
            revert InvalidMethod(targetSelector);
        }

        if (params.receiver != access.receiver) {
            revert InvalidRecipient();
        }

        if (destinationContract != address(this)) {
            revert InvalidTarget();
        }

        if (params.token != access.token) {
            revert InvalidTarget();
        }

        if (callValue != 0) {
            revert InvalidValue();
        }

        return access.sessionKeySigner;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function name() external pure virtual returns (string memory) {
        return "AutoSend";
    }

    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }
}
