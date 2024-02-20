import "../../external/ERC7579.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";

interface IMSA {
    function initializeAccount(bytes calldata initCode) external;
}

contract RefImplFactory {
    ERC7579Account internal implementation;

    constructor() {
        implementation = new ERC7579Account();
    }

    function _createUMSA(bytes32 salt, bytes memory initCode) public returns (address account) {
        bytes32 _salt = _getSalt(salt, initCode);
        address account = LibClone.cloneDeterministic(0, address(implementation), initCode, _salt);

        IMSA(account).initializeAccount(initCode);
        return account;
    }

    function getAddress(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        virtual
        returns (address)
    {
        bytes32 _salt = _getSalt(salt, initCode);
        return LibClone.predictDeterministicAddress(
            address(implementation), initCode, _salt, address(this)
        );
    }

    function _getSalt(
        bytes32 _salt,
        bytes memory initCode
    )
        public
        pure
        virtual
        returns (bytes32 salt)
    {
        salt = keccak256(abi.encodePacked(_salt, initCode));
    }
}
