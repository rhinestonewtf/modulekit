// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";

interface IFeeMachine {
    function getSplit(
        Claim calldata claim,
        address referral
    )
        external
        returns (ISignatureTransfer.SignatureTransferDetails[] memory transfers);
}
