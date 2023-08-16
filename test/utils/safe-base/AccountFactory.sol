// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Auxiliary.sol";

struct AccountInstance {
    address account;
    IRhinestone4337 rhinestoneManager;
    Auxiliary aux;
    bytes32 salt;
    AccountFlavour accountFlavour;
}

struct AccountFlavour {
    SafeProxyFactory accountFactory;
    ISafe accountSingleton;
}

contract SafeAccountFactory is AuxiliaryFactory {
    RhineStoneSafeFlavor internal rhinestoneManger;
    Bootstrap internal safeBootstrap;

    SafeProxyFactory internal safeFactory;
    Safe internal safeSingleton;

    function init() internal override {
        super.init();

        rhinestoneManager = new RhinestoneSafeFlavor(
          address(mockRegistry),
          address(entrypoint),
          defaultAttester
        );

        safeBootstrap = new Bootstrap();
    }

    function newInstance() internal returns (AccountInstance memory env) {}

    function getAccountAddress(Auxiliary memory env, bytes32 salt) public returns (address payable) {
        // Get initializer
        bytes memory initializer = SafeHelpers.getSafeInitializer(env, salt);

        // Safe deployment data
        bytes memory deploymentData =
            abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(address(singleton))));
        // Get salt
        // bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), safeSalt));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(proxyFactory), salt, keccak256(deploymentData)));
        return payable(address(uint160(uint256(hash))));
    }
}
