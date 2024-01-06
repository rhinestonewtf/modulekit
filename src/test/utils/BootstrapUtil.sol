// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    ERC7579Bootstrap,
    ERC7579BootstrapConfig,
    IERC7579Module
} from "../../external/ERC7579.sol";

contract BootstrapUtil {
    function _makeBootstrapConfig(
        address module,
        bytes memory data
    )
        public
        pure
        returns (ERC7579BootstrapConfig memory config)
    {
        config.module = IERC7579Module(module);
        config.data = abi.encodeCall(IERC7579Module.onInstall, data);
    }

    function makeBootstrapConfig(
        address module,
        bytes memory data
    )
        public
        pure
        returns (ERC7579BootstrapConfig[] memory config)
    {
        config = new ERC7579BootstrapConfig[](1);
        config[0].module = IERC7579Module(module);
        config[0].data = abi.encodeCall(IERC7579Module.onInstall, data);
    }

    function makeBootstrapConfig(
        address[] memory modules,
        bytes[] memory datas
    )
        public
        pure
        returns (ERC7579BootstrapConfig[] memory configs)
    {
        configs = new ERC7579BootstrapConfig[](modules.length);

        for (uint256 i; i < modules.length; i++) {
            configs[i] = _makeBootstrapConfig(modules[i], datas[i]);
        }
    }
}
