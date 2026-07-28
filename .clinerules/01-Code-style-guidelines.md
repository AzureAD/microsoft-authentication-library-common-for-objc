# Objective-C and Swift Code Style Guidelines for AI Agents

## Overview

This document provides code style guidelines that AI agents MUST follow when working with this codebase. These guidelines are adapted from industry best practices and tailored to match the existing Objective-C and Swift patterns in this repository.

## Key Principles

### RFC 2119 Compliance

- **MUST**: Absolute requirement
- **MUST NOT**: Absolute prohibition
- **SHOULD**: Recommended but may have valid reasons to ignore
- **SHOULD NOT**: Not recommended but may have valid reasons to use
- **MAY**: Optional

---

## Code Style Rules

### 1. Dot Notation Syntax

**RECOMMENDED:** Use dot notation for getting and setting properties.

```objc
// Preferred
view.backgroundColor = UIColor.orangeColor;
NSString *username = account.username;

// Avoid
[view setBackgroundColor:[UIColor orangeColor]];
NSString *username = [account username];
```

### 2. Spacing and Indentation

**MUST** follow these spacing rules:

- Indentation: 4 spaces (never tabs)
- **Opening braces on NEW line** (repository convention)
- Closing braces on new line
- One blank line between methods

```objc
// Correct (as used in this repository)
- (instancetype)initWithUsername:(NSString *)username
                   homeAccountId:(MSIDAccountId *)homeAccountId
                     environment:(NSString *)environment
{
    self = [super init];
    
    if (self)
    {
        _username = username;
        _environment = environment;
        _homeAccountId = homeAccountId;
    }
    
    return self;
}

// For if/else statements
if (user.isHappy)
{
    // Do something
}
else
{
    // Do something else
}
```

### 3. Conditionals

**MUST** always use braces for conditional bodies, even for single-line statements.

```objc
// Correct
if (!error)
{
    return success;
}

// Incorrect - Never do this
if (!error)
    return success;

if (!error) return success;
```

### 4. Ternary Operator

**SHOULD** only evaluate a single condition per ternary expression.

```objc
// Acceptable
result = account.isValid ? account : nil;

// Avoid - too complex
result = account.isValid ? account.username = tenant.isValid ? tenant.id : nil : nil;
```

### 5. Error Handling

**MUST** check the return value, **MUST NOT** check the error variable directly.

```objc
// Correct
NSError *error;
if (![self trySomethingWithError:&error])
{
    // Handle Error
}

// Incorrect - Apple APIs may write garbage to error on success
NSError *error;
[self trySomethingWithError:&error];
if (error)
{
    // Handle Error
}
```

### 6. Method Signatures

**SHOULD** include space after scope symbol and between method segments.

```objc
// Correct
- (void)acquireTokenWithParameters:(MSIDSilentTokenParameters *)parameters
                   completionBlock:(MSIDCompletionBlock)completionBlock;

// For methods exceeding 80 characters, format like a form
- (MSIDResult *)resultWithTokenResult:(MSIDTokenResult *)result
                           authScheme:(id<MSIDAuthenticationSchemeProtocol>)authScheme
                           popManager:(MSIDDevicePopManager *)popManager
                                error:(NSError **)error;
```

### 7. Variables

#### Naming

**SHOULD** use descriptive variable names:

- `NSString *username` - clear and concise
- `NSString *accessToken` - describes the token type
- `MSIDAccount *currentAccount` - not just `account`
- `MSIDRequestParameters *requestParams` - abbreviated but clear
- `MSIDApplicationConfig *config` - clear context

**NOT RECOMMENDED:** Single letter variable names (except loop counters)

#### Pointer Asterisks

**MUST** attach asterisks to variable name:

```objc
// Correct
NSString *clientId

// Incorrect
NSString* clientId
NSString * clientId
```

Exception: Constants (`NSString * const MSIDErrorDomain`)

#### Properties vs Instance Variables

**SHOULD** use properties instead of naked instance variables.

```objc
// Preferred
@interface MSIDAccount : NSObject
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *environment;
@end

// Avoid
@interface MSIDAccount : NSObject
{
    NSString *username;
    NSString *environment;
}
@end
```

**SHOULD** avoid direct instance variable access except in:

- Initializer methods (`init`, `initWithCoder:`)
- `dealloc` methods
- Custom setters and getters

#### Variable Qualifiers

**SHOULD** place ARC qualifiers between asterisks and variable name:

```objc
NSString * __weak weakReference;
MSIDAccount * __autoreleasing autoreleasedAccount;
```

### 8. Naming Conventions

#### Class Names and Constants

**MUST** use `MSID` prefix for classes and constants

```objc
// Correct
static const NSTimeInterval MSIDDefaultTokenRefreshInterval = 300.0;
static NSString * const MSIDInvalidTokenResultKey = @"MSIDInvalidTokenResultKey";

// Incorrect
static const NSTimeInterval refreshInterval = 300.0;
```

#### Properties and Local Variables

**MUST** be camelCase with lowercase leading word.

```objc
NSString *accessToken;
MSIDALAccount *currentAccount;
MSIDRequestParameters *requestParams;
```

#### Instance Variables

**MUST** be camelCase with lowercase leading word and underscore prefix:

```objc
@implementation MSIDPublicClientApplication
{
    BOOL _validateAuthority;
    WKWebView *_customWebview;
    NSString *_defaultKeychainGroup;
}
```

### 9. Categories

**MUST** prefix category methods with `msid` to avoid collisions:

```objc
// Correct
@interface NSArray (MSIDAccessors)
- (id)msidObjectOrNilAtIndex:(NSUInteger)index;
@end

// Incorrect - may conflict with other libraries
@interface NSArray (MSIDAccessors)
- (id)objectOrNilAtIndex:(NSUInteger)index;
@end
```

### 10. Comments

**SHOULD** explain **why**, not what.
**MUST** keep comments up-to-date or delete them.
**NOT RECOMMENDED:** Block comments (code should be self-documenting).

### 11. Literals

**SHOULD** use literals for `NSString`, `NSDictionary`, `NSArray`, `NSNumber`:

```objc
// Preferred
NSArray *scopes = @[@"user.read", @"mail.read", @"profile"];
NSDictionary *claims = @{@"id_token": @{@"auth_time": @{@"essential": @YES}}};
NSNumber *isEnabled = @YES;
NSNumber *timeout = @30;

// Avoid
NSArray *scopes = [NSArray arrayWithObjects:@"user.read", @"mail.read", @"profile", nil];
```

**Warning:** Never pass `nil` into array/dictionary literals - causes crash.

### 12. Constants

**MUST** declare as `static` constants:

```objc
static NSString * const MSIDInvalidTokenResultKey = @"MSIDInvalidTokenResultKey";
static const CGFloat MSIDDefaultTimeout = 30.0;
static const NSTimeInterval MSIDTokenExpirationBuffer = 300.0;
```

**MAY** use `#define` only when explicitly used as a macro.

### 13. Enumerated Types

**MUST** use `NS_ENUM()` for enumerations:

```objc
typedef NS_ENUM(NSInteger, MSIDThrottlingType)
{
    MSIDThrottlingTypeNone = 0,
    MSIDThrottlingType429 = 1,
    MSIDThrottlingTypeInteractiveRequired = 2
};
```

### 14. Private Properties

**SHALL** declare private properties in class extensions in implementation file:

```objc
// In MSIDDRSDiscoveryRequest.m
@interface MSIDDRSDiscoveryRequest()

@property (nonatomic) NSString *domain;
@property (nonatomic) MSIDDRSType adfsType;

@end
```

### 15. Singletons

**SHOULD** use thread-safe pattern with `dispatch_once`:

```objc
+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}
```

### 16. Imports

**MUST NOT** group imports (repository convention).

```objc
// Correct (as used in this repository)
#import "MSIDSSOExtensionSignoutController.h"
#import "MSIDSSOExtensionSignoutRequest.h"
#import "MSIDInteractiveRequestParameters.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDMainThreadUtil.h"

// Do NOT group like this
// Frameworks
#import <Foundation/Foundation.h>

// Extensions
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"
```

### 21. Protocols (Delegates)

**SHOULD** make first parameter the object sending the message:

```objc
// Correct
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

// Incorrect
- (void)didSelectTableRowAtIndexPath:(NSIndexPath *)indexPath;
```

### 22. Block Declarations

**SHOULD** use clear formatting for complex blocks:

```objc
MSIDRequestCompletionBlock completionBlockWrapper = ^(MSIDTokenResult *result, NSError *error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Silent broker xpc flow finished. Result %@, error: %ld error domain: %@, shouldFallBack: %@", _PII_NULLIFY(result), (long)error.code, error.domain, @(self.fallbackController != nil));
        completionBlock(result, error);
    };
```

### 23. Xcode Project Organization

**SHOULD** keep physical files in sync with Xcode project structure.
**SHOULD** reflect Xcode groups as filesystem folders.
**SHOULD** group code by feature, not just by type.
**SHOULD** enable "Treat Warnings as Errors" build setting.

---

## Swift Code Style Rules

### 1. Formatting and Indentation

- **MUST** use 4-space indentation (no tabs).
- **MUST** keep opening braces on the same line for types, functions, and control flow.
- **SHOULD** keep one blank line between methods for readability.
- **MUST** preserve the existing whitespace style within a file; do not normalize spacing differences between files.

```swift
class MSIDFlightManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
}
```

### 2. Naming

- **MUST** use `MSID` prefix for library types in Swift when adding new shared types.
- **MUST** use PascalCase for type names and enum cases.
- **MUST** use lowerCamelCase for functions, variables, and properties.

```swift
public enum Result<T> {
    case Success(T)
    case Failure(Error)
}
```

### 3. Access Control

- **SHOULD** specify access control (`private`, `internal`, `public`) explicitly.
- **SHOULD** keep helpers `private`/`internal` and limit exposure in test helpers.

### 4. Spacing Conventions

- **MUST** follow the existing spacing conventions in the file for type annotations and `switch` cases.
- In this repository you will encounter both `Type: Protocol` and `Type : Protocol` styles; match the local file.
- In `switch` statements, spacing around `case` colons must follow the local file style.

```swift
struct SecretInfo : Codable {
    let id: String
}

switch result {
case .Failure(let err) : return .Failure(err)
case .Success(let list) :
    return .Success(list)
}
```

### 5. Comments

- **SHOULD** use `// MARK:` separators in tests to group related cases.
- **MUST** keep comments accurate; remove stale comments.

---

## AI Agent-Specific Guidelines

### When Adding New Features:

1. **Match Existing Patterns**: Analyze similar existing code before implementing
2. **Follow Common Core Conventions**: Use `MSID` for classes
3. **Maintain Consistency**: Match indentation, spacing, and naming in surrounding code
4. **Property-First**: Use `@property` declarations rather than instance variables
5. **Error Handling**: Always check return values, never the error variable
6. **Thread Safety**: Use `dispatch_once` for singletons, consider thread safety for shared resources
7. **Memory Management**: Follow ARC patterns, be mindful of retain cycles
8. **Nil Safety**: Never pass `nil` to array/dictionary literals
9. **Documentation**: Add header documentation for public APIs
10. **Test Coverage**: Consider how changes affect existing tests

### When Modifying Existing Code:

1. **Preserve Style**: Don't mix styles within a file
2. **Minimal Changes**: Change only what's necessary
3. **Update Comments**: Keep comments synchronized with code changes
4. **Deprecation**: Use proper deprecation warnings when replacing APIs
5. **Backward Compatibility**: Consider impact on existing integrations

### Common Patterns:

#### Error Handling Pattern

```objc
NSError *msidError = nil;
BOOL result = [self performOperationWithError:&msidError];

if (!result)
{
    NSString *message = @"Failed perform operation MSIDOperationA"];
    if (error) *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, message, nil, nil, nil, nil, nil, YES);
    return nil;
}
```

#### Completion Block Pattern

```objc
__auto_type block = ^(MSIDResult *result, NSError *error)
{
    // Process result
    
    if (!completionBlock) return;
    
    if (parameters.completionBlockQueue)
    {
        dispatch_async(parameters.completionBlockQueue, ^{
            completionBlock(result, error);
        });
    }
    else
    {
        completionBlock(result, error);
    }
};
```

#### Logging Pattern

```objc
MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, 
                      @"Operation completed with account %@", 
                      MSID_PII_LOG_EMAIL(account.username));
```

### Code Review Checklist:

- [ ] Uses 4-space indentation (no tabs)
- [ ] Opening braces on new line
- [ ] All conditionals have braces
- [ ] Error handling checks return value, not error variable
- [ ] Method signatures properly spaced
- [ ] Variables descriptively named
- [ ] Pointers attached to variable names
- [ ] Uses properties instead of instance variables
- [ ] Category methods prefixed with `msid`
- [ ] Uses `NS_ENUM` for enumerations
- [ ] Private properties in class extension
- [ ] Singletons use `dispatch_once`
- [ ] Imports not grouped (per repository style)
- [ ] Delegate methods include sender as first parameter
- [ ] No warnings or errors in build
- [ ] Follows existing MSID patterns

---

## References

- [Apple: The Objective-C Programming Language](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html)
- [Apple: Coding Guidelines for Cocoa](https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html)
- [Apple: Memory Management Programming Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmPractical.html)
- [IETF RFC 2119: Key words for use in RFCs](http://tools.ietf.org/html/rfc2119)

---

## Repository-Specific Conventions

### Copyright Header

All new files **MUST** include the Microsoft copyright header when added to this repository:

```objc
//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------
```

---

## Notes

This style guide is adapted specifically for AI agents working on the Microsoft Authentication Library Common for iOS and macOS. When in doubt, prioritize consistency with existing codebase patterns over strict adherence to external style guides.
