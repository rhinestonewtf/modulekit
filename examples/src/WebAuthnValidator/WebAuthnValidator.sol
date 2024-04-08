// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { WebAuthnLib } from "./utils/WebAuthNLib.sol";
import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation, UserOperationLib } from "modulekit/src/external/ERC4337.sol";

struct PassKeyId {
    uint256 pubKeyX;
    uint256 pubKeyY;
    string keyId;
}

contract WebAuthnValidator is ERC7579ValidatorBase {
    using UserOperationLib for PackedUserOperation;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error NoPassKeyRegisteredForSmartAccount(address smartAccount);
    error AlreadyInitedForSmartAccount(address smartAccount);

    event NewPassKeyRegistered(address indexed smartAccount, string keyId);

    mapping(address account => PassKeyId passkeyConfig) public smartAccountPassKeys;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        PassKeyId memory passkey = abi.decode(data, (PassKeyId));
        smartAccountPassKeys[msg.sender] = passkey;
    }

    function onUninstall(bytes calldata) external override {
        _removePassKey();
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return smartAccountPassKeys[smartAccount].pubKeyX != 0;
    }

    function getAuthorizedKey(address account) public view returns (PassKeyId memory passkey) {
        passkey = smartAccountPassKeys[account];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        (
            ,
            bytes memory authenticatorData,
            bytes1 authenticatorDataFlagMask,
            bytes memory clientData,
            uint256 clientChallengeDataOffset,
            uint256[2] memory rs
        ) = abi.decode(userOp.signature, (bytes32, bytes, bytes1, bytes, uint256, uint256[2]));

        PassKeyId memory passKey = smartAccountPassKeys[userOp.getSender()];
        require(passKey.pubKeyX != 0 && passKey.pubKeyY != 0, "Key not found");
        uint256[2] memory Q = [passKey.pubKeyX, passKey.pubKeyY];
        bool isValidSignature = WebAuthnLib.checkSignature(
            authenticatorData,
            authenticatorDataFlagMask,
            clientData,
            userOpHash,
            clientChallengeDataOffset,
            rs,
            Q
        );

        return _packValidationData(!isValidSignature, type(uint48).max, 0);
    }

    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _removePassKey() internal {
        smartAccountPassKeys[msg.sender] = PassKeyId(0, 0, "");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "WebAuthnValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
