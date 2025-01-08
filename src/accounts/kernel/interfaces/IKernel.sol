// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IERC7579Account } from "./IERC7579Account.sol";
import { IAccount, ValidationData } from "./IAccount.sol";
import { IAccountExecute } from "./IAccountExecute.sol";
import { IHook } from "./IERC7579Module.sol";

// Types
import { ValidationId, ValidationConfig } from "../lib/ValidationTypeLib.sol";
import { PackedUserOperation } from
    "@ERC4337/account-abstraction/contracts/core/UserOperationLib.sol";
import { ExecMode } from "../lib/ExecLib.sol";

interface IKernel is IAccount, IAccountExecute, IERC7579Account {
    function initialize(
        ValidationId _rootValidator,
        IHook hook,
        bytes calldata validatorData,
        bytes calldata hookData,
        bytes[] calldata initConfig
    )
        external;

    function upgradeTo(address _newImplementation) external payable;

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    )
        external
        pure
        returns (bytes4);

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    )
        external
        pure
        returns (bytes4);

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes4);

    // validation part
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        payable
        returns (ValidationData validationData);

    // --- Execution ---
    function executeUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        payable;

    function executeFromExecutor(
        ExecMode execMode,
        bytes calldata executionCalldata
    )
        external
        payable
        returns (bytes[] memory returnData);

    function execute(ExecMode execMode, bytes calldata executionCalldata) external payable;

    function isValidSignature(
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        returns (bytes4);

    function installModule(
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        external
        payable;

    function installValidations(
        ValidationId[] calldata vIds,
        ValidationConfig[] memory configs,
        bytes[] calldata validationData,
        bytes[] calldata hookData
    )
        external
        payable;

    function uninstallValidation(
        ValidationId vId,
        bytes calldata deinitData,
        bytes calldata hookDeinitData
    )
        external
        payable;

    function invalidateNonce(uint32 nonce) external payable;

    function uninstallModule(
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        external
        payable;

    function supportsModule(uint256 moduleTypeId) external pure returns (bool);

    function isModuleInstalled(
        uint256 moduleType,
        address module,
        bytes calldata additionalContext
    )
        external
        view
        returns (bool);

    function accountId() external pure returns (string memory accountImplementationId);

    function supportsExecutionMode(ExecMode mode) external pure returns (bool);

    function isAllowedSelector(ValidationId vId, bytes4 selector) external view returns (bool);

    function _toWrappedHash(bytes32 hash) external view returns (bytes32);

    function validationConfig(ValidationId vId) external view returns (ValidationConfig memory);
}
