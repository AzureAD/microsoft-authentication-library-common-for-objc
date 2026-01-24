# Architecture Migration: Category to Manager-Based Composition

## Problem Statement

The original category-based implementation (`MSIDLocalInteractiveController+WebviewExtensions`) tied the webview session functionality to `MSIDLocalInteractiveController`. This created a code sharing problem:

- ❌ Logic needed by both `MSIDLocalInteractiveController` (identitycore repo) and `ADBrokerInteractiveControllerWithPRT` (broker repo)
- ❌ Category approach prevented code reuse across repositories
- ❌ Would require duplicating all logic in broker repo
- ❌ Maintenance burden: bugs would need fixes in multiple places

## Solution: Manager-Based Composition

Extracted all logic into `MSIDWebviewSessionManager`, a standalone class that can be used by **any controller** via composition.

### Architecture

```
┌──────────────────────────────────────────┐
│   MSIDWebviewSessionManager              │
│   (Standalone, Reusable Component)       │
│                                          │
│   • Header capture & storage            │
│   • BRT attempt tracking                │
│   • Custom URL action handling          │
│   • Webview configuration               │
└──────────────┬───────────────────────────┘
               │
               │ Used by (composition)
               │
    ┌──────────┴─────────────┐
    │                        │
    ▼                        ▼
┌───────────────┐    ┌──────────────────┐
│ Local Context │    │ Broker Context   │
│               │    │                  │
│ MSIDLocal...  │    │ MSIDBroker...    │
│ (This Repo)   │    │ (Broker Repo)    │
└───────────────┘    └──────────────────┘
```

## What Changed

### New Files

1. **MSIDWebviewSessionManager.h** - Public interface for the manager
   - Properties: brtAttemptTracker, responseHeaderStore, capturedHeaderKeys, customURLActionHandler
   - Methods: initWithController:, configureWebview:, handleCustomURLAction:completion:
   - Protocol: MSIDWebviewSessionControlling (defines controller requirements)

2. **MSIDWebviewSessionManager.m** - Implementation with all logic
   - Moved all implementation from category to manager
   - No functional changes to logic, just reorganization

3. **MANAGER_USAGE_GUIDE.md** - Comprehensive usage documentation
   - How to use in local controller
   - How to use in broker controller
   - Complete integration examples
   - Testing guidance

### Updated Files

**MSIDLocalInteractiveController+WebviewExtensions.h**
- Category now references manager
- All properties delegate to manager
- Added deprecation notice
- Backwards compatible

**MSIDLocalInteractiveController+WebviewExtensions.m**
- Category creates MSIDWebviewSessionManager instance
- All methods delegate to manager
- No behavior changes
- Full backwards compatibility

## Code Comparison

### Before (Category)

```objc
// In identitycore repo
@implementation MSIDLocalInteractiveController (WebviewExtensions)

- (void)configureWebviewWithResponseHandling:(id)webviewController
{
    // All logic implemented here
    // Cannot be used by broker controller
}

@end

// In broker repo - would need to duplicate everything
@implementation ADBrokerInteractiveControllerWithPRT (WebviewExtensions)

- (void)configureWebviewWithResponseHandling:(id)webviewController
{
    // Duplicate all the logic ❌
}

@end
```

### After (Manager)

```objc
// MSIDWebviewSessionManager.m (in identitycore repo)
@implementation MSIDWebviewSessionManager

- (void)configureWebview:(id)webviewController
{
    // All logic implemented once ✅
}

@end

// In identitycore repo (backwards compatible)
@implementation MSIDLocalInteractiveController (WebviewExtensions)

- (void)configureWebviewWithResponseHandling:(id)webviewController
{
    [self.webviewSessionManager configureWebview:webviewController];
}

@end

// In broker repo - reuse the manager ✅
@implementation ADBrokerInteractiveControllerWithPRT

- (instancetype)init
{
    self = [super init];
    if (self) {
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
    }
    return self;
}

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    [self.webviewSessionManager configureWebview:webviewController];
    // No duplication! ✅
}

@end
```

## Benefits

### For Identity Core Repo
- ✅ Cleaner architecture (composition over inheritance)
- ✅ Manager is independently testable
- ✅ No breaking changes (category provides backwards compatibility)
- ✅ Provides reusable component for broker repo

### For Broker Repo
- ✅ Can use same logic without duplication
- ✅ Just import manager and create instance
- ✅ Customize behavior via properties and handlers
- ✅ Single source of truth for updates/fixes

### For Maintenance
- ✅ Bug fixes in one place benefit all controllers
- ✅ New features added once, available everywhere
- ✅ Easier to test (manager isolated from controllers)
- ✅ Clear separation of concerns

## Integration Guide for Broker Repo

### Step 1: Import Manager

```objc
// In ADBrokerInteractiveControllerWithPRT.h
#import "MSIDWebviewSessionManager.h"

@interface ADBrokerInteractiveControllerWithPRT : NSObject <MSIDWebviewSessionControlling>

@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;

@end
```

### Step 2: Create Manager

```objc
// In ADBrokerInteractiveControllerWithPRT.m
- (instancetype)initWithParameters:(id)parameters
{
    self = [super init];
    if (self) {
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
    }
    return self;
}
```

### Step 3: Use Manager

```objc
- (void)acquireTokenWithWebview:(id)webviewController
{
    // Configure webview with manager
    [self.webviewSessionManager configureWebview:webviewController];
    
    // Optional: Customize headers
    self.webviewSessionManager.capturedHeaderKeys = [NSSet setWithArray:@[
        @"x-broker-token",
        @"x-enrollment-url"
    ]];
    
    // Start webview
    [webviewController start];
}

- (void)processEnrollmentHeaders
{
    // Access captured headers
    NSString *token = [self.webviewSessionManager.responseHeaderStore 
                       headerForKey:@"x-broker-token"];
    // Use token for broker-specific logic
}
```

## Testing

### Manager Tests (Already Exist)
- ✅ Unit tests for helper types pass
- ✅ Can add new tests for manager in isolation

### Integration Tests
- ✅ Test manager with mock controllers
- ✅ Test backwards compatibility with category
- ✅ Test integration in broker controller

## Migration Checklist

### For Existing Code (No Changes Needed)
- ✅ MSIDLocalInteractiveController works as before
- ✅ Category automatically uses manager
- ✅ No breaking changes

### For Broker Repo Integration
- [ ] Import MSIDWebviewSessionManager
- [ ] Make controller conform to MSIDWebviewSessionControlling
- [ ] Create manager instance in init
- [ ] Call `[manager configureWebview:]` when creating webview
- [ ] Access headers via `manager.responseHeaderStore`

## Summary

The migration from category-based to manager-based composition solves the code sharing problem by:

1. **Extracting logic** into a standalone, reusable manager class
2. **Enabling composition** so any controller can use the manager
3. **Maintaining backwards compatibility** via category delegation
4. **Eliminating duplication** between local and broker contexts
5. **Simplifying maintenance** with single source of truth

Both `MSIDLocalInteractiveController` (identitycore) and `ADBrokerInteractiveControllerWithPRT` (broker) can now use the same implementation without any duplication! 🎉
