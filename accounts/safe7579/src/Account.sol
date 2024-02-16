// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { SafeERC7579 } from "./SafeERC7579.sol";

import "@safe-global/safe-contracts/contracts/Safe.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";

contract AccountFactory is Test {
    // singletons
    SafeERC7579 erc7579Mod = new SafeERC7579();
    Safe safeImpl = new Safe();
    Safe safe;

    function safeSetup(
        address[] memory signers,
        uint256 threshold,
        address defaultValidator,
        address defaultExecutor
    )
        public
        returns (address _clone)
    {
        Safe clone = Safe(payable(LibClone.clone(address(safeImpl))));
        _clone = address(clone);

        clone.setup({
            _owners: signers,
            _threshold: threshold,
            to: address(0), // optional delegatecall
            data: "",
            fallbackHandler: address(erc7579Mod),
            paymentToken: address(0), // optional payment token
            payment: 0,
            paymentReceiver: payable(address(0)) // optional payment receiver
         });

        vm.startPrank(address(clone));
        clone.enableModule(address(erc7579Mod));
        address[] memory validators = new address[](1);
        validators[0] = address(defaultValidator);

        address[] memory executors = new address[](1);
        executors[0] = address(defaultExecutor);
        erc7579Mod.initializeAccount(abi.encode(validators, executors));
        vm.stopPrank();
    }
}
