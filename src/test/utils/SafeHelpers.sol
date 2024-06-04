// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { SafeFactory } from "src/accounts/safe/SafeFactory.sol";

interface ISafeFactory {
    function getInitDataSafe(
        address validator,
        bytes memory initData
    )
        external
        view
        returns (bytes memory init);
}

library SafeHelpers {
    function getInitCallData(
        bytes32 salt,
        address txValidator,
        bytes memory originalInitCode,
        bytes memory erc4337CallData
    )
        internal
        view
        returns (bytes memory initCode, bytes memory callData)
    {
        // TODO: refactor this to decode the initcode
        address factory;
        assembly {
            factory := mload(add(originalInitCode, 20))
        }
        Safe7579Launchpad.InitData memory initData = abi.decode(
            ISafeFactory(factory).getInitDataSafe(txValidator, ""), (Safe7579Launchpad.InitData)
        );
        // Safe7579Launchpad.InitData memory initData =
        //     abi.decode(_initCode, (Safe7579Launchpad.InitData));
        initData.callData = erc4337CallData;
        initCode = abi.encodePacked(
            factory, abi.encodeCall(SafeFactory.createAccount, (salt, abi.encode(initData)))
        );
        callData = abi.encodeCall(Safe7579Launchpad.setupSafe, (initData));
    }
}
