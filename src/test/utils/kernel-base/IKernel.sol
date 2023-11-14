// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { UserOperation } from "src/common/erc4337/UserOperation.sol";

enum Operation {
    Call,
    DelegateCall
}

enum ParamCondition {
    EQUAL,
    GREATER_THAN,
    LESS_THAN,
    GREATER_THAN_OR_EQUAL,
    LESS_THAN_OR_EQUAL,
    NOT_EQUAL
}

type ValidAfter is uint48;

type ValidUntil is uint48;

type ValidationData is uint256;

interface IKernelValidator {
    function enable(bytes calldata _data) external payable;

    function disable(bytes calldata _data) external payable;

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingFunds
    )
        external
        payable
        returns (ValidationData);

    function validateSignature(
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        returns (ValidationData);

    function validCaller(address caller, bytes calldata data) external view returns (bool);
}

interface IKernel {
    // Event declarations
    event Upgraded(address indexed newImplementation);
    event DefaultValidatorChanged(address indexed oldValidator, address indexed newValidator);
    event ExecutionChanged(
        bytes4 indexed selector, address indexed executor, address indexed validator
    );

    // Error declarations
    error NotAuthorizedCaller();
    error AlreadyInitialized();

    // -- Kernel.sol --
    function execute(
        address _to,
        uint256 _value,
        bytes calldata _data,
        Operation operation
    )
        external
        payable;

    function validateUserOp(
        UserOperation memory _op,
        bytes32 _hash,
        uint256 _missingAccountFunds
    )
        external
        payable
        returns (ValidationData validationData);

    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    )
        external
        view
        returns (bytes4);

    // -- KernelStorage.sol --
    function initialize(IKernelValidator _kernelValidator, bytes calldata _data) external payable;

    function upgradeTo(address _newImplementation) external payable;

    function setExecution(
        bytes4 _selector,
        address _executor,
        IKernelValidator _validator,
        ValidUntil _validUntil,
        ValidAfter _validAfter,
        bytes calldata _enableData
    )
        external
        payable;

    function setDefaultValidator(
        IKernelValidator _validator,
        bytes calldata _data
    )
        external
        payable;

    function disableMode(bytes4 _disableFlag) external payable;
}
