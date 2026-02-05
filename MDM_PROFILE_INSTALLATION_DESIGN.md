# MDM Profile Installation with Seamless Webview Transition - Design Document

## Overview

This document describes the design and implementation of seamless MDM (Mobile Device Management) profile installation during OAuth authentication flows in the Microsoft Authentication Library for iOS/macOS.

## Background

### Problem Statement

During OAuth authentication flows, users may need to install an MDM profile to complete device enrollment or compliance checks. Traditionally, this required interrupting the authentication flow, which resulted in:
- Poor user experience with explicit cancellation and restart
- Loss of authentication state
- Complex error handling and recovery logic

### Solution

Implement a seamless webview transition mechanism that allows the authentication flow to suspend temporarily while the MDM profile is installed via `ASWebAuthenticationSession`, then automatically resume without losing state.

## Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────────┐
│                  Authentication Flow                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  MSIDLocalInteractiveController                              │
│         │                                                     │
│         ├──► MSIDAADOAuthEmbeddedWebviewController           │
│         │         │                                           │
│         │         ├──► Detects msauth://installProfile       │
│         │         │                                           │
│         │         └──► Returns NavigationAction               │
│         │                                                     │
│         ├──► MSIDWebviewTransitionCoordinator                │
│         │         │                                           │
│         │         ├──► Suspends Embedded Webview             │
│         │         ├──► Launches ASWebAuthenticationSession   │
│         │         └──► Resumes Embedded Webview              │
│         │                                                     │
│         └──► Handles Completion/Errors                       │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. MSIDWebviewTransitionCoordinator

**Purpose**: Orchestrates seamless transitions between embedded webview and `ASWebAuthenticationSession`.

**Key Responsibilities**:
- Suspend embedded webview (hide UI, keep alive)
- Launch `ASWebAuthenticationSession` for external flows
- Resume suspended webview when external flow completes
- Clean up resources on completion or failure
- Generic design supports any flow requiring `ASWebAuthenticationSession` transition

**Properties**:
```objc
@property (nonatomic, nullable) MSIDOAuth2EmbeddedWebviewController *suspendedEmbeddedWebview;
@property (nonatomic, nullable) MSIDASWebAuthenticationSessionHandler *aSWebAuthenticationSessionHandler;
@property (nonatomic, readonly) BOOL isTransitioning;
```

**Key Methods**:
- `suspendEmbeddedWebview:` - Hides webview UI but keeps it alive
- `launchASWebAuthenticationSession:parentController:additionalHeaders:MSIDSystemWebviewPurpose:context:completion:` - Launches external auth session with optional headers (iOS 18+)
- `resumeSuspendedEmbeddedWebview` - Restores webview UI
- `dismissASWebAuthenticationSession` - Cancels external session
- `cleanup` - Releases all resources

#### 2. MSIDWebviewNavigationAction

**Purpose**: Encapsulates webview navigation decisions and actions.

**Action Types**:
```objc
typedef NS_ENUM(NSInteger, MSIDWebviewNavigationActionType) {
    MSIDWebviewNavigationActionTypeContinueDefault = 0,
    MSIDWebviewNavigationActionTypeLoadRequestInWebview,
    MSIDWebviewNavigationActionTypeOpenInASWebAuthenticationSession,
    MSIDWebviewNavigationActionTypeOpenInExternalBrowser,
    MSIDWebviewNavigationActionTypeCompleteWebAuthWithURL,
    MSIDWebviewNavigationActionTypeFailWithError
};
```

**System Webview Purposes**:
```objc
typedef NS_ENUM(NSInteger, MSIDSystemWebviewPurpose) {
    MSIDSystemWebviewPurposeUnknown = 0,
    MSIDSystemWebviewPurposeInstallProfile  // Requires ephemeral session
};
```

**Properties**:
- `type` - Action type to execute
- `request` - NSURLRequest for LoadRequestInWebview
- `url` - URL for OpenASWebAuthenticationSession or CompleteWithURL
- `purpose` - Purpose for system webview (determines ephemeral behavior)
- `error` - Error for FailWithError
- `additionalHeaders` - HTTP headers for ASWebAuthenticationSession (iOS 18+)

#### 3. MSIDWebMDMInstallProfileResponse

**Purpose**: Detects and parses `msauth://installProfile` trigger URL.

**Responsibilities**:
- Detects URL pattern: `msauth://installProfile`
- Extracts MDM profile installation parameters from HTTP headers
- Supports iOS 18+ header-based approach:
  - `x-intune-url` - Profile installation URL
  - `x-intune-token` - Authentication token

**Properties**:
```objc
@property (atomic, readonly, nullable) NSString *intuneURL;
@property (atomic, readonly, nullable) NSString *intuneToken;
```

#### 4. MSIDWebMDMEnrollmentCompletionResponse

**Purpose**: Detects and parses `msauth://profileInstalled` completion callback.

**Responsibilities**:
- Detects URL pattern: `msauth://profileInstalled`
- Extracts completion status and additional info from query parameters
- Signals that MDM profile installation completed

**Properties**:
```objc
@property (atomic, readonly, nullable) NSString *status;
@property (atomic, readonly, nullable) NSDictionary *additionalInfo;
```

#### 5. MSIDLocalInteractiveController

**Purpose**: Main orchestrator for interactive authentication flows.

**Enhancements**:
- Owns `MSIDWebviewTransitionCoordinator` instance
- Handles profile installation trigger actions
- Processes profile installation completion
- Manages flow transitions and state

**Key Methods**:
- `handleInstallProfileAction:parentController:` - Initiates profile installation flow
- `handleProfileInstalledResponse:` - Processes completion callback
- `resumeEmbeddedWebviewAfterProfileInstallation` - Resumes main auth flow

#### 6. MSIDWebviewNavigationActionUtil

**Purpose**: Utility class for processing special navigation URLs in embedded webview.

**Responsibilities**:
- State machine for URL pattern matching
- Generates appropriate `MSIDWebviewNavigationAction` objects
- Handles:
  - `msauth://installProfile` - Trigger profile installation
  - `msauth://profileInstalled` - Signal completion
  - `browser://` - External browser redirects
  - Standard OAuth callbacks

## Flow Sequence

### MDM Profile Installation Flow

```
┌──────────┐     ┌──────────────┐     ┌────────────────┐     ┌─────────────┐
│   User   │     │   Embedded   │     │  Transition    │     │ ASWebAuth   │
│          │     │   Webview    │     │  Coordinator   │     │   Session   │
└────┬─────┘     └──────┬───────┘     └───────┬────────┘     └──────┬──────┘
     │                  │                      │                     │
     │   Authenticate   │                      │                     │
     ├─────────────────>│                      │                     │
     │                  │                      │                     │
     │                  │  Server redirects    │                     │
     │                  │  msauth://           │                     │
     │                  │  installProfile      │                     │
     │                  │                      │                     │
     │                  │   Suspend Webview    │                     │
     │                  ├─────────────────────>│                     │
     │                  │                      │                     │
     │                  │                      │  Launch Session     │
     │                  │                      │  with profile URL   │
     │                  │                      ├────────────────────>│
     │                  │                      │                     │
     │   [Webview Hidden - State Preserved]    │   Install Profile   │
     │                  │                      │<────────────────────┤
     │                  │                      │                     │
     │                  │                      │  Profile Installed  │
     │                  │   Resume Webview     │  Callback URL       │
     │                  │<─────────────────────┤                     │
     │                  │                      │                     │
     │  Continue Auth   │                      │                     │
     │<─────────────────┤                      │                     │
     │                  │                      │                     │
     │   Complete       │                      │                     │
     │<─────────────────┤                      │                     │
     │                  │                      │                     │
```

### Detailed Step-by-Step Flow

1. **User initiates authentication**
   - App calls MSAL/ADAL interactive API
   - `MSIDLocalInteractiveController` starts embedded webview

2. **Server detects profile installation required**
   - OAuth server returns HTTP redirect to `msauth://installProfile`
   - Server includes headers (iOS 18+):
     - `x-intune-url`: Profile installation URL
     - `x-intune-token`: Authentication token

3. **Webview intercepts special URL**
   - `MSIDAADOAuthEmbeddedWebviewController` intercepts navigation
   - `MSIDWebviewNavigationActionUtil` detects pattern
   - Creates `MSIDWebviewNavigationAction` with:
     - Type: `OpenInASWebAuthenticationSession`
     - URL: Profile installation URL
     - Purpose: `MSIDSystemWebviewPurposeInstallProfile`
     - Headers: `{x-intune-token: <token>}`

4. **Controller handles action**
   - `MSIDLocalInteractiveController` receives action
   - Calls `handleInstallProfileAction:parentController:`
   - Extracts URL and headers from action

5. **Transition coordinator suspends webview**
   - `MSIDWebviewTransitionCoordinator.suspendEmbeddedWebview:` called
   - Stores reference to embedded webview
   - Hides webview UI (keeps instance alive)
   - Sets `isTransitioning = YES`

6. **Launch ASWebAuthenticationSession**
   - `launchASWebAuthenticationSession:...` called
   - Creates ephemeral `ASWebAuthenticationSession` (no cookies shared)
   - On iOS 18+: Passes additional headers to session handler
   - User installs MDM profile in system UI

7. **Profile installation completes**
   - MDM profile installer redirects to `msauth://profileInstalled?status=success`
   - `ASWebAuthenticationSession` completion handler invoked
   - `MSIDWebMDMEnrollmentCompletionResponse` parses callback

8. **Resume embedded webview**
   - Controller calls `handleProfileInstalledResponse:`
   - Validates completion status
   - Calls `resumeSuspendedEmbeddedWebview`
   - Embedded webview UI restored
   - Sets `isTransitioning = NO`

9. **Continue authentication**
   - Embedded webview continues from suspended state
   - Completes OAuth flow normally
   - Returns tokens to app

### Error Handling

**User Cancels Profile Installation**:
- `ASWebAuthenticationSession` returns cancellation error
- Coordinator dismisses suspended webview
- Main auth flow fails with appropriate error
- User sees cancellation message

**Profile Installation Fails**:
- Callback includes `status=failed` or error code
- Coordinator dismisses suspended webview
- Main auth flow fails with profile installation error
- Error propagated to app

**Timeout or Network Error**:
- `ASWebAuthenticationSession` fails with network error
- Coordinator cleans up state
- Main auth flow fails with network error
- User can retry

## HTTP Header Support (iOS 18+)

### Overview

iOS 18+ introduces the ability to pass additional HTTP headers to `ASWebAuthenticationSession` via `additionalHeaderFields` property.

### Implementation

**Header Storage**:
- `MSIDWebviewSession` stores `lastHTTPResponse`
- Factory can access response headers via session
- Headers extracted during response processing

**Header Propagation**:
```objc
// Server includes headers in HTTP response
x-intune-url: https://portal.manage.microsoft.com/EnrollProfile
x-intune-token: <auth-token>

// MSIDWebMDMInstallProfileResponse extracts headers
@property NSString *intuneURL;    // From x-intune-url
@property NSString *intuneToken;  // From x-intune-token

// MSIDWebviewNavigationAction carries headers
@property NSDictionary *additionalHeaders;  // {x-intune-token: <token>}

// MSIDASWebAuthenticationSessionHandler applies headers (iOS 18+)
if (@available(iOS 18.0, *)) {
    session.additionalHeaderFields = additionalHeaders;
}
```

### Fallback for iOS < 18

For devices running iOS < 18, authentication tokens must be passed via URL parameters or query strings since header support is unavailable.

## Special URL Patterns

### msauth://installProfile

**Purpose**: Trigger MDM profile installation flow

**Format**: `msauth://installProfile`

**Headers** (iOS 18+):
- `x-intune-url`: Profile installation URL (required)
- `x-intune-token`: Authentication token (optional)

**Behavior**:
- Suspend embedded webview
- Launch ASWebAuthenticationSession with profile URL
- Use ephemeral session (no cookie sharing)

### msauth://profileInstalled

**Purpose**: Signal profile installation completion

**Format**: `msauth://profileInstalled?status=<status>[&key=value...]`

**Query Parameters**:
- `status`: `success` or `failed` (required)
- Additional info as key-value pairs (optional)

**Behavior**:
- Resume suspended embedded webview
- Continue OAuth flow from suspended state
- Or fail flow if status indicates failure

## Configuration and Constants

### Error Codes

```objc
// MSIDError.h
MSIDErrorProfileInstallationRequired     // Profile must be installed
MSIDErrorProfileInstallationFailed       // Profile installation failed
MSIDErrorProfileInstallationCancelled    // User cancelled installation
```

### URL Schemes

```objc
// MSIDConstants.h
extern NSString * const MSIDURISchemeAuth;         // "msauth"
extern NSString * const MSIDProfileInstallPath;    // "installProfile"
extern NSString * const MSIDProfileInstalledPath;  // "profileInstalled"
```

## Testing Strategy

### Unit Tests

**MSIDWebMDMInstallProfileResponse**:
- ✓ Detects `msauth://installProfile` pattern
- ✓ Extracts x-intune-url header
- ✓ Extracts x-intune-token header
- ✓ Handles missing headers gracefully
- ✓ Rejects invalid URLs

**MSIDWebMDMEnrollmentCompletionResponse**:
- ✓ Detects `msauth://profileInstalled` pattern
- ✓ Parses status parameter
- ✓ Extracts additional info
- ✓ Handles missing parameters

**MSIDWebviewTransitionCoordinator**:
- ✓ Suspends and resumes webview correctly
- ✓ Launches ASWebAuthenticationSession
- ✓ Handles completion callbacks
- ✓ Cleans up resources
- ✓ Thread safety

**MSIDWebviewNavigationAction**:
- ✓ Creates correct action types
- ✓ Carries URL, headers, purpose correctly
- ✓ Factory methods work as expected

### Integration Tests

**End-to-End Flow**:
- Mock OAuth server returns `msauth://installProfile`
- Verify webview suspension
- Mock ASWebAuthenticationSession completion
- Verify webview resumption
- Verify OAuth flow completion

**Error Scenarios**:
- User cancellation
- Network failures
- Invalid callbacks
- Timeout handling

### Manual Testing

**iOS 18+ Devices**:
- Verify header propagation works
- Test with real Intune MDM profile
- Verify ephemeral session behavior

**iOS < 18 Devices**:
- Verify fallback mechanisms work
- Test without header support

## Security Considerations

### Ephemeral Sessions

Profile installation uses ephemeral `ASWebAuthenticationSession`:
- No cookies shared with main session
- No persistent storage
- Isolated from main auth flow

**Rationale**: Profile installation should not share authentication state with the main OAuth flow for security isolation.

### Token Handling

Authentication tokens in `x-intune-token` header:
- Passed securely via HTTPS
- Not logged or persisted
- Only used for single profile installation request
- Cleared after use

### URL Validation

All `msauth://` URLs validated:
- Scheme must be exactly "msauth"
- Path must match expected patterns
- Prevents URL injection attacks

## Performance Considerations

### Memory Management

**Suspended Webview**:
- Kept in memory during transition
- Released after completion or failure
- Typical suspension time: 10-30 seconds

**Resource Cleanup**:
- Coordinator cleans up on completion
- Strong reference breaks prevent leaks
- Automatic cleanup on controller deallocation

### UI Responsiveness

**Transition Speed**:
- Suspend: < 100ms (hide UI)
- Resume: < 100ms (show UI)
- No noticeable delay to user

**Thread Safety**:
- All UI operations on main thread
- Coordinator uses serial queue for state changes
- Callbacks dispatched to main thread

## Future Enhancements

### Potential Improvements

1. **Generic External Session Support**
   - Already designed generically
   - Can support other flows requiring ASWebAuthenticationSession
   - Add new `MSIDSystemWebviewPurpose` values as needed

2. **Progress Indicators**
   - Show loading indicator during transition
   - Display profile installation status
   - Custom UI for profile installation

3. **Retry Logic**
   - Automatic retry on transient failures
   - Exponential backoff
   - User-prompted retry

4. **Analytics and Telemetry**
   - Track profile installation success rates
   - Measure transition times
   - Identify common failure scenarios

5. **Multi-Profile Support**
   - Install multiple profiles in sequence
   - Queue profile installation requests
   - Batch profile installation

## Appendix

### Key Files Modified/Created

**Core Coordinator**:
- `MSIDWebviewTransitionCoordinator.h/m` - NEW

**Navigation Action System**:
- `MSIDWebviewNavigationAction.h/m` - NEW
- `MSIDWebviewNavigationActionUtil.h/m` - NEW
- `MSIDWebviewSpecialNavigationDelegate.h` - NEW

**Response Classes**:
- `MSIDWebMDMInstallProfileResponse.h/m` - NEW (renamed from MSIDWebProfileInstallTriggerResponse)
- `MSIDWebMDMEnrollmentCompletionResponse.h/m` - NEW (renamed from MSIDWebInstallProfileResponse)

**Controller Updates**:
- `MSIDLocalInteractiveController.h/m` - MODIFIED
- `MSIDLocalInteractiveController+Internal.h` - MODIFIED
- `MSIDAADOAuthEmbeddedWebviewController.h/m` - MODIFIED

**Configuration Classes**:
- `MSIDBaseWebRequestConfiguration.h/m` - MODIFIED (added lastHTTPResponse)
- `MSIDAuthorizeWebRequestConfiguration.m` - MODIFIED
- `MSIDWebviewSession.h` - MODIFIED

**Factory Classes**:
- `MSIDWebviewFactory.h/m` - MODIFIED
- `MSIDAADWebviewFactory.m` - MODIFIED

**Session Handler**:
- `MSIDASWebAuthenticationSessionHandler.h/m` - MODIFIED (iOS 18+ headers)

**Request Classes**:
- `MSIDInteractiveAuthorizationCodeRequest.h/m` - MODIFIED
- `MSIDInteractiveTokenRequest.m` - MODIFIED
- `MSIDInteractiveTokenRequestParameters.h` - MODIFIED

**Tests**:
- `MSIDWebProfileInstallTriggerResponseTests.m` - MODIFIED
- `MSIDWebInstallProfileResponseTests.m` - MODIFIED

### Dependencies

**iOS Frameworks**:
- `Foundation.framework`
- `WebKit.framework`
- `AuthenticationServices.framework`

**Minimum Versions**:
- iOS 12.0+ (ASWebAuthenticationSession available)
- iOS 18.0+ (additionalHeaderFields support)

### References

- [Apple ASWebAuthenticationSession Documentation](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [Microsoft Intune MDM Profile Installation](https://learn.microsoft.com/en-us/mem/intune/)
- [OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)

---

**Document Version**: 1.0  
**Last Updated**: February 5, 2026  
**Author**: Microsoft Authentication Library Team  
**Status**: Implementation Complete
