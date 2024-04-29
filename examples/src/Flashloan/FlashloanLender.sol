// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";

import { ERC7579ExecutorBase, ERC7579FallbackBase } from "modulekit/src/Modules.sol";
import {
    FlashLoanType,
    IERC3156FlashBorrower,
    IERC3156FlashLender
} from "modulekit/src/interfaces/Flashloan.sol";

/**
 * @title FlashloanLender
 * @dev A base for flashloan lender modules
 * @author Rhinestone
 */
abstract contract FlashloanLender is
    ERC7579FallbackBase,
    ERC7579ExecutorBase,
    IERC3156FlashLender
{
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error UnsupportedTokenType();
    error TokenNotRepaid();
    error FlashloanCallbackFailed();

    // account => nonce
    mapping(address account => uint256) public nonce;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Get the flash fee token address
     *
     * @return The flash fee token address
     */
    function flashFeeToken() external view virtual returns (address);

    /**
     * Get the flash fee for a flashloan
     *
     * @param token The token address
     * @param tokenId The token ID
     *
     * @return The flash fee
     */
    function flashFee(address token, uint256 tokenId) external view virtual returns (uint256);

    /**
     * Check if a token is available for flashloan
     *
     * @param token The token address
     * @param tokenId The token ID
     *
     * @return hasToken True if the token is available for flashloan
     */
    function availableForFlashLoan(
        address token,
        uint256 tokenId
    )
        public
        view
        returns (bool hasToken)
    {
        // if token is ERC721, check if the token is owned by the borrower
        try IERC721(token).ownerOf(tokenId) returns (address holder) {
            hasToken = holder == address(msg.sender);
        } catch {
            // else return false
            hasToken = false;
        }
    }

    /**
     * Execute a flashloan
     *
     * @param receiver The flashloan receiver
     * @param token The token address
     * @param value The token ID or amount
     * @param data The data to be passed to the receiver
     *
     * @return success True if the flashloan was successful
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 value,
        bytes calldata data
    )
        external
        virtual
        onlyAllowedBorrower(address(receiver))
        returns (bool)
    {
        // get the flashloan type
        (FlashLoanType flashLoanType,,) = abi.decode(data, (FlashLoanType, bytes, bytes));

        // cache the account and balance before
        address account = msg.sender;
        uint256 balanceBefore;

        // transfer the token to the receiver
        if (flashLoanType == FlashLoanType.ERC721) {
            balanceBefore = availableForFlashLoan({ token: token, tokenId: value }) ? 1 : 0;
            _execute(
                msg.sender,
                address(token),
                0,
                abi.encodeCall(IERC721.transferFrom, (account, address(receiver), value))
            );
        } else if (flashLoanType == FlashLoanType.ERC20) {
            balanceBefore = IERC20(token).balanceOf(account);
            _execute(
                msg.sender,
                address(token),
                0,
                abi.encodeCall(IERC20.transfer, (address(receiver), value))
            );
        } else {
            revert UnsupportedTokenType();
        }

        // trigger callback on borrrower
        bytes memory ret = _execute(
            address(receiver),
            0,
            abi.encodeCall(IERC3156FlashBorrower.onFlashLoan, (account, token, value, 0, data))
        );
        // check if the callback was successful
        bytes32 _ret = abi.decode(ret, (bytes32));
        bool success = _ret == keccak256("ERC3156FlashBorrower.onFlashLoan");
        // revert if the callback failed
        if (!success) revert FlashloanCallbackFailed();

        // check that token was sent back
        if (flashLoanType == FlashLoanType.ERC721) {
            if (!availableForFlashLoan({ token: token, tokenId: value })) {
                revert TokenNotRepaid();
            }
        } else if (flashLoanType == FlashLoanType.ERC20) {
            if (IERC20(token).balanceOf(msg.sender) < balanceBefore) {
                revert TokenNotRepaid();
            }
        }
        return true;
    }

    /**
     * Check if the borrower is allowed
     *
     * @param borrower The borrower address
     */
    modifier onlyAllowedBorrower(address borrower) {
        require(_isAllowedBorrower(borrower), "FlashloanLender: not allowed borrower");
        _;
    }

    /**
     * Check if the borrower is allowed
     *
     * @param account The borrower address
     *
     * @return True if the borrower is allowed
     */
    function _isAllowedBorrower(address account) internal view virtual returns (bool);
}
