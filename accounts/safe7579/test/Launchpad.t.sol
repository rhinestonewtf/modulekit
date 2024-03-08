// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/SafeERC7579.sol";
import "src/SafeERC7579.sol";
import "src/utils/SafeLaunchpad.sol";
import "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import "@safe-global/safe-contracts/contracts/Safe.sol";

contract SafeLaunchPadTest is Test {
    SafeSignerLaunchpad safeLaunchpad;
    SafeERC7579 safe7579;
    Safe singleton;
    Safe safeAccount;
    SafeProxyFactory safeProxyFactory;

    address entrypoint = address(this);

    Account signer1 = makeAccount("signer1");
    Account signer2 = makeAccount("signer2");

    function setUp() public {
        singleton = new Safe();
        safeProxyFactory = new SafeProxyFactory();
        safeLaunchpad = new SafeSignerLaunchpad(entrypoint);

        bytes memory safeLaunchPadSetup;
        //     Safe.setup,
        //     (
        //         owners,
        //         2,
        //         address(safeLaunchpad),
        //         safeLaunchPadSetup,
        //         address(safe7579),
        //         address(0),
        //         0,
        //         payable(address(0))
        //     )
        // );

        address[] memory owners = new address[](2);
        owners[0] = signer1.addr;
        owners[1] = signer2.addr;
        // SETUP SAFE
        bytes memory initializer = abi.encodeCall(
            Safe.setup,
            (
                owners,
                2,
                address(safeLaunchpad),
                safeLaunchPadSetup,
                address(safe7579),
                address(0),
                0,
                payable(address(0))
            )
        );
        uint256 salt = 0;

        SafeProxy safeProxy =
            safeProxyFactory.createProxyWithNonce(address(singleton), initializer, salt);
    }

    /**
     * Genereates initcode that will be passed to safeProxyFactory
     * @param safeLaunchPadSetup init code for safe launchpad setup() function
     */
    function _safeProxyFactory_initcode(bytes memory safeLaunchPadSetup)
        internal
        returns (bytes memory initCode)
    {
        // initCode = abi.encodeCall(
        //     Safe.setup,
        //     (
        //         owners,
        //         2,
        //         address(safeLaunchpad),
        //         safeLaunchPadSetup,
        //         address(safe7579),
        //         address(0),
        //         0,
        //         payable(address(0))
        //     )
        // );
    }

    function test_foo() public { }
}
