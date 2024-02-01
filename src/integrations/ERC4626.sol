// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { IERC7579Account, Execution } from "../Accounts.sol";

library ERC4626Integration {
    function deposit(
        IERC4626 vault,
        uint256 assets,
        address receiver
    )
        internal
        pure
        returns (Execution memory exec)
    {
        exec = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.deposit, (assets, receiver))
        });
    }

    function mint(
        IERC4626 vault,
        uint256 shares,
        address receiver
    )
        internal
        pure
        returns (Execution memory exec)
    {
        exec = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.mint, (shares, receiver))
        });
    }

    function withdraw(
        IERC4626 vault,
        uint256 assets,
        address receiver,
        address owner
    )
        internal
        pure
        returns (Execution memory exec)
    {
        exec = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.withdraw, (assets, receiver, owner))
        });
    }

    function redeem(
        IERC4626 vault,
        uint256 shares,
        address receiver,
        address owner
    )
        internal
        pure
        returns (Execution memory exec)
    {
        exec = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.redeem, (shares, receiver, owner))
        });
    }
}
