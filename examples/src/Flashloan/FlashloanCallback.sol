// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase, ERC7579FallbackBase } from "modulekit/src/Modules.sol";
import { FlashLoanType } from "modulekit/src/interfaces/Flashloan.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { Execution } from "modulekit/src/modules/ERC7579HookDestruct.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import "forge-std/console2.sol";

abstract contract FlashloanCallback is ERC7579FallbackBase, ERC7579ExecutorBase {
    using SentinelListLib for SentinelListLib.SentinelList;
    using SignatureCheckerLib for address;

    error TokenGatedTxFailed();
    error Unauthorized();
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address account => uint256 nonces) public nonce;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external virtual;

    function onUninstall(bytes calldata data) external virtual;

    function isInitialized(address smartAccount) external view virtual returns (bool);

    function getTokengatedTxHash(
        FlashLoanType flashLoanType,
        Execution[] memory executions,
        uint256 _nonce
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(flashLoanType, executions, _nonce));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    modifier onlyAllowedCallbackSender() {
        if (!_isAllowedCallbackSender()) revert Unauthorized();
        _;
    }

    function _isAllowedCallbackSender() internal view virtual returns (bool);

    /**
     * token / amount / fee is not necessary here.
     * token will get paid back in batched exec
     */
    function onFlashLoan(
        address borrower,
        address, /*token*/
        uint256, /*amount*/
        uint256, /*fee*/
        bytes calldata data
    )
        external
        onlyAllowedCallbackSender
        returns (bytes32)
    {
        console2.log("onFlashLoan called");
        (FlashLoanType flashLoanType, bytes memory signature, Execution[] memory executions) =
            abi.decode(data, (FlashLoanType, bytes, Execution[]));
        bytes32 hash = getTokengatedTxHash(flashLoanType, executions, nonce[borrower]);
        nonce[borrower]++;
        hash = ECDSA.toEthSignedMessageHash(hash);
        bool validSig = address(msg.sender).isValidSignatureNow(hash, signature);
        if (!validSig) revert TokenGatedTxFailed();
        _execute(executions);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
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
