// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { PackedUserOperation, IOperator } from "./IOperator.sol";
import "../LicenseManager.sol";
import "../lib/Currency.sol";
import "./ISwapRouter.sol";

contract SwapOperator is IOperator, Ownable {
    using CurrencyLibrary for Currency;

    struct OwnerAndBalance {
        address account;
        uint256 amount;
    }

    ISwapRouter internal immutable SWAP_ROUTER;
    LicenseManager internal immutable LICENSE_MANAGER;

    error InvalidSwapRecipient();

    constructor(LicenseManager licenseManager, ISwapRouter swapRouter) {
        _initializeOwner(msg.sender);
        SWAP_ROUTER = swapRouter;
        LICENSE_MANAGER = licenseManager;
    }

    function _transferLicenseManagerTokens(
        uint256 currencyId,
        OwnerAndBalance[] calldata withdraws
    )
        internal
        returns (uint256 totalAmount)
    {
        uint256 length;
        for (uint256 i; i < length; i++) {
            OwnerAndBalance calldata tokenOwner = withdraws[i];
            totalAmount += tokenOwner.amount;

            LICENSE_MANAGER.transferFrom({
                sender: tokenOwner.account,
                receiver: address(this),
                id: currencyId,
                amount: tokenOwner.amount
            });
        }
    }

    function _distributeTokenOut(
        Currency tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        OwnerAndBalance[] calldata withdraws
    )
        internal
    {
        uint256 factor = 100_000;
        uint256 ratio = (amountOut / amountIn) * factor;

        uint256 length;

        for (uint256 i; i < length; i++) {
            OwnerAndBalance calldata withdraw = withdraws[i];
            // TODO: check math
            uint256 _tokenOut = (withdraw.amount * ratio) / factor;
            tokenOut.transfer({ to: withdraw.account, amount: _tokenOut });
        }
    }

    function swap(
        Currency tokenIn,
        Currency tokenOut,
        OwnerAndBalance[] calldata withdraws,
        bytes calldata path,
        ISwapRouter.ExactOutputSingleParams calldata gasRefund
    )
        external
        onlyEntryPoint
    {
        uint256 currencyId = tokenIn.toId();
        uint256 totalAmount = _transferLicenseManagerTokens(currencyId, withdraws);

        LICENSE_MANAGER.withdraw({ currency: tokenIn, amount: totalAmount });

        // TODO: check that path first token ins tokenIn
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: totalAmount,
            amountOutMinimum: 0
        });

        uint256 amountOut = SWAP_ROUTER.exactInput(params);
        uint256 amountIn = SWAP_ROUTER.exactOutputSingle(gasRefund);
        _distributeTokenOut({
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            withdraws: withdraws
        });
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        onlyEntryPoint
        returns (uint256 packed)
    {
        bool validSig = ECDSA.recover({
            hash: ECDSA.toEthSignedMessageHash(userOpHash),
            signature: userOp.signature
        }) == owner();

        // TODO check middingAccountFunds

        if (!validSig) return 0;
        else return 1;
    }

    function withdraw(Currency currency, uint256 amount, address receiver) external onlyOwner {
        currency.transfer({ to: receiver, amount: amount });
    }

    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint()) revert Unauthorized();
        _;
    }

    function entryPoint() public view virtual returns (address) {
        return 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    }
}
