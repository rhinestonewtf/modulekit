import "../base/ERC6909.sol";
import "./Currency.sol";
import "../DataTypes.sol";
import "../subscription/ISubscription.sol";

library MintLib {
    using CurrencyLibrary for Currency;

    function mint(
        mapping(address owner => mapping(uint256 id => uint256)) storage balanceOf,
        address receiver,
        uint256 id,
        uint256 amount
    )
        internal
    {
        balanceOf[receiver][id] += amount;
        emit ERC6909.Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function burn(
        mapping(address owner => mapping(uint256 id => uint256)) storage balanceOf,
        address sender,
        uint256 id,
        uint256 amount
    )
        internal
    {
        balanceOf[sender][id] -= amount;

        emit ERC6909.Transfer(msg.sender, sender, address(0), id, amount);
    }

    function mint(
        mapping(address owner => mapping(uint256 id => uint256)) storage balanceOf,
        Currency currency,
        Split[] memory splits
    )
        internal
        returns (uint256 total)
    {
        uint256 id = currency.toId();

        uint256 length = splits.length;
        for (uint256 i; i < length; i++) {
            address receiver = splits[i].receiver;
            uint256 amount = splits[i].amount;
            total += amount;
            mint(balanceOf, receiver, id, amount);
        }
    }
}
