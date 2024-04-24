// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC7579ValidatorBase, ERC7579HookBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/ModuleKit.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract DeadmanSwitch is ERC7579HookBase, ERC7579ValidatorBase {
    using SignatureCheckerLib for address;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct DeadmanSwitchStorage {
        uint48 lastAccess;
        uint48 timeout;
        address nominee;
    }

    mapping(address account => DeadmanSwitchStorage config) private _lastAccess;

    event Recovery(address account, address nominee);

    error MissingCondition();

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        if (data.length == 0) return;
        (address nominee, uint48 timeout) = abi.decode(data, (address, uint48));
        DeadmanSwitchStorage storage config = _lastAccess[msg.sender];

        config.lastAccess = uint48(block.timestamp);
        config.timeout = timeout;
        config.nominee = nominee;
    }

    function onUninstall(bytes calldata) external override {
        delete _lastAccess[msg.sender];
    }

    function isInitialized(address smartAccount) external view returns (bool) { }

    function lastAccess(address account) external view returns (uint48) {
        return _lastAccess[account].lastAccess;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function preCheck(address, uint256, bytes calldata) external returns (bytes memory hookData) {
        DeadmanSwitchStorage storage config = _lastAccess[msg.sender];
        config.lastAccess = uint48(block.timestamp);
    }

    function postCheck(bytes calldata, bool, bytes calldata) external { }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        DeadmanSwitchStorage memory config = _lastAccess[userOp.sender];
        if (config.nominee == address(0)) return VALIDATION_FAILED;
        bool sigValid = config.nominee.isValidSignatureNow({
            hash: ECDSA.toEthSignedMessageHash(userOpHash),
            signature: userOp.signature
        });

        return _packValidationData({
            sigFailed: !sigValid,
            validAfter: config.lastAccess + config.timeout,
            validUntil: type(uint48).max
        });
    }

    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4)
    {
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "DeadmanSwitch";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK;
    }
}
