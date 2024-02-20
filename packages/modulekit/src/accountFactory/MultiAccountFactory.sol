import "forge-std/Base.sol";
import "./safe7579/Safe7579Factory.sol";
import "./referenceImpl/RefImplFactory.sol";

enum AccountType {
    DEFAULT,
    SAFE7579
}

string constant DEFAULT = "DEFAULT";
string constant SAFE7579 = "SAFE7579";

contract MultiAccountFactory is TestBase, Safe7579Factory, RefImplFactory {
    AccountType public env;

    constructor() {
        string memory _env = vm.envOr("ACCOUNT_TYPE", DEFAULT);

        if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(SAFE7579))) {
            env = AccountType.SAFE7579;
        } else {
            env = AccountType.DEFAULT;
        }
    }

    function makeAccount(bytes32 salt, bytes calldata initCode) public returns (address account) {
        if (env == AccountType.SAFE7579) {
            return _makeSafe(salt, initCode);
        } else {
            return _makeDefault(salt, initCode);
        }
    }

    function _makeDefault(bytes32 salt, bytes calldata initCode) public returns (address) {
        return _createUMSA(salt, initCode);
    }

    function _makeSafe(bytes32 salt, bytes calldata initCode) public returns (address) {
        return _createSafe(address(erc7579Mod), initCode);
    }
}
