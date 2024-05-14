// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Base.sol";
import "./safe7579/Safe7579Factory.sol";
import "./referenceImpl/RefImplFactory.sol";
import {ERC7579BootstrapConfig} from "../external/ERC7579.sol";
import {Kernel7579Factory} from "./kernel7579/Kernel7579Factory.sol";
import {ValidatorLib} from "kernel/utils/ValidationTypeLib.sol";
import {IValidator, IHook} from "kernel/interfaces/IERC7579Modules.sol";
import {ValidationId} from "kernel/types/Types.sol";
import {Kernel} from "kernel/Kernel.sol";

enum AccountType {
    DEFAULT,
    SAFE7579,
    KERNEL7579
}

string constant DEFAULT = "DEFAULT";
string constant SAFE7579 = "SAFE7579";
string constant KERNEL7579 = "KERNEL7579";

contract MultiAccountFactory is
    TestBase,
    Safe7579Factory,
    RefImplFactory,
    Kernel7579Factory
{
    AccountType public env;

    constructor() {
        string memory _env = vm.envOr("ACCOUNT_TYPE", DEFAULT);

        if (
            keccak256(abi.encodePacked(_env)) ==
            keccak256(abi.encodePacked(SAFE7579))
        ) {
            env = AccountType.SAFE7579;
        } else if (
            keccak256(abi.encodePacked(_env)) ==
            keccak256(abi.encodePacked(KERNEL7579))
        ) {
            env = AccountType.KERNEL7579;
        } else {
            env = AccountType.DEFAULT;
        }
    }

    function createAccount(
        bytes32 salt,
        bytes calldata initCode
    ) public returns (address account) {
        if (env == AccountType.SAFE7579) {
            return _makeSafe(salt, initCode);
        } else if (env == AccountType.KERNEL7579) {
            return _makeKernel(initCode, salt);
        } else {
            return _makeDefault(salt, initCode);
        }
    }

    function _makeDefault(
        bytes32 salt,
        bytes calldata initCode
    ) public returns (address) {
        return _createUMSA(salt, initCode);
    }

    function _makeSafe(
        bytes32 salt,
        bytes calldata initCode
    ) public returns (address) {
        return _createSafe(salt, initCode);
    }

    function _makeKernel(
        bytes calldata data,
        bytes32 salt
    ) public returns (address) {
        return _createKernel(data, salt);
    }

    function getAddress(
        bytes32 salt,
        bytes memory initCode
    ) public view virtual returns (address) {
        if (env == AccountType.SAFE7579) {
            return getAddressSafe(salt, initCode);
        } else if (env == AccountType.KERNEL7579) {
            return getAddressKernel(initCode, salt);
        } else {
            return getAddressUMSA(salt, initCode);
        }
    }

    function _getSalt(
        bytes32 _salt,
        bytes memory initCode
    )
        public
        pure
        virtual
        override(RefImplFactory, Safe7579Factory)
        returns (bytes32 salt)
    {
        salt = keccak256(abi.encodePacked(_salt, initCode));
    }

    function getMinimalInitData(
        address validator,
        bytes memory initData
    ) external view returns (bytes memory init) {
        if (env == AccountType.SAFE7579) {
            ERC7579BootstrapConfig[] memory _validators = generateConfig(
                validator,
                initData
            );
            ERC7579BootstrapConfig[] memory _executors = _emptyConfigs();

            ERC7579BootstrapConfig memory _hook = _emptyConfig();

            ERC7579BootstrapConfig[] memory _fallBacks = _emptyConfigs();
            init = abi.encode(
                address(bootstrapSafe),
                abi.encodeCall(
                    ERC7579Bootstrap.initMSA,
                    (_validators, _executors, _hook, _fallBacks)
                )
            );
        } else if (env == AccountType.KERNEL7579) {
            ValidationId rootValidator = ValidatorLib.validatorToIdentifier(
                IValidator(validator)
            );

            init = abi.encodeCall(
                Kernel.initialize,
                (rootValidator, IHook(address(0)), initData, "")
            );
        } else {
            ERC7579BootstrapConfig[] memory _validators = generateConfig(
                validator,
                initData
            );
            ERC7579BootstrapConfig[] memory _executors = _emptyConfigs();

            ERC7579BootstrapConfig memory _hook = _emptyConfig();

            ERC7579BootstrapConfig[] memory _fallBacks = _emptyConfigs();
            init = abi.encode(
                address(bootstrapDefault),
                abi.encodeCall(
                    BootstrapSafe.initMSA,
                    (_validators, _executors, _hook, _fallBacks)
                )
            );
        }
    }

    function generateConfig(
        address module,
        bytes memory data
    ) private pure returns (ERC7579BootstrapConfig[] memory config) {
        config = new ERC7579BootstrapConfig[](1);
        config[0].module = module;
        config[0].data = data;
    }

    function _emptyConfig()
        private
        pure
        returns (ERC7579BootstrapConfig memory config)
    {}

    function _emptyConfigs()
        private
        pure
        returns (ERC7579BootstrapConfig[] memory config)
    {}
    // function getBootstrapCallData(
    //     ERC7579BootstrapConfig[] calldata _validators,
    //     ERC7579BootstrapConfig[] calldata _executors,
    //     ERC7579BootstrapConfig calldata _hook,
    //     ERC7579BootstrapConfig[] calldata _fallbacks
    // ) external view returns (bytes memory init) {
    //     if (env == AccountType.SAFE7579) {
    //         init = abi.encode(
    //             address(bootstrapSafe),
    //             abi.encodeCall(
    //                 ERC7579Bootstrap.initMSA,
    //                 (_validators, _executors, _hook, _fallbacks)
    //             )
    //         );
    //     } else if (env == AccountType.KERNEL7579) {
    //         //TODO remove the comment
    //         // init = abi.encode(
    //         //     address(bootstrapDefault),
    //         //     abi.encodeCall(
    //         //         ERC7579Bootstrap.initMSA,
    //         //         (_validators, _executors, _hook, _fallbacks)
    //         //     )
    //         // );

    //         // init = abi.encodeCall(Kernel.initialize, (rootValidator, hook, validatorData, hookData));
    //     } else {
    //         init = abi.encode(
    //             address(bootstrapDefault),
    //             abi.encodeCall(
    //                 BootstrapSafe.initMSA,
    //                 (_validators, _executors, _hook, _fallbacks)
    //             )
    //         );
    //     }
    // }
}
