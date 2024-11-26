// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { ERC7579StatelessValidatorBase } from "../ERC7579StatelessValidatorBase.sol";

contract MockStatelessValidator is ERC7579StatelessValidatorBase {
    function onInstall(bytes calldata data) external virtual { }

    function onUninstall(bytes calldata data) external virtual { }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == 7;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function validateSignatureWithData(
        bytes32,
        bytes calldata,
        bytes calldata
    )
        external
        pure
        override
        returns (bool validSig)
    {
        return true;
    }
}
