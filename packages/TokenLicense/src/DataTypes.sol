// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";

string constant TXCLAIM_STRING =
    "TransactionClaim(address module, address smartAccount, address token, uint256 amount, bytes data)";
bytes32 constant TXCLAIM_HASH = keccak256(abi.encodePacked(TXCLAIM_STRING));

string constant TXCLAIM_SPONSOR_STRING =
    "TransactionFeeSponsor(address sponsor, TransactionClaim(address module, address smartAccount, address token, uint256 amount, bytes data))";

string constant SUBCLAIM_STRING =
    "SubscriptionClaim(address module, address smartAccount, address token, uint256 amount, bytes data)";
bytes32 constant SUBCLAIM_HASH = keccak256(abi.encodePacked(SUBCLAIM_STRING));

string constant SUBCLAIM_SPONSOR_STRING =
    "SubscriptionFeeSponsor(address sponsor, SubscriptionClaim(address module, address smartAccount, address token, uint256 amount, bytes data))";
bytes32 constant SUBCLAIM_SPONSOR_HASH = keccak256(abi.encodePacked(SUBCLAIM_SPONSOR_STRING));

struct TransactionClaim {
    address module;
    address smartAccount;
    IERC20 token;
    uint256 amount;
    bytes data;
}

struct TransactionFeeSponsor {
    address sponsor;
    TransactionClaim claim;
}

struct SubscriptionClaim {
    address module;
    address smartAccount;
    IERC20 token;
    uint256 amount;
    bytes data;
}

struct SubscriptionFeeSponsor {
    address sponsor;
    SubscriptionClaim claim;
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
