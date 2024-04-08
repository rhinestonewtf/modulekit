// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";

abstract contract ECDSAFactor is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct FactorConfig {
        address signer;
        uint48 validAfter;
        uint48 validBefore;
    }

    mapping(address smartAccount => FactorConfig ecdsaConfig) public ecdsaFactorConfig;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function setECDSAFactor(FactorConfig calldata config) external {
        ecdsaFactorConfig[msg.sender] = config;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _ecdsaSet(address smartAccount) internal view returns (bool) {
        return ecdsaFactorConfig[smartAccount].signer != address(0);
    }

    function _isValidSignature(
        bytes32 userOpHash,
        bytes memory signature
    )
        internal
        view
        returns (bool validSig)
    {
        FactorConfig memory config = ecdsaFactorConfig[msg.sender];
        validSig =
            config.signer == ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), signature);
    }

    function _checkSignature(
        bytes32 userOpHash,
        bytes memory signature
    )
        internal
        view
        returns (ValidationData _packedData)
    {
        FactorConfig memory config = ecdsaFactorConfig[msg.sender];
        bool validSig =
            config.signer == ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), signature);
        return _packValidationData(!validSig, config.validBefore, config.validAfter);
    }
}
