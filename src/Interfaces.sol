// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

/* solhint-disable no-unused-import */

/*//////////////////////////////////////////////////////////////
                           ERCs/EIPs
//////////////////////////////////////////////////////////////*/

import { IERC1271, EIP1271_MAGIC_VALUE } from "./module-bases/interfaces/IERC1271.sol";
import { IERC7484 } from "./module-bases/interfaces/IERC7484.sol";
import {
    IERC6682,
    IERC3156FlashLender,
    IERC3156FlashBorrower
} from "./module-bases/interfaces/Flashloan.sol";
import { IERC712 } from "./module-bases/interfaces/IERC712.sol";

/*//////////////////////////////////////////////////////////////
                            MODULES
//////////////////////////////////////////////////////////////*/

import { IStatelessValidator } from "./module-bases/interfaces/IStatelessValidator.sol";
import { IPolicy } from "./module-bases/interfaces/IPolicy.sol";

/*//////////////////////////////////////////////////////////////
                            TYPES
//////////////////////////////////////////////////////////////*/

import { FlashLoanType } from "./module-bases/interfaces/Flashloan.sol";
