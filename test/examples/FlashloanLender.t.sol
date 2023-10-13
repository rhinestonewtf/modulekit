// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount
} from "../../src/test/utils/safe-base/RhinestoneModuleKit.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";

import "../../src/examples/flashloan/FlashloanLenderModule.sol";

import "../../src/examples/flashloan/IERC3156FlashBorrower.sol";
import "../../src/examples/flashloan/IERC3156FlashLender.sol";

import "forge-std/console2.sol";

contract TokenBorrower is IERC3156FlashBorrower {
    function onFlashLoan(
        address lender,
        address token,
        uint256 tokenId,
        uint256 fee,
        bytes calldata data
    )
        external
        override
        returns (bytes32)
    {
        console2.log("FlashloanBorrower has the token");
        address feeToken = IERC6682(lender).flashFeeToken();
        IERC20(feeToken).approve(lender, fee);
        IERC721(token).transferFrom(address(this), lender, tokenId);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function initLending(
        address lender,
        address manager,
        address token,
        uint256 tokenId
    )
        external
    {
        IERC3156FlashLender(lender).flashLoan(
            IERC3156FlashBorrower(address(this)), token, tokenId, abi.encode(manager, bytes(""))
        );
    }
}

contract ModuleKitTemplateTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount; // <-- library that wraps smart account actions for easier testing

    RhinestoneAccount instance; // <-- this is a rhinestone smart account instance
    address receiver;
    MockERC20 token;
    MockERC721 nft;

    FlashloanLenderModule flashloan;

    TokenBorrower borrower;

    function setUp() public {
        // setting up receiver address. This is the EOA that this test is sending funds to
        receiver = makeAddr("receiver");

        // setting up mock executor and token
        token = new MockERC20("", "", 18);

        borrower = new TokenBorrower();

        nft = new MockERC721("", "");

        flashloan = new FlashloanLenderModule();

        // create a new rhinestone account instance
        instance = makeRhinestoneAccount("1");

        // dealing ether and tokens to newly created smart account
        vm.deal(instance.account, 10 ether);
        token.mint(instance.account, 100 ether);
        token.mint(address(borrower), 1000);
        nft.mint(instance.account, 1);
    }

    function testFlashloan() public {
        instance.addFallback({
            handleFunctionSig: IERC6682.availableForFlashLoan.selector,
            isStatic: true,
            handler: address(flashloan)
        });

        instance.addFallback({
            handleFunctionSig: IERC6682.flashFeeToken.selector,
            isStatic: true,
            handler: address(flashloan)
        });

        instance.addFallback({
            handleFunctionSig: IERC6682.flashFee.selector,
            isStatic: true,
            handler: address(flashloan)
        });

        instance.addFallback({
            handleFunctionSig: IERC3156FlashLender.flashLoan.selector,
            isStatic: false,
            handler: address(flashloan)
        });
        instance.addExecutor(address(flashloan));

        vm.startPrank(instance.account);
        flashloan.setFeeToken(address(token));
        flashloan.setFee(address(nft), 1, 1000);
        vm.stopPrank();

        borrower.initLending(
            instance.account, address(instance.aux.executorManager), address(nft), 1
        );
    }
}
