// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Base.sol";
import "./safe7579/Safe7579Factory.sol";
import "./referenceImpl/RefImplFactory.sol";
import { ERC7579BootstrapConfig } from "../external/ERC7579.sol";

enum AccountType {
    DEFAULT,
    SAFE
}

string constant DEFAULT = "DEFAULT";
string constant SAFE = "SAFE";

contract MultiAccountFactory is TestBase, Safe7579Factory, RefImplFactory {
    AccountType public env;

    constructor() {
        string memory _env = vm.envOr("ACCOUNT_TYPE", DEFAULT);

        if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(SAFE))) {
            env = AccountType.SAFE;
        } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(DEFAULT))) {
            env = AccountType.DEFAULT;
        } else {
            revert("Invalid account type");
        }
    }

    function createAccount(
        bytes32 salt,
        bytes calldata initCode
    )
        public
        returns (address account)
    {
        if (env == AccountType.SAFE) {
            return _makeSafe(salt, initCode);
        } else {
            return _makeDefault(salt, initCode);
        }
    }

    function _makeDefault(bytes32 salt, bytes calldata initCode) public returns (address) {
        return _createERC7579(salt, initCode);
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
        if (env == AccountType.SAFE) {
            return getAddressSafe(salt, initCode);
        } else {
            return getAddressERC7579(salt, initCode);
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
    )
        external
        returns (bytes memory init)
    {
        if (env == AccountType.SAFE) {
            init = getInitDataSafe(validator, initData);
        } else {
            ERC7579BootstrapConfig[] memory _validators = generateConfig(validator, initData);
            ERC7579BootstrapConfig[] memory _executors = _emptyConfigs();

            ERC7579BootstrapConfig memory _hook = _emptyConfig();

            ERC7579BootstrapConfig[] memory _fallBacks = _emptyConfigs();
            init = abi.encode(
                address(bootstrapDefault),
                abi.encodeCall(
                    ERC7579Bootstrap.initMSA, (_validators, _executors, _hook, _fallBacks)
                )
            );
        }
    }

    function generateConfig(
        address module,
        bytes memory data
    )
        private
        pure
        returns (ERC7579BootstrapConfig[] memory config)
    {
        config = new ERC7579BootstrapConfig[](1);
        config[0].module = module;
        config[0].data = data;
    }

    function _emptyConfig() private pure returns (ERC7579BootstrapConfig memory config) { }

    function _emptyConfigs() private pure returns (ERC7579BootstrapConfig[] memory config) { }
}
