// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Hook } from "../external/ERC7579.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579HookBaseNew is IERC7579Hook, ERC7579ModuleBase {
    mapping(address account => address) public trustedForwarder;

    function setTrustedForwarder(address forwarder) external {
        trustedForwarder[msg.sender] = forwarder;
    }

    function isTrustedForwarder(address forwarder, address account) public view returns (bool) {
        return forwarder == trustedForwarder[account];
    }

    function _msgSender() internal view returns (address account) {
        account = msg.sender;
        address _account;
        address forwarder;
        if (msg.data.length >= 40) {
            assembly {
                _account := shr(96, calldataload(sub(calldatasize(), 20)))
                forwarder := shr(96, calldataload(sub(calldatasize(), 40)))
            }
            if (forwarder == msg.sender && isTrustedForwarder(forwarder, _account)) {
                account = _account;
            }
        }
    }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        virtual
        returns (bytes memory hookData)
    {
        return _preCheck(_msgSender(), msgSender, msgValue, msgData);
    }

    function postCheck(bytes calldata hookData) external virtual {
        _postCheck(_msgSender(), hookData);
    }

    function _preCheck(
        address account,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function _postCheck(address account, bytes calldata hookData) internal virtual;
}
