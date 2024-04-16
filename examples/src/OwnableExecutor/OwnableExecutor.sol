// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { ERC7579ExecutorBase } from "modulekit/src/Modules.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { SentinelListLib, SENTINEL } from "sentinellist/SentinelList.sol";

contract OwnableExecutor is ERC7579ExecutorBase {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error UnauthorizedAccess();
    error OwnerAlreadyExists(address owner);
    error InvalidOwner(address owner);

    mapping(address subAccount => SentinelListLib.SentinelList) accountOwners;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        address owner = address(bytes20(data[0:20]));
        accountOwners[account].init();
        accountOwners[account].push(owner);
    }

    function onUninstall(bytes calldata) external override {
        //TODO
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return accountOwners[msg.sender].alreadyInitialized();
    }

    function addOwner(address owner) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        if (owner == address(0)) {
            revert InvalidOwner(owner);
        }

        if (accountOwners[account].contains(owner)) {
            revert OwnerAlreadyExists(owner);
        }

        accountOwners[account].push(owner);
    }

    function removeOwner(address prevOwner, address owner) external {
        accountOwners[msg.sender].pop(prevOwner, owner);
    }

    function getOwners(address account) external view returns (address[] memory ownersArray) {
        // TODO: return length
        (ownersArray,) = accountOwners[account].getEntriesPaginated(SENTINEL, 10);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function executeOnOwnedAccount(
        address ownedAccount,
        bytes calldata callData
    )
        external
        payable
    {
        if (!accountOwners[ownedAccount].contains(msg.sender)) {
            revert UnauthorizedAccess();
        }

        IERC7579Account(ownedAccount).executeFromExecutor(ModeLib.encodeSimpleSingle(), callData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "OwnableExecutor";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
