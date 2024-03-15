import "./interfaces/IDistributor.sol";
import { PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";
import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/Modules.sol";

import { IERC7579Account, Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import {
    CallType, ModeCode, ModeLib, CALLTYPE_SINGLE, CALLTYPE_BATCH
} from "erc7579/lib/ModeLib.sol";
import "forge-std/interfaces/IERC20.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";

contract AutoLicense is ERC7579ValidatorBase {
    IDistributor public immutable LICENSE_MANAGER;
    address immutable TOKEN;

    struct Permission {
        address signer;
        bool autoExtendEnabled;
    }

    mapping(address module => mapping(address account => Permission permission)) public licenseUntil;
    mapping(address account => uint256 limit) public approvalLimit;

    constructor(IDistributor licenseManager) {
        LICENSE_MANAGER = licenseManager;
        TOKEN = licenseManager.underlyingToken();
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata) external override { }

    function setPermission(address module, Permission calldata permission) external {
        licenseUntil[module][msg.sender] = permission;
    }

    function setLimit(uint256 limit) external {
        approvalLimit[msg.sender] = limit;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        CallType calltype = ModeLib.getCallType(ModeCode.wrap(bytes32(userOp.callData[4:36])));

        bytes calldata callData = userOp.callData[100:];

        bool scopedSession;
        address signer;
        if (calltype == CALLTYPE_BATCH) {
            Execution[] calldata execs = ExecutionLib.decodeBatch(callData);
            Execution calldata exec = execs[0];

            // first tx must be approval
            (bool valid, uint256 newApproval) =
                _onlyScopedApproval(exec.target, exec.value, exec.callData);
            if (!valid) return VALIDATION_FAILED;
            approvalLimit[msg.sender] -= newApproval;

            uint256 length = execs.length;
            for (uint256 i = 1; i < length; i++) {
                exec = execs[i];
                address module;
                (scopedSession, module) =
                    _onlyScopedLicenseManagerCall(exec.target, exec.value, exec.callData);
                if (!scopedSession) return VALIDATION_FAILED;

                address _signer = licenseUntil[module][msg.sender].signer;
                if (signer == address(0) || signer == _signer) signer = _signer;
                else return VALIDATION_FAILED;
            }
        } else {
            return VALIDATION_FAILED;
        }

        bool validSig =
            signer == ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), userOp.signature);

        return _packValidationData(!validSig, type(uint48).max, 0);
    }

    function _onlyScopedSession(
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        returns (bool)
    {
        bytes4 methodSig = bytes4(callData[:4]);
        if (methodSig == IERC20.approve.selector) {
            _onlyScopedApproval(target, value, callData);
        } else if (methodSig == LICENSE_MANAGER.distribute.selector) {
            _onlyScopedLicenseManagerCall(target, value, callData);
        } else {
            return false;
        }
    }

    function _checkSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        address expectedSigner
    )
        internal
        returns (bool validSig)
    {
        validSig = expectedSigner
            == ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), userOp.signature);
    }

    function _onlyScopedApproval(
        address to,
        uint256 value,
        bytes calldata callData
    )
        internal
        returns (bool isApproval, uint256 amount)
    {
        if (value != 0) return (false, 0);
        if (to != TOKEN) return (false, 0);
        if (bytes4(callData[:4]) != IERC20.approve.selector) return (false, 0);
        address spender;
        (spender, amount) = abi.decode(callData[4:], (address, uint256));
        if (spender != address(LICENSE_MANAGER)) return (false, 0);
        if (amount > approvalLimit[msg.sender]) return (false, 0);
        return (true, amount);
    }

    function _onlyScopedLicenseManagerCall(
        address to,
        uint256 value,
        bytes calldata callData
    )
        internal
        returns (bool isDistribution, address module)
    {
        if (to != address(LICENSE_MANAGER)) return (false, module);
        if (value != 0) return (false, module);
        IDistributor.FeeDistribution memory distro =
            abi.decode(callData[4:], (IDistributor.FeeDistribution));
        Permission storage $permission = licenseUntil[distro.module][msg.sender];
        if (!$permission.autoExtendEnabled) return (false, module);
        return (true, distro.module);
    }

    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        return EIP1271_FAILED;
    }

    function name() external pure returns (string memory) {
        return "WebAuthnValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }
}
