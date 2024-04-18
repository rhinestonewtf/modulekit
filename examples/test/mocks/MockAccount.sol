// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import {
    CallType,
    ExecType,
    ModeCode,
    CALLTYPE_BATCH,
    CALLTYPE_SINGLE,
    ModeLib
} from "erc7579/lib/ModeLib.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { ExecutionHelper, Execution } from "erc7579/core/ExecutionHelper.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";

contract MockAccount is IERC7579Account, ExecutionHelper {
    using ExecutionLib for bytes;
    using ModeLib for ModeCode;

    error UnsupportedCallType(CallType callType);

    function execute(ModeCode mode, bytes calldata executionCalldata) external payable { }

    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        payable
        returns (bytes[] memory returnData)
    {
        CallType callType = mode.getCallType();

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            returnData = _execute(executions);
        } else if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) =
                executionCalldata.decodeSingle();
            returnData = new bytes[](1);
            returnData[0] = _execute(target, value, callData);
        } else {
            revert UnsupportedCallType(callType);
        }
    }

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
