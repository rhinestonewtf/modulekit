// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../common/erc4337/UserOperation.sol";
import "../modulekit/ValidatorBase.sol";
import "../modulekit/lib/ValidatorSelectionLib.sol";
import "./ISessionKeyValidationModule.sol";

import "forge-std/console2.sol";

struct SessionStorage {
    bytes32 merkleRoot;
}

struct SessionKeyParams {
    uint256 validUntil;
    uint256 validAfter;
    address sessionValidationModule;
    bytes sessionKeyData;
    bytes32[] merkleProof;
    bytes sessionKeySignature;
}

contract SessionKeyManager is ValidatorBase {
    using ValidatorSelectionLib for UserOperation;

    error SessionNotApproved(bytes32 root, bytes32 leaf);

    /**
     * @dev mapping of Smart Account to a SessionStorage
     * Info about session keys is stored as root of the merkle tree built over the session keys
     */
    mapping(address => SessionStorage) internal userSessions;

    // biconomy
    // target @ 16:36
    // targetCallData @ 132:
    // address target = address(bytes20(userOp.callData[16:36]));

    // safe
    // target @ 48:68
    // targetCallData @ 164:
    uint256 immutable TARGET_OFFSET;
    uint256 immutable CALLDATA_OFFSET;

    constructor(uint256 _targetOffset, uint256 _callDataOffset) {
        TARGET_OFFSET = _targetOffset;
        CALLDATA_OFFSET = _callDataOffset;
    }

    /**
     * @dev returns the SessionStorage object for a given smartAccount
     * @param smartAccount Smart Account address
     */
    function getSessionKeys(address smartAccount) external view returns (SessionStorage memory) {
        return userSessions[smartAccount];
    }

    /**
     * @dev sets the merkle root of a tree containing session keys for msg.sender
     * should be called by Smart Account
     * @param _merkleRoot Merkle Root of a tree that contains session keys with their permissions and parameters
     */
    function setMerkleRoot(bytes32 _merkleRoot) external {
        userSessions[msg.sender].merkleRoot = _merkleRoot;
    }

    function _sessionMerkelLeaf(
        uint256 validUntil,
        uint256 validAfter,
        address sessionValidationModule,
        bytes memory sessionKeyData
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(validUntil, validAfter, sessionValidationModule, sessionKeyData)
        );
    }

    /**
     * @dev validates userOperation
     * @param userOp User Operation to be validated.
     * @param userOpHash Hash of the User Operation to be validated.
     * @return sigValidationResult 0 if signature is valid, SIG_VALIDATION_FAILED otherwise.
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        virtual
        override
        returns (uint256)
    {
        SessionStorage storage sessionKeyStorage = _getSessionData(userOp.sender);

        // biconomy
        // target @ 16:36
        // targetCallData @ 132:
        // address target = address(bytes20(userOp.callData[16:36]));

        // safe
        // target @ 48:68
        // targetCallData @ 164:
        address target = address(bytes20(userOp.callData[TARGET_OFFSET:TARGET_OFFSET + 20]));
        console2.log("target", target);

        (bytes memory signature,) = abi.decode(userOp.signature, (bytes, address));

        SessionKeyParams memory sessionKeyParams = abi.decode(signature, (SessionKeyParams));

        console2.log("asdf");

        bytes32 leaf = _sessionMerkelLeaf({
            validUntil: sessionKeyParams.validUntil,
            validAfter: sessionKeyParams.validAfter,
            sessionValidationModule: sessionKeyParams.sessionValidationModule,
            sessionKeyData: sessionKeyParams.sessionKeyData
        });
        if (!MerkleProof.verify(sessionKeyParams.merkleProof, sessionKeyStorage.merkleRoot, leaf)) {
            revert SessionNotApproved(sessionKeyStorage.merkleRoot, leaf);
        }
        //_packValidationData expects true if sig validation has failed, false otherwise
        bool validSig = ISessionKeyValidationModule(sessionKeyParams.sessionValidationModule)
            .validateSessionUserOp(
            userOp,
            userOpHash,
            sessionKeyParams.sessionKeyData,
            sessionKeyParams.sessionKeySignature,
            target,
            CALLDATA_OFFSET
        );

        if (validSig) return 0;
        else return 1;
    }

    /**
     * @dev isValidSignature according to BaseAuthorizationModule
     * @param _dataHash Hash of the data to be validated.
     * @param _signature Signature over the the _dataHash.
     * @return always returns 0xffffffff as signing messages is not supported by SessionKeys
     */
    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signature
    )
        public
        view
        override
        returns (bytes4)
    {
        return 0xffffffff; // do not support it here
    }

    /**
     * @dev returns the SessionStorage object for a given smartAccount
     * @param _account Smart Account address
     * @return sessionKeyStorage SessionStorage object at storage
     */
    function _getSessionData(address _account)
        internal
        view
        returns (SessionStorage storage sessionKeyStorage)
    {
        sessionKeyStorage = userSessions[_account];
    }

    function recoverValidator(
        address recoveryModule,
        bytes calldata recoveryProof,
        bytes calldata recoveryData
    )
        external
    { }
}
