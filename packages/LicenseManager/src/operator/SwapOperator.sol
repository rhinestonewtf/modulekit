// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { PackedUserOperation, IOperator } from "./IOperator.sol";
import "../LicenseManager.sol";
import "../lib/Currency.sol";
import "./ISwapRouter.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/interfaces/IERC20.sol";

library PathLib {
    function decodeCurrency(bytes calldata path)
        internal
        pure
        returns (Currency tokenIn, Currency tokenOut)
    {
        tokenIn = Currency.wrap(address(bytes20(path[0:20])));
        tokenOut = Currency.wrap(address(bytes20(path[path.length - 20:])));
    }
}

contract SwapOperator is IOperator, Ownable {
    using CurrencyLibrary for Currency;
    using PathLib for bytes;

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
        Currency currency,
        OwnerAndBalance[] calldata withdraws
    )
        internal
        returns (uint256 totalAmount)
    {
        uint256 currencyId = currency.toId();
        uint256 length = withdraws.length;
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
        uint256 amountOut,
        uint256 amountIn,
        OwnerAndBalance[] calldata withdraws
    )
        internal
    {
        IERC20 _tokenOut = IERC20(Currency.unwrap(tokenOut));
        console2.log("balanceOf", _tokenOut.balanceOf(address(this)));

        uint256 length = withdraws.length;
        uint256 ratio;
        if (amountOut < amountIn) {
            ratio = amountIn / amountOut;

            console2.log("ratio", ratio);

            for (uint256 i; i < length; i++) {
                OwnerAndBalance calldata withdraw = withdraws[i];
                uint256 _tokenOut = withdraw.amount / ratio;

                console2.log("tokenOut", _tokenOut);
                tokenOut.transfer({ to: withdraw.account, amount: _tokenOut });
            }
        } else { }
    }

    function swap(
        OwnerAndBalance[] calldata withdraws,
        bytes calldata path,
        ISwapRouter.ExactOutputSingleParams calldata gasRefund
    )
        external
        onlyEntryPoint
    {
        (Currency tokenIn, Currency tokenOut) = path.decodeCurrency();
        uint256 amountIn = _transferLicenseManagerTokens(tokenIn, withdraws);

        LICENSE_MANAGER.withdraw({ currency: tokenIn, amount: amountIn });

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0
        });

        IERC20(Currency.unwrap(tokenIn)).approve(address(SWAP_ROUTER), amountIn);

        uint256 amountOut = SWAP_ROUTER.exactInput(params);

        _distributeTokenOut({
            tokenOut: tokenOut,
            amountOut: amountOut,
            amountIn: amountIn,
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
