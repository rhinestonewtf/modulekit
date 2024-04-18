// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";

import { ERC7579ExecutorBase, ERC7579FallbackBase } from "modulekit/src/Modules.sol";
import { FlashLoanType, IERC3156FlashBorrower } from "./interfaces/Flashloan.sol";

contract FlashloanLender is ERC7579FallbackBase, ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address account => uint256) public nonce;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }
    function isInitialized(address smartAccount) external view returns (bool) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function flashFeeToken() external view returns (address) { }

    function flashFee(address token, uint256 tokenId) external view returns (uint256) {
        // uint256 tokenOwnerFee = _feePerToken[account][token][tokenId];
        // total = tokenOwnerFee + calcDevFee(tokenOwnerFee, FEE_PERCENTAGE);
    }

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
        uint256 amount,
        bytes calldata data
    )
        external
        returns (bool)
    {
        (FlashLoanType flashLoanType,,) = abi.decode(data, (FlashLoanType, bytes, bytes));

        IERC3156FlashBorrower borrower = IERC3156FlashBorrower(_msgSender());
        address account = msg.sender;

        if (flashLoanType == FlashLoanType.ERC721) {
            _execute(
                msg.sender,
                address(token),
                0,
                abi.encodeCall(IERC721.transferFrom, (address(account), address(borrower), amount))
            );
        }
        // TODO impl ERC20

        // trigger callback on borrrower
        bool success = borrower.onFlashLoan(account, token, amount, 0, data)
            == keccak256("ERC3156FlashBorrower.onFlashLoan");
        if (!success) revert();

        // check that token was sent back
        if (!availableForFlashLoan({ token: token, tokenId: amount })) {
            revert();
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
