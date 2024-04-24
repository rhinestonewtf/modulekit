// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Solarray } from "solarray/Solarray.sol";
import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp,
    AccountInstance
} from "test/BaseIntegration.t.sol";
import { ColdStorageHook, Execution } from "src/ColdStorageHook/ColdStorageHook.sol";
import { ColdStorageFlashloan } from "src/ColdStorageHook/ColdStorageFlashloan.sol";
import {
    FlashLoanType,
    IERC3156FlashBorrower,
    IERC3156FlashLender
} from "modulekit/src/interfaces/Flashloan.sol";
import { OwnableExecutor } from "src/OwnableExecutor/OwnableExecutor.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import {
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "modulekit/src/external/ERC7579.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";
import { MockTarget } from "../../../mocks/MockTarget.sol";

import "forge-std/interfaces/IERC20.sol";
import "forge-std/interfaces/IERC721.sol";

contract FlashloanTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ColdStorageHook internal hook;
    ColdStorageFlashloan internal flashloanCallback;
    OwnableExecutor internal executor;
    MockERC20 internal token;
    MockERC721 internal token721;
    MockTarget internal target;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    AccountInstance internal owner;
    uint128 _waitPeriod;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();
        target = new MockTarget();
        token721 = new MockERC721("ERC721", "ERC721");
        hook = new ColdStorageHook();
        flashloanCallback = new ColdStorageFlashloan();
        executor = new OwnableExecutor();

        owner = makeAccountInstance("owner");
        vm.deal(address(owner.account), 10 ether);

        token = new MockERC20("USDC", "USDC", 18);
        vm.label(address(token), "USDC");
        token.mint(address(instance.account), 1_000_000);
        token721.mint(address(instance.account), 10);

        _waitPeriod = 100;
        bytes memory init = abi.encodePacked(
            IERC3156FlashLender.flashLoan.selector,
            bytes1(0),
            abi.encodePacked(_waitPeriod, owner.account)
        );

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encodePacked(address(owner.account))
        });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_FALLBACK,
            module: address(hook),
            data: init
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(hook),
            data: ""
        });
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });

        address[] memory allowedCallback = Solarray.addresses(instance.account);
        init = abi.encodePacked(
            IERC3156FlashBorrower.onFlashLoan.selector, bytes1(0), abi.encode(allowedCallback)
        );
        owner.installModule({
            moduleTypeId: MODULE_TYPE_FALLBACK,
            module: address(flashloanCallback),
            data: init
        });
        owner.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(flashloanCallback),
            data: ""
        });

        owner.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(instance.defaultValidator),
            data: ""
        });
    }

    function test_flashloanERC20() public {
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(target),
            value: 0,
            callData: abi.encodeCall(MockTarget.setValue, (1337))
        });
        executions[1] = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (instance.account, 100))
        });

        FlashLoanType flashLoanType = FlashLoanType.ERC20;
        bytes memory signature = abi.encodePacked(instance.defaultValidator, "test");

        vm.startPrank(address(executor));
        IERC3156FlashLender(address(instance.account)).flashLoan({
            receiver: IERC3156FlashBorrower(address(owner.account)),
            token: address(token),
            amount: 100,
            data: abi.encode(flashLoanType, signature, executions)
        });
    }

    function test_flashloanERC721() public {
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(target),
            value: 0,
            callData: abi.encodeCall(MockTarget.setValue, (1337))
        });
        executions[1] = Execution({
            target: address(token721),
            value: 0,
            callData: abi.encodeCall(IERC721.transferFrom, (owner.account, instance.account, 10))
        });

        FlashLoanType flashLoanType = FlashLoanType.ERC721;
        bytes memory signature = abi.encodePacked(instance.defaultValidator, "test");

        vm.startPrank(address(executor));
        IERC3156FlashLender(address(instance.account)).flashLoan({
            receiver: IERC3156FlashBorrower(address(owner.account)),
            token: address(token721),
            amount: 10,
            data: abi.encode(flashLoanType, signature, executions)
        });
    }
}
