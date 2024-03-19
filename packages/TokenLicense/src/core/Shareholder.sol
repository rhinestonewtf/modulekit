// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import "../DataTypes.sol";
import "forge-std/console2.sol";

contract Shareholder {
    using MathLib for uint256;

    mapping(address module => ModuleRecordTxFee) internal _moduleRecords;

    function setRecord(
        address module,
        bps txPercentage,
        address[] calldata shareholders,
        bps[] calldata equities
    )
        public
    {
        ModuleRecordTxFee storage $moduleRecord = _moduleRecords[module];
        $moduleRecord.txPercentage = txPercentage;

        uint256 length = shareholders.length;
        if (length != equities.length) revert();

        $moduleRecord.shareholders = shareholders;
        $moduleRecord.equities = equities;
    }

    function getTokenPermissions(
        address module,
        IERC20 token, // TODO: swap?
        uint256 totalAmount
    )
        public
        view
        returns (
            uint256 feeAmount,
            bps txPercentage,
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
        )
    {
        ModuleRecordTxFee storage $module = _moduleRecords[module];

        console2.log("foo");
        // calc percentage of total amount
        txPercentage = $module.txPercentage;
        console2.log("foo");
        feeAmount = totalAmount.percent(txPercentage);
        console2.log("fee amount", totalAmount, bps.unwrap(txPercentage), feeAmount);

        uint256 shareholdersLength = $module.shareholders.length;

        permissions = new ISignatureTransfer.TokenPermissions[](shareholdersLength);
        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](shareholdersLength);
        for (uint256 i; i < shareholdersLength; i++) {
            uint256 _amount = feeAmount.percent($module.equities[i]);

            permissions[i] =
                ISignatureTransfer.TokenPermissions({ token: address(token), amount: _amount });

            transferDetails[i] = ISignatureTransfer.SignatureTransferDetails({
                to: $module.shareholders[i],
                requestedAmount: _amount
            });
        }
    }
}
