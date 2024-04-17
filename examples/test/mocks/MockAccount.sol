// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { CallType, ExecType, ModeCode } from "erc7579/lib/ModeLib.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";

contract MockAccount is IERC7579Account {
    function execute(ModeCode mode, bytes calldata executionCalldata) external payable { }
    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        payable
        returns (bytes[] memory returnData)
    { }
    function isValidSignature(bytes32 hash, bytes calldata data) external view returns (bytes4) { }
    function installModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata initData
    )
        external
        payable
    { }

    function uninstallModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata deInitData
    )
        external
        payable
    { }
    function supportsExecutionMode(ModeCode encodedMode) external view returns (bool) { }
    function supportsModule(uint256 moduleTypeId) external view returns (bool) { }

    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata additionalContext
    )
        external
        view
        returns (bool)
    {
        if (module == address(0x420)) {
            return false;
        }
        return true;
    }

    function accountId() external view returns (string memory accountImplementationId) { }
}
