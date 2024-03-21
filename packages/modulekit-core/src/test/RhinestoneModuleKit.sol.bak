// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
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
import { MultiAccountFactory } from "./MultiAccountFactory.sol";
import { AccountDetection } from "./utils/AccountDetection.sol";
import { IAccountFactory } from "../IAccountFactory.sol";

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

contract RhinestoneModuleKit is AccountDetection, AuxiliaryFactory, MultiAccountFactory {
    IAccountFactory public accountFactory;
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
        defaultValidator = new MockValidator();
        label(address(defaultValidator), "DefaultValidator");

        // // Deploy default contracts
        // accountImplementationSingleton = new ERC7579Account();
        // label(address(accountImplementationSingleton), "ERC7579AccountImpl");
        // accountFactory = new ERC7579AccountFactory(address(accountImplementationSingleton));
        // label(address(accountFactory), "ERC7579AccountFactory");
        // defaultValidator = new MockValidator();
        // label(address(defaultValidator), "DefaultValidator");
        //
        // // Stake factory on EntryPoint
        // deal(address(accountFactory), 10 ether);
        // prank(address(accountFactory));
        // IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
    }

    function makeAccountInstance(bytes32 salt) internal returns (AccountInstance memory instance) {
        address account = makeAccount(accountFlavor, salt, address(defaultValidator), "");

        instance = AccountInstance({
            account: account,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(address(defaultValidator)),
            initCode: "",
            gasLog: false
        });
    }

    function makeAccountInstance(
        bytes32 salt,
        address account,
        address defaultValidator,
        bytes memory initCode
    )
        internal
        returns (AccountInstance memory instance)
    { }
}
