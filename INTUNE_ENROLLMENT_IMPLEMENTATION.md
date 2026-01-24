# Intune Enrollment Flow Implementation Summary

This document summarizes the changes made to support Intune enrollment flow requirements in embedded/system webviews.

## Overview

The implementation adds support for:
1. Best-effort BRT (Broker Refresh Token) acquisition with controlled retry logic (max 2 attempts per session)
2. Response header capture from HTTP 302 redirects for enrollment metadata
3. Special URL handling for Intune enrollment actions (msauth://enroll, msauth://installProfile, msauth://profileInstalled)
4. System webview header injection for profile installation flows

## Files Added

### Helper Types
1. **IdentityCore/src/webview/MSIDWebviewAction.h/m**
   - Represents an action to be taken by the webview controller
   - Supports cancel, continue, loadRequest, and complete actions
   - Carries optional additional headers for requests

2. **IdentityCore/src/webview/MSIDWebviewResponseEvent.h/m**
   - Structured event forwarded from webview to InteractiveController
   - Contains URL, HTTP headers, and status code from navigation responses

3. **IdentityCore/src/webview/MSIDBRTAttemptTracker.h/m**
   - Tracks BRT acquisition attempts per token acquisition session
   - Enforces maximum 2 attempts per session
   - Thread-safe when used on main thread (as expected in webview flow)

4. **IdentityCore/src/webview/MSIDResponseHeaderStore.h/m**
   - Session-level store for captured HTTP response headers
   - Stores x-ms-clitelem, X-Intune-AuthToken, X-Install-Url headers
   - Simple key-value store with clear operation

### Reference Implementation
5. **IdentityCore/src/controllers/MSIDLocalInteractiveController+IntuneEnrollment.h/m**
   - Category demonstrating how to wire Intune enrollment callbacks
   - Implements handlers for msauth://enroll, msauth://installProfile, msauth://profileInstalled
   - Shows integration pattern for production use

### Documentation
6. **docs/intune-enrollment-webview-flow.md**
   - Comprehensive design document with architecture diagrams
   - Sequence diagrams for enrollment flows
   - BRT state machine documentation
   - Callback wiring guide

### Unit Tests
7. **IdentityCore/tests/MSIDWebviewActionTests.m**
8. **IdentityCore/tests/MSIDWebviewResponseEventTests.m**
9. **IdentityCore/tests/MSIDBRTAttemptTrackerTests.m**
10. **IdentityCore/tests/MSIDResponseHeaderStoreTests.m**

## Files Modified

### Embedded Webview Controller
1. **IdentityCore/src/webview/embeddedWebview/MSIDOAuth2EmbeddedWebviewController.h**
   - Added MSIDWebviewResponseEventBlock typedef
   - Added MSIDWebviewActionDecisionBlock typedef
   - Added webviewResponseEventBlock property
   - Added webviewActionDecisionBlock property

2. **IdentityCore/src/webview/embeddedWebview/MSIDOAuth2EmbeddedWebviewController.m**
   - Added imports for MSIDWebviewResponseEvent and MSIDWebviewAction
   - Updated decidePolicyForNavigationResponse to capture and forward HTTP headers
   - Response events sent to InteractiveController via callback

3. **IdentityCore/src/webview/embeddedWebview/MSIDAADOAuthEmbeddedWebviewController.m**
   - Added import for MSIDWebviewAction
   - Updated decidePolicyAADForNavigationAction to support async action callback
   - msauth:// and browser:// URLs now invoke webviewActionDecisionBlock
   - Controller executes action returned by InteractiveController

### System Webview Handler
4. **IdentityCore/src/webview/systemWebview/session/MSIDASWebAuthenticationSessionHandler.h**
   - Added new initializer accepting additionalHeaders parameter

5. **IdentityCore/src/webview/systemWebview/session/MSIDASWebAuthenticationSessionHandler.m**
   - Added additionalHeaders property
   - Original initializer now delegates to new one with nil headers
   - Headers applied to ASWebAuthenticationSession via performSelector (iOS 17.4+, macOS 14.4+)
   - Runtime check ensures compatibility with older OS versions

6. **IdentityCore/src/webview/systemWebview/session/MSIDSystemWebViewControllerFactory.m**
   - Added new factory method accepting additionalHeaders parameter
   - Original factory method delegates to new one with nil headers
   - Headers passed to ASWebAuthenticationSessionHandler initializer

## Integration Guide

### For Library Consumers

#### Step 1: Create Trackers and Stores
```objc
// In your InteractiveController or token request flow
MSIDBRTAttemptTracker *brtTracker = [[MSIDBRTAttemptTracker alloc] init];
MSIDResponseHeaderStore *headerStore = [[MSIDResponseHeaderStore alloc] init];
```

#### Step 2: Configure Webview Callbacks
```objc
// After webview controller is created
__weak typeof(self) weakSelf = self;

// Capture headers from HTTP responses
webviewController.webviewResponseEventBlock = ^(MSIDWebviewResponseEvent *event) {
    __strong typeof(self) strongSelf = weakSelf;
    if (!strongSelf) return;
    
    // Store relevant headers (case-insensitive)
    for (NSString *key in event.httpHeaders) {
        if ([[key lowercaseString] isEqualToString:@"x-intune-authtoken"]) {
            [strongSelf.headerStore setHeader:event.httpHeaders[key] forKey:@"X-Intune-AuthToken"];
        }
        // ... store other headers
    }
};

// Handle msauth:// and browser:// actions
webviewController.webviewActionDecisionBlock = ^(NSURL *url, void(^completion)(MSIDWebviewAction *action)) {
    __strong typeof(self) strongSelf = weakSelf;
    if (!strongSelf) {
        completion([MSIDWebviewAction continueAction]);
        return;
    }
    
    if ([url.host isEqualToString:@"enroll"]) {
        [strongSelf handleEnrollAction:url completion:completion];
    }
    else if ([url.host isEqualToString:@"installprofile"]) {
        [strongSelf handleInstallProfileAction:url completion:completion];
    }
    else {
        completion([MSIDWebviewAction completeAction:url]);
    }
};
```

#### Step 3: Implement Action Handlers
See `MSIDLocalInteractiveController+IntuneEnrollment.m` for reference implementations of:
- `handleEnrollAction:completion:` - BRT acquisition and cpurl loading
- `handleInstallProfileAction:completion:` - ASWebAuthenticationSession with headers
- `handleProfileInstalledAction:completion:` - Broker context continuation

### For ASWebAuthenticationSession with Headers
```objc
// Create session with additional headers
id<MSIDWebviewInteracting> session = 
    [[MSIDASWebAuthenticationSessionHandler alloc] initWithParentController:parentVC
                                                                    startURL:installURL
                                                              callbackScheme:@"msauth"
                                                          useEmpheralSession:YES
                                                           additionalHeaders:@{@"X-Intune-AuthToken": token}];
[session startWithCompletionHandler:^(NSURL *url, NSError *error) {
    // Handle completion
}];
```

## Testing

All unit tests are in `IdentityCore/tests/`:
- `MSIDWebviewActionTests.m` - Tests all action factory methods
- `MSIDWebviewResponseEventTests.m` - Tests event initialization
- `MSIDBRTAttemptTrackerTests.m` - Tests attempt tracking and limits
- `MSIDResponseHeaderStoreTests.m` - Tests header storage and retrieval

Run tests using Xcode or xcodebuild:
```bash
xcodebuild test -workspace IdentityCore.xcworkspace -scheme IdentityCore -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Security Considerations

1. **Header Storage**: Headers are stored in memory only, cleared between sessions
2. **BRT Acquisition**: Best-effort only, failures don't block flow
3. **OS Version Checks**: ASWebAuthenticationSession header support checked at runtime
4. **Thread Safety**: All callbacks invoked on main thread, state modified on main thread only

## Backward Compatibility

- Existing flows unchanged - new callbacks are optional
- System webview handler maintains original initializer for backward compatibility
- Factory methods maintain original signatures, new parameters are optional
- No breaking changes to public APIs

## Known Limitations

1. **ASWebAuthenticationSession Headers**: Only supported on iOS 17.4+, macOS 14.4+
2. **BRT Acquisition**: Reference implementation only - actual BRT logic not included
3. **Thread Safety**: BRTAttemptTracker and ResponseHeaderStore not thread-safe - caller must serialize access
4. **Error Handling**: Production implementations should add comprehensive error handling and telemetry

## Next Steps

For production deployment:
1. Integrate reference implementation into main InteractiveController flow
2. Implement actual BRT acquisition logic in handleEnrollAction
3. Add comprehensive telemetry for enrollment flows
4. Add integration tests for full enrollment scenarios
5. Document enrollment flow for app developers

## References

- [Design Document](docs/intune-enrollment-webview-flow.md)
- [Intune Enrollment Overview](https://docs.microsoft.com/en-us/intune/)
- [ASWebAuthenticationSession Documentation](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
