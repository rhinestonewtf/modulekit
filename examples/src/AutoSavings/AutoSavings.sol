// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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

contract AutoSavings is ERC7579ExecutorBase {
    using ERC4626Integration for *;
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct Config {
        uint16 percentage; // percentage to be saved to the vault
        address vault;
        uint128 sqrtPriceLimitX96;
    }

    mapping(address account => mapping(address token => Config)) public config;
    mapping(address account => SentinelListLib.SentinelList) tokens;

    event AutoSaveExecuted(
        address indexed smartAccount, address indexed token, uint256 amountReceived
    );

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        (address[] memory _tokens, Config[] memory _configs) =
            abi.decode(data, (address[], Config[]));

        tokens[account].init();

        uint256 tokenLength = _tokens.length;
        for (uint256 i; i < tokenLength; i++) {
            address _token = _tokens[i];

            config[account][_token] = _configs[i];
            tokens[account].push(_token);
        }
    }

    function onUninstall(bytes calldata) external override {
        // TODO
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return tokens[smartAccount].alreadyInitialized();
    }

    function setConfig(address token, Config memory _config) public {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        // TODO check for min / max sqrtPriceLimitX96

        config[account][token] = _config;
        if (!tokens[account].contains(token)) {
            tokens[account].push(token);
        }
    }

    function deleteConfig(address prevToken, address token) public {
        address account = msg.sender;

        delete config[account][token];
        tokens[account].pop(prevToken, token);
    }

    function getTokens(address account) external view returns (address[] memory tokensArray) {
        // TODO
        (tokensArray,) = tokens[account].getEntriesPaginated(SENTINEL, 10);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function calcDepositAmount(
        uint256 amountReceived,
        uint256 percentage
    )
        public
        pure
        returns (uint256)
    {
        return (amountReceived * percentage) / 100;
    }

    function autoSave(address token, uint256 amountReceived) external {
        // get vault that was configured for this token
        address account = msg.sender;

        Config memory conf = config[account][token];
        IERC4626 vault = IERC4626(conf.vault);

        if (address(vault) == address(0)) {
            revert NotInitialized(account);
        }

        // calc amount that is subject to be saved
        uint256 amountIn = calcDepositAmount(amountReceived, conf.percentage);
        IERC20 tokenToSave;

        // if underlying asset is not the same as the token, add a swap
        address underlying = vault.asset();
        if (token != underlying) {
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
            tokenToSave = IERC20(token);
        } // set tokenToSave to token since no swap was needed

        // approve and deposit to vault
        Execution[] memory approveAndDeposit = new Execution[](2);
        approveAndDeposit[0] = ERC20Integration.approve(tokenToSave, address(vault), amountIn);
        approveAndDeposit[1] = ERC4626Integration.deposit(vault, amountIn, account);

        // execute deposit to vault on account
        _execute(approveAndDeposit);

        emit AutoSaveExecuted(account, token, amountIn);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function name() external pure virtual returns (string memory) {
        return "AutoSavings";
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
