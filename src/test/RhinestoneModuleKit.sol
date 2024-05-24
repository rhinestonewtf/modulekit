// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
import { MultiAccountFactory } from "src/accounts/MultiAccountFactory.sol";
import { PackedUserOperation, IStakeManager } from "../external/ERC4337.sol";
import { ENTRYPOINT_ADDR } from "./predeploy/EntryPoint.sol";
import {
    ERC7579BootstrapConfig,
    IERC7579Account,
    ERC7579Account,
    ERC7579AccountFactory,
    IERC7579Validator
} from "../external/ERC7579.sol";
import { MockValidator } from "../Mocks.sol";
import "./utils/Vm.sol";
import "./utils/ModuleKitCache.sol";

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
    MultiAccountFactory public accountFactory;
    bool internal isInit;
    MockValidator public _defaultValidator;

    /**
     * Initializes Auxiliary and /src/core
     * This function will run before any accounts can be created
     */
    modifier initializeModuleKit() {
        if (!isInit) {
            super.init();
            isInit = true;

            accountFactory = new MultiAccountFactory();
            label(address(accountFactory), "AccountFactory");
            _defaultValidator = new MockValidator();
            label(address(_defaultValidator), "DefaultValidator");

            // Stake factory on EntryPoint
            deal(address(accountFactory), 10 ether);
            prank(address(accountFactory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
        }
        _;
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
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        // Create AccountInstance struct with counterFactualAddress and initCode
        // The initcode will be set to 0, once the account was created by EntryPoint.sol
        instance = AccountInstance({
            account: counterFactualAddress,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(address(_defaultValidator)),
            initCode: initCode4337,
            gasLog: false
        });

        ModuleKitCache.logEntrypoint(instance.account, auxiliary.entrypoint);
    }

    /**
     * create new AccountInstance with modulekit defaults
     *
     * @param salt account salt / name
     */
    function makeAccountInstance(bytes32 salt)
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        bytes memory initData = accountFactory.getInitData(address(_defaultValidator), "");
        address account = accountFactory.getAddress(salt, initData);
        bytes memory initCode4337 = abi.encodePacked(
            address(accountFactory), abi.encodeCall(accountFactory.createAccount, (salt, initData))
        );
        label(address(account), toString(salt));
        deal(account, 1 ether);
        instance = makeAccountInstance(salt, account, initCode4337);
    }

    function makeAccountInstance(
        bytes32 salt,
        address account,
        address defaultValidator,
        bytes memory initCode
    )
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
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
}
