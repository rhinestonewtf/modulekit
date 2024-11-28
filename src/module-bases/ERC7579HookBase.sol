// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { IHook as IERC7579Hook } from "../accounts/common/interfaces/IERC7579Module.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";
import { TrustedForwarder } from "./utils/TrustedForwarder.sol";

abstract contract ERC7579HookBase is IERC7579Hook, ERC7579ModuleBase, TrustedForwarder {
    /**
     * Precheck hook
     *
     * @param msgSender sender of the transaction
     * @param msgValue value of the transaction
     * @param msgData data of the transaction
     *
     * @return hookData data for the postcheck hook
     */
    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        virtual
        returns (bytes memory hookData)
    {
        // route to internal function
        return _preCheck(_getAccount(), msgSender, msgValue, msgData);
    }

    /**
     * Postcheck hook
     *
     * @param hookData data from the precheck hook
     */
    function postCheck(bytes calldata hookData) external virtual {
        // route to internal function
        _postCheck(_getAccount(), hookData);
    }

    /**
     * Precheck hook
     *
     * @param account account of the transaction
     * @param msgSender sender of the transaction
     * @param msgValue value of the transaction
     * @param msgData data of the transaction
     *
     * @return hookData data for the postcheck hook
     */
    function _preCheck(
        address account,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        virtual
        returns (bytes memory hookData);

    /**
     * Postcheck hook
     *
     * @param account account of the transaction
     * @param hookData data from the precheck hook
     */
    function _postCheck(address account, bytes calldata hookData) internal virtual;
}
