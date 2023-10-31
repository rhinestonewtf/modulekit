// SPDX-License-Identifier: MIT
import "kernel/interfaces/IValidator.sol";
import "kernel/interfaces/IKernel.sol";

contract RhinestoneValidator is IKernelValidator {
    function enable(bytes calldata _data) external payable { }

    function disable(bytes calldata _data) external payable { }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingFunds
    )
        external
        payable
        returns (ValidationData)
    { }

    function validateSignature(
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        returns (ValidationData)
    { }

    function validCaller(address caller, bytes calldata data) external view returns (bool) { }

    function foo(IKernel account, address to, bytes calldata callData) external {
        IKernel.execute({ _to: to, _value: 0, _data: callData, operationType: OperationType.Call });
    }
}
