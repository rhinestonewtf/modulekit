// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { SafeERC7579 } from "src/SafeERC7579.sol";
import { ModuleManager } from "src/core/ModuleManager.sol";
import { MockValidator } from "./mocks/MockValidator.sol";
import { MockExecutor } from "./mocks/MockExecutor.sol";
import { MockFallback } from "./mocks/MockFallback.sol";
import { MockTarget } from "modulekit/src/mocks/MockTarget.sol";

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { LibClone } from "solady/utils/LibClone.sol";

import "./dependencies/EntryPoint.sol";

contract Bootstrap is ModuleManager {
    function singleInitMSA(
        address validator,
        bytes calldata validatorData,
        address executor,
        bytes calldata executorData
    )
        external
    {
        // init validator
        _installValidator(address(validator), validatorData);
        _installExecutor(executor, executorData);
    }
}

contract TestBaseUtil is Test {
    // singletons
    SafeERC7579 internal erc7579Mod;
    Safe internal safeImpl;
    Safe internal safe;
    IEntryPoint internal entrypoint = IEntryPoint(ENTRYPOINT_ADDR);

    MockValidator internal defaultValidator;
    MockExecutor internal defaultExecutor;
    Bootstrap internal bootstrap;

    MockTarget internal target;

    Account internal signer1;
    Account internal signer2;

    function setUp() public virtual {
        // Set up EntryPoint
        etchEntrypoint();

        // Set up MSA and Factory
        bootstrap = new Bootstrap();
        erc7579Mod = new SafeERC7579();
        safeImpl = new Safe();

        signer1 = makeAccount("signer1");
        signer2 = makeAccount("signer2");

        // Set up Modules
        defaultExecutor = new MockExecutor();
        defaultValidator = new MockValidator();

        // Set up Target for testing
        target = new MockTarget();

        (safe,) = safeSetup();
        vm.deal(address(safe), 100 ether);
    }

    function safeSetup() internal returns (Safe clone, address _defaultValidator) {
        clone = Safe(payable(LibClone.clone(address(safeImpl))));
        _defaultValidator = address(defaultValidator);

        address[] memory signers = new address[](2);
        signers[0] = signer1.addr;
        signers[1] = signer2.addr;

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
        erc7579Mod.initializeAccount(
            abi.encode(
                address(bootstrap),
                abi.encodeCall(
                    Bootstrap.singleInitMSA, (_defaultValidator, "", address(defaultExecutor), "")
                )
            )
        );
        vm.stopPrank();
    }

    function getNonce(address account, address validator) internal view returns (uint256 nonce) {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        nonce = entrypoint.getNonce(address(account), key);
    }

    function getDefaultUserOp() internal pure returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }
}
