# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Common Changelog](https://common-changelog.org/).

[0.4.6]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.4.6
[0.4.5]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.4.5
[0.4.4]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.4.4
[0.4.3]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.4.3
[0.4.2]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.4.2
[0.4.1]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.4.1
[0.4.0]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.4.0
[0.3.7]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.7
[0.3.6]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.6
[0.3.5]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.5
[0.3.4]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.4
[0.3.3]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.3
[0.3.2]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.2
[0.3.1]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.1
[0.3.0]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.3.0
[0.2.0]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.2.0
[0.1.0]: https://github.com/rhinestonewtf/modulekit/releases/tag/v0.1.0

## [0.4.5] - 04-06-2024

### Fixed

- Bugs in uninstall module functions

## [0.4.4] - 04-06-2024

### Fixed

- Specify correct Kernel version
- Dependency based CI

## [0.4.3] - 30-05-2024

### Changed

- Refactored multi-account handling
- Clean up compiler warnings and linting issues

### Added

- Kernel v3 support
- Factory base for accounts to use the Module Registry

## [0.4.2] - 24-05-2024

### Fixed

- Incorrectly parsing the account salt for call traces

## [0.4.1] - 24-05-2024

### Changed

- Integrated `Safe7579Launchpad`
- Cleaned up and standardized multi-account logic
- Removed redundant components

### Added

- Account factory template to guide integration of new accounts
- Multi-account ci
- Dependency installation ci

## [0.4.0] - 21-05-2024

### Changed

- `instance.expect4337Revert` now catches reverts in both validation and execution
- Gas calculations are now split by `_` on every thousand
- General restructuring of the codebase and split into multiple repositories
  - Moved module bases and mocks to `@rhinestone/module-bases`
  - Moved core modules to `@rhinestone/core-modules`
  - Moved the Safe ERC-7579 adapter to `@rhinestone/safe7579`

### Added

- ERC-7484 support with interface, mock registry and registry adapter base
- Support for stateless validators
- Under-the-hood support for multi-hooks
- Base module for scheduling-based executors

### Fixed

- Bugs related to installation and uninstallation calldata
- Various other bugs

## [0.3.7] - 09-03-2024

### Changed

- Updated Registry Deployer

## [0.3.6] - 09-03-2024

### Changed

- Updated Registry Deployer

## [0.3.5] - 09-03-2024

### Changed

- Updated Registry Deployer

## [0.3.4] - 05-03-2024

### Changed

- Updated ERC-7579 reference implementation dependency to latest
- Simplified remappings
- Updated examples and tests

## [0.3.3] - 29-02-2024

### Changed

- Various bug fixes
- Updated ERC-7579 reference implementation dependency to latest

## [0.3.2] - 28-02-2024

### Changed

- Various bug fixes and improvements

## [0.3.1] - 23-02-2024

### Changed

- File structure:
  - `packages` now includes the core components
  - `examples` now includes the example modules
  - `accounts` includes the account integrations (the ERC-7579 reference implementation is currently inside the `packages/modulekit` package)
- Support for the latest version of ERC-7579
- Entrypoint address is now the official v0.7 EntryPoint address

### Added

- Module Examples are now in the `examples` folder

## [0.3.0] - 01-02-2024

### Changed

- Native ERC-7579 support
- Improved Folder structure
- Testing interface:
  - `RhinestoneAccount` -> `AccountInstance`
  - `install`, `uininstall` and `isInstalled` functions for module types have been collapsed into `installModule`, `uninstallModule` and `isModuleInstalled` respectively
- Safe suppport now via a Safe ERC7579 module (still experimental)

### Added

- Hooks and Fallbacks: `ERC7579HookBase` and `ERC7579FallbackBase`
- Module Bases
- Gas measurement helper: `instance.log4337Gas("identifier")` and `GAS=true forge test`
- ERC4337 rule validation support in Foundry: `SIMULATE=true forge test`

### Removed

- Unused components

## [0.2.0] - 17-10-2023

### Changed

- Folder structure for better readability
- Ported Rhinestone Manager to Singleton

### Added

- Biconomy account integration test helper
- Conditional Execution Manager
- DeFi integrations and actions
- Fallback handler

### Removed

- Recovery flow in Validator interface
- Various dependencies
