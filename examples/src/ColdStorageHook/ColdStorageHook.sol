// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { ERC7579HookDestruct, Execution } from "modulekit/src/modules/ERC7579HookDestruct.sol";
import { IERC3156FlashLender } from "modulekit/src/interfaces/Flashloan.sol";

/**
 * @title ColdStorageHook
 * @dev Module that allows user to lock down a subaccount and only transfer assets
 * after a certain time period has passed
 * @author Rhinestone
 */
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

    // account => VaultConfig
    mapping(address subAccount => VaultConfig) public vaultConfig;
    // account => executionHash => executeAfter
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

    /**
     * Initializes the module with the waitPeriod and owner
     * @dev data is encoded as follows: abi.encodePacked(waitPeriod, owner)
     * @dev if the owner is address(0) or waitPeriod is 0, the function will revert
     *
     * @param data encoded data containing the waitPeriod and owner
     */
    function onInstall(bytes calldata data) external override {
        // cache the account address
        address account = msg.sender;
        // check if the module is already initialized and revert if it is
        if (isInitialized(account)) revert AlreadyInitialized(account);

        // decode the data to get the waitPeriod and owner
        uint128 waitPeriod = uint128(bytes16(data[0:16]));
        address owner = address(bytes20(data[16:36]));

        // check if the owner is address(0) or waitPeriod is 0 and revert
        if (waitPeriod == 0) revert InvalidWaitPeriod();
        if (owner == address(0)) revert InvalidOwner();

        // set the waitPeriod and owner in the vaultConfig
        VaultConfig storage _config = vaultConfig[account];
        _config.waitPeriod = waitPeriod;
        _config.owner = owner;
    }

    /**
     * Handles the uninstallation of the module and clears the vaultConfig
     * @dev the data parameter is not used
     */
    function onUninstall(bytes calldata) external override {
        // cache the account address
        address account = msg.sender;

        // clear the vaultConfig
        delete vaultConfig[account];

        // TODO: clear the executions
    }

    /**
     * Checks if the module is initialized
     *
     * @param smartAccount address of the smart account
     *
     * @return bool true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        return vaultConfig[smartAccount].owner != address(0);
    }

    /**
     * Sets the wait period for the subaccount
     *
     * @param waitPeriod the time in seconds to wait before executing a transaction
     */
    function setWaitPeriod(uint256 waitPeriod) external {
        // cache the account address
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        // check if the waitPeriod is 0 and revert if it is
        if (waitPeriod == 0) revert InvalidWaitPeriod();

        // set the waitPeriod in the vaultConfig
        vaultConfig[account].waitPeriod = uint128(waitPeriod);
    }

    /**
     * Gets the execution hash and executeAfter timestamp for a given execution
     * @dev if the executionHash is not found, the function will not revert but executeAfter will be
     * 0
     *
     * @param account address of the subaccount
     * @param exec Execution struct containing the target, value, and callData
     *
     * @return executionHash bytes32 hash of the execution
     * @return executeAfter bytes32 timestamp after which the execution can be executed
     */
    function checkHash(
        address account,
        Execution calldata exec
    )
        external
        view
        returns (bytes32 executionHash, bytes32 executeAfter)
    {
        // get the executionHash
        executionHash = _execDigestMemory(exec.target, exec.value, exec.callData);

        // get the executeAfter timestamp
        bool success;
        (success, executeAfter) = executions[account].tryGet(executionHash);
    }

    /**
     * Gets the executeAfter timestamp for a given execution hash
     * @dev if the executionHash is not found, the function will not revert but executeAfter will be
     * 0
     *
     * @param account address of the subaccount
     * @param executionHash bytes32 hash of the execution
     *
     * @return executeAfter bytes32 timestamp after which the execution can be executed
     */
    function getExecution(
        address account,
        bytes32 executionHash
    )
        external
        view
        returns (bytes32 executeAfter)
    {
        // get the executeAfter timestamp
        bool success;
        (success, executeAfter) = executions[account].tryGet(executionHash);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Requests the execution of a transaction after a certain time period
     * @dev the function will revert if the transaction is not a transfer to the owner or a call to
     * setWaitPeriod
     *
     * @param _exec Execution struct containing the target, value, and callData
     * @param additionalWait additional time to wait before executing the transaction, on top of the
     * waitPeriod
     */
    function requestTimelockedExecution(
        Execution calldata _exec,
        uint256 additionalWait
    )
        external
    {
        // get the vault config
        VaultConfig memory _config = vaultConfig[msg.sender];
        // get the execution hash
        bytes32 executionHash = _execDigest(_exec.target, _exec.value, _exec.callData);

        if (_exec.callData.length != 0) {
            // check that transaction is only a token transfer
            address tokenReceiver = _getTokenTxReceiver(_exec.callData);

            // if tokenReceiver is the owner, continue
            if (tokenReceiver != _config.owner) {
                // Else check that transaction is to setWaitPeriod
                if (bytes4(_exec.callData[0:4]) != this.setWaitPeriod.selector) {
                    // if not, revert
                    revert InvalidTransferReceiver();
                }
            }
        } else {
            // check that the transaction is a native token transfer to the owner
            if (_exec.target != _config.owner) revert InvalidTransferReceiver();
        }

        // calculate the time after which the transaction can be executed
        uint256 executeAfter = uint256(block.timestamp + _config.waitPeriod + additionalWait);

        // write executionHash to storage
        executions[msg.sender].set(executionHash, bytes32(executeAfter));

        // emit the ExecutionRequested event
        emit ExecutionRequested(msg.sender, _exec.target, _exec.value, _exec.callData, executeAfter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Gets the digest hash of the target, value, and callData
     *
     * @param to address of the target
     * @param value value to be sent
     * @param callData data to be sent
     *
     * @return digest bytes32 hash of the target, value, and callData
     */
    function _execDigest(
        address to,
        uint256 value,
        bytes calldata callData
    )
        internal
        pure
        returns (bytes32)
    {
        // load the calldata into memory
        bytes memory _callData = callData;
        // get the digest hash
        return _execDigestMemory(to, value, _callData);
    }

    /**
     * Gets the digest hash of the target, value, and callData
     *
     * @param to address of the target
     * @param value value to be sent
     * @param callData data to be sent
     *
     * @return digest bytes32 hash of the target, value, and callData
     */
    function _execDigestMemory(
        address to,
        uint256 value,
        bytes memory callData
    )
        internal
        pure
        returns (bytes32 digest)
    {
        // hash the arguments
        digest = keccak256(abi.encodePacked(to, value, callData));
    }

    /**
     * Gets the receiver of the token transfer
     * @dev if the function is not a token transfer, the receiver will be address(0)
     *
     * @param callData data to be sent
     *
     * @return receiver address of the receiver
     */
    function _getTokenTxReceiver(bytes calldata callData)
        internal
        pure
        returns (address receiver)
    {
        // get the function signature
        bytes4 functionSig = bytes4(callData[0:4]);
        // get the parameters
        bytes calldata params = callData[4:];

        if (functionSig == IERC20.transfer.selector) {
            // decode the erc20 transfer receiver
            (receiver,) = abi.decode(params, (address, uint256));
        } else if (functionSig == IERC20.transferFrom.selector) {
            // decode the erc20 transferFrom receiver
            (, receiver,) = abi.decode(params, (address, address, uint256));
        } else if (functionSig == IERC721.transferFrom.selector) {
            // decode the erc721 transferFrom receiver
            (, receiver,) = abi.decode(params, (address, address, uint256));
        }
    }

    /**
     * Post check hook function to determine if the execution should be allowed
     *
     * @param hookData data passed from the hook to the account during pre-check
     */
    function onPostCheck(bytes calldata hookData, bool, bytes calldata) internal virtual override {
        if (
            keccak256(hookData) != keccak256(abi.encode(this.requestTimelockedExecution.selector))
                && keccak256(hookData) != keccak256(abi.encode(PASS))
        ) {
            revert UnauthorizedAccess();
        }
    }

    /**
     * Execute function was called on the account
     * @dev this function will revert as the module does not allow direct execution
     */
    function onExecute(
        address,
        address,
        uint256,
        bytes calldata
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        revert UnsupportedExecution();
    }

    /**
     * ExecuteBatch function was called on the account
     * @dev this function will revert as the module does not allow direct execution
     */
    function onExecuteBatch(
        address,
        Execution[] calldata
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        revert UnsupportedExecution();
    }

    /**
     * Execute from executor function was called on the account
     * @dev this function will revert as the module does not allow direct execution
     *
     * @param target address of the target
     * @param value value to be sent by account
     * @param callData data to be sent by account
     */
    function onExecuteFromExecutor(
        address,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        // get the function signature
        bytes4 functionSig;
        if (callData.length >= 4) {
            functionSig = bytes4(callData[0:4]);
        }

        if (target == address(this) && functionSig == this.requestTimelockedExecution.selector) {
            // if the function is requestTimelockedExecution, return the function selector
            return abi.encode(this.requestTimelockedExecution.selector);
        } else {
            // get the execution hash
            bytes32 executionHash = _execDigestMemory(target, value, callData);
            // get the executeAfter timestamp
            (bool success, bytes32 executeAfter) = executions[msg.sender].tryGet(executionHash);

            // if the executionHash is not found, revert
            if (!success) revert InvalidExecutionHash(executionHash);

            // determine if the transaction can be executed and revert if not
            uint256 requestTimeStamp = uint256(executeAfter);
            if (requestTimeStamp > block.timestamp) revert UnauthorizedAccess();

            // emit the ExecutionExecuted event
            emit ExecutionExecuted(msg.sender, target, value, callData);

            // return pass
            return abi.encode(PASS);
        }
    }

    /**
     * ExecuteBatch from executor function was called on the account
     * @dev this function will revert as the module does not allow batched executions from executor
     */
    function onExecuteBatchFromExecutor(
        address,
        Execution[] calldata
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        revert UnsupportedExecution();
    }

    /**
     * InstallModule function was called on the account
     * @dev this function will revert as the module does not allow module installation
     */
    function onInstallModule(
        address,
        uint256,
        address,
        bytes calldata
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        revert UnsupportedExecution();
    }

    /**
     * UninstallModule function was called on the account
     * @dev this function will revert as the module does not allow module uninstallation
     */
    function onUninstallModule(
        address,
        uint256,
        address,
        bytes calldata
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        revert UnsupportedExecution();
    }

    /**
     * Unknown function was called on the account
     * @dev This function will revert except when used for flashloans
     *
     * @param msgSender address of the sender
     * @param callData data passed to the account
     *
     * @return bytes encoded data
     */
    function onUnknownFunction(
        address msgSender,
        uint256,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        // get the vault config
        VaultConfig memory _config = vaultConfig[msg.sender];

        if (callData.length >= 4 && msgSender == _config.owner) {
            // if the sender is the owner, check if the function is a flashloan function
            bytes4 functionSig = bytes4(callData[0:4]);

            if (
                functionSig == IERC3156FlashLender.maxFlashLoan.selector
                    || functionSig == IERC3156FlashLender.maxFlashLoan.selector
                    || functionSig == IERC3156FlashLender.maxFlashLoan.selector
            ) {
                // return pass
                return abi.encode(PASS);
            }
        }
        revert UnsupportedExecution();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/
    /**
     * Returns the type of the module
     *
     * @param typeID type of the module
     *
     * @return true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure virtual override returns (bool) {
        return typeID == TYPE_HOOK;
    }

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "ColdStorageHook";
    }

    /**
     * Returns the version of the module
     *
     * @return version of the module
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
