// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SessionKeyBase } from "modulekit/src/Modules.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";

contract ERC20Revocation is SessionKeyBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    enum TokenType {
        ERC20,
        ERC721
    }

    struct Token {
        address token;
        TokenType tokenType;
        address sessionKeySigner;
    }

    error InvalidToken();
    error NotZero();

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external { }

    function onUninstall(bytes calldata data) external { }

    function isInitialized(address smartAccount) external view returns (bool) { }

    function encode(Token memory transaction) public pure returns (bytes memory) {
        return abi.encode(transaction);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function validateSessionParams(
        address to,
        uint256 value,
        bytes calldata callData,
        bytes calldata sessionKeyData,
        bytes calldata /*_callSpecificData*/
    )
        external
        returns (address)
    {
        Token memory transaction = abi.decode(sessionKeyData, (Token));
        bytes4 targetSelector = bytes4(callData[:4]);

        if (transaction.token != to) revert InvalidToken();
        if (value != 0) revert InvalidValue();
        if (transaction.tokenType == TokenType.ERC20) {
            _validateERC20(targetSelector, callData);
        } else if (transaction.tokenType == TokenType.ERC721) {
            _validateERC721(targetSelector, callData);
        } else {
            revert InvalidToken();
        }

        return transaction.sessionKeySigner;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _validateERC20(bytes4 targetSelector, bytes calldata callData) internal pure {
        // handle ERC20
        if (targetSelector == IERC20.approve.selector) {
            (, uint256 amount) = abi.decode(callData[4:], (address, uint256)); // (spender,
                // amount)
            if (amount != 0) revert NotZero();
        } else {
            revert InvalidMethod(targetSelector);
        }
    }

    function _validateERC721(bytes4 targetSelector, bytes calldata callData) internal pure {
        // Handle ERC721
        if (targetSelector == IERC721.approve.selector) {
            (address spender,) = abi.decode(callData[4:], (address, uint256)); // (spender,tokenId)
            if (spender != address(0)) revert NotZero();
        } else if (targetSelector == IERC721.setApprovalForAll.selector) {
            (, bool approved) = abi.decode(callData[4:], (address, bool)); // (spender,
                // approved)
            if (approved) revert NotZero();
        } else {
            revert InvalidMethod(targetSelector);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function name() external pure virtual returns (string memory) {
        return "AutoSaving";
    }

    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }
}
