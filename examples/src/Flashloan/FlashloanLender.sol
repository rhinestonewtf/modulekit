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

import "forge-std/console2.sol";

abstract contract FlashloanLender is
    ERC7579FallbackBase,
    ERC7579ExecutorBase,
    IERC3156FlashLender
{
    error UnsupportedTokenType();
    error TokenNotRepaid();
    error FlashloanCallbackFailed();
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address account => uint256 value) public nonce;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function flashFeeToken() external view virtual returns (address);

    function flashFee(address token, uint256 tokenId) external view virtual returns (uint256);

    function availableForFlashLoan(
        address token,
        uint256 tokenId
    )
        public
        view
        returns (bool hasToken)
    {
        try IERC721(token).ownerOf(tokenId) returns (address holder) {
            hasToken = holder == address(msg.sender);
        } catch {
            hasToken = false;
        }
    }

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
        (FlashLoanType flashLoanType,,) = abi.decode(data, (FlashLoanType, bytes, bytes));

        address account = msg.sender;
        uint256 balanceBefore;

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
        bool success = receiver.onFlashLoan(account, token, value, 0, data)
            == keccak256("ERC3156FlashBorrower.onFlashLoan");
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

    modifier onlyAllowedBorrower(address borrower) {
        require(_isAllowedBorrower(borrower), "FlashloanLender: not allowed borrower");
        _;
    }

    function _isAllowedBorrower(address account) internal view virtual returns (bool);

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/
}
