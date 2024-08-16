// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./BaseTest.t.sol";
import {
    RegistryDeployer,
    REGISTRY_ADDR,
    ResolverUID,
    SchemaUID,
    ModuleRecord,
    ModuleType
} from "src/deployment/RegistryDeployer.sol";
import { MockValidator } from "src/Mocks.sol";

contract RegistryDeployerTest is RegistryDeployer, BaseTest {
    function setUp() public override {
        super.setUp();

        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(MAINNET_RPC_URL);
        vm.rollFork(18_501_477);
    }

    function testDeployModule() public {
        // Setup module bytecode, deploy params, and data
        bytes memory initCode = type(MockValidator).creationCode;
        bytes32 salt = bytes32(0);
        bytes memory metadata = hex"41414141414141";
        bytes memory resolverContext = "";

        // Deploy module
        address module = deployModule({
            initCode: initCode,
            salt: salt,
            metadata: metadata,
            resolverContext: resolverContext
        });

        assertEq(module, predictModuleAddress({ salt: salt, initCode: initCode }));
        assertGt(module.code.length, 0);

        ModuleRecord memory moduleRecord = findModule(module);
        assertEq(ResolverUID.unwrap(moduleRecord.resolverUID), ResolverUID.unwrap(resolverUID));
        assertEq(moduleRecord.metadata, metadata);
    }

    function testDeployModuleViaFactory() public {
        bytes32 salt = bytes32(0);
        address factory = address(this);
        bytes memory callOnFactory = abi.encodeCall(this.deploy, (salt));
        bytes memory metadata = hex"41414141414141";
        bytes memory resolverContext = "";

        address module = deployModuleViaFactory({
            factory: factory,
            callOnFactory: callOnFactory,
            metadata: metadata,
            resolverContext: resolverContext
        });

        assertEq(module, predictAddress(salt));
        assertGt(module.code.length, 0);

        ModuleRecord memory moduleRecord = findModule(module);
        assertEq(ResolverUID.unwrap(moduleRecord.resolverUID), ResolverUID.unwrap(resolverUID));
        assertEq(moduleRecord.metadata, metadata);
    }

    function testMockAttestModule() public {
        testDeployModule();

        bytes memory initCode = type(MockValidator).creationCode;
        bytes32 salt = bytes32(0);

        address module = predictModuleAddress({ salt: salt, initCode: initCode });

        bytes memory attestationData = hex"41414141414141";
        ModuleType[] memory moduleTypes = new ModuleType[](1);
        moduleTypes[0] = ModuleType.wrap(1);

        mockAttestToModule({
            module: module,
            attestationData: attestationData,
            moduleTypes: moduleTypes
        });

        assertTrue(isModuleAttestedMock(module));
    }

    function testFindResolver() public {
        ResolverUID _resolverUID = findResolver();
        assertEq(ResolverUID.unwrap(_resolverUID), ResolverUID.unwrap(resolverUID));
    }

    function testRegisterResolver() public {
        ResolverUID _resolverUID = registerResolver(address(this));
        setResolverUID(_resolverUID);
        findResolver();
    }

    function testFindSchema() public {
        SchemaUID _schemaUID = findSchema();
        assertEq(SchemaUID.unwrap(_schemaUID), SchemaUID.unwrap(schemaUID));
    }

    function testRegisterSchema() public {
        SchemaUID _schemaUID = registerSchema({ schema: "schema", validator: address(this) });
        setSchemaUID(_schemaUID);
        findSchema();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CALLBACKS
    //////////////////////////////////////////////////////////////////////////*/

    function deploy(bytes32 salt) external returns (address) {
        return address(new MockValidator{ salt: salt }());
    }

    function predictAddress(bytes32 salt) public returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), salt, keccak256(type(MockValidator).creationCode)
            )
        );
        return address(uint160(uint256(hash)));
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return true;
    }
}
