// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579HookDestruct } from "modulekit/src/modules/ERC7579HookDestruct.sol";
import { IERC7484 } from "modulekit/src/interfaces/IERC7484.sol";

contract RegistryHook is ERC7579HookDestruct {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    event RegistrySet(address indexed smartAccount, address registry);

    mapping(address account => address) registry;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        address registryAddress = address(uint160(bytes20(data[0:20])));

        registry[account] = registryAddress;
        emit RegistrySet({ smartAccount: account, registry: registryAddress });

        // TODO add attesters?
    }

    function onUninstall(bytes calldata data) external override {
        delete registry[msg.sender];
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return registry[smartAccount] != address(0);
    }

    function setRegistry(address _registry) external {
        registry[msg.sender] = _registry;
        emit RegistrySet(msg.sender, _registry);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function onInstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        IERC7484(registry[msg.sender]).checkForAccount({
            smartAccount: msg.sender,
            module: module,
            moduleType: moduleType
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure virtual returns (string memory) {
        return "RegistryHook";
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_HOOK;
    }
}
