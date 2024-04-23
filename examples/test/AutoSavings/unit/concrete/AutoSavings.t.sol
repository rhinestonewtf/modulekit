// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { AutoSavings } from "src/AutoSavings/AutoSavings.sol";
import { IERC7579Module } from "modulekit/src/external/ERC7579.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockERC4626 } from "solmate/test/utils/mocks/MockERC4626.sol";
import { MockAccount } from "test/mocks/MockAccount.sol";
import { MockUniswap } from "modulekit/src/integrations/uniswap/MockUniswap.sol";
import { SWAPROUTER_ADDRESS } from "modulekit/src/integrations/uniswap/helpers/MainnetAddresses.sol";
import { SENTINEL } from "sentinellist/SentinelList.sol";

contract AutoSavingsTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AutoSavings internal executor;

    MockAccount internal account;
    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC4626 internal vault1;
    MockERC4626 internal vault2;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address[] _tokens;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        executor = new AutoSavings();
        account = new MockAccount();

        token1 = new MockERC20("USDC", "USDC", 18);
        vm.label(address(token1), "USDC");
        token1.mint(address(account), 1_000_000);

        token2 = new MockERC20("wETH", "wETH", 18);
        vm.label(address(token2), "wETH");
        token2.mint(address(account), 1_000_000);

        vault1 = new MockERC4626(token1, "vUSDC", "vUSDC");
        vault2 = new MockERC4626(token2, "vwETH", "vwETH");

        _tokens = new address[](2);
        _tokens[0] = address(token1);
        _tokens[1] = address(token2);

        // set up mock uniswap
        MockUniswap _mockUniswap = new MockUniswap();
        vm.etch(SWAPROUTER_ADDRESS, address(_mockUniswap).code);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function getConfigs() public returns (AutoSavings.Config[] memory _configs) {
        _configs = new AutoSavings.Config[](2);
        _configs[0] = AutoSavings.Config(100, address(vault1), 1);
        _configs[1] = AutoSavings.Config(100, address(vault2), 1);
    }

    function installFromAccount(address account) public {
        AutoSavings.Config[] memory _configs = getConfigs();

        bytes memory data = abi.encode(_tokens, _configs);

        vm.prank(account);
        executor.onInstall(data);

        for (uint256 i; i < _tokens.length; i++) {
            (uint16 _percentage, address _vault, uint128 _sqrtPriceLimitX96) =
                executor.config(account, _tokens[i]);
            assertEq(_percentage, _configs[i].percentage);
            assertEq(_vault, _configs[i].vault);
            assertEq(_sqrtPriceLimitX96, _configs[i].sqrtPriceLimitX96);
        }

        address[] memory tokens = executor.getTokens(account);
        assertEq(tokens.length, _tokens.length);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        bytes memory data = abi.encode(_tokens, getConfigs());

        executor.onInstall(data);

        vm.expectRevert();
        executor.onInstall(data);
    }

    function test_OnInstallRevertWhen_TokensIsGreaterThanMax() public whenModuleIsNotIntialized {
        // it should revert
        uint256 maxTokens = 100;

        address[] memory tokens = new address[](maxTokens + 1);
        AutoSavings.Config[] memory configs = new AutoSavings.Config[](maxTokens + 1);
        for (uint256 i = 0; i < maxTokens; i++) {
            tokens[i] = makeAddr(vm.toString(i));
            configs[i] = AutoSavings.Config(100, address(0), 0);
        }

        bytes memory data = abi.encode(tokens, configs);

        vm.expectRevert(abi.encodeWithSelector(AutoSavings.TooManyTokens.selector));
        executor.onInstall(data);
    }

    function test_OnInstallRevertWhen_SqrtPriceLimitX96Is0()
        public
        whenModuleIsNotIntialized
        whenTokensIsNotGreaterThanMax
    {
        // it should revert
        AutoSavings.Config[] memory _configs = getConfigs();
        _configs[0].sqrtPriceLimitX96 = 0;

        bytes memory data = abi.encode(_tokens, _configs);

        vm.expectRevert(abi.encodeWithSelector(AutoSavings.InvalidSqrtPriceLimitX96.selector));
        executor.onInstall(data);
    }

    function test_OnInstallWhenSqrtPriceLimitX96IsNot0()
        public
        whenModuleIsNotIntialized
        whenTokensIsNotGreaterThanMax
    {
        // it should set the configs for each token
        // it should add all tokens
        AutoSavings.Config[] memory _configs = getConfigs();

        bytes memory data = abi.encode(_tokens, _configs);

        executor.onInstall(data);

        for (uint256 i; i < _tokens.length; i++) {
            (uint16 _percentage, address _vault, uint128 _sqrtPriceLimitX96) =
                executor.config(address(this), _tokens[i]);
            assertEq(_percentage, _configs[i].percentage);
            assertEq(_vault, _configs[i].vault);
            assertEq(_sqrtPriceLimitX96, _configs[i].sqrtPriceLimitX96);
        }

        address[] memory tokens = executor.getTokens(address(this));
        assertEq(tokens.length, _tokens.length);
    }

    function test_OnUninstallShouldRemoveAllTheConfigs() public {
        // it should remove all the configs
        test_OnInstallWhenSqrtPriceLimitX96IsNot0();

        executor.onUninstall("");

        for (uint256 i; i < _tokens.length; i++) {
            (uint16 _percentage, address _vault, uint128 _sqrtPriceLimitX96) =
                executor.config(address(this), _tokens[i]);
            assertEq(_percentage, 0);
            assertEq(_vault, address(0));
            assertEq(_sqrtPriceLimitX96, 0);
        }
    }

    function test_OnUninstallShouldRemoveAllStoredTokens() public {
        // it should remove all stored tokens
        test_OnInstallWhenSqrtPriceLimitX96IsNot0();

        executor.onUninstall("");

        address[] memory tokens = executor.getTokens(address(this));
        assertEq(tokens.length, 0);
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = executor.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenSqrtPriceLimitX96IsNot0();

        bool isInitialized = executor.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_SetConfigRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        executor.setConfig(_tokens[0], getConfigs()[0]);
    }

    function test_SetConfigRevertWhen_SqrtPriceLimitX96Is0() public whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenSqrtPriceLimitX96IsNot0();

        address token = address(2);
        AutoSavings.Config memory config = AutoSavings.Config(10, address(1), 0);

        vm.expectRevert(abi.encodeWithSelector(AutoSavings.InvalidSqrtPriceLimitX96.selector));
        executor.setConfig(token, config);
    }

    function test_SetConfigWhenSqrtPriceLimitX96IsNot0() public whenModuleIsIntialized {
        // it should set the config for the token
        test_OnInstallWhenSqrtPriceLimitX96IsNot0();

        address token = address(2);
        AutoSavings.Config memory config = AutoSavings.Config(10, address(1), 100);

        executor.setConfig(token, config);

        (uint16 _percentage, address _vault, uint128 _sqrtPriceLimitX96) =
            executor.config(address(this), token);
        assertEq(_percentage, config.percentage);
        assertEq(_vault, config.vault);
        assertEq(_sqrtPriceLimitX96, config.sqrtPriceLimitX96);
    }

    function test_DeleteConfigRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert();
        executor.deleteConfig(SENTINEL, _tokens[1]);
    }

    function test_DeleteConfigWhenModuleIsIntialized() public {
        // it should remove the token from the stored tokens
        // it should delete the config for the token
        test_OnInstallWhenSqrtPriceLimitX96IsNot0();

        executor.deleteConfig(SENTINEL, _tokens[1]);

        (uint16 _percentage, address _vault, uint128 _sqrtPriceLimitX96) =
            executor.config(address(this), _tokens[1]);
        assertEq(_percentage, 0);
        assertEq(_vault, address(0));
        assertEq(_sqrtPriceLimitX96, 0);
    }

    function test_CalcDepositAmountShouldReturnTheDepositAmount() public {
        // it should return the deposit amount
        uint256 amountReceived = 100;
        uint256 percentage = 10;

        uint256 depositAmount = executor.calcDepositAmount(amountReceived, percentage);

        assertEq(depositAmount, 10);
    }

    function test_AutoSaveRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        address token = _tokens[0];
        uint256 amountReceived = 100;

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        executor.autoSave(token, amountReceived);
    }

    function test_AutoSaveWhenTheTokenProvidedIsNotTheUnderlyingAsset()
        public
        whenModuleIsIntialized
    {
        // it should execute a swap to the underlying asset
        // it should deposit the amount to the vault
        // it should emit an AutoSaveExecuted event
        installFromAccount(address(account));
        AutoSavings.Config memory config = AutoSavings.Config(10, address(vault2), 10);

        vm.prank(address(account));
        executor.setConfig(address(token1), config);

        uint256 assetsBefore = vault2.totalAssets();

        uint256 amountReceived = 100;
        uint256 amountSaved = executor.calcDepositAmount(amountReceived, config.percentage);

        vm.expectEmit(true, true, true, true, address(executor));
        emit AutoSavings.AutoSaveExecuted({
            smartAccount: address(account),
            token: address(token1),
            amountReceived: amountSaved
        });

        vm.prank(address(account));
        executor.autoSave(address(token1), amountReceived);

        (uint16 percentage,,) = executor.config(address(account), address(token1));

        uint256 assetsAfter = vault2.totalAssets();
        assertEq(assetsAfter, amountSaved);
    }

    function test_AutoSaveWhenTheTokenProvidedIsTheUnderlyingAsset()
        public
        whenModuleIsIntialized
    {
        // it should deposit the amount to the vault
        // it should emit an AutoSaveExecuted event
        installFromAccount(address(account));

        uint256 assetsBefore = vault1.totalAssets();

        address token = _tokens[0];
        uint256 amountReceived = 100;

        vm.expectEmit(true, true, true, true, address(executor));
        emit AutoSavings.AutoSaveExecuted({
            smartAccount: address(account),
            token: token,
            amountReceived: amountReceived
        });

        vm.prank(address(account));
        executor.autoSave(token, amountReceived);

        (uint16 percentage,,) = executor.config(address(account), token);

        uint256 assetsAfter = vault1.totalAssets();
        assertEq(assetsAfter, assetsBefore + (amountReceived * percentage) / 100);
    }

    function test_NameShouldReturnAutoSavings() public {
        // it should return AutoSavings
        string memory name = executor.name();
        assertEq(name, "AutoSavings");
    }

    function test_VersionShouldReturn100() public {
        // it should return 1.0.0
        string memory version = executor.version();
        assertEq(version, "1.0.0");
    }

    function test_IsModuleTypeWhenTypeIDIs2() public {
        // it should return true
        bool isModuleType = executor.isModuleType(2);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIsNot2() public {
        // it should return false
        bool isModuleType = executor.isModuleType(1);
        assertFalse(isModuleType);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenTokensIsNotGreaterThanMax() {
        _;
    }

    modifier whenModuleIsNotIntialized() {
        _;
    }

    modifier whenModuleIsIntialized() {
        _;
    }
}
