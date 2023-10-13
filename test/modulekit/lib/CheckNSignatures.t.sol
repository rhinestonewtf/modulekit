// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../../../src/modulekit/lib/CheckNSignatures.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";

/// @title CheckNSignaturesTest
/// @author zeroknots
contract CheckNSignaturesTest is Test {
    function setUp() public { }

    function testCheckOneSignature() public {
        (address signer1, uint256 signerPk1) = makeAddrAndKey("signer1");

        bytes memory data = abi.encodePacked("DATA TO SIGN");

        bytes32 dataHash = keccak256(data);

        bytes memory signatures;
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(signerPk1, dataHash);
        signatures = abi.encodePacked(r, s, v);

        address[] memory recovered = CheckSignatures.recoverNSignatures(dataHash, signatures, 1);

        assertEq(signer1, recovered[0]);
    }

    function testCheckTwoSignatures() public {
        (address signer1, uint256 signerPk1) = makeAddrAndKey("signer1");
        (address signer2, uint256 signerPk2) = makeAddrAndKey("signer2");

        bytes memory data = abi.encodePacked("DATA TO SIGN");

        bytes32 dataHash = keccak256(data);

        bytes memory signatures;
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(signerPk1, dataHash);
        signatures = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(signerPk2, dataHash);
        signatures = abi.encodePacked(signatures, abi.encodePacked(r, s, v));

        address[] memory recovered = CheckSignatures.recoverNSignatures(dataHash, signatures, 2);

        assertEq(signer1, recovered[0]);
        assertEq(signer2, recovered[1]);
    }
}
