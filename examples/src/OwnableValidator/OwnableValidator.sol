// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { SentinelList4337Lib, SENTINEL } from "sentinellist/SentinelList4337.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { CheckSignatures } from "checknsignatures/CheckNSignatures.sol";

contract OwnableValidator is ERC7579ValidatorBase {
    using LibSort for *;
    using SignatureCheckerLib for address;
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error ThresholdNotSet();
    error InvalidThreshold();
    error InvalidOwner(address owner);

    SentinelList4337Lib.SentinelList owners;
    mapping(address account => uint256) public threshold;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        (uint256 _threshold, address[] memory _owners) = abi.decode(data, (uint256, address[]));

        // Sort and uniquify the owners to make sure an owner is not reused
        _owners.sort();
        _owners.uniquifySorted();

        // Make sure the threshold is set
        if (_threshold == 0) {
            revert ThresholdNotSet();
        }

        // Make sure the threshold is less than the number of owners
        uint256 ownersLength = _owners.length;
        if (ownersLength < _threshold) {
            revert InvalidThreshold();
        }

        // Set threshold
        threshold[account] = _threshold;

        // Initialize the owner list
        owners.init(account);

        // Add owners to the list
        for (uint256 i = 0; i < ownersLength; i++) {
            address _owner = _owners[i];
            if (_owner == address(0)) {
                revert InvalidOwner(_owner);
            }
            owners.push(account, _owner);
        }
    }

    function onUninstall(bytes calldata) external override {
        // TODO
        threshold[msg.sender] = 0;
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return threshold[smartAccount] != 0;
    }

    function setThreshold(uint256 _threshold) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        if (_threshold == 0) {
            revert InvalidThreshold();
        }
        // TODO check if the threshold is less than the number of owners
        threshold[account] = _threshold;
    }

    function addOwner(address owner) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        if (owner == address(0)) {
            revert InvalidOwner(owner);
        }

        if (owners.contains(account, owner)) {
            revert InvalidOwner(owner);
        }

        owners.push(account, owner);
    }

    function removeOwner(address prevOwner, address owner) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        owners.pop(account, prevOwner, owner);
    }

    function getOwners(address account) external view returns (address[] memory ownersArray) {
        // TODO: return length
        (ownersArray,) = owners.getEntriesPaginated(account, SENTINEL, 10);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        // Get the account
        address account = userOp.sender;

        // Get the threshold and check that its set
        uint256 _threshold = threshold[account];
        if (_threshold == 0) {
            return VALIDATION_FAILED;
        }

        // Recover the signers from the signatures
        address[] memory signers =
            CheckSignatures.recoverNSignatures(userOpHash, userOp.signature, _threshold);

        // Sort and uniquify the signers to make sure a signer is not reused
        signers.sort();
        signers.uniquifySorted();

        // Check if the signers are owners
        uint256 validSigners;
        for (uint256 i = 0; i < signers.length; i++) {
            if (owners.contains(account, signers[i])) {
                validSigners++;
            }
        }

        // Check if the threshold is met and return the result
        if (validSigners >= _threshold) {
            return VALIDATION_SUCCESS;
        }
        return VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        // Get the account
        address account = msg.sender;

        // Get the threshold and check that its set
        uint256 _threshold = threshold[account];
        if (_threshold == 0) {
            revert ThresholdNotSet();
        }

        // Recover the signers from the signatures
        address[] memory signers = CheckSignatures.recoverNSignatures(hash, data, _threshold);

        // Sort and uniquify the signers to make sure a signer is not reused
        signers.sort();
        signers.uniquifySorted();

        // Check if the signers are owners
        uint256 validSigners;
        for (uint256 i = 0; i < signers.length; i++) {
            if (owners.contains(account, signers[i])) {
                validSigners++;
            }
        }

        // Check if the threshold is met and return the result
        if (validSigners >= _threshold) {
            return EIP1271_SUCCESS;
        }
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "OwnableValidator";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
