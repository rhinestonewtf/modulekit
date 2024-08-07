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
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    bool internal isInit;
    MockValidator public _defaultValidator;

    IAccountFactory public accountFactory;
    HelperBase public accountHelper;

    IAccountFactory public safeFactory;
    IAccountFactory public kernelFactory;
    IAccountFactory public erc7579Factory;
    IAccountFactory public nexusFactory;

    HelperBase public safeHelper;
    HelperBase public kernelHelper;
    HelperBase public erc7579Helper;

    AccountType public env;

    error InvalidAccountType();
    error ModuleKitUninitialized();

    /*//////////////////////////////////////////////////////////////////////////
                                     SETUP
    //////////////////////////////////////////////////////////////////////////*/

    modifier initializeModuleKit() {
        if (!isInit) {
            super.init();
            isInit = true;

            safeFactory = new SafeFactory();
            kernelFactory = new KernelFactory();
            erc7579Factory = new ERC7579Factory();
            nexusFactory = new NexusFactory();

            erc7579Helper = new ERC7579Helpers();
            safeHelper = new SafeHelpers();
            kernelHelper = new KernelHelpers();

            safeFactory.init();
            kernelFactory.init();
            erc7579Factory.init();
            nexusFactory.init();

            label(address(safeFactory), "SafeFactory");
            label(address(kernelFactory), "KernelFactory");
            label(address(erc7579Factory), "ERC7579Factory");
            label(address(nexusFactory), "NexusFactory");

            // Stake factory on EntryPoint
            deal(address(safeFactory), 10 ether);
            deal(address(kernelFactory), 10 ether);
            deal(address(erc7579Factory), 10 ether);
            deal(address(nexusFactory), 10 ether);

            prank(address(safeFactory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
            prank(address(kernelFactory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
            prank(address(erc7579Factory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
            prank(address(nexusFactory));
            IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);

            string memory _env = envOr("ACCOUNT_TYPE", DEFAULT);

            _setAccountEnv(_env);

            label(address(accountFactory), "AccountFactory");

            _defaultValidator = new MockValidator();
            label(address(_defaultValidator), "DefaultValidator");
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
            helper: address(accountHelper),
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
        makeAccountInstance({
            salt: salt,
            helper: address(accountHelper),
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

        instance = _makeAccountInstance({
            salt: salt,
            accountType: env,
            helper: helper,
            account: account,
            initCode: initCode,
            validator: address(_defaultValidator),
            accountFactory: _factory
        });
        setAccountType(AccountType.CUSTOM);
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

        instance = _makeAccountInstance({
            salt: salt,
            accountType: env,
            helper: helper,
            account: account,
            initCode: initCode,
            validator: defaultValidator,
            accountFactory: _factory
        });
        setAccountType(AccountType.CUSTOM);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ACCOUNT TYPE
    //////////////////////////////////////////////////////////////////////////*/

    modifier usingAccountEnv(string memory _env) {
        // Revert if the module kit is not initialized
        if (!isInit) {
            revert ModuleKitUninitialized();
        }
        // Cache the current env to restore it after the function call
        AccountType _oldEnv = env;
        IAccountFactory _oldAccountFactory;
        HelperBase _oldAccountHelper;
        // Set the new env
        _setAccountEnv(_env);
        _;
        // Restore the old env
        env = _oldEnv;
        accountFactory = _oldAccountFactory;
        accountHelper = _oldAccountHelper;
    }

    function setAccountType(AccountType _env) public {
        env = _env;
    }

    function setAccountEnv(string memory _env) public {
        _setAccountEnv(_env);
    }

    function setAccountEnv(AccountType _env) public {
        _setAccountEnv(_env);
    }

    function getAccountType() public view returns (AccountType) {
        return env;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

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

    function _setAccountEnv(string memory _env) internal {
        if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(DEFAULT))) {
            _setAccountEnv(AccountType.DEFAULT);
        } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(SAFE))) {
            _setAccountEnv(AccountType.SAFE);
        } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(KERNEL))) {
            _setAccountEnv(AccountType.KERNEL);
        } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(CUSTOM))) {
            _setAccountEnv(AccountType.CUSTOM);
        } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(NEXUS))) {
            _setAccountEnv(AccountType.NEXUS);
        } else {
            revert InvalidAccountType();
        }
    }

    function _setAccountEnv(AccountType _env) internal {
        env = _env;
        if (_env == AccountType.DEFAULT) {
            accountFactory = erc7579Factory;
            accountHelper = erc7579Helper;
        } else if (_env == AccountType.SAFE) {
            accountFactory = safeFactory;
            accountHelper = safeHelper;
        } else if (_env == AccountType.KERNEL) {
            accountFactory = kernelFactory;
            accountHelper = kernelHelper;
        } else if (_env == AccountType.CUSTOM) {
            accountFactory = erc7579Factory;
            accountHelper = erc7579Helper;
        } else if (_env == AccountType.NEXUS) {
            accountFactory = nexusFactory;
            accountHelper = erc7579Helper;
        } else {
            revert InvalidAccountType();
        }
    }
}
