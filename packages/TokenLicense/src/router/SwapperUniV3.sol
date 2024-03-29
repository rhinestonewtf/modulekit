contract Swapper {
    mapping(address pool => bool enabled) internal _pools;

    modifier onlyPool(address pool) {
        require(_pools[pool], "Swapper: pool not enabled");
        _;
    }

    function swap() internal { }
}
