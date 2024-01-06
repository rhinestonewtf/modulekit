// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../core/sessionKey/ISessionValidationModule.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import "forge-std/console2.sol";

contract ERC20Revocation is ISessionValidationModule {
    struct Token {
        address token;
        address sessionKeySigner;
    }

    function encode(Token memory transaction) public pure returns (bytes memory) {
        return abi.encode(transaction);
    }

    function validateSessionParams(
        address destinationContract,
        uint256 callValue,
        bytes calldata callData,
        bytes calldata _sessionKeyData,
        bytes calldata /*_callSpecificData*/
    )
        public
        virtual
        override
        returns (address)
    {
        Token memory transaction = abi.decode(_sessionKeyData, (Token));

        address spender;
        uint256 amount;
        bytes4 targetSelector = bytes4(callData[:4]);
        if (targetSelector == IERC20.approve.selector) {
            (spender, amount) = abi.decode(callData[4:], (address, uint256));
        } else {
            revert("invalid token method");
        }
        if (callValue != 0) {
            revert("ERC20SV Call Value Not Zero");
        }
        if (amount != 0) {
            revert("ERC20SV Wrong Token");
        }

        return transaction.sessionKeySigner;
    }
}
