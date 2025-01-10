// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Factories
import { SafeFactory } from "../accounts/safe/SafeFactory.sol";
import { ERC7579Factory } from "../accounts/erc7579/ERC7579Factory.sol";
import { KernelFactory } from "../accounts/kernel/KernelFactory.sol";
import { NexusFactory } from "../accounts/nexus/NexusFactory.sol";

// Auxiliaries
import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";

// Helpers
import { HelperBase } from "./helpers/HelperBase.sol";
import { ERC7579Helpers } from "./helpers/ERC7579Helpers.sol";
import { SafeHelpers } from "./helpers/SafeHelpers.sol";
import { KernelHelpers } from "./helpers/KernelHelpers.sol";
import { NexusHelpers } from "./helpers/NexusHelpers.sol";
import { ModuleKitHelpers } from "./ModuleKitHelpers.sol";

// Interfaces
import { IAccountFactory } from "../accounts/factory/interface/IAccountFactory.sol";
import { PackedUserOperation, IStakeManager, IEntryPoint } from "../external/ERC4337.sol";
import { ISmartSession, ISessionValidator } from "../integrations/interfaces/ISmartSession.sol";
import { IValidator as IERC7579Validator } from "../accounts/common/interfaces/IERC7579Module.sol";

// Deployment
import { ENTRYPOINT_ADDR } from "../deployment/predeploy/EntryPoint.sol";
import { SMARTSESSION_ADDR } from "../deployment/precompiles/SmartSessionsPrecompiles.sol";

// Mocks
import { MockValidator, MockStatelessValidator } from "../Mocks.sol";

// Utils
import { envOr, prank, label, deal, toString } from "../test/utils/Vm.sol";
import { VmSafe } from "./utils/Vm.sol";
import {
    getAccountEnv,
    getHelper,
    getFactory,
    getAccountType,
    writeAccountEnv,
    writeFactory,
    writeHelper
} from "./utils/Storage.sol";

/*//////////////////////////////////////////////////////////////
                            CONSTANTS
//////////////////////////////////////////////////////////////*/

string constant DEFAULT = "DEFAULT";
string constant SAFE = "SAFE";
string constant KERNEL = "KERNEL";
string constant CUSTOM = "CUSTOM";
string constant NEXUS = "NEXUS";

/*//////////////////////////////////////////////////////////////
                            ENUMS
//////////////////////////////////////////////////////////////*/

/// @notice Currently supported account types
enum AccountType {
    DEFAULT,
    SAFE,
    KERNEL,
    CUSTOM,
    NEXUS
}

/*//////////////////////////////////////////////////////////////
                            STRUCTS
//////////////////////////////////////////////////////////////*/

/// @title AccountInstance
/// @notice A struct that contains all the necessary information for an account used during testing
/// @param account The address of the account
/// @param accountType The type of the account
/// @param accountHelper The address of the account helper
/// @param aux Auxiliary contracts
/// @param defaultValidator The default validator address
/// @param salt The salt used to create the account
/// @param initCode The init code used to create the account
/// @param accountFactory The address of the account factory
/// @param smartSession The address of the smart session contract
/// @param defaultSessionValidator The default session validator address
struct AccountInstance {
    address account;
    AccountType accountType;
    address accountHelper;
    Auxiliary aux;
    IERC7579Validator defaultValidator;
    bytes32 salt;
    bytes initCode;
    address accountFactory;
    ISmartSession smartSession;
    ISessionValidator defaultSessionValidator;
}

/// @title UserOpData
/// @param userOp The user operation
/// @param userOpHash The hash of the user operation
/// @param entrypoint The entrypoint contract
struct UserOpData {
    PackedUserOperation userOp;
    bytes32 userOpHash;
    IEntryPoint entrypoint;
}

/// @title ExecutionReturnData
/// @param logs Execution logs
struct ExecutionReturnData {
    VmSafe.Log[] logs;
}

/// @title RhinestoneModuleKit
/// @notice A development kit for building and testing smart account modules
contract RhinestoneModuleKit is AuxiliaryFactory {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The default validator used for testing
    MockValidator public _defaultValidator;
    /// @notice The default stateless validator used for testing smart sessions
    MockStatelessValidator public _defaultSessionValidator;
    /// @notice Whether the module kit has been initialized on a specific chain
    mapping(uint256 chainId => bool initialized) public isInit;

    /*//////////////////////////////////////////////////////////////
                                  INIT
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the module kit with the provided environment, deploy the factories,
    ///         helpers, and validators, and stake them on the entrypoint
    function _initializeModuleKit(string memory _env) internal {
        // Init
        super.init();
        isInit[block.chainid] = true;

        // Factories
        writeFactory(address(new ERC7579Factory()), DEFAULT);
        writeFactory(address(new SafeFactory()), SAFE);
        writeFactory(address(new KernelFactory()), KERNEL);
        writeFactory(address(new NexusFactory()), NEXUS);
        writeFactory(address(new ERC7579Factory()), CUSTOM);

        // Helpers
        writeHelper(address(new ERC7579Helpers()), DEFAULT);
        writeHelper(address(new SafeHelpers()), SAFE);
        writeHelper(address(new KernelHelpers()), KERNEL);
        writeHelper(address(new NexusHelpers()), NEXUS);
        writeHelper(address(new ERC7579Helpers()), CUSTOM);

        // Initialize factories
        IAccountFactory safeFactory = IAccountFactory(getFactory(SAFE));
        IAccountFactory kernelFactory = IAccountFactory(getFactory(KERNEL));
        IAccountFactory erc7579Factory = IAccountFactory(getFactory(DEFAULT));
        IAccountFactory nexusFactory = IAccountFactory(getFactory(NEXUS));
        IAccountFactory customFactory = IAccountFactory(getFactory(CUSTOM));
        safeFactory.init();
        kernelFactory.init();
        erc7579Factory.init();
        nexusFactory.init();
        customFactory.init();

        // Label factories
        label(address(safeFactory), "SafeFactory");
        label(address(kernelFactory), "KernelFactory");
        label(address(erc7579Factory), "ERC7579Factory");
        label(address(nexusFactory), "NexusFactory");
        label(address(customFactory), "CustomFactory");

        // Stake factory on EntryPoint
        deal(address(safeFactory), 10 ether);
        deal(address(kernelFactory), 10 ether);
        deal(address(erc7579Factory), 10 ether);
        deal(address(nexusFactory), 10 ether);
        deal(address(customFactory), 10 ether);

        // Stake on EntryPoint
        prank(address(safeFactory));
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
        prank(address(kernelFactory));
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
        prank(address(erc7579Factory));
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
        prank(address(nexusFactory));
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);

        // Set env
        ModuleKitHelpers.setAccountEnv(_env);

        // Set factory
        IAccountFactory accountFactory = IAccountFactory(getFactory(_env));
        label(address(accountFactory), "AccountFactory");

        // Set default validator
        _defaultValidator = new MockValidator();
        label(address(_defaultValidator), "DefaultValidator");

        // Set session validator
        _defaultSessionValidator = new MockStatelessValidator();
        label(address(_defaultSessionValidator), "SessionValidator");
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNT INSTANCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Create an account instance with the provided salt
    /// @param salt The salt used to create the account
    /// @return instance The account instance
    function makeAccountInstance(bytes32 salt)
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        (AccountType env, address accountFactoryAddress, address accountHelper) =
            ModuleKitHelpers.getAccountEnv();
        IAccountFactory accountFactory = IAccountFactory(accountFactoryAddress);
        bytes memory initData = accountFactory.getInitData(address(_defaultValidator), "");
        address account = accountFactory.getAddress(salt, initData);
        bytes memory initCode = abi.encodePacked(
            address(accountFactory), abi.encodeCall(accountFactory.createAccount, (salt, initData))
        );

        label(address(account), toString(salt));
        deal(account, 10 ether);
        instance = _makeAccountInstance({
            salt: salt,
            accountType: env,
            helper: accountHelper,
            account: account,
            initCode: initCode,
            validator: address(_defaultValidator),
            accountFactory: address(accountFactory),
            sessionValidator: address(_defaultSessionValidator)
        });
    }

    // @notice Create an account instance with the provided salt, account, and init code
    // @param salt The salt used to create the account
    // @param account The address of the account
    // @param initCode The init code used to create the account
    function makeAccountInstance(
        bytes32 salt,
        address account,
        bytes memory initCode
    )
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        address accountHelper = ModuleKitHelpers.getHelper(ModuleKitHelpers.getAccountType());
        instance = makeAccountInstance({
            salt: salt,
            helper: accountHelper,
            account: account,
            initCode: initCode
        });
    }

    /// @notice Create an account instance with the provided salt, account, init code, and helper.
    ///         Funds the account with 10 ether.
    /// @param salt The salt used to create the account
    /// @param account The address of the account
    /// @param initCode The init code used to create the account
    /// @param helper The address of the account helper
    /// @return instance The account instance
    function makeAccountInstance(
        bytes32 salt,
        address account,
        bytes memory initCode,
        address helper
    )
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        label(address(account), toString(salt));
        deal(account, 10 ether);

        address _factory;
        assembly {
            _factory := mload(add(initCode, 20))
        }

        AccountType env = ModuleKitHelpers.getAccountType();

        instance = _makeAccountInstance({
            salt: salt,
            accountType: env,
            helper: helper,
            account: account,
            initCode: initCode,
            validator: address(_defaultValidator),
            accountFactory: _factory,
            sessionValidator: address(_defaultSessionValidator)
        });

        ModuleKitHelpers.setAccountType(AccountType.CUSTOM);
    }

    /// @notice Create an account instance with the provided salt, account, init code, helper,
    /// default validator,
    ///         and default session validator. Funds the account with 10 ether.
    /// @param salt The salt used to create the account
    /// @param account The address of the account
    /// @param initCode The init code used to create the account
    /// @param helper The address of the account helper
    /// @param defaultValidator The address of the default validator
    /// @param defaultSessionValidator The address of the default session validator
    /// @return instance The account instance
    function makeAccountInstance(
        bytes32 salt,
        address account,
        bytes memory initCode,
        address helper,
        address defaultValidator,
        address defaultSessionValidator
    )
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        label(address(account), toString(salt));
        deal(account, 10 ether);

        address _factory;
        assembly {
            _factory := mload(add(initCode, 20))
        }

        AccountType env = instance.getAccountType();

        instance = _makeAccountInstance({
            salt: salt,
            accountType: env,
            helper: helper,
            account: account,
            initCode: initCode,
            validator: defaultValidator,
            accountFactory: _factory,
            sessionValidator: defaultSessionValidator
        });
        ModuleKitHelpers.setAccountType(AccountType.CUSTOM);
    }

    /// @notice Create an account instance with the provided salt, account, init code, account
    ///         factory, validator, session validator, account type, and helper
    /// @param salt The salt used to create the account
    /// @param account The address of the account
    /// @param initCode The init code used to create the account
    /// @param accountFactory The address of the account factory
    /// @param validator The address of the validator
    /// @param sessionValidator The address of the session validator
    /// @param accountType The type of the account
    /// @param helper The address of the account helper
    /// @return instance The account instance
    function _makeAccountInstance(
        bytes32 salt,
        address account,
        bytes memory initCode,
        address accountFactory,
        address validator,
        address sessionValidator,
        AccountType accountType,
        address helper
    )
        internal
        view
        returns (AccountInstance memory instance)
    {
        instance = AccountInstance({
            accountType: accountType,
            accountHelper: helper,
            account: account,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(validator),
            initCode: initCode,
            accountFactory: accountFactory,
            smartSession: ISmartSession(SMARTSESSION_ADDR),
            defaultSessionValidator: ISessionValidator(sessionValidator)
        });
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Initialize the module kit with the provided environment if it has not been initialized
    modifier initializeModuleKit() {
        if (!isInit[block.chainid]) {
            string memory _env = envOr("ACCOUNT_TYPE", DEFAULT);
            _initializeModuleKit(_env);
        }
        _;
    }

    /// @dev Set the account type for a function, and restore the previous account type
    ///      after the function call. Useful for testing different account types in the same test
    /// @param env The account type to set
    modifier usingAccountEnv(AccountType env) {
        // If the module kit is not initialized, initialize it
        if (!isInit[block.chainid]) {
            _initializeModuleKit(env.toString());
        } else {
            // Cache the current env to restore it after the function call
            (AccountType _oldEnv, address _oldAccountFactory, address _oldAccountHelper) =
                ModuleKitHelpers.getAccountEnv();
            // Set the new env
            ModuleKitHelpers.setAccountEnv(env);
            _;
            // Restore the old env
            ModuleKitHelpers.setAccountEnv(_oldEnv);
        }
    }

    /// @notice Verify that the storage of a module was cleared after a function call
    modifier withModuleStorageClearValidation(AccountInstance memory instance, address module) {
        instance.startStateDiffRecording();
        _;
        VmSafe.AccountAccess[] memory accountAccess = instance.stopAndReturnStateDiff();
        instance.verifyModuleStorageWasCleared(accountAccess, module);
    }
}
