// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase, ERC7579FallbackBase } from "modulekit/src/Modules.sol";
import { FlashLoanType } from "modulekit/src/interfaces/Flashloan.sol";

contract FlashloanCallback is ERC7579FallbackBase, ERC7579ExecutorBase {
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

    function getTokengatedTxHash(
        bytes memory transaction,
        uint256 _nonce
    )
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(transaction, _nonce));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    )
        external
        returns (bytes32)
    {
        address borrower = _msgSender();
        (FlashLoanType flashLoanType, bytes memory signature, bytes memory callData) =
            abi.decode(data, (FlashLoanType, bytes, bytes));
        bytes32 hash = getTokengatedTxHash(callData, nonce[borrower]);
        // TODO signature
        (bool success,) = borrower.call(callData);
        if (!success) revert();
        nonce[borrower]++;
        keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "FlashloanCallback";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_EXECUTOR || isType == TYPE_FALLBACK;
    }
}
