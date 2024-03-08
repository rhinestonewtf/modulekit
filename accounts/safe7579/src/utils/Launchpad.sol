import "../SafeERC7579.sol";

contract Launchpad {
    function initSafe7579(address safe7579, bytes calldata safe7579InitCode) public {
        ISafe(address(this)).enableModule(safe7579);
        SafeERC7579(payable(safe7579)).initializeAccount(safe7579InitCode);
    }
}
