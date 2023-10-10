interface ISmartAccount {
    function enableModule(address module) external;

    function setupAndEnableModule(
        address setupContract,
        bytes memory setupData
    )
        external
        returns (address);

    function isModuleEnabled(address module) external returns (bool);
}

interface ISmartAccountFactory {
    function getAddressForCounterFactualAccount(
        address moduleSetupContract,
        bytes calldata moduleSetupData,
        uint256 index
    )
        external
        view
        returns (address _account);

    function deployCounterFactualAccount(
        address moduleSetupContract,
        bytes calldata moduleSetupData,
        uint256 index
    )
        external
        returns (address proxy);
}
