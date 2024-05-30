// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { LibClone } from "solady/utils/LibClone.sol";
import { IMSA, ERC7579Bootstrap, IERC7579Module } from "src/external/ERC7579.sol";
import { FactoryBase } from "./FactoryBase.sol";

contract ExampleFactory is FactoryBase {
    address public immutable IMPLEMENTATION;
    address public immutable BOOTSTRAP;

    constructor(
        address _msaImplementation,
        address _bootstrap,
        address _registry,
        address[] memory _trustedAttesters,
        uint8 _threshold
    )
        FactoryBase(_registry, _trustedAttesters, _threshold)
    {
        IMPLEMENTATION = _msaImplementation;
        BOOTSTRAP = _bootstrap;
    }

    function createAccount(
        bytes32 salt,
        address validator,
        bytes calldata validatorInitData
    )
        public
        payable
        virtual
        returns (address)
    {
        _checkRegistry(validator, 1);

        bytes32 _salt = _getSalt(salt, validator, validatorInitData);
        (bool alreadyDeployed, address account) =
            LibClone.createDeterministicERC1967(msg.value, IMPLEMENTATION, _salt);

        if (!alreadyDeployed) {
            bytes memory initData = abi.encode(
                BOOTSTRAP,
                abi.encodeCall(
                    ERC7579Bootstrap.singleInitMSA, (IERC7579Module(validator), validatorInitData)
                )
            );
            IMSA(account).initializeAccount(initData);
        }
        return account;
    }

    function getAddress(
        bytes32 salt,
        address validator,
        bytes calldata validatorInitData
    )
        public
        view
        virtual
        returns (address)
    {
        bytes32 _salt = _getSalt(salt, validator, validatorInitData);
        return LibClone.predictDeterministicAddressERC1967(IMPLEMENTATION, _salt, address(this));
    }

    function getInitCode(
        bytes32 salt,
        address validator,
        bytes calldata validatorInitData
    )
        public
        view
        virtual
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            address(this), abi.encodeCall(this.createAccount, (salt, validator, validatorInitData))
        );
    }

    function _getSalt(
        bytes32 _salt,
        address validator,
        bytes calldata validatorInitData
    )
        public
        pure
        virtual
        returns (bytes32 salt)
    {
        salt = keccak256(abi.encodePacked(_salt, validator, validatorInitData));
    }
}
