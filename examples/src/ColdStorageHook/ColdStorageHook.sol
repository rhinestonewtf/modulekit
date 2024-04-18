// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { ERC7579HookDestruct, Execution } from "modulekit/src/modules/ERC7579HookDestruct.sol";

contract ColdStorageHook is ERC7579HookDestruct {
    using EnumerableMap for EnumerableMap.Bytes32ToBytes32Map;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidOwner();
    error InvalidWaitPeriod();
    error InvalidTransferReceiver();
    error UnsupportedExecution();
    error UnauthorizedAccess();
    error InvalidExecutionHash(bytes32 executionHash);

    bytes32 internal constant PASS = keccak256("pass");

    struct VaultConfig {
        uint128 waitPeriod;
        address owner;
    }

    mapping(address subAccount => VaultConfig) public vaultConfig;
    mapping(address subAccount => EnumerableMap.Bytes32ToBytes32Map) executions;

    event ExecutionRequested(
        address indexed subAccount,
        address target,
        uint256 value,
        bytes callData,
        uint256 executeAfter
    );

    event ExecutionExecuted(
        address indexed subAccount, address target, uint256 value, bytes callData
    );

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        uint128 waitPeriod = uint128(bytes16(data[0:16]));
        address owner = address(bytes20(data[16:36]));

        if (waitPeriod == 0) revert InvalidWaitPeriod();
        if (owner == address(0)) revert InvalidOwner();

        VaultConfig storage _config = vaultConfig[account];
        _config.waitPeriod = waitPeriod;
        _config.owner = owner;
    }

    function onUninstall(bytes calldata data) external override {
        address account = msg.sender;

        delete vaultConfig[account].waitPeriod;
        delete vaultConfig[account].owner;
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return vaultConfig[smartAccount].owner != address(0);
    }

    function setWaitPeriod(uint256 waitPeriod) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        if (waitPeriod == 0) revert InvalidWaitPeriod();

        vaultConfig[account].waitPeriod = uint128(waitPeriod);
    }

    function checkHash(
        address account,
        Execution calldata exec
    )
        external
        view
        returns (bytes32 executionHash, bytes32 entry)
    {
        executionHash = _execDigestMemory(exec.target, exec.value, exec.callData);

        bool success;
        (success, entry) = executions[account].tryGet(executionHash);
    }

    function getExecution(
        address account,
        bytes32 executionHash
    )
        external
        view
        returns (bytes32 entry)
    {
        bool success;
        (success, entry) = executions[account].tryGet(executionHash);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Function that must be triggered from subaccount.
     * requests an execution to happen in the future
     */
    function requestTimelockedExecution(
        Execution calldata _exec,
        uint256 additionalWait
    )
        external
    {
        VaultConfig memory _config = vaultConfig[msg.sender];
        bytes32 executionHash = _execDigest(_exec.target, _exec.value, _exec.callData);

        if (_exec.callData.length != 0) {
            // check that transaction is only a token transfer
            address tokenReceiver = _getTokenTxReceiver(_exec.callData);
            if (tokenReceiver != _config.owner) {
                // Else check that transaction is to setWaitPeriod
                if (bytes4(_exec.callData[0:4]) != this.setWaitPeriod.selector) {
                    revert InvalidTransferReceiver();
                }
            }
        } else {
            if (_exec.target != _config.owner) revert InvalidTransferReceiver();
        }

        uint256 executeAfter = uint256(block.timestamp + _config.waitPeriod + additionalWait);

        // write executionHash to storage
        executions[msg.sender].set(executionHash, bytes32(executeAfter));

        emit ExecutionRequested(msg.sender, _exec.target, _exec.value, _exec.callData, executeAfter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _execDigest(
        address to,
        uint256 value,
        bytes calldata callData
    )
        internal
        pure
        returns (bytes32)
    {
        bytes memory _callData = callData;
        return _execDigestMemory(to, value, _callData);
    }

    function _execDigestMemory(
        address to,
        uint256 value,
        bytes memory callData
    )
        internal
        pure
        returns (bytes32 digest)
    {
        digest = keccak256(abi.encodePacked(to, value, callData));
    }

    function _getTokenTxReceiver(bytes calldata callData)
        internal
        pure
        returns (address receiver)
    {
        bytes4 functionSig = bytes4(callData[0:4]);
        bytes calldata params = callData[4:];
        if (functionSig == IERC20.transfer.selector) {
            (receiver,) = abi.decode(params, (address, uint256));
        } else if (functionSig == IERC20.transferFrom.selector) {
            (, receiver,) = abi.decode(params, (address, address, uint256));
        } else if (functionSig == IERC721.transferFrom.selector) {
            (, receiver,) = abi.decode(params, (address, address, uint256));
        }
    }

    function onPostCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        internal
        virtual
        override
    {
        if (
            keccak256(hookData) != keccak256(abi.encode(this.requestTimelockedExecution.selector))
                && keccak256(hookData) != keccak256(abi.encode(PASS))
        ) {
            revert UnauthorizedAccess();
        }
    }

    function onExecute(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        revert UnsupportedExecution();
    }

    function onExecuteBatch(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        revert UnsupportedExecution();
    }

    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        bytes4 functionSig;

        if (callData.length >= 4) {
            functionSig = bytes4(callData[0:4]);
        }

        // check if call is a requestTimelockedExecution
        if (target == address(this) && functionSig == this.requestTimelockedExecution.selector) {
            return abi.encode(this.requestTimelockedExecution.selector);
        } else {
            bytes32 executionHash = _execDigestMemory(target, value, callData);
            (bool success, bytes32 entry) = executions[msg.sender].tryGet(executionHash);

            if (!success) revert InvalidExecutionHash(executionHash);

            uint256 requestTimeStamp = uint256(entry);
            if (requestTimeStamp > block.timestamp) revert UnauthorizedAccess();

            emit ExecutionExecuted(msg.sender, target, value, callData);

            return abi.encode(PASS);
        }
    }

    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        revert UnsupportedExecution();
    }

    function onInstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        revert UnsupportedExecution();
    }

    function onUninstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        revert UnsupportedExecution();
    }

    function onUnknownFunction(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        revert UnsupportedExecution();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "ColdStorageHook";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_HOOK;
    }
}
