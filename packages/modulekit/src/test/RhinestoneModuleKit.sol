// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
import { MultiAccountFactory } from "../accountFactory/MultiAccountFactory.sol";
import { PackedUserOperation, IEntryPoint, IStakeManager } from "../external/ERC4337.sol";
import { ERC7579Helpers, BootstrapUtil } from "./utils/ERC7579Helpers.sol";
import { ENTRYPOINT_ADDR } from "./predeploy/EntryPoint.sol";

import {
    ERC7579BootstrapConfig,
    IERC7579Account,
    ERC7579Account,
    ERC7579AccountFactory,
    IERC7579Validator
} from "../external/ERC7579.sol";

import { ModuleKitUserOp } from "./ModuleKitUserOp.sol";
import { ModuleKitHelpers } from "./ModuleKitHelpers.sol";
import { MockValidator } from "../Mocks.sol";

import "./utils/Vm.sol";
import "./utils/ModuleKitCache.sol";
import "./utils/Log.sol";

struct AccountInstance {
    address account;
    Auxiliary aux;
    IERC7579Validator defaultValidator;
    bytes32 salt;
    bytes initCode;
    bool gasLog;
}

struct UserOpData {
    PackedUserOperation userOp;
    bytes32 userOpHash;
}

contract RhinestoneModuleKit is AuxiliaryFactory {
    // ERC7579AccountFactory public accountFactory;
    // IERC7579Account public accountImplementationSingleton;

    MultiAccountFactory public accountFactory;

    bool internal isInit;

    MockValidator public defaultValidator;

    constructor() {
        init();
    }

    /**
     * Initializes Auxiliary and /src/core
     * This function will run before any accounts can be created
     */
    function init() internal virtual override {
        if (!isInit) {
            super.init();
            isInit = true;
        }

        isInit = true;

        // // Deploy default contracts
        // accountImplementationSingleton = new ERC7579Account();
        // label(address(accountImplementationSingleton), "ERC7579AccountImpl");
        // accountFactory = new ERC7579AccountFactory(address(accountImplementationSingleton));
        // label(address(accountFactory), "ERC7579AccountFactory");

        accountFactory = new MultiAccountFactory();
        defaultValidator = new MockValidator();
        label(address(defaultValidator), "DefaultValidator");

        // Stake factory on EntryPoint
        deal(address(accountFactory), 10 ether);
        prank(address(accountFactory));
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
    }

    /**
     * create new AccountInstance with initCode
     * @param salt account salt / name
     * @param counterFactualAddress of the account
     * @param initCode4337 to be added to userOp:initCode
     */
    function makeAccountInstance(
        bytes32 salt,
        address counterFactualAddress,
        bytes memory initCode4337
    )
        internal
        returns (AccountInstance memory instance)
    {
        // Create AccountInstance struct with counterFactualAddress and initCode
        // The initcode will be set to 0, once the account was created by EntryPoint.sol
        instance = AccountInstance({
            account: counterFactualAddress,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(address(defaultValidator)),
            initCode: initCode4337,
            gasLog: false
        });

        ModuleKitCache.logEntrypoint(instance.account, auxiliary.entrypoint);
    }

    /**
     * create new AccountInstance with ERC7579BootstrapConfig
     *
     * @param salt account salt / name
     * @param validators ERC7579 validators to be installed on the account
     * @param executors ERC7579 executors to be installed on the account
     * @param hook ERC7579 hook to be installed on the account
     * @param fallBacks ERC7579 array of fallbackHandlers to be installed on the account
     */
    function makeAccountInstance(
        bytes32 salt,
        ERC7579BootstrapConfig[] memory validators,
        ERC7579BootstrapConfig[] memory executors,
        ERC7579BootstrapConfig memory hook,
        ERC7579BootstrapConfig[] memory fallBacks
    )
        internal
        returns (AccountInstance memory instance)
    {
        init();

        if (validators.length == 0) validators = new ERC7579BootstrapConfig[](1);

        // inject the defaultValidator if it is not already in the list
        // defaultValidator is used a lot in ModuleKit, to make it easier to use
        // if defaultValidator isnt available on the account, a lot of ModuleKit Abstractions would
        // break
        if (validators[0].module != address(0) && validators[0].module != address(defaultValidator))
        {
            ERC7579BootstrapConfig[] memory _validators =
                new ERC7579BootstrapConfig[](validators.length + 1);
            _validators[0] = ERC7579BootstrapConfig({ module: address(defaultValidator), data: "" });
            for (uint256 i = 0; i < validators.length; i++) {
                _validators[i + 1] = validators[i];
            }
            validators = _validators;
        }

        // bytes memory bootstrapCalldata =
        //     auxiliary.bootstrap._getInitMSACalldata(validators, executors, hook, fallBacks);
        bytes memory bootstrapCalldata =
            accountFactory.getBootstrapCallData(validators, executors, hook, fallBacks);
        address account = accountFactory.getAddress(salt, bootstrapCalldata);

        // using MSAFactory from ERC7579 repo.
        bytes memory createAccountOnFactory =
            abi.encodeCall(accountFactory.createAccount, (salt, bootstrapCalldata));

        address factory = address(accountFactory);
        // encode pack factory and account initCode to comply with SenderCreater (EntryPoint.sol)
        bytes memory initCode4337 = abi.encodePacked(factory, createAccountOnFactory);
        label(address(account), bytes32ToString(salt));
        deal(account, 1 ether);

        instance = makeAccountInstance(salt, account, initCode4337);
    }

    /**
     * create new AccountInstance with modulekit defaults
     *
     * @param salt account salt / name
     */
    function makeAccountInstance(bytes32 salt) internal returns (AccountInstance memory instance) {
        init();
        ERC7579BootstrapConfig[] memory validators =
            makeBootstrapConfig(address(defaultValidator), "");

        ERC7579BootstrapConfig[] memory executors = _emptyConfigs();

        ERC7579BootstrapConfig memory hook = _emptyConfig();

        ERC7579BootstrapConfig[] memory fallBack = _emptyConfigs();
        instance = makeAccountInstance(salt, validators, executors, hook, fallBack);
    }

    function makeAccountInstance(
        bytes32 salt,
        address account,
        address defaultValidator,
        bytes memory initCode
    )
        internal
        returns (AccountInstance memory instance)
    {
        init();

        instance = AccountInstance({
            account: account,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(address(defaultValidator)),
            initCode: initCode,
            gasLog: false
        });

        ModuleKitCache.logEntrypoint(instance.account, auxiliary.entrypoint);
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        bytes memory _bytes = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            _bytes[i] = _bytes32[i];
        }
        return string(_bytes);
    }

    function _emptyConfig() internal pure returns (ERC7579BootstrapConfig memory config) { }
    function _emptyConfigs() internal pure returns (ERC7579BootstrapConfig[] memory config) { }

    function _makeBootstrapConfig(
        address module,
        bytes memory data
    )
        public
        pure
        returns (ERC7579BootstrapConfig memory config)
    {
        config.module = module;
        config.data = data;
    }

    function makeBootstrapConfig(
        address module,
        bytes memory data
    )
        public
        pure
        returns (ERC7579BootstrapConfig[] memory config)
    {
        config = new ERC7579BootstrapConfig[](1);
        config[0].module = module;
        config[0].data = data;
    }

    function makeBootstrapConfig(
        address[] memory modules,
        bytes[] memory datas
    )
        public
        pure
        returns (ERC7579BootstrapConfig[] memory configs)
    {
        configs = new ERC7579BootstrapConfig[](modules.length);

        for (uint256 i; i < modules.length; i++) {
            configs[i] = _makeBootstrapConfig(modules[i], datas[i]);
        }
    }
}
