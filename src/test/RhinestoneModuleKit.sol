// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SafeFactory } from "src/accounts/safe/SafeFactory.sol";
import { ERC7579Factory } from "src/accounts/erc7579/ERC7579Factory.sol";
import { KernelFactory } from "src/accounts/kernel/KernelFactory.sol";
import { envOr } from "src/test/utils/Vm.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { IAccountHelpers } from "./helpers/IAccountHelpers.sol";
import { ERC7579Helpers } from "./helpers/ERC7579Helpers.sol";
import { SafeHelpers } from "./helpers/SafeHelpers.sol";
import { KernelHelpers } from "./helpers/KernelHelpers.sol";
import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
import { PackedUserOperation, IStakeManager } from "../external/ERC4337.sol";
import { ENTRYPOINT_ADDR } from "./predeploy/EntryPoint.sol";
import { IERC7579Validator } from "../external/ERC7579.sol";
import { MockValidator } from "../Mocks.sol";
import "./utils/Vm.sol";
import "./utils/ModuleKitCache.sol";

enum AccountType {
    DEFAULT,
    SAFE,
    KERNEL,
    CUSTOM
}

struct AccountInstance {
    AccountType accountType;
    address account;
    address accountHelper;
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

string constant DEFAULT = "DEFAULT";
string constant SAFE = "SAFE";
string constant KERNEL = "KERNEL";
string constant CUSTOM = "CUSTOM";

contract RhinestoneModuleKit is AuxiliaryFactory {
    bool internal isInit;
    MockValidator public _defaultValidator;

    IAccountFactory public accountFactory;
    IAccountHelpers public accountHelper;

    IAccountFactory public safeFactory;
    IAccountFactory public kernelFactory;
    IAccountFactory public erc7579Factory;

    IAccountHelpers public safeHelper;
    IAccountHelpers public kernelHelper;
    IAccountHelpers public erc7579Helper;

    AccountType public env;

    error InvalidAccountType();

    /**
     * Initializes Auxiliary and /src/core
     * This function will run before any accounts can be created
     */
    modifier initializeModuleKit() {
        if (!isInit) {
            super.init();
            isInit = true;

            safeFactory = new SafeFactory();
            kernelFactory = new KernelFactory();
            erc7579Factory = new ERC7579Factory();

            erc7579Helper = new ERC7579Helpers();
            safeHelper = new SafeHelpers();
            kernelHelper = new KernelHelpers();

            safeFactory.init();
            kernelFactory.init();
            erc7579Factory.init();

            label(address(safeFactory), "SafeFactory");
            label(address(kernelFactory), "KernelFactory");
            label(address(erc7579Factory), "ERC7579Factory");

            // Stake factory on EntryPoint
            deal(address(safeFactory), 10 ether);
            deal(address(kernelFactory), 10 ether);
            deal(address(erc7579Factory), 10 ether);

            prank(address(safeFactory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
            prank(address(kernelFactory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
            prank(address(erc7579Factory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);

            string memory _env = envOr("ACCOUNT_TYPE", DEFAULT);

            if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(DEFAULT))) {
                env = AccountType.DEFAULT;
                accountFactory = erc7579Factory;
                accountHelper = erc7579Helper;
            } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(SAFE))) {
                env = AccountType.SAFE;
                accountFactory = safeFactory;
                accountHelper = safeHelper;
            } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(KERNEL))) {
                env = AccountType.KERNEL;
                accountFactory = kernelFactory;
                accountHelper = kernelHelper;
            } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(CUSTOM))) {
                env = AccountType.CUSTOM;
                accountFactory = erc7579Factory;
                accountHelper = erc7579Helper;
            } else {
                revert InvalidAccountType();
            }

            label(address(accountFactory), "AccountFactory");

            _defaultValidator = new MockValidator();
            label(address(_defaultValidator), "DefaultValidator");
        }
        _;
    }

    /**
     * create new AccountInstance with initCode
     * @param salt account salt / name
     * @param helper address of the account helper, follows the IAccountHelpers interface
     * @param counterFactualAddress of the account
     * @param initCode4337 to be added to userOp:initCode
     */
    function makeAccountInstance(
        bytes32 salt,
        address helper,
        address counterFactualAddress,
        bytes memory initCode4337
    )
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        label(address(counterFactualAddress), toString(salt));
        deal(counterFactualAddress, 10 ether);
        // Create AccountInstance struct with counterFactualAddress and initCode
        // The initcode will be set to 0, once the account was created by EntryPoint.sol
        instance = _makeAccountInstance(
            salt, env, helper, counterFactualAddress, initCode4337, address(_defaultValidator)
        );

        setAccountType(AccountType.CUSTOM);
    }

    /**
     * create new AccountInstance with modulekit defaults
     *
     * @param salt account salt / name
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
        makeAccountInstance(salt, address(accountHelper), counterFactualAddress, initCode4337);
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
        deal(account, 10 ether);
        instance = _makeAccountInstance(
            salt, env, address(accountHelper), account, initCode4337, address(_defaultValidator)
        );
    }

    function makeAccountInstance(
        bytes32 salt,
        address account,
        address helper,
        address defaultValidator,
        bytes memory initCode
    )
        internal
        initializeModuleKit
        returns (AccountInstance memory instance)
    {
        instance = _makeAccountInstance(salt, env, helper, account, initCode, defaultValidator);

        setAccountType(AccountType.CUSTOM);
    }

    function _makeAccountInstance(
        bytes32 salt,
        AccountType accountType,
        address helper,
        address account,
        bytes memory initCode4337,
        address validator
    )
        internal
        returns (AccountInstance memory instance)
    {
        instance = AccountInstance({
            accountType: accountType,
            accountHelper: helper,
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
