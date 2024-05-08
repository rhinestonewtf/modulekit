import "src/interfaces/IFeeMachine.sol";
import "src/DataTypes.sol";

contract MockFeeMachine is IFeeMachine {
    address[] public beneficiaries;
    uint256[] public amounts;

    function setSplit(address[] calldata _beneficiaries, uint256[] calldata _amounts) external {
        beneficiaries = _beneficiaries;
        amounts = _amounts;
    }

    function supportsInterface(bytes4 interfaceID) external pure override returns (bool) {
        if (interfaceID == type(IFeeMachine).interfaceId) return true;
    }

    function split(
        address module,
        ClaimTransaction calldata claim
    )
        external
        override
        returns (Split[] memory splits)
    {
        splits = new Split[](beneficiaries.length);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            splits[i] = Split({ receiver: beneficiaries[i], amount: amounts[i] });
        }
    }

    function split(ClaimSubscription calldata claim)
        external
        override
        returns (Split[] memory splits)
    {
        splits = new Split[](beneficiaries.length);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            splits[i] = Split({ receiver: beneficiaries[i], amount: amounts[i] });
        }
    }

    function split(ClaimPerUse calldata claim) external returns (Split[] memory splits) {
        splits = new Split[](beneficiaries.length);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            splits[i] = Split({ receiver: beneficiaries[i], amount: amounts[i] });
        }
    }
}
