// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import {
    ERC20Integration,
    ERC4626Integration,
    UniswapV3Integration
} from "modulekit/src/Integrations.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { Execution } from "modulekit/src/Accounts.sol";
import { ERC7579ExecutorBase } from "modulekit/src/Modules.sol";
import { SentinelListLib, SENTINEL } from "sentinellist/SentinelList.sol";

/**
 * @title AutoSavings
 * @dev Module that allows users to automatically save a percentage of their received tokens to a
 * vault
 * @author Rhinestone
 */
contract AutoSavings is ERC7579ExecutorBase {
    using ERC4626Integration for *;
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error TooManyTokens();
    error InvalidSqrtPriceLimitX96();

    uint256 internal constant MAX_TOKENS = 100;

    struct Config {
        uint16 percentage; // percentage to be saved to the vault
        address vault; // address of the vault
        uint128 sqrtPriceLimitX96; // sqrtPriceLimitX96 for UniswapV3 swap
    }

    // account => token => Config
    mapping(address account => mapping(address token => Config)) public config;

    // account => tokens
    mapping(address account => SentinelListLib.SentinelList) tokens;

    event AutoSaveExecuted(
        address indexed smartAccount, address indexed token, uint256 amountReceived
    );

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initializes the module with the tokens and their configurations
     * @dev data is encoded as follows: abi.encode([tokens], [configs])
     * @dev if there are more tokens than configs, the function will revert
     * @dev if there are more configs than tokens, the function will ignore the extra configs
     *
     * @param data encoded data containing the tokens and their configurations
     */
    function onInstall(bytes calldata data) external override {
        // cache the account address
        address account = msg.sender;

        // decode the data to get the tokens and their configurations
        (address[] memory _tokens, Config[] memory _configs) =
            abi.decode(data, (address[], Config[]));

        // initialize the sentinel list
        tokens[account].init();

        // get the length of the tokens
        uint256 tokenLength = _tokens.length;

        // check that the length of tokens is less than max
        if (tokenLength > MAX_TOKENS) revert TooManyTokens();

        // loop through the tokens, add them to the list and set their configurations
        for (uint256 i; i < tokenLength; i++) {
            address _token = _tokens[i];

            // check that sqrtPriceLimitX96 > 0
            // sqrtPriceLimitX96 = 0 means unlimitted slippage
            if (_configs[i].sqrtPriceLimitX96 == 0) {
                revert InvalidSqrtPriceLimitX96();
            }

            config[account][_token] = _configs[i];
            tokens[account].push(_token);
        }
    }

    /**
     * Handles the uninstallation of the module and clears the tokens and configurations
     * @dev the data parameter is not used
     */
    function onUninstall(bytes calldata) external override {
        // cache the account address
        address account = msg.sender;

        // clear the configurations
        (address[] memory tokensArray,) = tokens[account].getEntriesPaginated(SENTINEL, MAX_TOKENS);
        uint256 tokenLength = tokensArray.length;
        for (uint256 i; i < tokenLength; i++) {
            delete config[account][tokensArray[i]];
        }

        // clear the tokens
        tokens[account].popAll();
    }

    /**
     * Checks if the module is initialized
     *
     * @param smartAccount address of the smart account
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        // check if the linked list is initialized for the smart account
        return tokens[smartAccount].alreadyInitialized();
    }

    /**
     * Sets the configuration for a token
     * @dev the function will revert if the module is not initialized
     * @dev this function can be used to set a new configuration or update an existing one
     *
     * @param token address of the token
     * @param _config Config struct containing the configuration
     */
    function setConfig(address token, Config memory _config) public {
        // cache the account address
        address account = msg.sender;
        // check if the module is not initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        // check that sqrtPriceLimitX96 > 0
        // sqrtPriceLimitX96 = 0 means unlimitted slippage
        if (_config.sqrtPriceLimitX96 == 0) {
            revert InvalidSqrtPriceLimitX96();
        }

        // set the configuration for the token
        config[account][token] = _config;

        // add the token to the list if it is not already there
        if (!tokens[account].contains(token)) {
            tokens[account].push(token);
        }
    }

    /**
     * Deletes the configuration for a token
     * @dev the function will revert if the module is not initialized
     *
     * @param prevToken address of the token stored before the token to be deleted
     * @param token address of the token to be deleted
     */
    function deleteConfig(address prevToken, address token) public {
        // cache the account address
        address account = msg.sender;

        // delete the configuration for the token
        delete config[account][token];

        // remove the token from the list
        tokens[account].pop(prevToken, token);
    }

    /**
     * Gets a list of all tokens
     * @dev the function will revert if the module is not initialized
     *
     * @param account address of the account
     */
    function getTokens(address account) external view returns (address[] memory tokensArray) {
        // return the tokens from the list
        (tokensArray,) = tokens[account].getEntriesPaginated(SENTINEL, MAX_TOKENS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Calculates the amount to be saved to the vault
     *
     * @param amountReceived amount received by the user
     * @param percentage percentage to be saved to the vault
     *
     * @return amount to be saved to the vault
     */
    function calcDepositAmount(
        uint256 amountReceived,
        uint256 percentage
    )
        public
        pure
        returns (uint256)
    {
        // calculate the amount to be saved which is the
        // percentage of the amount received
        return (amountReceived * percentage) / 100;
    }

    /**
     * Executes the auto save logic
     *
     * @param token address of the token received
     * @param amountReceived amount received by the user
     */
    function autoSave(address token, uint256 amountReceived) external {
        // cache the account address
        address account = msg.sender;

        // get the configuration for the token
        Config memory conf = config[account][token];
        // get the vault
        IERC4626 vault = IERC4626(conf.vault);

        // check if the config exists and revert if not
        if (address(vault) == address(0)) {
            revert NotInitialized(account);
        }

        // calculate amount that is subject to be saved
        uint256 amountIn = calcDepositAmount(amountReceived, conf.percentage);
        IERC20 tokenToSave;

        // get the underlying token of the vault
        address underlying = vault.asset();

        // if token is not the underlying token, swap it
        if (token != underlying) {
            // create swap from received token to underlying token
            Execution[] memory swap = UniswapV3Integration.approveAndSwap({
                smartAccount: account,
                tokenIn: IERC20(token),
                tokenOut: IERC20(underlying),
                amountIn: amountIn,
                sqrtPriceLimitX96: conf.sqrtPriceLimitX96
            });

            // execute swap on account
            bytes[] memory results = _execute(swap);

            // get return data of swap, and set it as amountIn.
            // this will be the actual amount that is subject to be saved
            amountIn = abi.decode(results[1], (uint256));

            // change tokenToSave to underlying
            tokenToSave = IERC20(underlying);
        } else {
            // set tokenToSave to token since no swap was needed
            tokenToSave = IERC20(token);
        }

        // approve and deposit to vault
        Execution[] memory approveAndDeposit = new Execution[](2);
        approveAndDeposit[0] = ERC20Integration.approve(tokenToSave, address(vault), amountIn);
        approveAndDeposit[1] = ERC4626Integration.deposit(vault, amountIn, account);

        // execute deposit to vault on account
        _execute(approveAndDeposit);

        // emit event
        emit AutoSaveExecuted(account, token, amountIn);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Returns the type of the module
     *
     * @param typeID type of the module
     *
     * @return true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "AutoSavings";
    }

    /**
     * Returns the version of the module
     *
     * @return version of the module
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
