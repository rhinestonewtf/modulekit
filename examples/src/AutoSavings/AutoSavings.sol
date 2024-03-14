// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC20Integration, ERC4626Integration } from "modulekit/src/Integrations.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { UniswapV3Integration } from "modulekit/src/Integrations.sol";
import { Execution } from "modulekit/src/Accounts.sol";
import { ERC7579ExecutorBase, SessionKeyBase } from "modulekit/src/Modules.sol";

contract AutoSavingToVault is ERC7579ExecutorBase, SessionKeyBase {
    using ERC4626Integration for *;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct Params {
        address token;
        uint256 amountReceived;
    }

    struct ScopedAccess {
        address sessionKeySigner;
        address onlyToken;
        uint256 maxAmount;
    }

    struct Config {
        uint16 percentage; // percentage to be saved to the vault
        address vault;
        uint128 sqrtPriceLimitX96;
    }

    mapping(address account => mapping(address token => Config)) internal _config;

    event AutoSaveExecuted(
        address indexed smartAccount, address indexed token, uint256 amountReceived
    );

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function getConfig(address account, address token) public view returns (Config memory) {
        return _config[account][token];
    }

    function setConfig(address token, Config memory config) public {
        // TODO check for min / max sqrtPriceLimitX96
        _config[msg.sender][token] = config;
    }

    function onInstall(bytes calldata data) external override {
        if (data.length == 0) return;
        (address[] memory tokens, Config[] memory log) = abi.decode(data, (address[], Config[]));

        for (uint256 i; i < tokens.length; i++) {
            _config[msg.sender][tokens[i]] = log[i];
        }
    }

    function onUninstall(bytes calldata data) external override {
        if (data.length == 0) return;
        address[] memory tokens = abi.decode(data, (address[]));
        for (uint256 i; i < tokens.length; i++) {
            delete _config[msg.sender][tokens[i]];
        }
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        // Todo
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

    function autoSave(Params calldata params) external {
        // get vault that was configured for this token
        Config memory conf = _config[msg.sender][params.token];
        IERC4626 vault = IERC4626(conf.vault);

        // calc amount that is subject to be saved
        uint256 amountIn = calcDepositAmount(params.amountReceived, conf.percentage);
        IERC20 tokenToSave;

        // if underlying asset is not the same as the token, add a swap
        address underlying = vault.asset();
        if (params.token != underlying) {
            Execution[] memory swap = UniswapV3Integration.approveAndSwap({
                smartAccount: msg.sender,
                tokenIn: IERC20(params.token),
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
            tokenToSave = IERC20(params.token);
        } // set tokenToSave to params.token since no swap was needed

        // approve and deposit to vault
        Execution[] memory approveAndDeposit = new Execution[](2);
        approveAndDeposit[0] = ERC20Integration.approve(tokenToSave, address(vault), amountIn);
        approveAndDeposit[1] = ERC4626Integration.deposit(vault, amountIn, msg.sender);

        // execute deposit to vault on account
        _execute(approveAndDeposit);

        emit AutoSaveExecuted(msg.sender, params.token, amountIn);
    }

    function validateSessionParams(
        address destinationContract,
        uint256 callValue,
        bytes calldata callData,
        bytes calldata _sessionKeyData,
        bytes calldata /*_callSpecificData*/
    )
        public
        virtual
        override
        onlyFunctionSig(this.autoSave.selector, bytes4(callData[:4]))
        onlyZeroValue(callValue)
        onlyThis(destinationContract)
        returns (address)
    {
        ScopedAccess memory access = abi.decode(_sessionKeyData, (ScopedAccess));
        Params memory params = abi.decode(callData[4:], (Params));

        if (params.token != access.onlyToken) {
            revert InvalidRecipient();
        }

        if (params.amountReceived > access.maxAmount) {
            revert InvalidRecipient();
        }

        return access.sessionKeySigner;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function name() external pure virtual returns (string memory) {
        return "AutoSaving";
    }

    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }
}
