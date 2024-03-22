// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/console2.sol";
import "../DataTypes.sol";
import "./IShareholder.sol";

struct ShareholderData {
    address addr;
    uint64 shares;
}

contract Shareholder is IShareholder {
    using Math for uint256;
    using MathLib for uint256;

    struct ShareholderRecord {
        uint64 totalShares;
        uint8 shareholdersLength;
        bps fee;
        mapping(uint256 shareholderId => ShareholderData shareholders) shareholders;
    }

    mapping(address module => ShareholderRecord record) internal $moduleShares;

    mapping(address referal => bps dialution) internal $referralFees;

    function setShareholder(
        address module,
        bps fee,
        ShareholderData[] calldata shareholders
    )
        external
    {
        ShareholderRecord storage $record = $moduleShares[module];
        uint64 totalShares;
        uint256 length = shareholders.length;
        for (uint256 i; i < length; i++) {
            ShareholderData calldata shareholder = shareholders[i];
            totalShares += shareholder.shares;
            $record.shareholders[i] = shareholder;
        }
        $moduleShares[module].totalShares = totalShares;
        $moduleShares[module].fee = fee;
        $moduleShares[module].shareholdersLength = uint8(length);
    }

    function setReferal(address referal, bps dialution) external {
        $referralFees[referal] = dialution;
    }

    function getPermitTransfers(TransactionClaim calldata claim)
        public
        view
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        )
    {
        ShareholderRecord storage $record = $moduleShares[claim.module];

        uint256 length = $record.shareholdersLength;
        uint256 totalShares = $record.totalShares;

        uint256 totalAmount = claim.amount.percent($record.fee);

        permissions = new ISignatureTransfer.TokenPermissions[](length);
        transfers = new ISignatureTransfer.SignatureTransferDetails[](length);
        for (uint256 i; i < length; i++) {
            ShareholderData memory shareholder = $record.shareholders[i];
            uint256 _amount = _convertToAssets({
                shares: shareholder.shares,
                totalShares: totalShares,
                totalAmount: totalAmount,
                rounding: Math.Rounding.Floor
            });

            permissions[i] = ISignatureTransfer.TokenPermissions({
                token: address(claim.token),
                amount: _amount
            });

            transfers[i] = ISignatureTransfer.SignatureTransferDetails({
                to: shareholder.addr,
                requestedAmount: _amount
            });
        }
    }

    function getPermitTransfers(
        TransactionClaim calldata claim,
        address referal
    )
        public
        view
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        )
    {
        (permissions, transfers) = getPermitTransfers(claim);

        // dialute last shareholder
        uint256 length = permissions.length;
        uint256 _amountLastShareholder = transfers[length - 1].requestedAmount;
        uint256 referalAmount = _amountLastShareholder.percent($referralFees[referal]);

        uint256 dialutedAmount = _amountLastShareholder - referalAmount;
        transfers[length - 1].requestedAmount = dialutedAmount;
        permissions[length - 1].amount = dialutedAmount;

        // push +1 length to permissions and transfers
        assembly {
            mstore(permissions, add(mload(permissions), 1))
            mstore(transfers, add(mload(transfers), 1))
        }

        transfers[length] = ISignatureTransfer.SignatureTransferDetails({
            to: referal,
            requestedAmount: referalAmount
        });
        permissions[length] = ISignatureTransfer.TokenPermissions({
            token: address(claim.token),
            amount: referalAmount
        });
    }

    function _convertToAssets(
        uint64 shares,
        uint256 totalShares,
        uint256 totalAmount,
        Math.Rounding rounding
    )
        internal
        view
        returns (uint256)
    {
        return
            uint256(shares).mulDiv(totalAmount + 1, totalShares + 10 ** _decimalsOffset(), rounding);
    }

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    function getPermitTransfers(SubscriptionClaim calldata claim)
        external
        override
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        )
    { }

    function getPermitTransfers(
        SubscriptionClaim calldata claim,
        address referal
    )
        external
        override
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        )
    { }
}
