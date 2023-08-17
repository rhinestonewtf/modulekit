// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "safe-contracts/contracts/proxies/SafeProxy.sol";
import "safe-contracts/contracts/Safe.sol";
import "safe-contracts/contracts/proxies/SafeProxyFactory.sol";

import "../Auxiliary.sol";
import "../../../contracts/safe/ISafe.sol";
import "../../../contracts/safe/RhinestoneSafeFlavor.sol";

struct AccountInstance {
    address account;
    IRhinestone4337 rhinestoneManager;
    Auxiliary aux;
    bytes32 salt;
    AccountFlavor accountFlavor;
}

struct AccountFlavor {
    SafeProxyFactory accountFactory;
    ISafe accountSingleton;
}

contract RhinestoneSDK is AuxiliaryFactory {
    RhinestoneSafeFlavor internal rhinestoneManager;
    Bootstrap internal safeBootstrap;

    SafeProxyFactory internal safeFactory;
    Safe internal safeSingleton;

    bool initialzed;

    function init() internal override {
        super.init();
        safeFactory = new SafeProxyFactory();
        safeSingleton = new Safe();

        rhinestoneManager = new RhinestoneSafeFlavor(
          address(entrypoint),
          address(mockRegistry),
          defaultAttester
        );

        safeBootstrap = new Bootstrap();
        initialzed = true;
    }

    function newInstance(bytes32 _salt) internal returns (AccountInstance memory instance) {
        if (!initialzed) init();

        Auxiliary memory env = makeAuxiliary(rhinestoneManager, safeBootstrap);

        instance = AccountInstance({
            account: getAccountAddress(env, _salt),
            rhinestoneManager: IRhinestone4337(
                payable(AuxiliaryLib.getModuleCloneAddress(env, address(rhinestoneManager), _salt))
                ),
            aux: env,
            salt: _salt,
            accountFlavor: AccountFlavor({accountFactory: safeFactory, accountSingleton: ISafe(address(safeSingleton))})
        });
    }

    function getAccountAddress(Auxiliary memory env, bytes32 _salt) public returns (address payable) {
        // Get initializer
        bytes memory initializer = SafeHelpers.getSafeInitializer(env, _salt);

        // Safe deployment data
        bytes memory deploymentData =
            abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(address(safeSingleton))));
        // Get salt
        // bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), _salt));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(safeFactory), salt, keccak256(deploymentData)));
        return payable(address(uint160(uint256(hash))));
    }
}

import {SafeHelpers} from "./SafeSetup.sol";
import {ERC4337Wrappers} from "./ERC4337Helpers.sol";
import "../../../contracts/auxiliary/interfaces/IModuleManager.sol";

library RhinestoneSDKLib {
    function exec4337(AccountInstance memory instance, address target, bytes memory callData)
        internal
        returns (bool, bytes memory)
    {
        return exec4337(instance, target, 0, callData);
    }

    function exec4337(AccountInstance memory instance, address target, uint256 value, bytes memory callData)
        internal
        returns (bool, bytes memory)
    {
        return exec4337(instance, target, value, callData, 0, bytes(""));
    }

    function exec4337(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        uint8 operation, // {0: Call, 1: DelegateCall}
        bytes memory signature
    ) internal returns (bool, bytes memory) {
        bytes memory data = ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);

        if (signature.length == 0) {
            // TODO: generate default signature
            signature = bytes("");
        }
        return exec4337(instance, data);
    }

    function exec4337(AccountInstance memory instance, bytes memory callData) internal returns (bool, bytes memory) {
        // prepare ERC4337 UserOperation

        bytes memory initCode = isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, callData, initCode);
        // mock signature
        userOp.signature = bytes("");

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        // send userOps to 4337 entrypoint
        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));
    }

    function addValidator(AccountInstance memory instance, address validator) internal returns (bool) {}

    function addRecovery(AccountInstance memory instance, address recovery) internal returns (bool) {}

    function addPlugin(AccountInstance memory instance, address plugin) internal returns (bool) {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.rhinestoneManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.rhinestoneManager.enablePlugin.selector, plugin, false)
        });
        return success;
    }

    function isDeployed(AccountInstance memory instance) internal view returns (bool) {
        address _addr = address(instance.account);
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
