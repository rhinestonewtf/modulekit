// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import {
    ColdStorageFlashloan, FlashloanCallback
} from "src/ColdStorageHook/ColdStorageFlashloan.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { Execution } from "erc7579/lib/ExecutionLib.sol";
import { FlashLoanType } from "modulekit/src/interfaces/Flashloan.sol";

contract ColdStorageFlashloanTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ColdStorageFlashloan internal module;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address[] _whitelist;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        module = new ColdStorageFlashloan();

        _whitelist = new address[](2);
        _whitelist[0] = address(this);
        _whitelist[1] = address(3);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_DataIsNotEmpty() public whenModuleIsIntialized {
        // it should revert
        module.onInstall(abi.encode(_whitelist));

        vm.expectRevert();
        module.onInstall(abi.encode(_whitelist));
    }

    function test_OnInstallWhenDataIsEmpty() public whenModuleIsIntialized {
        // it should return
        module.onInstall(abi.encode(_whitelist));

        module.onInstall("");
    }

    function test_OnInstallWhenModuleIsNotIntialized() public {
        // it should set the whitelist
        module.onInstall(abi.encode(_whitelist));

        address[] memory whitelist = module.getWhitelist(address(this));
        assertEq(whitelist.length, _whitelist.length);
    }

    function test_OnUninstallShouldRemoveTheWhitelist() public {
        // it should remove the whitelist
        test_OnInstallWhenModuleIsNotIntialized();

        module.onUninstall("");

        address[] memory whitelist = module.getWhitelist(address(this));
        assertEq(whitelist.length, 0);
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool initialized = module.isInitialized(address(this));
        assertFalse(initialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenModuleIsNotIntialized();

        bool initialized = module.isInitialized(address(this));
        assertTrue(initialized);
    }

    function test_AddAddressRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert();
        module.addAddress(address(5));
    }

    function test_AddAddressWhenModuleIsIntialized() public {
        // it should add the address to the whitelist
        test_OnInstallWhenModuleIsNotIntialized();

        address[] memory prevWhitelist = module.getWhitelist(address(this));

        module.addAddress(address(5));

        address[] memory whitelist = module.getWhitelist(address(this));
        assertEq(whitelist.length, prevWhitelist.length + 1);
    }

    function test_RemoveAddressRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert();
        module.removeAddress(address(5), address(0));
    }

    function test_RemoveAddressWhenModuleIsIntialized() public {
        // it should remove the address from the whitelist
        test_OnInstallWhenModuleIsNotIntialized();

        address[] memory prevWhitelist = module.getWhitelist(address(this));

        module.removeAddress(_whitelist[1], address(1));

        address[] memory whitelist = module.getWhitelist(address(this));
        assertEq(whitelist.length, prevWhitelist.length - 1);
    }

    function test_GetWhitelist() public {
        // it should return the whitelist
        test_OnInstallWhenModuleIsNotIntialized();

        address[] memory whitelist = module.getWhitelist(address(this));
        assertEq(whitelist.length, _whitelist.length);
    }

    function test_GetTokengatedTxHashShouldReturnTheTokengatedTxHash() public {
        // it should return the tokengatedTxHash
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution(address(1), 0, "");

        bytes32 hash = module.getTokengatedTxHash(FlashLoanType.ERC20, executions, 1);
    }

    function test_OnFlashLoanRevertWhen_TheSenderIsNotAllowed() public {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        address borrower = address(1);
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution(address(1), 0, "");

        bytes memory data = abi.encode(FlashLoanType.ERC20, bytes("signature"), executions);

        bytes memory callData =
            abi.encodeCall(FlashloanCallback.onFlashLoan, (address(1), address(0), 0, 0, data));

        (bool success,) = address(module).call(abi.encodePacked(callData, address(2)));
        assertFalse(success);
    }

    function test_OnFlashLoanRevertWhen_TheSignatureIsInvalid() public whenTheSenderIsAllowed {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        address borrower = address(1);
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution(address(1), 0, "");

        bytes memory data = abi.encode(FlashLoanType.ERC20, "", executions);

        bytes memory callData =
            abi.encodeCall(FlashloanCallback.onFlashLoan, (address(1), address(0), 0, 0, data));

        (bool success,) = address(module).call(abi.encodePacked(callData, address(this)));
        assertFalse(success);
    }

    function test_OnFlashLoanWhenTheSignatureIsValid() public whenTheSenderIsAllowed {
        // it should execute the flashloan
        // it should increment the nonce
        // it should return the right hash
        test_OnInstallWhenModuleIsNotIntialized();

        address borrower = address(1);
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution(address(1), 0, "");

        bytes memory data = abi.encode(FlashLoanType.ERC20, bytes("signature"), executions);

        bytes memory callData =
            abi.encodeCall(FlashloanCallback.onFlashLoan, (address(1), address(0), 0, 0, data));

        (bool success,) = address(module).call(abi.encodePacked(callData, address(this)));
        assertTrue(success);
    }

    function test_NameShouldReturnFlashloanCallback() public {
        // it should return FlashloanCallback
        string memory name = module.name();
        assertEq(name, "FlashloanCallback");
    }

    function test_VersionShouldReturn100() public {
        // it should return 1.0.0
        string memory version = module.version();
        assertEq(version, "1.0.0");
    }

    function test_IsModuleTypeWhenTypeIDIs2And3() public {
        // it should return true
        bool isModuleType = module.isModuleType(2);
        assertTrue(isModuleType);

        isModuleType = module.isModuleType(3);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIsNot2Or3() public {
        // it should return false
        bool isModuleType = module.isModuleType(1);
        assertFalse(isModuleType);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenModuleIsIntialized() {
        _;
    }

    modifier whenTheSenderIsAllowed() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      CALLBACKS
    //////////////////////////////////////////////////////////////////////////*/

    function executeFromExecutor(
        bytes32 mode,
        bytes calldata executionCalldata
    )
        external
        payable
        returns (bytes[] memory returnData)
    { }

    function isValidSignature(
        bytes32 _hash,
        bytes memory _signature
    )
        public
        view
        returns (bytes4 magicValue)
    {
        if (_signature.length == 0) {
            return 0xffffffff;
        }
        return 0x1626ba7e;
    }
}
