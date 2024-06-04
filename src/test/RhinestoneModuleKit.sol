// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SafeFactory } from "src/accounts/safe/SafeFactory.sol";
import { ERC7579Factory } from "src/accounts/erc7579/ERC7579Factory.sol";
import { KernelFactory } from "src/accounts/kernel/KernelFactory.sol";
import { envOr } from "src/test/utils/Vm.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
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

enum AccountType {
    DEFAULT,
    SAFE,
    KERNEL,
    CUSTOM
}

contract RhinestoneModuleKit is AuxiliaryFactory {
    bool internal isInit;
    MockValidator public _defaultValidator;
    IAccountFactory public accountFactory;

    AccountType public env;
    /**
     * Initializes Auxiliary and /src/core
     * This function will run before any accounts can be created
     */

    modifier initializeModuleKit() {
        if (!isInit) {
            super.init();
            isInit = true;

            string memory _env = envOr("ACCOUNT_TYPE", DEFAULT);

            initSafe();
            initERC7579();
            initKernel();

            if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(DEFAULT))) {
                env = AccountType.DEFAULT;
                accountFactory = IAccountFactory(new ERC7579Factory());
            } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(SAFE))) {
                env = AccountType.SAFE;
                accountFactory = IAccountFactory(new SafeFactory());
            } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(KERNEL))) {
                env = AccountType.KERNEL;
                accountFactory = IAccountFactory(new KernelFactory());
            } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(CUSTOM))) {
                env = AccountType.CUSTOM;
                // TODO: What should happen in the custom case?
                accountFactory = IAccountFactory(new ERC7579Factory());
            } else {
                revert InvalidAccountType();
            }

            accountFactory.init();
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
        instance = _makeAccountInstance(
            salt, counterFactualAddress, initCode4337, address(_defaultValidator)
        );

        accountFactory.setAccountType(AccountType.CUSTOM);
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
        instance = _makeAccountInstance(salt, account, initCode4337, address(_defaultValidator));
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
        instance = _makeAccountInstance(salt, account, initCode, defaultValidator);
    }

    function _makeAccountInstance(
        bytes32 salt,
        address account,
        bytes memory initCode4337,
        address validator
    )
        internal
        returns (AccountInstance memory instance)
    {
        instance = AccountInstance({
            account: account,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(validator),
            initCode: initCode4337,
            gasLog: false
        });

        ModuleKitCache.logEntrypoint(instance.account, auxiliary.entrypoint);
    }

    function setAccountType(AccountType _env) public {
        env = _env;
    }

    function getAccountType() public view returns (AccountType) {
        return env;
    }
}
