// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "safe-contracts/contracts/proxies/SafeProxy.sol";
import "safe-contracts/contracts/Safe.sol";
import "safe-contracts/contracts/proxies/SafeProxyFactory.sol";

import "../Auxiliary.sol";
import "../../../src/safe/ISafe.sol";
import "../../../src/safe/RhinestoneSafeFlavor.sol";

import "./SafeSetup.sol";

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

contract AccountFactory is AuxiliaryFactory {
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
