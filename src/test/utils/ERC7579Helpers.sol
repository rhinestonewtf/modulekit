// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {
    ERC7579Bootstrap, ERC7579BootstrapConfig, IERC7579Module
} from "../../external/ERC7579.sol";
import {
    IERC7579Account,
    ERC7579Account,
    ERC7579AccountFactory,
    ERC7579Bootstrap,
    ERC7579BootstrapConfig,
    IERC7579Validator,
    IERC7579Config,
    IERC7579Execution,
    IERC7579ConfigHook
} from "../../external/ERC7579.sol";
import { UserOperation, IEntryPoint } from "../../external/ERC4337.sol";

library ERC7579Helpers {
    function map(
        IERC7579Execution.Execution[] memory self,
        function(IERC7579Execution.Execution memory) internal  returns (IERC7579Execution.Execution memory)
            f
    )
        internal
        returns (IERC7579Execution.Execution[] memory result)
    {
        result = new IERC7579Execution.Execution[](self.length);
        for (uint256 i; i < self.length; i++) {
            result[i] = f(self[i]);
        }
        return result;
    }

    function reduce(
        IERC7579Execution.Execution[] memory self,
        function(IERC7579Execution.Execution memory, IERC7579Execution.Execution memory) 
        internal  returns (IERC7579Execution.Execution memory) f
    )
        internal
        returns (IERC7579Execution.Execution memory result)
    {
        result = self[0];
        for (uint256 i = 1; i < self.length; i++) {
            result = f(result, self[i]);
        }
        return result;
    }

    function configModule(
        address account,
        address module,
        bytes memory initData,
        function(address, address, bytes memory) internal  returns (address, uint256, bytes memory)
            fn
    )
        internal
        returns (bytes memory erc7579Tx)
    {
        (address to, uint256 value, bytes memory callData) = fn(account, module, initData);
        erc7579Tx = encode(to, value, callData);
    }

    function installValidator(
        address account,
        address validator,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        to = account;
        value = 0;
        callData = abi.encodeCall(IERC7579Config.installValidator, (validator, initData));
    }

    function uninstallValidator(
        address account,
        address validator,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array, address next) =
            ERC7579Account(account).getValidatorPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == validator) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == validator) previous = array[i - 1];
            }
        }

        to = account;
        value = 0;
        callData = abi.encodeCall(
            IERC7579Config.uninstallValidator, (validator, abi.encode(previous, initData))
        );
    }

    function installExecutor(
        address account,
        address validator,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        to = account;
        value = 0;
        callData = abi.encodeCall(IERC7579Config.installExecutor, (validator, initData));
    }

    function uninstallExecutor(
        address account,
        address executor,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array, address next) =
            ERC7579Account(account).getExecutorsPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == executor) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == executor) previous = array[i - 1];
            }
        }

        to = account;
        value = 0;
        callData = abi.encodeCall(
            IERC7579Config.uninstallExecutor, (executor, abi.encode(previous, initData))
        );
    }

    function installHook(
        address account,
        address hook,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        to = account;
        value = 0;
        callData = abi.encodeCall(IERC7579ConfigHook.installHook, (hook, initData));
    }

    function uninstallHook(
        address account,
        address hook,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        to = account;
        value = 0;
        callData = abi.encodeCall(IERC7579ConfigHook.installHook, (address(0), initData));
    }

    function installFallback(
        address account,
        address fallbackHandler,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        to = account;
        value = 0;
        callData = abi.encodeCall(IERC7579Config.installFallback, (fallbackHandler, initData));
    }

    function uninstallFallback(
        address account,
        address fallbackHandler,
        bytes memory initData
    )
        internal
        view
        returns (address to, uint256 value, bytes memory callData)
    {
        to = account;
        value = 0;
        callData = abi.encodeCall(IERC7579Config.installFallback, (address(0), initData));
    }

    function installModule(
        function(address,uint,bytes memory) internal pure returns(address , uint256 , bytes memory )
            fn,
        address module,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory erc7579Tx)
    {
        (address target, uint256 value, bytes memory data) = fn(module, 0, initData);
        return encode(target, value, data);
    }

    function encode(
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        pure
        returns (bytes memory erc7579Tx)
    {
        return abi.encodeCall(IERC7579Execution.execute, (target, value, callData));
    }

    function encode(IERC7579Execution.Execution[] memory executions)
        internal
        pure
        returns (bytes memory erc7579Tx)
    {
        return abi.encodeCall(IERC7579Execution.executeBatch, (executions));
    }

    function toExecutions(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas
    )
        internal
        pure
        returns (IERC7579Execution.Execution[] memory executions)
    {
        executions = new IERC7579Execution.Execution[](targets.length);
        if (targets.length != values.length && values.length != callDatas.length) revert();

        for (uint256 i; i < targets.length; i++) {
            executions[i] = IERC7579Execution.Execution({
                target: targets[i],
                value: values[i],
                callData: callDatas[i]
            });
        }
    }

    function signUserOp(
        address account,
        IEntryPoint entrypoint,
        UserOperation memory userOp,
        address validator,
        bytes memory signature
    )
        internal
        view
        returns (bytes32 userOpHash, UserOperation memory)
    {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        uint256 nonce = entrypoint.getNonce(address(account), key);

        userOp.nonce = nonce;
        userOp.signature = signature;

        userOpHash = entrypoint.getUserOpHash(userOp);
        return (userOpHash, userOp);
    }
}

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

library ArrayLib {
    function executions(IERC7579Execution.Execution memory _1)
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](1);
        array[0] = _1;
    }

    function executions(
        IERC7579Execution.Execution memory _1,
        IERC7579Execution.Execution memory _2
    )
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](2);
        array[0] = _1;
        array[1] = _2;
    }

    function executions(
        IERC7579Execution.Execution memory _1,
        IERC7579Execution.Execution memory _2,
        IERC7579Execution.Execution memory _3
    )
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](3);
        array[0] = _1;
        array[1] = _2;
        array[2] = _3;
    }

    function executions(
        IERC7579Execution.Execution memory _1,
        IERC7579Execution.Execution memory _2,
        IERC7579Execution.Execution memory _3,
        IERC7579Execution.Execution memory _4
    )
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](4);
        array[0] = _1;
        array[1] = _2;
        array[2] = _3;
        array[3] = _4;
    }
}
