# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Common Changelog](https://common-changelog.org/).

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
