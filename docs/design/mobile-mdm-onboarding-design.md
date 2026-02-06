# Design Document: Mobile MDM Onboarding &amp; In-App Enrollment Flow

**PR:** <a href="https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/pull/1689">#1689 – Veena/mob onb2</a>
**Branch:** `veena/mob_onb2` → `dev`
**Repository:** `AzureAD/microsoft-authentication-library-common-for-objc`
**Author:** @swasti29
**Status:** Draft, Open
**Stats:** +2,814 additions, -37 deletions across 38 files

---

## 1. Executive Summary

This change introduces **in-app MDM (Mobile Device Management) profile installation and enrollment** support into the MSAL common library for Objective-C. It enables an interactive authentication flow where, when the AAD server signals that an Intune management profile must be installed, the embedded webview (WKWebView) seamlessly transitions to an `ASWebAuthenticationSession` for profile installation, then returns to the embedded webview to complete the original authentication. Additionally, it introduces **Broker Refresh Token (BRT)** acquisition logic triggered on special `msauth://` and `browser://` redirects.

---

## 2. Problem Statement

Currently, when AAD determines that a device requires MDM enrollment (Intune profile installation) before authentication can complete, the library lacks the ability to:

1. **Detect** an MDM profile installation trigger (`msauth://installProfile`) from the server.
2. **Orchestrate** a seamless transition from the embedded webview to `ASWebAuthenticationSession` for profile download (which requires system-level handling).
3. **Resume** the embedded webview after profile installation completes (`msauth://in_app_enrollment_complete`).
4. **Acquire a Broker Refresh Token (BRT)** opportunistically on special redirect schemes.
5. **Hand off to the broker** (SSO Extension) after successful enrollment for final token acquisition.

---

## 3. Architecture Overview

### 3.1 High-Level Flow

```
┌──────────────┐     ┌─────────────────────┐     ┌──────────────────────────┐
│  App calls   │────▶│ LocalInteractive     │────▶│ Embedded WKWebview       │
│ acquireToken │     │ Controller           │     │ (AAD login page)         │
└──────────────┘     └─────────────────────┘     └──────────┬───────────────┘
                                                            │
                         ┌──────────────────────────────────┤
                         │ Server returns msauth://          │
                         │ installProfile redirect           │
                         ▼                                   │
              ┌──────────────────────┐                       │
              │ SpecialNavigation    │ Delegate intercepts   │
              │ Delegate callback    │◀──────────────────────┘
              └──────┬───────────────┘
                     │ 1. Acquire BRT (first time only)
                     │ 2. Resolve navigation action
                     ▼
              ┌──────────────────────┐
              │ NavigationActionUtil │  Parses msauth:// URL
              │ resolves action      │  + HTTP response headers
              └──────┬───────────────┘
                     │ Returns: OpenInASWebAuthSession
                     ▼
              ┌──────────────────────┐     ┌─────────────────────────┐
              │ TransitionCoordinator│────▶│ ASWebAuthenticationSession│
              │ - Suspend WKWebview  │     │ (Profile installation)   │
              │ - Launch ASWebAuth   │     └──────────┬──────────────┘
              └──────────────────────┘                │
                                                      │ Callback:
                                                      │ msauth://in_app_enrollment_complete
                                                      ▼
              ┌──────────────────────┐     ┌──────────────────────────┐
              │ TransitionCoordinator│────▶│ Resume WKWebview         │
              │ - Resume webview     │     │ Load enrollment callback │
              │ - Clean up ASWebAuth │     └──────────┬───────────────┘
              └──────────────────────┘                │
                                                      │ WKWebview processes
                                                      │ enrollment completion
                                                      ▼
              ┌──────────────────────────────────────────────────────┐
              │ Controller handles MDMEnrollmentCompletionResponse   │
              │ → Creates BrokerInteractiveController               │
              │ → Delegates to SSO Extension for final token        │
              └─────────────────────────────────────────────────────┘
```

---

## 4. New Components

### 4.1 New Classes

| Class | Location | Purpose |
|---|---|---|
| **`MSIDWebviewNavigationAction`** | `embeddedWebview/` | Value object representing a navigation decision (load request, open ASWebAuth, complete, fail, etc.) with associated action type enum |
| **`MSIDWebviewNavigationActionUtil`** | `util/` | Singleton that resolves `msauth://` URLs into `MSIDWebviewNavigationAction` objects by parsing host/query params and HTTP response headers |
| **`MSIDWebviewTransitionCoordinator`** | `webview/` | Orchestrates suspend/resume of embedded webview and launch/completion of `ASWebAuthenticationSession` |
| **`MSIDWebMDMInstallProfileResponse`** | `webview/response/` | Response model for `msauth://installProfile` trigger, carrying `intuneURL` and `intuneToken` from HTTP headers |
| **`MSIDWebMDMEnrollmentCompletionResponse`** | `webview/response/` | Response model for `msauth://in_app_enrollment_complete`, carrying enrollment `status` and `additionalInfo` |

### 4.2 New Protocol

| Protocol | Location | Purpose |
|---|---|---|
| **`MSIDWebviewSpecialNavigationDelegate`** | `embeddedWebview/` | Delegate protocol allowing controllers to intercept `msauth://` and `browser://` redirects, perform BRT acquisition, and return navigation actions |

### 4.3 New Enums

| Enum | Values | Purpose |
|---|---|---|
| `MSIDWebviewNavigationActionType` | `ContinueDefault`, `LoadRequestInWebview`, `OpenInASWebAuthenticationSession`, `OpenInExternalBrowser`, `CompleteWebAuthWithURL`, `FailWithError` | Defines what the webview should do after a special redirect is intercepted |
| `MSIDSystemWebviewPurpose` | `Unknown`, `InstallProfile` | Defines why an ASWebAuthenticationSession is being launched (affects ephemeral session behavior) |

### 4.4 New Error Code

| Error Code | Value | Purpose |
|---|---|---|
| `MSIDErrorMDMEnrollmentCompletedNeedsRetry` | `-51733` | Signals that MDM enrollment completed and auth should be retried |

---

## 5. Modified Components

### 5.1 `MSIDLocalInteractiveController`

**Major changes** (~+550 / -29 lines):

- **Now conforms to `MSIDWebviewSpecialNavigationDelegate`** – acts as the delegate for embedded webview special redirect handling.
- **New properties:** `transitionCoordinator`, `lastResponseHeaders`, `brtAttempted`, `brtAcquired`.
- **Webview configuration block:** Sets itself as the `specialNavigationDelegate` on the embedded webview controller during initialization.
- **New response handlers:**
  - `handleWebMDMInstallProfileResponse:` – validates Intune URL, suspends webview, launches ASWebAuth.
  - `handleWebMDMEnrollmentCompletionResponse:` – on success, creates `MSIDBrokerInteractiveController` and delegates to broker for final token; on failure, returns error.
  - `handleASWebAuthnSessionCompletion:` – processes ASWebAuth callback, resumes webview.
- **BRT acquisition:** `shouldAcquireBRT` / `acquireBRTWithCompletion:` – acquires BRT on first `msauth://` or `browser://` redirect (one attempt per session, placeholder implementation).
- **Delegate methods:** `webviewController:handleSpecialRedirect:completion:`, `handleMsauthRedirect:`, `handleBrowserRedirect:`, `processResponseHeaders:`, `handleASWebAuthenticationTransitionWithUrl:`.

### 5.2 `MSIDAADOAuthEmbeddedWebviewController`

- **HTTP response capture:** Sets up `navigationResponseBlock` to store the last HTTP response and propagate headers to `MSIDWebviewSession.lastResponseHeaders`.
- **Delegate-based redirect interception:** In `decidePolicyAADForNavigationAction:`, when `msauth://` or `browser://` is detected AND a `specialNavigationDelegate` is set, cancels the navigation and delegates to the controller.
- **New action executor:** `executeViewNavigationAction:requestURL:error:` – switch-based handler that executes the returned `MSIDWebviewNavigationAction` (load request, open ASWebAuth, complete auth, fail).

### 5.3 `MSIDAADWebviewFactory`

- **New response type parsing:** Overloaded `oAuthResponseWithURL:` to accept `responseHeaders` parameter. Now attempts to create `MSIDWebMDMInstallProfileResponse` (using URL + HTTP headers) and `MSIDWebMDMEnrollmentCompletionResponse` before falling through to existing response types.

### 5.4 Completion Block Type Generalization

Several completion block typedefs changed from `MSIDWebWPJResponse` to the more general `MSIDWebviewResponse`:

- `MSIDInteractiveAuthorizationCodeCompletionBlock`
- `MSIDInteractiveRequestCompletionBlock`
- `MSIDInteractiveTokenRequest` completion handler

This allows the same pipeline to carry MDM-specific response types alongside existing WPJ responses.

### 5.5 HTTP Response Header Propagation

A new pipeline ensures HTTP response headers flow from WKWebView navigation responses to the response factory:

1. `MSIDAADOAuthEmbeddedWebviewController.navigationResponseBlock` captures `NSHTTPURLResponse`.
2. Headers stored in `MSIDWebviewSession.lastResponseHeaders`.
3. `MSIDWebviewAuthorization` passes `lastResponseHeaders` to `MSIDBaseWebRequestConfiguration.responseWithResultURL:factory:responseHeaders:context:error:`.
4. Factory uses headers to extract `x-ms-intune-install-url` and `x-ms-intune-token` for MDM response objects.

### 5.6 `MSIDInteractiveTokenRequestParameters`

- **New property:** `webviewConfigurationBlock` – a block called after webview creation to allow controllers to inject delegates/configuration without subclassing the webview.

### 5.7 `MSIDInteractiveAuthorizationCodeRequest`

- **New property:** `currentWebview` – stores reference to the active webview for suspension.
- **Configuration block invocation:** Calls `webviewConfigurationBlock` after webview creation, ensuring it runs on the main thread.

---

## 6. Key Design Decisions

### 6.1 Dual Transition Paths (Option 1 vs Option 2)

The code contains **two implementation paths** for ASWebAuthenticationSession transitions:

| Path | Trigger | Flow |
|---|---|---|
| **Option 1 (Response-based)** | MDM response bubbles up through completion blocks to controller | Controller calls `transitionCoordinator.launchASWebAuthenticationSession:` with `MSIDRequestCompletionBlock` |
| **Option 2 (Delegate-based)** | `MSIDWebviewSpecialNavigationDelegate` callback from webview | Controller calls `transitionCoordinator.launchASWebAuthenticationSessionWithUrl:` returning `MSIDWebviewNavigationAction` |

Both paths coexist in the codebase. The delegate-based path (Option 2) provides finer-grained control at the webview navigation level.

### 6.2 BRT Acquisition Strategy

- **Trigger:** First `msauth://` or `browser://` redirect in a session.
- **Policy:** Single attempt per session (`brtAttempted` flag). No retry on failure.
- **Current state:** **Placeholder implementation** – always returns success. Needs actual BRT acquisition logic.

### 6.3 Webview Suspend/Resume

Rather than dismissing the embedded webview during profile installation, the `TransitionCoordinator` **hides** the parent view controller's view (`view.hidden = YES/NO`). This keeps the WKWebView process alive and avoids losing navigation state.

### 6.4 iOS 18+ Requirement for Additional Headers

`ASWebAuthenticationSession` with additional headers (`initWithParentController:startURL:callbackScheme:useEmpheralSession:additionalHeaders:`) requires iOS 18.0+ / macOS 15.0+. For older OS versions, headers are silently ignored with a warning log.

---

## 7. `msauth://` URL Scheme Routing

The `MSIDWebviewNavigationActionUtil` resolves the following `msauth://` hosts:

| URL Pattern | Action |
|---|---|
| `msauth://enroll?cpurl=...` | Load `cpurl` in embedded webview |
| `msauth://compliance?cpurl=...` | Load `cpurl` in embedded webview |
| `msauth://installProfile?requireASWebAuthenticationSession=true` | Open URL from `x-ms-intune-install-url` header in ASWebAuthenticationSession with `x-ms-intune-token` header |
| `msauth://installProfile` (without ASWebAuth flag) | Load profile URL in embedded webview |
| `msauth://in_app_enrollment_complete` | Complete web auth with this URL |
| Other `msauth://` hosts | Continue default behavior |

---

## 8. Post-Enrollment Flow

On successful enrollment (`msauth://in_app_enrollment_complete` with `status=success`):

1. ASWebAuthenticationSession is dismissed.
2. Embedded webview is resumed.
3. Enrollment completion response is processed.
4. A new `MSIDBrokerInteractiveController` is created with the same request parameters.
5. Control is delegated to the broker (SSO Extension) to complete authentication.
6. On non-iOS platforms, an error is returned ("Broker authentication not supported").

---

## 9. Known TODOs &amp; Incomplete Items

| Item | Location | Status |
|---|---|---|
| BRT acquisition logic | `MSIDLocalInteractiveController.acquireBRTWithCompletion:` | **Placeholder** – always returns success |
| Extra headers/query params for enrollment and compliance URLs | `MSIDWebviewNavigationActionUtil` | TODO comments |
| Telemetry for response headers | `processResponseHeaders:` | TODO comment |
| Delegate method duplication | `MSIDLocalInteractiveController` | TODO: move to common place |
| Commented-out method declarations | `MSIDLocalInteractiveController+Internal.h` | Commented code for `handleWebMDM*` methods |
| Cleanup ordering bug | `MSIDWebviewTransitionCoordinator.cleanup` | Sets `suspendedEmbeddedWebview = nil` before checking it (dead code) |

---

## 10. Risk Assessment

| Area | Risk Level | Notes |
|---|---|---|
| Completion block type change (`MSIDWebWPJResponse` → `MSIDWebviewResponse`) | **Medium** | Breaking change for downstream consumers that explicitly type-check against `MSIDWebWPJResponse` |
| Webview suspend/resume via `view.hidden` | **Medium** | May not work correctly with all view controller presentation styles |
| Dual transition paths (Option 1 + Option 2) | **Low-Medium** | Code complexity; should converge on one approach before merge |
| BRT acquisition placeholder | **High** | Feature is non-functional without actual implementation |
| iOS 18+ additional headers | **Low** | Graceful fallback for older OS |
| No unit tests in this PR | **High** | 38 changed files with 0 test files added |

---

## 11. Files Changed Summary

| Category | Files |
|---|---|
| **New Classes** (10 files) | `MSIDWebviewNavigationAction.h/m`, `MSIDWebviewNavigationActionUtil.h/m`, `MSIDWebviewTransitionCoordinator.h/m`, `MSIDWebMDMInstallProfileResponse.h/m`, `MSIDWebMDMEnrollmentCompletionResponse.h/m` |
| **New Protocol** (1 file) | `MSIDWebviewSpecialNavigationDelegate.h` |
| **Modified Controllers** (4 files) | `MSIDLocalInteractiveController.h/m`, `MSIDLocalInteractiveController+Internal.h` |
| **Modified Webview** (4 files) | `MSIDAADOAuthEmbeddedWebviewController.h/m`, `MSIDOAuth2EmbeddedWebviewController.h` |
| **Modified Request/Response pipeline** (8 files) | `MSIDInteractiveAuthorizationCodeRequest.h/m`, `MSIDInteractiveTokenRequest.m`, `MSIDInteractiveTokenRequest+Internal.h`, `MSIDInteractiveRequestControlling.h`, `MSIDWebviewFactory.h/m`, `MSIDAADWebviewFactory.m` |
| **Modified Configuration** (3 files) | `MSIDBaseWebRequestConfiguration.h/m`, `MSIDAuthorizeWebRequestConfiguration.m` |
| **Modified Session/Auth** (3 files) | `MSIDWebviewSession.h`, `MSIDWebviewAuthorization.m`, `MSIDInteractiveTokenRequestParameters.h` |
| **Modified Error codes** (2 files) | `MSIDError.h/m` |
| **Project file** (1 file) | `project.pbxproj` |
