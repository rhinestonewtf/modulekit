// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { IMSA } from "./interfaces/IMSA.sol";
import { IERC7579Account } from "src/accounts/common/interfaces/IERC7579Account.sol";
import {
    IERC7579Bootstrap,
    BootstrapConfig as ERC7579BootstrapConfig
} from "src/accounts/erc7579/interfaces/IERC7579Bootstrap.sol";
import { ERC7579Precompiles } from "src/test/precompiles/ERC7579Precompiles.sol";
import { MSAProxy } from "./MSAProxy.sol";

contract ERC7579Factory is IAccountFactory, ERC7579Precompiles {
    IERC7579Account internal implementation;
    IERC7579Bootstrap internal bootstrapDefault;

    function init() public override {
        implementation = deployERC7579Account();
        bootstrapDefault = IERC7579Bootstrap(deployERC7579Bootstrap());
    }

    function createAccount(bytes32 salt, bytes memory initCode) public override returns (address) {
        address account = address(
            new MSAProxy{ salt: salt }(
                address(implementation), abi.encodeCall(IMSA.initializeAccount, initCode)
            )
        );

        return account;
    }

    function getAddress(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        override
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(
                    abi.encodePacked(
                        type(MSAProxy).creationCode,
                        abi.encode(
                            address(implementation),
                            abi.encodeCall(IMSA.initializeAccount, initCode)
                        )
                    )
                )
            )
        );

        return address(uint160(uint256(hash)));
    }

    function getInitData(
        address validator,
        bytes memory initData
    )
        public
        view
        override
        returns (bytes memory _init)
    {
        ERC7579BootstrapConfig[] memory _validators = new ERC7579BootstrapConfig[](1);
        _validators[0].module = validator;
        _validators[0].data = initData;
        ERC7579BootstrapConfig[] memory _executors = new ERC7579BootstrapConfig[](0);

        ERC7579BootstrapConfig memory _hook;

        ERC7579BootstrapConfig[] memory _fallBacks = new ERC7579BootstrapConfig[](0);
        _init = abi.encode(
            address(bootstrapDefault),
            abi.encodeCall(IERC7579Bootstrap.initMSA, (_validators, _executors, _hook, _fallBacks))
        );
    }

    function _getSalt(bytes32 _salt, bytes memory initCode) internal pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_salt, initCode));
    }
}
