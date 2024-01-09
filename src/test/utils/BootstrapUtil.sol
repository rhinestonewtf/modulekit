// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    ERC7579Bootstrap, ERC7579BootstrapConfig, IERC7579Module
} from "../../external/ERC7579.sol";

contract BootstrapUtil {
    function _emptyConfig() internal pure returns (ERC7579BootstrapConfig memory config) { }
    function _emptyConfigs() internal pure returns (ERC7579BootstrapConfig[] memory config) { }

    function _makeBootstrapConfig(
        address module,
        bytes memory data
    )
        public
        pure
        returns (ERC7579BootstrapConfig memory config)
    {
        config.module = module;
        config.data = data;
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
        config[0].module = module;
        config[0].data = data;
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
