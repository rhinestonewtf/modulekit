// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../interfaces/IExecutor.sol";
import { IERC1271, ERC1271_MAGICVALUE } from "../../common/IERC1271.sol";

contract SignatureCondition is ICondition {
    struct Params {
        bytes32 hash;
        bytes signature;
    }

    event ScheduleUpdated(address account, uint256 lastExecuted);

    function checkCondition(
        address account,
        address,
        bytes calldata conditionData,
        bytes calldata
    )
        external
        view
        override
        returns (bool valid)
    {
        Params memory params = abi.decode(conditionData, (Params));
        if (IERC1271(account).isValidSignature(params.hash, params.signature) == ERC1271_MAGICVALUE)
        {
            return true;
        }
    }
}
