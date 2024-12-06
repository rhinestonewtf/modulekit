// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";
import { IStatelessValidator } from "./interfaces/IStatelessValidator.sol";

abstract contract ERC7579StatelessValidatorBase is ERC7579ModuleBase, IStatelessValidator {
    function validateSignatureWithData(
        bytes32,
        bytes calldata,
        bytes calldata
    )
        external
        view
        virtual
        returns (bool validSig);
}
