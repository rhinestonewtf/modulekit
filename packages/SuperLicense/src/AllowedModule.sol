import "permit2/src/interfaces/IPermit2.sol";

struct ModuleWitness {
    uint256 value;
    address module;
}

contract Module {
    function mockFeature() public returns (uint256) {
        return 1337;
    }
}
