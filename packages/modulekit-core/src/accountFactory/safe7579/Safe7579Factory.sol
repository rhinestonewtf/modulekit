// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Base.sol";
import { SafeERC7579 } from "@rhinestone/safe7579/src/SafeERC7579.sol";
import "@safe-global/safe-contracts/contracts/Safe.sol";
import { LibClone } from "solady/utils/LibClone.sol";

import { BootstrapSafe } from "./BootstrapSafe.sol";

abstract contract Safe7579Factory is TestBase {
    // singletons

    SafeERC7579 internal erc7579Mod;
    Safe internal safeImpl;

    BootstrapSafe internal bootstrapSafe;

    constructor() {
        // Set up MSA and Factory
        erc7579Mod = new SafeERC7579();
        safeImpl = new Safe();
        bootstrapSafe = new BootstrapSafe();
    }

    function _createSafe(bytes32 salt, bytes calldata initCode) internal returns (address safe) {
        bytes32 _salt = _getSalt(salt, initCode);
        Safe clone =
            Safe(payable(LibClone.cloneDeterministic(0, address(safeImpl), initCode, _salt)));

        address[] memory signers = new address[](2);
        signers[0] = address(0x12345);
        signers[1] = address(0x54321);

        clone.setup({
            _owners: signers,
            _threshold: 2,
            to: address(0), // optional delegatecall
            data: "",
            fallbackHandler: address(erc7579Mod),
            paymentToken: address(0), // optional payment token
            payment: 0,
            paymentReceiver: payable(address(0)) // optional payment receiver
         });

        vm.startPrank(address(clone));
        clone.enableModule(address(erc7579Mod));
        erc7579Mod.initializeAccount(initCode);
        vm.stopPrank();

        return address(clone);
    }

    function getAddressSafe(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        virtual
        returns (address)
    {
        bytes32 _salt = _getSalt(salt, initCode);
        return
            LibClone.predictDeterministicAddress(address(safeImpl), initCode, _salt, address(this));
    }

    function _getSalt(
        bytes32 _salt,
        bytes memory initCode
    )
        public
        pure
        virtual
        returns (bytes32 salt);
}
