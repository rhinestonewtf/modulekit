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

    mapping(address account => DeadmanSwitchStorage) public config;

    event Recovery(address account, address nominee);

    error UnsopportedOperation();
    error MissingCondition();

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        address account = msg.sender;
        if (isInitialized(account)) {
            if (data.length == 0) {
                return;
            } else {
                revert AlreadyInitialized(account);
            }
        }

        address nominee = address(uint160(bytes20(data[0:20])));
        uint48 timeout = uint48(bytes6(data[20:26]));

        config[account] = DeadmanSwitchStorage({
            lastAccess: uint48(block.timestamp),
            timeout: timeout,
            nominee: nominee
        });
    }

    function onUninstall(bytes calldata) external override {
        delete config[msg.sender];
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return config[smartAccount].nominee != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function preCheck(address, uint256, bytes calldata) external returns (bytes memory) {
        address account = msg.sender;
        if (!isInitialized(account)) return "";

        DeadmanSwitchStorage storage _config = config[account];
        _config.lastAccess = uint48(block.timestamp);
    }

    function postCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        external
    { }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        DeadmanSwitchStorage memory _config = config[userOp.sender];
        address nominee = _config.nominee;
        if (nominee == address(0)) return VALIDATION_FAILED;

        bool sigValid = nominee.isValidSignatureNow({
            hash: ECDSA.toEthSignedMessageHash(userOpHash),
            signature: userOp.signature
        });

        return _packValidationData({
            sigFailed: !sigValid,
            validAfter: _config.lastAccess + _config.timeout,
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
        // ERC-1271 not supported for deadman switch
        revert UnsopportedOperation();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "DeadmanSwitch";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK || typeID == TYPE_VALIDATOR;
    }
}
