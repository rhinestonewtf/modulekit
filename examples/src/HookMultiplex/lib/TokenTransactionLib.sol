// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

library TokenTransactionLib {
    function isERC20Transfer(bytes4 functionSig) internal pure returns (bool isErc20Transfer) {
        if (functionSig == IERC20.transfer.selector || functionSig == IERC20.transferFrom.selector)
        {
            isErc20Transfer = true;
        }
    }

    function isERC721Transfer(bytes4 functionSig) internal pure returns (bool isErc721Transfer) {
        if (functionSig == IERC721.transferFrom.selector) {
            isErc721Transfer = true;
        }
    }
}
