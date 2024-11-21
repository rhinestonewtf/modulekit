// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IMSA, ERC7579Bootstrap, IERC7579Module } from "src/external/ERC7579.sol";
import { FactoryBase } from "./FactoryBase.sol";
import { IMSA } from "erc7579/interfaces/IMSA.sol";
import { MSAProxy } from "erc7579/utils/MSAProxy.sol";

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

        bytes memory initData = abi.encode(
            BOOTSTRAP,
            abi.encodeCall(
                ERC7579Bootstrap.singleInitMSA, (IERC7579Module(validator), validatorInitData)
            )
        );

        address account = address(
            new MSAProxy{ salt: salt }(
                IMPLEMENTATION, abi.encodeCall(IMSA.initializeAccount, initData)
            )
        );

        return account;
    }

    function getAddress(
        bytes32 salt,
        address validator,
        bytes calldata validatorInitData
    )
        public
        virtual
        returns (address)
    {
        _checkRegistry(validator, 1);

        bytes memory initData = abi.encode(
            BOOTSTRAP,
            abi.encodeCall(
                ERC7579Bootstrap.singleInitMSA, (IERC7579Module(validator), validatorInitData)
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(
                    abi.encodePacked(
                        type(MSAProxy).creationCode,
                        abi.encode(IMPLEMENTATION, abi.encodeCall(IMSA.initializeAccount, initData))
                    )
                )
            )
        );

        return address(uint160(uint256(hash)));
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
