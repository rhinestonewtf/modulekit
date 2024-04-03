// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";

string constant CLAIM_STRING =
    "Claim(ClaimType claimType, address module, address smartAccount, address payToken, uint256 usdAmount, bytes data)";
bytes32 constant CLAIM_HASH = keccak256(abi.encodePacked(CLAIM_STRING));

enum ClaimType {
    Transaction,
    Subscription,
    SingleCharge
}

struct Claim {
    ClaimType claimType;
    address module;
    address smartAccount;
    IERC20 payToken;
    uint256 usdAmount;
    bytes data;
}

struct LicenseRecord {
    uint48 validUntil;
    uint48 renewalSeconds;
}

struct SubscriptionConfig {
    uint128 pricePerSecond;
    uint128 minSubTime; // in seconds
}

error SubscriptionTooShort();

error UnauthorizedModuleOwner();

event NewSplitter(address indexed module, address indexed splitter);

event NewModuleOwner(address indexed module, address indexed newOwner);

event NewModuleMonetization(address indexed module);

type bps is uint32;

using { bpsEq as == } for bps global;
using { bpsNeq as != } for bps global;
using { bpsBt as > } for bps global;
using { bpsLt as < } for bps global;

function bpsEq(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) == bps.unwrap(val2);
}

function bpsNeq(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) != bps.unwrap(val2);
}

function bpsBt(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) > bps.unwrap(val2);
}

function bpsLt(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) < bps.unwrap(val2);
}

library MathLib {
    uint256 internal constant dec = 10_000;

    function percent(uint256 amount, bps _bps) internal pure returns (uint256 _result) {
        require((amount * bps.unwrap(_bps)) >= dec, "Invalid BPS");
        return amount * bps.unwrap(_bps) / dec;
    }
}
