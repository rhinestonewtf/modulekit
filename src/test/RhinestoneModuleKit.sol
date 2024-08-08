// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SafeFactory } from "src/accounts/safe/SafeFactory.sol";
import { ERC7579Factory } from "src/accounts/erc7579/ERC7579Factory.sol";
import { KernelFactory } from "src/accounts/kernel/KernelFactory.sol";
import { NexusFactory } from "src/accounts/nexus/NexusFactory.sol";
import { envOr, prank, label, deal, toString } from "src/test/utils/Vm.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { HelperBase } from "./helpers/HelperBase.sol";
import { ERC7579Helpers } from "./helpers/ERC7579Helpers.sol";
import { SafeHelpers } from "./helpers/SafeHelpers.sol";
import { KernelHelpers } from "./helpers/KernelHelpers.sol";
import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
import { PackedUserOperation, IStakeManager, IEntryPoint } from "../external/ERC4337.sol";
import { ENTRYPOINT_ADDR } from "./predeploy/EntryPoint.sol";
import { IERC7579Validator } from "../external/ERC7579.sol";
import { MockValidator } from "../Mocks.sol";
import {
    getAccountEnv,
    getHelper,
    getFactory,
    getAccountType,
    writeAccountEnv,
    writeFactory,
    writeHelper
} from "./utils/Storage.sol";
import { ModuleKitHelpers } from "./ModuleKitHelpers.sol";

enum AccountType {
    DEFAULT,
    SAFE,
    KERNEL,
    CUSTOM,
    NEXUS
}

struct AccountInstance {
    address account;
    AccountType accountType;
    address accountHelper;
    Auxiliary aux;
    IERC7579Validator defaultValidator;
    bytes32 salt;
    bytes initCode;
    address accountFactory;
}

struct UserOpData {
    PackedUserOperation userOp;
    bytes32 userOpHash;
    IEntryPoint entrypoint;
}

string constant DEFAULT = "DEFAULT";
string constant SAFE = "SAFE";
string constant KERNEL = "KERNEL";
string constant CUSTOM = "CUSTOM";
string constant NEXUS = "NEXUS";

contract RhinestoneModuleKit is AuxiliaryFactory {
    /*//////////////////////////////////////////////////////////////////////////
                                    LIBRARIES
    //////////////////////////////////////////////////////////////////////////*/

    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    MockValidator public _defaultValidator;
    bool public isInit;

    /*//////////////////////////////////////////////////////////////////////////
                                     SETUP
    //////////////////////////////////////////////////////////////////////////*/

    modifier initializeModuleKit() {
        if (!isInit) {
            string memory _env = envOr("ACCOUNT_TYPE", DEFAULT);
            _initializeModuleKit(_env);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MAKE INSTANCE
    //////////////////////////////////////////////////////////////////////////*/

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
            accountFactory: address(accountFactory)
        });
    }

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
            accountFactory: _factory
        });

        ModuleKitHelpers.setAccountType(AccountType.CUSTOM);
    }

    function makeAccountInstance(
        bytes32 salt,
        address account,
        bytes memory initCode,
        address helper,
        address defaultValidator
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
            accountFactory: _factory
        });
        ModuleKitHelpers.setAccountType(AccountType.CUSTOM);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ACCOUNT TYPE
    //////////////////////////////////////////////////////////////////////////*/

    modifier usingAccountEnv(AccountType env) {
        // If the module kit is not initialized, initialize it
        if (!isInit) {
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

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _initializeModuleKit(string memory _env) internal {
        // Init
        super.init();
        isInit = true;

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
        writeHelper(address(new ERC7579Helpers()), NEXUS);
        writeHelper(address(new ERC7579Helpers()), CUSTOM);

        // Initialize factories
        IAccountFactory safeFactory = IAccountFactory(getFactory(SAFE));
        IAccountFactory kernelFactory = IAccountFactory(getFactory(KERNEL));
        IAccountFactory erc7579Factory = IAccountFactory(getFactory(DEFAULT));
        IAccountFactory nexusFactory = IAccountFactory(getFactory(NEXUS));
        safeFactory.init();
        kernelFactory.init();
        erc7579Factory.init();
        nexusFactory.init();

        // Label factories
        label(address(safeFactory), "SafeFactory");
        label(address(kernelFactory), "KernelFactory");
        label(address(erc7579Factory), "ERC7579Factory");
        label(address(nexusFactory), "NexusFactory");

        // Stake factory on EntryPoint
        deal(address(safeFactory), 10 ether);
        deal(address(kernelFactory), 10 ether);
        deal(address(erc7579Factory), 10 ether);
        deal(address(nexusFactory), 10 ether);

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

        IAccountFactory accountFactory = IAccountFactory(getFactory(_env));
        label(address(accountFactory), "AccountFactory");

        _defaultValidator = new MockValidator();
        label(address(_defaultValidator), "DefaultValidator");
    }

    function _makeAccountInstance(
        bytes32 salt,
        address account,
        bytes memory initCode,
        address accountFactory,
        address validator,
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
            accountFactory: accountFactory
        });
    }
}
