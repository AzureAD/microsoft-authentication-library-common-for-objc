# Architecture: Manager-Based Composition

## Design Decision

Use `MSIDWebviewSessionManager` **directly** in all controllers (local and broker).

## Architecture

```
┌──────────────────────────────────────────┐
│   MSIDWebviewSessionManager              │
│   (Standalone, Reusable)                 │
│                                          │
│   • Header capture & storage            │
│   • BRT attempt tracking                │
│   • Custom URL action handling          │
│   • Webview configuration               │
└──────────────┬───────────────────────────┘
               │
               │ Used directly by
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

## Usage (Same Pattern Everywhere)

### In MSIDLocalInteractiveController

```objc
#import "MSIDWebviewSessionManager.h"

@interface MSIDLocalInteractiveController : MSIDBaseRequestController <MSIDWebviewSessionControlling>
@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;
@end

@implementation MSIDLocalInteractiveController

- (instancetype)init {
    self = [super init];
    if (self) {
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
    }
    return self;
}

- (void)acquireToken {
    [self.webviewSessionManager configureWebview:webviewController];
}

@end
```

### In MSIDBrokerInteractiveController (Broker Repo)

```objc
#import "MSIDWebviewSessionManager.h"

@interface MSIDBrokerInteractiveController : MSIDBaseRequestController <MSIDWebviewSessionControlling>
@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;
@end

@implementation MSIDBrokerInteractiveController

- (instancetype)init {
    self = [super init];
    if (self) {
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
    }
    return self;
}

- (void)acquireToken {
    [self.webviewSessionManager configureWebview:webviewController];
}

@end
```

**Exactly the same pattern! ✅**

## Benefits

### For Identity Core Repo
- ✅ Clean, simple architecture
- ✅ No unnecessary wrapper code
- ✅ Manager is independently testable
- ✅ Provides reusable component for broker repo

### For Broker Repo
- ✅ Import and use manager directly
- ✅ Same pattern as local controller
- ✅ Zero code duplication
- ✅ Single source of truth

### For Maintenance
- ✅ Less code to maintain (no wrapper)
- ✅ Consistent usage pattern
- ✅ Bug fixes benefit all controllers
- ✅ Clear, simple architecture

## Summary

No category wrapper, no backwards compatibility layer, no abstraction overhead.

Just one simple pattern: Create manager, configure webview, use captured state.

Works the same way in both local and broker controllers! 🎯
