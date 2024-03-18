// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import { ISafe, SafeERC7579 } from "../SafeERC7579.sol";
import { ISafe7579Init } from "../interfaces/ISafe7579Init.sol";

/**
 * Helper contract that gets delegatecalled byt SafeProxy.setup() to setup safe7579 as a module
 * (safe module)
 * as well as initializing Safe7579 for the SafeProxy
 */
contract Safe7579Launchpad {
    address immutable SAFE7579Singleton;

    constructor(address _safe7579Singleton) {
        SAFE7579Singleton = _safe7579Singleton;
    }

    // function initSafe7579(address safe7579, bytes calldata safe7579InitCode) public {
    //     ISafe(address(this)).enableModule(safe7579);
    //     SafeERC7579(payable(safe7579)).initializeAccount(safe7579InitCode);
    // }

    function initSafe7579(
        address safe7579,
        ISafe7579Init.ModuleInit[] calldata validators,
        ISafe7579Init.ModuleInit[] calldata executors,
        ISafe7579Init.ModuleInit[] calldata fallbacks,
        ISafe7579Init.ModuleInit[] calldata hooks
    )
        public
    {
        ISafe(address(this)).enableModule(safe7579);
        SafeERC7579(payable(safe7579)).initializeAccount(validators, executors, fallbacks, hooks);
    }

    function predictSafeAddress(
        address singleton,
        address safeProxyFactory,
        bytes memory creationCode,
        bytes32 salt,
        bytes memory initializer
    )
        external
        pure
        returns (address safeProxy)
    {
        salt = keccak256(abi.encodePacked(keccak256(initializer), salt));

        safeProxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(safeProxyFactory),
                            salt,
                            keccak256(
                                abi.encodePacked(creationCode, uint256(uint160(address(singleton))))
                            )
                        )
                    )
                )
            )
        );
    }

    function getInitCode(
        address[] memory signers,
        uint256 threshold,
        ISafe7579Init.ModuleInit[] calldata validators,
        ISafe7579Init.ModuleInit[] calldata executors,
        ISafe7579Init.ModuleInit[] calldata fallbacks,
        ISafe7579Init.ModuleInit[] calldata hooks
    )
        external
        view
        returns (bytes memory initCode)
    {
        bytes memory safeLaunchPadSetup = abi.encodeCall(
            this.initSafe7579, (address(SAFE7579Singleton), validators, executors, fallbacks, hooks)
        );
        // SETUP SAFE
        initCode = abi.encodeCall(
            ISafe.setup,
            (
                signers,
                threshold,
                address(this),
                safeLaunchPadSetup,
                SAFE7579Singleton,
                address(0),
                0,
                payable(address(0))
            )
        );
    }
}
