# Copilot Instructions for IdentityCore

This repository contains `IdentityCore`, a shared library used by the Microsoft Authentication Library (MSAL) for iOS and macOS. It contains internal classes and is not intended for public API consumption.

## High Level Details

- **Project Type**: Objective-C Shared Library (Internal).
- **Languages**: Objective-C, Python (build scripts).
- **Platforms**: iOS, macOS, visionOS.
- **Key Frameworks**: Foundation, Security.
- **Versioning**: Semantic Versioning.
- **Branching**: `main` is the active branch.

## Build and Validation

To build and validate changes, use the provided Python build script. This script handles building the project and running unit tests.

**Build and Test:**
Run the `build.py` script with the appropriate target. This command performs both build and test operations by default.

```bash
# For iOS
./build.py --targets ios_library

# For macOS
./build.py --targets mac_library

# For visionOS
./build.py --targets vision_library
```

**Note:**
- The build script uses `xcodebuild` under the hood.
- Ensure you have the appropriate Xcode version selected (CI uses Xcode 16.2).
- If you encounter issues, try running with `--no-clean` to speed up subsequent builds or `--show-build-settings` for debugging.

## Code Style

**CRITICAL**: Always adhere to the code style guidelines defined in `.clinerules/01-Code-style-guidelines.md`. This includes:
- Using dot notation for properties.
- 4-space indentation.
- Opening braces on a NEW line.
- Using `MSID` prefix classes.
- Checking return values instead of error variables.

## Project Layout

- **`IdentityCore/`**: Root directory for the library.
    - **`src/`**: Source code files. Classes are generally prefixed with `MSID`.
        - **`IdentityCore_Internal.h`**: Internal header.
        - **`MSID*.h/m`**: Core implementation files.
    - **`tests/`**: Unit tests.
        - **`MSID*Tests.m`**: Test classes corresponding to source files.
    - **`xcconfig/`**: Xcode build configuration files.
    - **`IdentityCore.xcodeproj`**: The Xcode project file.
- **`build.py`**: The main build automation script.
- **`scripts/`**: Helper scripts, including `update_xcode_config_cpp_checks.py`.
- **`azure_pipelines/`**: CI configuration files defining the validation pipelines.

## Key Architectural Elements

- **`MSID` Prefix**: Most classes in this library use the `MSID` prefix to denote Microsoft Identity internal classes.
- **Error Handling**: The project uses `NSError` extensively. Always validate the boolean return of a method before checking the `NSError` object.
- **Logging**: Uses internal logging macros (e.g., `MSID_LOG_WITH_CTX`).

## Validation Steps

1.  **Run the Build Script**: `./build.py --targets <target>`
2.  **Check Output**: Ensure the script finishes with "Succeeded".

