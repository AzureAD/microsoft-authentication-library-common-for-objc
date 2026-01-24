# Using MSIDWebviewSessionManager in Controllers

## Overview

`MSIDWebviewSessionManager` is a standalone class that manages webview session state, response handling, and custom URL actions for interactive authentication flows. It can be used by **any controller** (local or broker) via composition, enabling code sharing across different contexts.

## Architecture

### Before (Category-Based)
```
MSIDLocalInteractiveController+WebviewExtensions (Category)
  └── All logic tied to MSIDLocalInteractiveController
  └── Cannot be reused by broker controllers
```

### After (Manager-Based)
```
MSIDWebviewSessionManager (Standalone)
  └── Reusable by any controller via composition

MSIDLocalInteractiveController
  └── Uses MSIDWebviewSessionManager (via category for backwards compatibility)

MSIDBrokerInteractiveController (in broker repo)
  └── Can use MSIDWebviewSessionManager directly
```

## Usage in MSIDLocalInteractiveController

### Option 1: Via Category (Backwards Compatible)

```objc
#import "MSIDLocalInteractiveController+WebviewExtensions.h"

// Use as before - category automatically creates manager
[localController configureWebviewWithResponseHandling:webviewController];

// Configure captured headers
localController.capturedHeaderKeys = [NSSet setWithArray:@[@"x-custom-header"]];

// Set custom URL handler
localController.customURLActionHandler = ^(NSURL *url, void(^completion)(MSIDWebviewAction *action)) {
    // Custom logic
};
```

### Option 2: Direct Manager Usage

```objc
#import "MSIDWebviewSessionManager.h"

// Create manager explicitly
MSIDWebviewSessionManager *manager = [[MSIDWebviewSessionManager alloc] initWithController:localController];

// Configure
manager.capturedHeaderKeys = [NSSet setWithArray:@[@"x-custom-header"]];
[manager configureWebview:webviewController];

// Access state
NSString *header = [manager.responseHeaderStore headerForKey:@"x-custom-header"];
```

## Usage in MSIDBrokerInteractiveController (Broker Repo)

### Step 1: Make Controller Conform to Protocol

```objc
// In MSIDBrokerInteractiveController.h
#import "MSIDWebviewSessionManager.h"

@interface MSIDBrokerInteractiveController : MSIDBaseRequestController <MSIDRequestControlling, MSIDWebviewSessionControlling>

@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;

@end
```

```objc
// In MSIDBrokerInteractiveController.m

- (instancetype)initWithInteractiveRequestParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                  fallbackController:(id<MSIDRequestControlling>)fallbackController
                                               error:(NSError **)error
{
    self = [super initWithRequestParameters:parameters
                       tokenRequestProvider:tokenRequestProvider
                         fallbackController:fallbackController
                                      error:error];
    if (self)
    {
        // Create webview session manager
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
    }
    return self;
}

// Implement protocol (already have this property)
- (id<MSIDRequestContext>)requestParameters
{
    return self.interactiveParameters;
}
```

### Step 2: Use Manager in Broker Controller

```objc
// When creating webview
- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    // ... existing code to create webview ...
    
    // Configure webview with manager
    [self.webviewSessionManager configureWebview:webviewController];
    
    // Optional: Configure captured headers
    self.webviewSessionManager.capturedHeaderKeys = [NSSet setWithArray:@[
        @"x-broker-specific-header",
        @"x-install-url",
        @"authorization"
    ]];
    
    // Optional: Set custom URL handler
    self.webviewSessionManager.customURLActionHandler = ^(NSURL *url, void(^completion)(MSIDWebviewAction *action)) {
        // Broker-specific URL handling
        if ([url.host isEqualToString:@"broker-action"]) {
            [self handleBrokerAction:url completion:completion];
        }
        else {
            // Fall back to default handling
            [self.webviewSessionManager handleCustomURLAction:url completion:completion];
        }
    };
    
    // Start webview
    [webviewController startWithCompletionHandler:^(NSURL *url, NSError *error) {
        // Handle completion
    }];
}

// Access captured headers
- (void)processEnrollmentHeaders
{
    NSString *installUrl = [self.webviewSessionManager.responseHeaderStore headerForKey:@"x-install-url"];
    NSString *authToken = [self.webviewSessionManager.responseHeaderStore headerForKey:@"authorization"];
    
    // Use headers for broker-specific logic
}
```

## Protocol Requirements

Any controller using `MSIDWebviewSessionManager` must implement `MSIDWebviewSessionControlling`:

```objc
@protocol MSIDWebviewSessionControlling <NSObject>

@required
/**
 Request context for logging and correlation.
 */
@property (nonatomic, readonly, nullable) id<MSIDRequestContext> requestParameters;

@end
```

This minimal protocol allows the manager to access logging context from any controller.

## Complete Example: Broker Controller Integration

```objc
// MSIDBrokerInteractiveController.h
#import "MSIDWebviewSessionManager.h"

@interface MSIDBrokerInteractiveController : MSIDBaseRequestController <MSIDWebviewSessionControlling>

@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;

@end

// MSIDBrokerInteractiveController.m

@implementation MSIDBrokerInteractiveController

- (instancetype)initWithInteractiveRequestParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                  fallbackController:(id<MSIDRequestControlling>)fallbackController
                                               error:(NSError **)error
{
    self = [super initWithRequestParameters:parameters
                       tokenRequestProvider:tokenRequestProvider
                         fallbackController:fallbackController
                                      error:error];
    if (self)
    {
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
        
        // Configure for broker-specific enrollment flow
        _webviewSessionManager.capturedHeaderKeys = [NSSet setWithArray:@[
            @"x-broker-enrollment-token",
            @"x-device-registration-url",
            @"x-ms-clitelem"
        ]];
    }
    return self;
}

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    // Create webview
    id<MSIDWebviewInteracting> webview = [self createWebviewWithParameters:self.interactiveParameters];
    
    // Configure with session manager
    [self.webviewSessionManager configureWebview:webview];
    
    // Start webview
    [webview startWithCompletionHandler:^(NSURL *url, NSError *error) {
        if (url) {
            // Access captured headers for broker processing
            [self processBrokerEnrollment];
        }
        completionBlock(result, error);
    }];
}

- (void)processBrokerEnrollment
{
    // Retrieve captured headers
    NSString *enrollmentToken = [self.webviewSessionManager.responseHeaderStore 
                                  headerForKey:@"x-broker-enrollment-token"];
    NSString *registrationUrl = [self.webviewSessionManager.responseHeaderStore 
                                  headerForKey:@"x-device-registration-url"];
    
    if (enrollmentToken && registrationUrl) {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.interactiveParameters,
                         @"Processing broker enrollment with captured headers");
        
        // Broker-specific enrollment logic
        [self enrollDeviceWithToken:enrollmentToken url:registrationUrl];
    }
}

@end
```

## Key Benefits

### Code Reuse
- ✅ Same logic in both local and broker controllers
- ✅ No duplication between repos
- ✅ Single source of truth for webview session management

### Flexibility
- ✅ Each controller can customize behavior (headers, handlers)
- ✅ Controllers maintain independence
- ✅ Easy to add controller-specific logic

### Maintainability
- ✅ Bug fixes in one place benefit all controllers
- ✅ Clear separation of concerns
- ✅ Testable in isolation

### Backwards Compatibility
- ✅ Existing category still works for MSIDLocalInteractiveController
- ✅ No breaking changes to existing code
- ✅ Gradual migration path

## Testing

### Unit Tests for Manager

```objc
- (void)testManagerCapturesHeaders
{
    MSIDWebviewSessionManager *manager = [[MSIDWebviewSessionManager alloc] initWithController:nil];
    manager.capturedHeaderKeys = [NSSet setWithArray:@[@"x-custom-header"]];
    
    // Create mock response event
    MSIDWebviewResponseEvent *event = [[MSIDWebviewResponseEvent alloc] 
                                        initWithURL:[NSURL URLWithString:@"https://test.com"]
                                        httpHeaders:@{@"X-Custom-Header": @"value123"}
                                        statusCode:302];
    
    // Capture headers
    [manager captureHeadersFromResponseEvent:event];
    
    // Verify
    NSString *captured = [manager.responseHeaderStore headerForKey:@"x-custom-header"];
    XCTAssertEqualObjects(captured, @"value123");
}
```

### Integration Tests

Test that both local and broker controllers can use the manager successfully with their respective webview configurations.

## Migration Guide

### For Existing MSIDLocalInteractiveController Code
No changes needed - category provides backwards compatibility.

### For New Broker Controller Integration
1. Import `MSIDWebviewSessionManager.h`
2. Make controller conform to `MSIDWebviewSessionControlling`
3. Create manager in init: `_webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self]`
4. Configure webview: `[self.webviewSessionManager configureWebview:webviewController]`
5. Use captured headers as needed

## Summary

`MSIDWebviewSessionManager` solves the code sharing problem by providing a standalone, reusable component that works with any controller via composition. Both `MSIDLocalInteractiveController` and `MSIDBrokerInteractiveController` can use the same implementation without duplication.
