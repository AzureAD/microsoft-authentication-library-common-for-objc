# Generic Webview Extensions for Enrollment and Registration Flows

## Overview

This document describes the architecture and implementation of generic webview extensions in the Microsoft Authentication Library Common for Objective-C. The implementation uses a **manager-based composition pattern** that enables code sharing across different controller types (local and broker contexts).

The implementation enables enhanced webview flows that support device enrollment, registration, and other scenarios requiring:

1. **Best-effort BRT (Broker Refresh Token) acquisition** with controlled retry logic
2. **Response header capture** from HTTP 302 redirects for enrollment/registration metadata
3. **Extensible custom URL handling** for enrollment actions (msauth://enroll, msauth://installProfile, msauth://profileInstalled, and custom schemes)
4. **System webview header injection** for profile installation and similar flows
5. **Pluggable action handlers** for custom enrollment scenarios
6. **Code reuse across controllers** - same logic can be used by MSIDLocalInteractiveController and MSIDBrokerInteractiveController

The implementation is generic and not tied to any specific enrollment provider (e.g., Intune). It provides a flexible framework that can be configured for various enrollment/registration scenarios.

## Architecture Overview

### Manager-Based Composition

The functionality is implemented in `MSIDWebviewSessionManager`, a standalone class that can be used by **any controller** via composition:

```
┌─────────────────────────────────────────────────────────┐
│         MSIDWebviewSessionManager (Core Logic)          │
│                                                           │
│  • Header capture and storage                           │
│  • BRT attempt tracking                                 │
│  • Custom URL action handling                           │
│  • Webview configuration                                │
│  • Pluggable action handlers                            │
└───────────────────┬─────────────────────────────────────┘
                    │
                    │ Used by (composition)
                    │
        ┌───────────┴────────────┐
        │                        │
        ▼                        ▼
┌──────────────────┐    ┌──────────────────┐
│ Local Controller │    │ Broker Controller│
│                  │    │                  │
│ MSIDLocal...     │    │ MSIDBroker...    │
│ (Identity Core)  │    │ (Broker Repo)    │
└──────────────────┘    └──────────────────┘
```

This architecture allows:
- ✅ Code sharing between local and broker contexts
- ✅ No duplication across repositories
- ✅ Independent testing of manager logic
- ✅ Consistent usage pattern across all controllers

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    InteractiveController                     │
│  (MSIDLocalInteractiveController / MSIDBrokerInteractive)   │
│                                                               │
│  • Owns BRT attempt tracking (max 2 per session)            │
│  • Stores captured headers (configurable keys)              │
│  • Implements custom URL action handlers (extensible)       │
│  • Coordinates webview → token request transitions           │
│  • Supports pluggable action handlers via blocks            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Sets callbacks:
                        │ • webviewResponseEventBlock
                        │ • webviewActionDecisionBlock
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              MSIDAADOAuthEmbeddedWebviewController          │
│              (WKWebView-based embedded webview)              │
│                                                               │
│  • Captures HTTP response headers (all navigations)         │
│  • Forwards MSIDWebviewResponseEvent to controller          │
│  • Intercepts msauth:// and browser:// URLs                 │
│  • Invokes async action callback for decision               │
│  • Executes action returned by controller                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│        MSIDASWebAuthenticationSessionHandler                │
│          (ASWebAuthenticationSession wrapper)                │
│                                                               │
│  • Accepts additionalHeaders in initializer                 │
│  • Applies headers to session (iOS 17.4+, macOS 14.4+)      │
│  • Used for profile installation and similar handoffs       │
└─────────────────────────────────────────────────────────────┘
```

## Component Overview

### Core Manager

#### MSIDWebviewSessionManager
The central component that manages all webview session state and logic. This manager can be used by any controller (local or broker) via composition.

```objc
@interface MSIDWebviewSessionManager : NSObject

@property (nonatomic, weak, nullable) id<MSIDWebviewSessionControlling> controller;
@property (nonatomic, readonly) MSIDBRTAttemptTracker *brtAttemptTracker;
@property (nonatomic, readonly) MSIDResponseHeaderStore *responseHeaderStore;
@property (nonatomic, copy, nullable) NSSet<NSString *> *capturedHeaderKeys;
@property (nonatomic, copy, nullable) MSIDCustomURLActionHandler customURLActionHandler;

- (instancetype)initWithController:(nullable id<MSIDWebviewSessionControlling>)controller;
- (void)configureWebview:(id)webviewController;
- (void)handleCustomURLAction:(NSURL *)url 
                   completion:(void(^)(MSIDWebviewAction *action))completionHandler;

@end
```

**Usage Examples:**

In MSIDLocalInteractiveController (via category for backwards compatibility):
```objc
[controller configureWebviewWithResponseHandling:webviewController];
```

In MSIDBrokerInteractiveController (direct usage):
```objc
self.webviewSessionManager = [[MSIDWebviewSessionManager alloc] initWithController:self];
[self.webviewSessionManager configureWebview:webviewController];
```

See [MANAGER_USAGE_GUIDE.md](../MANAGER_USAGE_GUIDE.md) for complete integration examples.

### Helper Types

#### MSIDWebviewAction
Represents an action to be taken by the webview controller in response to a navigation event.

```objc
typedef NS_ENUM(NSInteger, MSIDWebviewActionType) {
    MSIDWebviewActionTypeCancel,      // Cancel navigation
    MSIDWebviewActionTypeContinue,    // Continue with default behavior
    MSIDWebviewActionTypeLoadRequest, // Load a new request
    MSIDWebviewActionTypeComplete     // Complete webview flow with URL
};

@interface MSIDWebviewAction : NSObject
@property (nonatomic, readonly) MSIDWebviewActionType actionType;
@property (nonatomic, readonly, nullable) NSURLRequest *request;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *additionalHeaders;
@property (nonatomic, readonly, nullable) NSURL *completeURL;
@end
```

#### MSIDWebviewResponseEvent
Structured event forwarded from webview to InteractiveController containing HTTP response metadata.

```objc
@interface MSIDWebviewResponseEvent : NSObject
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *httpHeaders;
@property (nonatomic, readonly) NSInteger statusCode;
@end
```

#### MSIDResponseHeaderStore
Session-level store for headers captured from 302 responses.

**Stored Headers:**
- `x-ms-clitelem`: Telemetry header
- `X-Intune-AuthToken`: Authentication token for profile installation
- `X-Install-Url`: URL for profile installation endpoint

```objc
@interface MSIDResponseHeaderStore : NSObject
- (void)setHeader:(NSString *)value forKey:(NSString *)key;
- (nullable NSString *)headerForKey:(NSString *)key;
- (NSDictionary<NSString *, NSString *> *)allHeaders;
- (void)clearHeaders;
@end
```

#### MSIDBRTAttemptTracker
Tracks BRT acquisition attempts per token acquisition session.

**Rules:**
- Maximum 2 attempts per session
- First attempt on first msauth:// or browser:// redirect
- Second attempt only if first fails and another redirect occurs
- Failures do not block the flow (best-effort)

```objc
@interface MSIDBRTAttemptTracker : NSObject
@property (nonatomic, readonly) NSInteger attemptCount;
@property (nonatomic, readonly) BOOL canAttemptBRT;
- (BOOL)recordAttempt;
- (void)reset;
@end
```

## Sequence Diagrams

### 1. Token Request with Header Capture

```
┌────────┐         ┌──────────────┐         ┌──────────────┐         ┌────────┐
│  App   │         │ Interactive  │         │   Webview    │         │  AAD   │
│        │         │  Controller  │         │  Controller  │         │        │
└───┬────┘         └──────┬───────┘         └──────┬───────┘         └───┬────┘
    │                     │                        │                     │
    │ acquireToken()      │                        │                     │
    ├────────────────────>│                        │                     │
    │                     │                        │                     │
    │                     │ Set callbacks:         │                     │
    │                     │ - responseEventBlock   │                     │
    │                     │ - actionDecisionBlock  │                     │
    │                     ├───────────────────────>│                     │
    │                     │                        │                     │
    │                     │ startWithCompletion()  │                     │
    │                     ├───────────────────────>│                     │
    │                     │                        │                     │
    │                     │                        │ Initial request     │
    │                     │                        ├────────────────────>│
    │                     │                        │                     │
    │                     │                        │ 302 Redirect        │
    │                     │                        │ Headers:            │
    │                     │                        │ X-Intune-AuthToken  │
    │                     │                        │ X-Install-Url       │
    │                     │                        │<────────────────────┤
    │                     │                        │                     │
    │                     │ responseEvent          │                     │
    │                     │ (headers captured)     │                     │
    │                     │<───────────────────────┤                     │
    │                     │                        │                     │
    │   Store headers     │                        │                     │
    │   in headerStore    │                        │                     │
    │                     │                        │                     │
    │                     │                        │ msauth://...        │
    │                     │                        │<────────────────────┤
    │                     │                        │                     │
    │                     │ actionDecision(url)    │                     │
    │                     │<───────────────────────┤                     │
    │                     │                        │                     │
    │  Parse URL,         │                        │                     │
    │  handle action      │                        │                     │
    │                     │                        │                     │
    │                     │ action (continue/load) │                     │
    │                     ├───────────────────────>│                     │
    │                     │                        │                     │
```

### 2. Enrollment Flow (msauth://enroll)

```
┌────────┐         ┌──────────────┐         ┌──────────────┐         ┌────────┐
│  App   │         │ Interactive  │         │   Webview    │         │  AAD   │
│        │         │  Controller  │         │  Controller  │         │        │
└───┬────┘         └──────┬───────┘         └──────┬───────┘         └───┬────┘
    │                     │                        │                     │
    │                     │                        │ msauth://enroll?    │
    │                     │                        │ cpurl=...           │
    │                     │                        │<────────────────────┤
    │                     │                        │                     │
    │                     │ actionDecision         │                     │
    │                     │<───────────────────────┤                     │
    │                     │                        │                     │
    │  Parse cpurl,       │                        │                     │
    │  attempt BRT        │                        │                     │
    │  (if canAttemptBRT) │                        │                     │
    │                     │                        │                     │
    │  Return action:     │                        │                     │
    │  - LoadRequest      │                        │                     │
    │    with cpurl       │                        │                     │
    │                     │                        │                     │
    │                     │ action                 │                     │
    │                     ├───────────────────────>│                     │
    │                     │                        │                     │
    │                     │                        │ Load cpurl          │
    │                     │                        ├────────────────────>│
```

### 3. Profile Installation Flow (msauth://installProfile)

```
┌────────┐       ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  App   │       │ Interactive  │       │   Webview    │       │  ASWebAuth   │
│        │       │  Controller  │       │  Controller  │       │   Session    │
└───┬────┘       └──────┬───────┘       └──────┬───────┘       └──────┬───────┘
    │                   │                      │                       │
    │                   │                      │ msauth://             │
    │                   │                      │ installProfile        │
    │                   │                      │<──────────────────────┤
    │                   │                      │                       │
    │                   │ actionDecision       │                       │
    │                   │<─────────────────────┤                       │
    │                   │                      │                       │
    │ Get stored        │                      │                       │
    │ X-Install-Url     │                      │                       │
    │ X-Intune-AuthToken│                      │                       │
    │                   │                      │                       │
    │ Open ASWebAuth    │                      │                       │
    │ with headers      │                      │                       │
    │                   ├─────────────────────────────────────────────>│
    │                   │                      │                       │
    │                   │                      │                       │
    │                   │ msauth://profileInstalled                    │
    │                   │<─────────────────────────────────────────────┤
    │                   │                      │                       │
    │ If broker context:│                      │                       │
    │   continue broker │                      │                       │
    │ Else:             │                      │                       │
    │   retry in broker │                      │                       │
```

### 4. BRT Attempt State Machine

```
                    ┌─────────────────┐
                    │   Start Session │
                    │  attemptCount=0 │
                    └────────┬────────┘
                             │
                             │
                    ┌────────▼────────┐
                    │  First msauth:// │
                    │  or browser://   │
                    │  redirect        │
                    └────────┬────────┘
                             │
                             │ canAttemptBRT? YES
                             │
                    ┌────────▼────────┐
                    │  Attempt BRT #1 │
                    │  attemptCount=1 │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  BRT Success?   │
                    └────────┬────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
         YES    │                         │   NO
    ┌───────────▼────────┐   ┌────────────▼──────────┐
    │  Store BRT,        │   │  Record telemetry,    │
    │  Continue flow     │   │  Continue flow        │
    └────────────────────┘   └───────────┬───────────┘
                                         │
                                         │ Another msauth://
                                         │ or browser:// ?
                                         │
                             ┌───────────▼───────────┐
                             │ canAttemptBRT? YES    │
                             │ (attemptCount < 2)    │
                             └───────────┬───────────┘
                                         │
                             ┌───────────▼───────────┐
                             │  Attempt BRT #2       │
                             │  attemptCount=2       │
                             └───────────┬───────────┘
                                         │
                             ┌───────────▼───────────┐
                             │  Continue flow        │
                             │  (regardless of       │
                             │   success/failure)    │
                             └───────────────────────┘
```

## Callback Wiring

### Webview Controller → InteractiveController

**MSIDWebviewResponseEventBlock**: Fired on every WKNavigationDelegate response

```objc
typedef void (^MSIDWebviewResponseEventBlock)(MSIDWebviewResponseEvent *event);
```

**Usage in InteractiveController (Option 1: Simple - Use Built-in):**
```objc
// Configure with defaults - automatically captures common headers
[interactiveController configureWebviewWithResponseHandling:webviewController];

// Optional: Customize which headers to capture
interactiveController.capturedHeaderKeys = [NSSet setWithArray:@[
    @"x-custom-auth-token",
    @"x-install-url",
    @"x-ms-clitelem"
]];
```

**Usage in InteractiveController (Option 2: Manual - Full Control):**
```objc
webviewController.webviewResponseEventBlock = ^(MSIDWebviewResponseEvent *event) {
    // Extract relevant headers (example for enrollment scenario)
    NSString *authToken = event.httpHeaders[@"X-Custom-Auth-Token"];
    NSString *installUrl = event.httpHeaders[@"X-Install-Url"];
    NSString *clitelem = event.httpHeaders[@"x-ms-clitelem"];
    
    // Store in session header store
    if (authToken) [self.headerStore setHeader:authToken forKey:@"X-Custom-Auth-Token"];
    if (installUrl) [self.headerStore setHeader:installUrl forKey:@"X-Install-Url"];
    if (clitelem) [self.headerStore setHeader:clitelem forKey:@"x-ms-clitelem"];
    
    // Update telemetry
    [self updateTelemetryWithHeaders:event.httpHeaders];
};
```

**MSIDWebviewActionDecisionBlock**: Invoked when msauth:// or browser:// URL is encountered

```objc
typedef void (^MSIDWebviewActionDecisionBlock)(NSURL *url, void(^completionHandler)(MSIDWebviewAction *action));
```

**Usage in InteractiveController (Option 1: Simple - Use Built-in):**
```objc
// Use default handler - handles common patterns (enroll, installProfile, profileInstalled)
[interactiveController configureWebviewWithResponseHandling:webviewController];
// Now custom URLs are automatically handled by built-in logic
```

**Usage in InteractiveController (Option 2: Custom Handler):**
```objc
// Set custom handler before configuring
interactiveController.customURLActionHandler = ^(NSURL *url, void(^completionHandler)(MSIDWebviewAction *action)) {
    NSString *host = [url.host lowercaseString];
    
    if ([host isEqualToString:@"custom-action"]) {
        [self handleCustomAction:url completion:completionHandler];
    }
    else {
        // Fall back to built-in handler for standard patterns
        [interactiveController handleCustomURLAction:url completion:completionHandler];
    }
};

[interactiveController configureWebviewWithResponseHandling:webviewController];
```

**Usage in InteractiveController (Option 3: Manual - Full Control):**
```objc
webviewController.webviewActionDecisionBlock = ^(NSURL *url, void(^completionHandler)(MSIDWebviewAction *action)) {
    // Completely custom URL handling logic
    if ([url.host isEqualToString:@"enroll"]) {
        [self handleEnrollAction:url completion:completionHandler];
    }
    else if ([url.host isEqualToString:@"installProfile"]) {
        [self handleInstallProfileAction:url completion:completionHandler];
    }
    else if ([url.host isEqualToString:@"profileInstalled"]) {
        [self handleProfileInstalledAction:url completion:completionHandler];
    }
    else {
        // Default: complete with URL
        completionHandler([MSIDWebviewAction completeAction:url]);
    }
};
```

## State Ownership

### MSIDLocalInteractiveController (WebviewExtensions)
- **MSIDBRTAttemptTracker**: Instance per token acquisition session; reset at start of new session
- **MSIDResponseHeaderStore**: Instance per token acquisition session; cleared between sessions
- **capturedHeaderKeys**: Configurable set of headers to capture; nil defaults to common headers
- **customURLActionHandler**: Optional custom URL action handler; nil uses built-in handler
- **Webview callbacks**: Set when calling configureWebviewWithResponseHandling; cleared when session ends

### Webview Controllers
- **Navigation state**: Managed internally; transitions reported via callbacks
- **HTTP responses**: Captured and forwarded; not stored
- **Action execution**: Synchronous; completed before returning from callback

## Session Lifetime

1. **Session Start**: InteractiveController creates BRTAttemptTracker and ResponseHeaderStore
2. **Webview Creation**: Callbacks set on webview controller
3. **Navigation Flow**: Headers captured, actions handled via callbacks
4. **Session End**: Trackers/stores cleared, callbacks released
5. **New Session**: Fresh trackers/stores created

## Header Capture Strategy

### Configurable Header Capture

**Default Headers (captured if capturedHeaderKeys is nil):**
- `x-ms-clitelem`: Microsoft client telemetry
- `x-intune-authtoken`: Authentication token for profile installation (example)
- `x-install-url`: Installation endpoint URL (example)

**Custom Configuration:**
```objc
// Capture specific headers
interactiveController.capturedHeaderKeys = [NSSet setWithArray:@[
    @"x-custom-token",
    @"x-enrollment-url",
    @"x-device-id"
]];

// Disable header capture
interactiveController.capturedHeaderKeys = [NSSet set];
```

### Capture Points
- **All HTTP responses** via `WKNavigationDelegate.decidePolicyForNavigationResponse`
- Particularly important for **302 redirects** where enrollment/registration metadata is present
- Headers stored in session-level store, overwriting previous values
- **Case-insensitive matching**: Headers are matched without regard to case

### Header Usage
- Headers can be retrieved via `responseHeaderStore.headerForKey:` for use in subsequent requests
- Typically used when custom-scheme redirects occur (e.g., msauth://installProfile)
- **Example**: Installation URL + Auth Token used together when opening system webview
- **Telemetry headers**: Can be forwarded to telemetry system

## Custom URL Action Handling

The framework provides flexible URL action handling through three approaches:

### Built-in Handler (Default)

If no custom handler is set, the built-in `handleCustomURLAction:completion:` method handles common patterns:

**msauth://enroll?cpurl=...**
**Purpose**: Trigger enrollment flow with continuation URL

**Handler Logic**:
1. Extract `cpurl` query parameter
2. If `brtAttemptTracker.canAttemptBRT`, attempt BRT acquisition (non-blocking)
3. Return `MSIDWebviewAction.loadRequestAction` with cpurl as target
4. Record attempt in tracker

### msauth://installProfile
**Purpose**: Hand off to system webview for profile installation

**Handler Logic**:
1. Retrieve `X-Install-Url` from headerStore
2. Retrieve `X-Intune-AuthToken` from headerStore
3. Create ASWebAuthenticationSession with URL from X-Install-Url
4. Apply X-Intune-AuthToken as additional header (if OS supports)
5. Start session
6. Return `MSIDWebviewAction.cancelAction` (embedded webview done)

### msauth://profileInstalled
**Purpose**: Resume flow after profile installation

**Handler Logic**:
- **If broker context available**: Continue broker flow with profileInstalled indication
- **If non-broker context**: Retry entire token request in broker context (existing architecture handles this transition)
- Return appropriate action based on context

## Implementation Notes

### Thread Safety
- Callbacks invoked on main thread (WKWebView delegates run on main)
- InteractiveController state modified on main thread
- BRTAttemptTracker and ResponseHeaderStore not thread-safe; caller ensures serialization

### Error Handling
- **BRT acquisition failure**: Record in telemetry, continue flow (best-effort)
- **Missing headers**: Proceed without them; log warning
- **Invalid URLs**: Return cancel or continue action; log error

### OS Version Compatibility
- **ASWebAuthenticationSession.additionalHeaderFields**: iOS 17.4+, macOS 14.4+
- **Runtime check**: Use `respondsToSelector:` before applying headers
- **Fallback**: If headers not supported, session starts without them (may fail enrollment, but doesn't crash)

### Telemetry
- **BRT attempts**: Count, success/failure
- **Header capture**: Which headers captured, when
- **Action handling**: Which msauth:// URLs encountered
- **Errors**: Any failures in handlers or header application

## Testing Strategy

### Unit Tests
- **MSIDWebviewAction**: Factory methods, property access
- **MSIDWebviewResponseEvent**: Initialization with various header combinations
- **MSIDBRTAttemptTracker**: Attempt tracking, max limit enforcement
- **MSIDResponseHeaderStore**: Set/get/clear operations

### Integration Tests
- **Header capture**: Verify headers captured from mock HTTP responses
- **Action callback**: Mock msauth:// URLs, verify correct actions returned
- **BRT attempt flow**: Simulate multiple redirects, verify attempt limits
- **ASWebAuthenticationSession headers**: Verify headers applied when supported

### Manual/E2E Tests
- **Full enrollment flow**: Real AAD interaction with enrollment trigger
- **Profile installation**: Verify ASWebAuthenticationSession opens with correct URL and headers
- **Broker transition**: Verify profileInstalled triggers broker retry

## Future Enhancements
- **Configurable header list**: Allow apps to specify additional headers to capture
- **Header encryption**: Sensitive headers stored encrypted in memory
- **Advanced BRT retry logic**: Exponential backoff, conditional retry based on error type
- **Enhanced telemetry**: Detailed timing and correlation data for enrollment flows
