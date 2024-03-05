// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Base.sol";
import "./safe7579/Safe7579Factory.sol";
import "./referenceImpl/RefImplFactory.sol";
import { ERC7579BootstrapConfig } from "../external/ERC7579.sol";

enum AccountType {
    DEFAULT,
    SAFE7579
}

string constant DEFAULT = "DEFAULT";
string constant SAFE7579 = "SAFE7579";

contract MultiAccountFactory is TestBase, Safe7579Factory, RefImplFactory {
    AccountType public env;

    constructor() {
        string memory _env = vm.envOr("ACCOUNT_TYPE", DEFAULT);

        if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(SAFE7579))) {
            env = AccountType.SAFE7579;
        } else {
            env = AccountType.DEFAULT;
        }
    }

    function createAccount(
        bytes32 salt,
        bytes calldata initCode
    )
        public
        returns (address account)
    {
        if (env == AccountType.SAFE7579) {
            return _makeSafe(salt, initCode);
        } else {
            return _makeDefault(salt, initCode);
        }
    }

    function _makeDefault(bytes32 salt, bytes calldata initCode) public returns (address) {
        return _createUMSA(salt, initCode);
    }

    function _makeSafe(bytes32 salt, bytes calldata initCode) public returns (address) {
        return _createSafe(salt, initCode);
    }

    function getAddress(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        virtual
        returns (address)
    {
        if (env == AccountType.SAFE7579) {
            return getAddressSafe(salt, initCode);
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

    function getBootstrapCallData(
        ERC7579BootstrapConfig[] calldata _validators,
        ERC7579BootstrapConfig[] calldata _executors,
        ERC7579BootstrapConfig calldata _hook,
        ERC7579BootstrapConfig[] calldata _fallbacks
    )
        external
        view
        returns (bytes memory init)
    {
        if (env == AccountType.SAFE7579) {
            init = abi.encode(
                address(bootstrapSafe),
                abi.encodeCall(
                    ERC7579Bootstrap.initMSA, (_validators, _executors, _hook, _fallbacks)
                )
            );
        } else {
            init = abi.encode(
                address(bootstrapDefault),
                abi.encodeCall(BootstrapSafe.initMSA, (_validators, _executors, _hook, _fallbacks))
            );
        }
    }
}
