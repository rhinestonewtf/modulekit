// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

abstract contract ERC2771Context {
    error ERC2771Unauthorized();

    modifier onlySmartAccount() {
        _onlySmartAccount();
        _;
    }

    function _onlySmartAccount() private view {
        if (_msgSender() != msg.sender) {
            revert ERC2771Unauthorized();
        }
    }

    function _msgSender() internal view virtual returns (address sender) {
        assembly {
            sender := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    function _manager() internal view virtual returns (address manager) {
        manager = msg.sender;
    }
}
