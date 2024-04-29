// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { ColdStorageFlashloan } from "src/ColdStorageFlashloan/ColdStorageFlashloan.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { IERC3156FlashLender } from "modulekit/src/interfaces/Flashloan.sol";

contract ColdStorageFlashloanTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ColdStorageFlashloan internal module;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _owner;
    uint128 _waitPeriod;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        module = new ColdStorageFlashloan();

        _owner = makeAddr("owner");
        _waitPeriod = uint128(100);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_DataIsNotEmpty() external whenModuleIsIntialized {
        // it should revert
    }

    function test_OnInstallWhenDataIsEmpty() external whenModuleIsIntialized {
        // it should return
    }

    function test_OnInstallWhenModuleIsNotIntialized() external {
        // it should set the whitelist
    }

    function test_OnUninstallShouldRemoveTheWhitelist() external {
        // it should remove the whitelist
    }

    function test_IsInitializedWhenModuleIsNotIntialized() external {
        // it should return false
    }

    function test_IsInitializedWhenModuleIsIntialized() external {
        // it should return true
    }

    function test_GetTokengatedTxHashShouldReturnTheTokengatedTxHash() external {
        // it should return the tokengatedTxHash
    }

    function test_OnFlashLoanRevertWhen_TheSenderIsNotAllowed() external {
        // it should revert
    }

    function test_OnFlashLoanRevertWhen_TheSignatureIsInvalid() external whenTheSenderIsAllowed {
        // it should revert
    }

    function test_OnFlashLoanWhenTheSignatureIsValid() external whenTheSenderIsAllowed {
        // it should execute the flashloan
        // it should increment the nonce
        // it should rerturn the right hash
    }

    function test_NameShouldReturnFlashloanCallback() external {
        // it should return FlashloanCallback
    }

    function test_VersionShouldReturn100() external {
        // it should return 1.0.0
    }

    function test_IsModuleTypeWhenTypeIDIs2And3() external {
        // it should return true
    }

    function test_IsModuleTypeWhenTypeIDIsNot2Or3() external {
        // it should return false
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
}
