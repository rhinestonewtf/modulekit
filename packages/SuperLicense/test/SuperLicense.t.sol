// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/SuperLicense.sol";
import { ISuperfluid } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ERC1820RegistryCompiled } from
    "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";

// import { ISuperToken } from
//     "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {
    TestToken,
    SuperToken,
    SuperfluidFrameworkDeployer
} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";

import { SuperTokenV1Library } from
    "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import "forge-std/console2.sol";

contract StreamRebounderRandomTest is Test {
    using SuperTokenV1Library for ISuperToken;

    SuperLicense public superLicense;

    Account superTokenAdmin;

    Account smartAccount;

    // struct Framework {
    //     TestGovernance governance;
    //     Superfluid host;
    //     ConstantFlowAgreementV1 cfa;
    //     CFAv1Library.InitData cfaLib;
    //     InstantDistributionAgreementV1 ida;
    //     IDAv1Library.InitData idaLib;
    //     SuperTokenFactory superTokenFactory;
    // }

    TestToken underlying;
    SuperToken superToken;

    SuperfluidFrameworkDeployer.Framework sf;

    function setUp() public {
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        address owner;
        superTokenAdmin = makeAccount("tokenAdmin");
        smartAccount = makeAccount("smartAccount");
        //DEPLOYING THE FRAMEWORK
        SuperfluidFrameworkDeployer sfDeployer = new SuperfluidFrameworkDeployer();
        sfDeployer.deployTestFramework();
        sf = sfDeployer.getFramework();

        // DEPLOYING DAI and DAI wrapper super token

        vm.prank(owner);
        (underlying, superToken) = sfDeployer.deployWrapperSuperToken(
            "Fake USDC", "USDC", 18, 1000 ether, superTokenAdmin.addr
        );
        superLicense = new SuperLicense(superToken, sf.host);

        vm.startPrank(smartAccount.addr);
        underlying.mint(smartAccount.addr, 100 ether);
        underlying.approve(address(superToken), type(uint256).max);
        superToken.upgrade(100 ether);
        // superToken.transfer(address(superLicense), 1e18);
        vm.stopPrank();
    }

    //add other functions and test contracts...

    function test_foo() public {
        // superLicense.createFlowIntoContract(superToken, 30_000_000);
        vm.startPrank(smartAccount.addr);
        sf.cfaV1Forwarder.grantPermissions(superToken, address(superLicense));
        // superToken.createFlow(smartAccount.addr, 30_000_000, new bytes(0));

        // vm.startPrank(account1);
        // sf.cfaV1Forwarder.grantPermissions(daix, address(moneyRouter));
        // moneyRouter.createFlowIntoContract(daix, 30000000);
        // (, int96 checkCreatedFlowRate, , ) = sf.cfa.getFlow(daix, account1,
        // address(moneyRouter));
        // assertEq(30000000, checkCreatedFlowRate);
    }

    function test_createFlow() public {
        SuperLicense.LicenseData[] memory licenseData = new SuperLicense.LicenseData[](2);
        licenseData[0] = SuperLicense.LicenseData({
            operation: SuperLicense.Operation.NEW,
            module: address(1),
            value: 5
        });

        licenseData[1] = SuperLicense.LicenseData({
            operation: SuperLicense.Operation.UPDATE,
            module: address(2),
            value: 15
        });

        vm.startPrank(smartAccount.addr);
        sf.cfaV1Forwarder.grantPermissions(superToken, address(superLicense));
        SuperTokenV1Library.createFlow(
            superToken, address(superLicense), int96(20), abi.encode(licenseData)
        );
        vm.stopPrank();
    }
}
