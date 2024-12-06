// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IERC7579Account } from "./IERC7579Account.sol";
import { ISafeOp } from "./ISafeOp.sol";

// Types
import "../types/DataTypes.sol";
import { ModeCode } from "../../common/lib/ModeLib.sol";
import { PackedUserOperation } from
    "@ERC4337/account-abstraction/contracts/core/UserOperationLib.sol";

/**
 * @title ERC7579 Adapter for Safe accounts.
 * creates full ERC7579 compliance to Safe accounts
 * @author rhinestone | zeroknots.eth, Konrad Kopp (@kopy-kat)
 */
interface ISafe7579 is IERC7579Account, ISafeOp {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Validation                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * ERC4337 v0.7 validation function
     * @dev expects that a ERC7579 validator module is encoded within the UserOp nonce.
     *         if no validator module is provided, it will fallback to validate the transaction with
     *         Safe's signers
     */
    function validateUserOp(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        returns (uint256 packedValidSig);

    /**
     * Will use Safe's signed messages or checkSignatures features or ERC7579 validation modules
     * if no signature is provided, it makes use of Safe's signedMessages
     * if address(0) or a non-installed validator module is provided, it will use Safe's
     * checkSignatures
     * if a valid validator module is provided, it will use the module's validateUserOp function
     *    @param hash message hash of ERC1271 request
     *    @param data abi.encodePacked(address validationModule, bytes signatures)
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory data
    )
        external
        view
        returns (bytes4 magicValue);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Executions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Executes a transaction on behalf of the Safe account.
     *         This function is intended to be called by ERC-4337 EntryPoint.sol
     * @dev If a global hook and/or selector hook is set, it will be called
     * @dev AccessControl: only Self of Entrypoint can install modules
     * Safe7579 supports the following feature set:
     *    CallTypes:
     *             - CALLTYPE_SINGLE
     *             - CALLTYPE_BATCH
     *             - CALLTYPE_DELEGATECALL
     *    ExecTypes:
     *             - EXECTYPE_DEFAULT (revert if not successful)
     *             - EXECTYPE_TRY
     *    If a different mode is selected, this function will revert
     * @param mode The encoded execution mode of the transaction. See ModeLib.sol for details
     * @param executionCalldata The encoded execution call data
     */
    function execute(ModeCode mode, bytes memory executionCalldata) external;

    /**
     * @dev Executes a transaction on behalf of the Safe account.
     *         This function is intended to be called by executor modules
     * @dev If a global hook and/or selector hook is set, it will be called
     * @dev AccessControl: only enabled executor modules
     * Safe7579 supports the following feature set:
     *    CallTypes:
     *             - CALLTYPE_SINGLE
     *             - CALLTYPE_BATCH
     *             - CALLTYPE_DELEGATECALL
     *    ExecTypes:
     *             - EXECTYPE_DEFAULT (revert if not successful)
     *             - EXECTYPE_TRY
     *    If a different mode is selected, this function will revert
     * @param mode The encoded execution mode of the transaction. See ModeLib.sol for details
     * @param executionCalldata The encoded execution call data
     */
    function executeFromExecutor(
        ModeCode mode,
        bytes memory executionCalldata
    )
        external
        returns (bytes[] memory returnDatas);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Manage Modules                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Installs a 7579 Module of a certain type on the smart account
     * @dev The module has to be initialized from msg.sender == SafeProxy, we thus use a
     *    delegatecall to DCUtil, which calls the onInstall/onUninstall function on the ERC7579
     *    module and emits the ModuleInstall/ModuleUnintall events
     * @dev AccessControl: only Self of Entrypoint can install modules
     * @dev If the safe set a registry, ERC7484 registry will be queried before installing
     * @dev If a global hook and/or selector hook is set, it will be called
     * @param moduleType the module type ID according the ERC-7579 spec
     *                   Note: MULTITYPE_MODULE (uint(0)) is a special type to install a module with
     *                         multiple types
     * @param module the module address
     * @param initData arbitrary data that may be required on the module during `onInstall`
     * initialization.
     */
    function installModule(uint256 moduleType, address module, bytes memory initData) external;

    /**
     * Uninstalls a Module of a certain type on the smart account.
     * @dev The module has to be initialized from msg.sender == SafeProxy, we thus use a
     *    delegatecall to DCUtil, which calls the onInstall/onUninstall function on the ERC7579
     *    module and emits the ModuleInstall/ModuleUnintall events
     * @dev AccessControl: only Self of Entrypoint can install modules
     * @dev If a global hook and/or selector hook is set, it will be called
     * @param moduleType the module type ID according the ERC-7579 spec
     * @param module the module address
     * @param deInitData arbitrary data that may be required on the module during `onUninstall`
     * de-initialization.
     */
    function uninstallModule(
        uint256 moduleType,
        address module,
        bytes memory deInitData
    )
        external;

    /**
     * Function to check if the account has a certain module installed
     * @param moduleType the module type ID according the ERC-7579 spec
     *      Note: keep in mind that some contracts can be multiple module types at the same time. It
     *            thus may be necessary to query multiple module types
     * @param module the module address
     * @param additionalContext additional context data that the smart account may interpret to
     *                          identifiy conditions under which the module is installed.
     *                          usually this is not necessary, but for some special hooks that
     *                          are stored in mappings, this param might be needed
     */
    function isModuleInstalled(
        uint256 moduleType,
        address module,
        bytes memory additionalContext
    )
        external
        view
        returns (bool);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   Initialize Safe7579                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * This function can be called by the Launchpad.initSafe7579() or by already existing Safes that
     * want to use Safe7579
     * if this is called by the Launchpad, it is expected that launchpadValidators() was called
     * previously, and the param validators is empty
     * @param validators validator modules and initData
     * @param executors executor modules and initData
     * @param executors executor modules and initData
     * @param fallbacks fallback modules and initData
     * @param hooks hook module and initData
     * @param registryInit (OPTIONAL) registry, attesters and threshold for IERC7484 Registry
     *                    If not provided, the registry will be set to the zero address, and no
     *                    registry checks will be performed
     */
    function initializeAccount(
        ModuleInit[] memory validators,
        ModuleInit[] memory executors,
        ModuleInit[] memory fallbacks,
        ModuleInit[] memory hooks,
        RegistryInit memory registryInit
    )
        external;

    /**
     * This function is intended to be called by Launchpad.validateUserOp()
     * @dev it will initialize the SentinelList4337 list for validators, and sstore all
     * validators
     * @dev Since this function has to be 4337 compliant (storage access), only validator storage is  acccess
     * @dev Note: this function DOES NOT call onInstall() on the validator modules or emit
     * ModuleInstalled events. this has to be done by the launchpad
     */
    function initializeAccountWithValidators(ModuleInit[] memory validators) external;

    /**
     * Configure the Safe7579 with a IERC7484 registry
     * @param registry IERC7484 registry
     * @param attesters list of attesters
     * @param threshold number of attesters required
     */
    function setRegistry(IERC7484 registry, address[] memory attesters, uint8 threshold) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   Query Account Details                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function getValidatorsPaginated(
        address cursor,
        uint256 pageSize
    )
        external
        view
        returns (address[] memory array, address next);

    /**
     * Get the current active global hook
     */
    function getActiveHook() external view returns (address hook);

    /**
     * Get the current active selector hook
     */
    function getActiveHook(bytes4 selector) external view returns (address hook);

    function getExecutorsPaginated(
        address cursor,
        uint256 size
    )
        external
        view
        returns (address[] memory array, address next);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Query Misc                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Safe7579 is using validator selection encoding in the userop nonce.
     * to make it easier for SDKs / devs to integrate, this function can be
     * called to get the next nonce for a specific validator
     * @param safe address of safe account
     * @param validator ERC7579 validator to encode
     */
    function getNonce(address safe, address validator) external view returns (uint256 nonce);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Custom Errors                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error InvalidModule(address module);
    error InvalidModuleType(address module, uint256 moduleType);

    // fallback handlers
    error InvalidInput();
    error InvalidCallType(CallType callType);
    error NoFallbackHandler(bytes4 msgSig);
    error InvalidFallbackHandler(bytes4 msgSig);
    error FallbackInstalled(bytes4 msgSig);

    // Hooks
    error HookAlreadyInstalled(address currentHook);
    error InvalidHookType();

    // Registry Adapter
    event ERC7484RegistryConfigured(address indexed smartAccount, IERC7484 indexed registry);
}
