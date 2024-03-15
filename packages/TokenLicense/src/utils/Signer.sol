// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@rhinestone/modulekit/src/Modules.sol";
import { PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";
import "forge-std/console2.sol";

contract Signer is ERC7579ValidatorBase {
    struct SignerConf {
        bool autoPermitEnabled;
        uint256 foo;
    }

    address immutable LICENSE_MANAGER;
    string constant TX_FEE_WITNESS = "LicenseManagerTxFee(address module, uint256 amount)";
    address immutable PERMIT2;

    error UnauthorizedERC1271Request();

    mapping(address smartAccount => mapping(address module => SignerConf)) internal _signer;

    constructor(address permit2) {
        PERMIT2 = permit2;
    }

    function enableAutoPermit(address module) external {
        _signer[msg.sender][module].autoPermitEnabled = true;
    }

    modifier onlyPermit2(address sender) {
        if (sender != PERMIT2) revert UnauthorizedERC1271Request();
        _;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (ValidationData)
    {
        return VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        onlyPermit2(sender)
        returns (bytes4)
    {
        console2.logBytes32(hash);
        (address module, uint256 totalAmount) = abi.decode(data, (address, uint256));
        if (!_signer[msg.sender][module].autoPermitEnabled) revert();
        console2.log(sender, module, totalAmount);
        return EIP1271_SUCCESS;
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }
}
