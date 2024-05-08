import "../base/ERC6909.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import "./ISubscription.sol";

contract SubscriptionToken is ISubscription, Ownable {
    event NewSubscriptionValidDate(address account, address module, uint256 validUntil);

    mapping(address module => mapping(address account => uint256 validUntil)) public subscriptionOf;

    address internal mintAuthority;

    constructor() {
        _initializeOwner(msg.sender);
    }

    function authorizeMintAuthority(address newMintAuthority) external onlyOwner {
        mintAuthority = newMintAuthority;
    }

    modifier onlyMintAuthorityOrOwner() {
        if (msg.sender == mintAuthority || msg.sender == owner()) {
            _;
        } else {
            revert Unauthorized();
        }
    }

    function mint(
        address account,
        address module,
        uint256 validUntil
    )
        external
        onlyMintAuthorityOrOwner
    {
        subscriptionOf[module][account] = validUntil;
        emit NewSubscriptionValidDate(account, module, validUntil);
    }

    function burn(address account, address module) external onlyMintAuthorityOrOwner {
        uint256 validUntil = 0;
        subscriptionOf[module][account] = validUntil;
        emit NewSubscriptionValidDate(account, module, validUntil);
    }
}
