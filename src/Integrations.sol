// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

/* solhint-disable no-unused-import */

/*//////////////////////////////////////////////////////////////
                             ERCs
//////////////////////////////////////////////////////////////*/

import { ERC20Integration } from "./integrations/ERC20.sol";
import { ERC721Integration } from "./integrations/ERC721.sol";
import { ERC4626Integration } from "./integrations/ERC4626.sol";

/*//////////////////////////////////////////////////////////////
                            UNIV3
//////////////////////////////////////////////////////////////*/

import { UniswapV3Integration, SWAPROUTER_ADDRESS } from "./integrations/uniswap/v3/Uniswap.sol";
