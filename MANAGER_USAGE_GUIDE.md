# Using MSIDWebviewSessionManager

## Overview

`MSIDWebviewSessionManager` is a standalone class that manages webview session state, response handling, and custom URL actions. It is used **directly by all controllers** (local and broker) via composition.

## Architecture

```
MSIDWebviewSessionManager (Standalone)
├── Used directly by MSIDLocalInteractiveController
└── Used directly by MSIDBrokerInteractiveController

No wrapper layers - simple and consistent!
```

## Integration Pattern (Same for All Controllers)

### Step 1: Import Manager

```objc
#import "MSIDWebviewSessionManager.h"
```

### Step 2: Declare Property

```objc
@interface YourController : MSIDBaseRequestController <MSIDWebviewSessionControlling>

@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;

@end
```

### Step 3: Create Manager in Init

```objc
- (instancetype)init
{
    self = [super init];
    if (self) {
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
    }
    return self;
}

// Implement protocol requirement
- (id<MSIDRequestContext>)requestParameters
{
    return self.interactiveParameters; // Provide your request context
}
```

### Step 4: Configure Webview

```objc
- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    // Create webview
    id<MSIDWebviewInteracting> webview = [self createWebview];
    
    // Configure with manager
    [self.webviewSessionManager configureWebview:webview];
    
    // Optional: Configure captured headers
    self.webviewSessionManager.capturedHeaderKeys = [NSSet setWithArray:@[
        @"x-custom-token",
        @"x-install-url",
        @"x-ms-clitelem"
    ]];
    
    // Optional: Set custom URL handler
    self.webviewSessionManager.customURLActionHandler = ^(NSURL *url, void(^completion)(MSIDWebviewAction *action)) {
        if ([url.host isEqualToString:@"custom-action"]) {
            [self handleCustomAction:url completion:completion];
        }
        else {
            [self.webviewSessionManager handleCustomURLAction:url completion:completion];
        }
    };
    
    // Start webview
    [webview startWithCompletionHandler:^(NSURL *url, NSError *error) {
        completionBlock(result, error);
    }];
}
```

### Step 5: Use Captured Headers

```objc
- (void)processEnrollmentHeaders
{
    NSString *token = [self.webviewSessionManager.responseHeaderStore headerForKey:@"x-custom-token"];
    NSString *url = [self.webviewSessionManager.responseHeaderStore headerForKey:@"x-install-url"];
    
    // Use headers for your logic
}
```

## Example: MSIDLocalInteractiveController Integration

```objc
// MSIDLocalInteractiveController.h (or private header)
#import "MSIDWebviewSessionManager.h"

@interface MSIDLocalInteractiveController : MSIDBaseRequestController <MSIDWebviewSessionControlling>

@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;

@end

// MSIDLocalInteractiveController.m

- (instancetype)initWithInteractiveRequestParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                                tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                               error:(NSError **)error
{
    self = [super initWithRequestParameters:parameters
                       tokenRequestProvider:tokenRequestProvider
                         fallbackController:nil
                                      error:error];
    if (self) {
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
    }
    return self;
}

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    // Create webview
    // ...
    
    // Configure with manager
    [self.webviewSessionManager configureWebview:webviewController];
    
    // Start webview
    // ...
}
```

## Example: MSIDBrokerInteractiveController Integration (Broker Repo)

```objc
// In MSIDBrokerInteractiveController.h
#import "MSIDWebviewSessionManager.h"

@interface MSIDBrokerInteractiveController : MSIDBaseRequestController <MSIDWebviewSessionControlling>

@property (nonatomic, strong) MSIDWebviewSessionManager *webviewSessionManager;

@end

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
    if (self) {
        // Create webview session manager
        _webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
        
        // Optional: Configure for broker-specific headers
        _webviewSessionManager.capturedHeaderKeys = [NSSet setWithArray:@[
            @"x-broker-enrollment-token",
            @"x-device-registration-url"
        ]];
    }
    return self;
}

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    // Create webview
    id<MSIDWebviewInteracting> webview = [self createWebview];
    
    // Configure with manager (same as local controller!)
    [self.webviewSessionManager configureWebview:webview];
    
    // Start webview
    [webview startWithCompletionHandler:^(NSURL *url, NSError *error) {
        if (url) {
            [self processBrokerEnrollment];
        }
        completionBlock(result, error);
    }];
}

- (void)processBrokerEnrollment
{
    // Access captured headers
    NSString *enrollmentToken = [self.webviewSessionManager.responseHeaderStore 
                                  headerForKey:@"x-broker-enrollment-token"];
    
    if (enrollmentToken) {
        // Broker-specific enrollment logic
        [self enrollDeviceWithToken:enrollmentToken];
    }
}
```

## Protocol Requirements

Any controller using `MSIDWebviewSessionManager` must implement `MSIDWebviewSessionControlling`:

```objc
@protocol MSIDWebviewSessionControlling <NSObject>

@required
@property (nonatomic, readonly, nullable) id<MSIDRequestContext> requestParameters;

@end
```

This minimal protocol allows the manager to access logging context.

## Benefits

### Code Reuse
- ✅ Same implementation used by local and broker controllers
- ✅ No duplication between repositories
- ✅ Single source of truth

### Simplicity
- ✅ Direct usage - no wrapper layers
- ✅ Consistent pattern across all controllers
- ✅ Easy to understand and maintain

### Flexibility
- ✅ Each controller can customize behavior
- ✅ Pluggable handlers for custom logic
- ✅ Configurable header capture

## Testing

```objc
- (void)testManagerConfiguration
{
    // Create mock controller
    id<MSIDWebviewSessionControlling> controller = [self createMockController];
    
    // Create manager
    MSIDWebviewSessionManager *manager = [[MSIDWebviewSessionManager alloc] initWithController:controller];
    
    // Configure
    manager.capturedHeaderKeys = [NSSet setWithArray:@[@"x-test-header"]];
    
    // Create mock webview
    id webview = [self createMockWebview];
    
    // Configure webview
    [manager configureWebview:webview];
    
    // Verify callbacks were set
    XCTAssertNotNil(webview.webviewResponseEventBlock);
    XCTAssertNotNil(webview.webviewActionDecisionBlock);
}
```

## Summary

`MSIDWebviewSessionManager` provides a simple, consistent pattern for all controllers:

1. Create manager in init
2. Configure webview with manager
3. Access captured state via manager

No category wrappers, no backwards compatibility layers - just clean, direct composition! 🎯
