// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../core/sessionKey/ISessionValidationModule.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import "forge-std/console2.sol";

contract ERC20SessionKey is ISessionValidationModule {
    struct ERC20Transaction {
        address sessionKeySigner;
        address token;
        address recipient;
        uint256 maxAmount;
    }

    function encode(ERC20Transaction memory transaction) public pure returns (bytes memory) {
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
        ERC20Transaction memory transaction = abi.decode(_sessionKeyData, (ERC20Transaction));

        address recipient;
        uint256 amount;
        bytes4 targetSelector = bytes4(callData[:4]);
        if (targetSelector == IERC20.transfer.selector) {
            (recipient, amount) = abi.decode(callData[4:], (address, uint256));
        } else if (targetSelector == IERC20.transferFrom.selector) {
            (, recipient, amount) = abi.decode(callData[4:], (address, address, uint256));
        } else {
            revert("invalid token method");
        }

        if (transaction.recipient != address(0) && recipient != transaction.recipient) {
            revert("ERC20SV Wrong Recipient");
        }
        if (transaction.maxAmount < amount) {
            revert("ERC20SV Max Amount Exceeded");
        }
        if (callValue != 0) {
            revert("ERC20SV Call Value Not Zero");
        }
        if (transaction.token == address(0) || transaction.token != destinationContract) {
            revert("ERC20SV Wrong Token");
        }

        return transaction.sessionKeySigner;
    }
}
