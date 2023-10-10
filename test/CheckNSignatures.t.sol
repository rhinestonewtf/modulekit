// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/modulekit/lib/CheckNSignatures.sol";

import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";
/// @title CheckNSignaturesTest
/// @author zeroknots

contract CheckNSignaturesTest is Test {
    function setUp() public { }

    function testCheckOneSignature() public {
        (address signer1, uint256 signerPk1) = makeAddrAndKey("signer1");
        (address signer2, uint256 signerPk2) = makeAddrAndKey("signer2");

        console2.log("signer1", signer1);
        console2.log("signer2", signer2);
        console2.log("this", address(this));

        bytes memory data = abi.encodePacked("DATA TO SIGN");

        bytes32 dataHash = keccak256(data);

        bytes memory signatures;
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(signerPk1, dataHash);
        address signer = address(uint160(uint256(r)));
        console2.log("signerDecode", signer);
        signatures = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(signerPk2, dataHash);
        signatures = abi.encodePacked(signatures, abi.encodePacked(r, s, v));

        address[] memory recovered = CheckSignatures.recoverNSignatures(dataHash, signatures, 2);

        assertEq(signer1, recovered[0]);
        assertEq(signer2, recovered[1]);
    }
}
