// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";

import { ERC7579ExecutorBase, ERC7579FallbackBase } from "modulekit/src/Modules.sol";
import { FlashLoanType, IERC3156FlashBorrower } from "modulekit/src/interfaces/Flashloan.sol";

abstract contract FlashloanLender is ERC7579FallbackBase, ERC7579ExecutorBase {
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

    function onInstall(bytes calldata data) external virtual;

    function onUninstall(bytes calldata data) external virtual;
    function isInitialized(address smartAccount) external view virtual returns (bool);

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
        returns (bool)
    {
        (FlashLoanType flashLoanType,,) = abi.decode(data, (FlashLoanType, bytes, bytes));

        address account = msg.sender;

        // ERC20 and ERC721 share the same token type.
        // Technically, the condition is not necessary,
        // but should be kept for clarity.
        if (flashLoanType == FlashLoanType.ERC721) {
            _execute(
                msg.sender,
                address(token),
                0,
                abi.encodeCall(IERC721.transferFrom, (address(account), address(receiver), value))
            );
        } else if (flashLoanType == flashLoanType.ERC20) {
            _execute(
                msg.sender,
                address(token),
                0,
                abi.encodeCall(IERC20.transferFrom, (address(account), address(receiver), value))
            );
        } else {
            revert UnsupportedTokenType();
        }

        // trigger callback on borrrower
        bool success = borrower.onFlashLoan(account, token, amount, 0, data)
            == keccak256("ERC3156FlashBorrower.onFlashLoan");
        if (!success) revert FlashloanCallbackFailed();

        // check that token was sent back
        if (!availableForFlashLoan({ token: token, tokenId: amount })) {
            revert TokenNotRepaid();
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "FlashloanLender";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_EXECUTOR || isType == TYPE_FALLBACK;
    }
}
