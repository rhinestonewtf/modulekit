// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Safe7579, ISafe7579 } from "safe7579/Safe7579.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { SafeProxy } from "@safe-global/safe-contracts/contracts/proxies/SafeProxy.sol";
import { SafeProxyFactory } from
    "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import { Safe7579Launchpad, IERC7484, ModuleInit } from "safe7579/Safe7579Launchpad.sol";
import { ENTRYPOINT_ADDR } from "src/test/predeploy/EntryPoint.sol";
import { REGISTRY_ADDR } from "src/test/predeploy/Registry.sol";
import { makeAddr } from "src/test/utils/Vm.sol";
import { Solarray } from "solarray/Solarray.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";

contract SafeFactory is IAccountFactory {
    // singletons
    Safe7579 internal safe7579;
    Safe7579Launchpad internal launchpad;
    Safe internal safeSingleton;
    SafeProxyFactory internal safeProxyFactory;

    function init() public override {
        // Set up MSA and Factory
        safe7579 = new Safe7579();
        launchpad = new Safe7579Launchpad(ENTRYPOINT_ADDR, IERC7484(address(REGISTRY_ADDR)));
        safeSingleton = new Safe();
        safeProxyFactory = new SafeProxyFactory();
    }

    function createAccount(
        bytes32 salt,
        bytes memory initCode
    )
        public
        override
        returns (address safe)
    {
        Safe7579Launchpad.InitData memory initData =
            abi.decode(initCode, (Safe7579Launchpad.InitData));
        bytes32 initHash = launchpad.hash(initData);

        bytes memory factoryInitializer =
            abi.encodeCall(Safe7579Launchpad.preValidationSetup, (initHash, address(0), ""));

        safe = address(
            safeProxyFactory.createProxyWithNonce(
                address(launchpad), factoryInitializer, uint256(salt)
            )
        );
    }

    function getAddress(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        override
        returns (address)
    {
        Safe7579Launchpad.InitData memory initData =
            abi.decode(initCode, (Safe7579Launchpad.InitData));
        bytes32 initHash = launchpad.hash(initData);

        bytes memory factoryInitializer =
            abi.encodeCall(Safe7579Launchpad.preValidationSetup, (initHash, address(0), ""));

        return launchpad.predictSafeAddress({
            singleton: address(launchpad),
            safeProxyFactory: address(safeProxyFactory),
            creationCode: type(SafeProxy).creationCode,
            salt: salt,
            factoryInitializer: factoryInitializer
        });
    }

    function getInitData(
        address validator,
        bytes memory initData
    )
        public
        view
        override
        returns (bytes memory _init)
    {
        ModuleInit[] memory validators = new ModuleInit[](1);
        validators[0] = ModuleInit({ module: address(validator), initData: initData });
        ModuleInit[] memory executors = new ModuleInit[](0);
        ModuleInit[] memory fallbacks = new ModuleInit[](0);
        ModuleInit[] memory hooks = new ModuleInit[](0);

        Safe7579Launchpad.InitData memory initDataSafe = Safe7579Launchpad.InitData({
            singleton: address(safeSingleton),
            owners: Solarray.addresses(makeAddr("owner1")),
            threshold: 1,
            setupTo: address(launchpad),
            setupData: abi.encodeCall(
                Safe7579Launchpad.initSafe7579,
                (
                    address(safe7579),
                    executors,
                    fallbacks,
                    hooks,
                    Solarray.addresses(makeAddr("attester1"), makeAddr("attester2")),
                    2
                )
            ),
            safe7579: ISafe7579(safe7579),
            validators: validators,
            callData: ""
        });
        _init = abi.encode(initDataSafe);
    }
}
