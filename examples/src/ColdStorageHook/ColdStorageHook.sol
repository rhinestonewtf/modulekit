// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { ERC7579HookDestruct, Execution } from "modulekit/src/modules/ERC7579HookDestruct.sol";
import { IERC3156FlashLender } from "modulekit/src/interfaces/Flashloan.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import {
    FlashLoanType,
    IERC3156FlashBorrower,
    IERC3156FlashLender
} from "modulekit/src/interfaces/Flashloan.sol";
import { FlashloanLender } from "../Flashloan/FlashloanLender.sol";

/**
 * @title ColdStorageHook
 * @dev Module that allows user to lock down a subaccount and only transfer assets
 * after a certain time period has passed
 * @author Rhinestone
 */
contract ColdStorageHook is ERC7579HookDestruct, FlashloanLender {
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

    event TimelockRequested(address indexed subAccount, bytes32 hash, uint256 executeAfter);

    event TimelockExecuted(address indexed subAccount, bytes32 hash);

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

        // bool isInitialized = isInitialized(account);
        // check if the module is already initialized if data is not empty, revert. If data is
        // empty, skip
        if (isInitialized(account)) {
            if (data.length == 0) return;
            else revert AlreadyInitialized(account);
        }

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

        // clear the trusted forwarder
        clearTrustedForwarder();
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
     * Gets the executeAfter timestamp for a given execution hash
     * @dev if the hash is not found, the function will not revert but executeAfter will be
     * 0
     *
     * @param account address of the subaccount
     * @param hash bytes32 hash of the execution
     *
     * @return executeAfter bytes32 timestamp after which the execution can be executed
     */
    function checkHash(
        address account,
        bytes32 hash
    )
        external
        view
        returns (bytes32 executeAfter)
    {
        // get the executeAfter timestamp
        bool success;
        (success, executeAfter) = executions[account].tryGet(hash);
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
        bytes memory callData = _exec.callData;
        // get the execution hash
        bytes32 executionHash = _execDigest(_exec.target, _exec.value, callData);

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

        // revert if executeAfter is not in the future
        if (executeAfter == block.timestamp) {
            revert InvalidWaitPeriod();
        }

        // write executionHash to storage
        executions[msg.sender].set(executionHash, bytes32(executeAfter));

        // emit the TimelockRequested event
        emit TimelockRequested(msg.sender, executionHash, executeAfter);
    }

    /**
     * Requests the execution of a transaction after a certain time period
     * @dev the function will revert if the transaction is not a transfer to the owner or a call to
     * setWaitPeriod
     *
     * @param moduleTypeId type of the module
     * @param module address of the module
     * @param data data to be passed to the module
     * @param isInstall true if the module is being installed, false if it is being uninstalled
     * @param additionalWait additional time to wait before executing the transaction, on top of the
     */
    function requestTimelockedModuleConfig(
        uint256 moduleTypeId,
        address module,
        bytes calldata data,
        bool isInstall,
        uint256 additionalWait
    )
        external
    {
        // get the vault config
        VaultConfig memory _config = vaultConfig[msg.sender];

        // get the execution hash
        bytes32 executionHash = _moduleDigest(moduleTypeId, module, data, isInstall);

        // calculate the time after which the transaction can be executed
        uint256 executeAfter = uint256(block.timestamp + _config.waitPeriod + additionalWait);

        // revert if executeAfter is not in the future
        if (executeAfter == block.timestamp) {
            revert InvalidWaitPeriod();
        }

        // write executionHash to storage
        executions[msg.sender].set(executionHash, bytes32(executeAfter));

        // emit the TimelockRequested event
        emit TimelockRequested(msg.sender, executionHash, executeAfter);
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
     * Gets the digest hash for a module configuration
     *
     * @param moduleTypeId type of the module
     * @param module address of the module
     * @param data data to be passed to the module
     * @param isInstall true if the module is being installed, false if it is being uninstalled
     *
     * @return digest bytes32 hash
     */
    function _moduleDigest(
        uint256 moduleTypeId,
        address module,
        bytes calldata data,
        bool isInstall
    )
        internal
        pure
        returns (bytes32 digest)
    {
        // get the relevant function selector
        // the function selector is used here so that the hash is unique to installing a module
        bytes4 selector;
        if (isInstall == true) {
            selector = IERC7579Account.installModule.selector;
        } else {
            selector = IERC7579Account.uninstallModule.selector;
        }

        // hash the arguments
        digest = keccak256(abi.encodePacked(selector, moduleTypeId, module, data));
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
     * Checks if the transaction can be executed
     * @dev the function will revert if the transaction is not allowed to be executed
     *
     * @param executionHash bytes32 hash of the execution
     */
    function _checkTimelockedExecution(address account, bytes32 executionHash) internal view {
        // get the executeAfter timestamp
        (bool success, bytes32 executeAfter) = executions[account].tryGet(executionHash);

        // if the executionHash is not found, revert
        if (!success) revert InvalidExecutionHash(executionHash);

        // determine if the transaction can be executed and revert if not
        uint256 requestTimeStamp = uint256(executeAfter);
        if (requestTimeStamp > block.timestamp) revert UnauthorizedAccess();
    }

    /**
     * Execute function was called on the account
     * @dev this function will revert as the module does not allow direct execution
     */
    function onExecute(
        address,
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
        address account,
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
        // get the function signature
        bytes4 functionSig;
        if (callData.length >= 4) {
            functionSig = bytes4(callData[0:4]);
        }

        // This condition is true, if this coldstorage hook is making executions.
        if (msgSender == address(this)) {
            if (
                functionSig == IERC20.transfer.selector
                    || functionSig == IERC721.transferFrom.selector
                    || functionSig == IERC3156FlashBorrower.onFlashLoan.selector
            ) {
                return "";
            }
        }
        if (
            target == address(this)
                && (
                    functionSig == this.requestTimelockedExecution.selector
                        || functionSig == this.requestTimelockedModuleConfig.selector
                )
        ) {
            // allow requestTimelockedExecution and requestTimelockedModuleConfig
            return "";
        } else {
            // get the execution hash
            bytes32 executionHash = _execDigest(target, value, callData);

            // check the timelocked execution
            _checkTimelockedExecution(account, executionHash);

            // emit the TimelockExecuted event
            emit TimelockExecuted(account, executionHash);

            return "";
        }
    }

    /**
     * ExecuteBatch from executor function was called on the account
     * @dev this function will revert as the module does not allow batched executions from executor
     */
    function onExecuteBatchFromExecutor(
        address,
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
     * @dev install module calls need to be timelocked
     *
     * @param moduleTypeId type of the module
     * @param module address of the module
     * @param initData data to be passed to the module
     */
    function onInstallModule(
        address account,
        address,
        uint256 moduleTypeId,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        // get the execution hash
        bytes32 executionHash = _moduleDigest(moduleTypeId, module, initData, true);

        // check the timelocked execution
        _checkTimelockedExecution(account, executionHash);

        // emit the TimelockExecuted event
        emit TimelockExecuted(account, executionHash);
    }

    /**
     * UninstallModule function was called on the account
     * @dev install module calls need to be timelocked
     *
     * @param moduleTypeId type of the module
     * @param module address of the module
     * @param deInitData data to be passed to the module
     */
    function onUninstallModule(
        address account,
        address,
        uint256 moduleTypeId,
        address module,
        bytes calldata deInitData
    )
        internal
        virtual
        override
        returns (bytes memory)
    {
        // get the execution hash
        bytes32 executionHash = _moduleDigest(moduleTypeId, module, deInitData, false);

        // check the timelocked execution
        _checkTimelockedExecution(account, executionHash);

        // emit the TimelockExecuted event
        emit TimelockExecuted(account, executionHash);
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
        address account,
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
        VaultConfig memory _config = vaultConfig[account];

        if (callData.length >= 4 && msgSender == _config.owner) {
            // if the sender is the owner, check if the function is a flashloan function
            bytes4 functionSig = bytes4(callData[0:4]);

            if (
                functionSig == IERC3156FlashLender.maxFlashLoan.selector
                    || functionSig == IERC3156FlashLender.flashFee.selector
                    || functionSig == IERC3156FlashLender.flashLoan.selector
            ) {
                // return
                return "";
            }
        }

        // otherwise revert
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
    function isModuleType(uint256 typeID) external pure virtual returns (bool) {
        if (typeID == TYPE_EXECUTOR || typeID == TYPE_HOOK || typeID == TYPE_FALLBACK) {
            return true;
        }
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

    function maxFlashLoan(address token) external view override returns (uint256) { }

    function flashFee(address token, uint256 amount) external view override returns (uint256) { }

    function flashFeeToken() external view virtual override returns (address) { }

    function _isAllowedBorrower(address account) internal view virtual override returns (bool) {
        return account == vaultConfig[msg.sender].owner;
    }
}
