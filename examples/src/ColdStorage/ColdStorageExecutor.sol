// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { ERC7579ExecutorBase } from "modulekit/src/Modules.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";

contract ColdStorageExecutor is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error UnauthorizedAccess();

    mapping(address subAccount => address owner) private _subAccountOwner;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata data) external override {
        address owner = address(bytes20(data[0:20]));
        _subAccountOwner[msg.sender] = owner;
    }

    function onUninstall(bytes calldata) external override {
        delete _subAccountOwner[msg.sender];
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return _subAccountOwner[smartAccount] != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function executeOnSubAccount(address subAccount, bytes calldata callData) external payable {
        if (msg.sender != _subAccountOwner[subAccount]) {
            revert UnauthorizedAccess();
        }

        IERC7579Account(subAccount).executeFromExecutor(ModeLib.encodeSimpleSingle(), callData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
