// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

/* solhint-disable no-unused-import */
/*//////////////////////////////////////////////////////////////
                             ERCs
//////////////////////////////////////////////////////////////*/
import { IERC1271, EIP1271_MAGIC_VALUE } from "src/module-bases/interfaces/IERC1271.sol";
import { IERC7484 } from "src/module-bases/interfaces/IERC7484.sol";

/*//////////////////////////////////////////////////////////////
                             Modules
//////////////////////////////////////////////////////////////*/
import { IStatelessValidator } from "src/module-bases/interfaces/IStatelessValidator.sol";

/*//////////////////////////////////////////////////////////////
                             Misc
//////////////////////////////////////////////////////////////*/
import {
    FlashLoanType,
    IERC6682,
    IERC3156FlashLender,
    IERC3156FlashBorrower
} from "src/module-bases/interfaces/Flashloan.sol";
