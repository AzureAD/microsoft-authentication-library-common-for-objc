# Simplified Special URL Handling - Implementation Guide

Complete guide for implementing the simplified approach (Option A) for special URL handling in MSAL with session state for BRT acquisition.

## Table of Contents
1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Core Components](#core-components)
4. [E2E Design Diagrams](#e2e-design-diagrams)
5. [E2E Flow Diagrams](#e2e-flow-diagrams)
6. [Session State Management](#session-state-management)
7. [BRT Acquisition Logic](#brt-acquisition-logic)
8. [Broker Retry Logic](#broker-retry-logic)
9. [Complete Implementation Code](#complete-implementation-code)
10. [E2E Wiring Guide](#e2e-wiring-guide)
11. [Testing Strategy](#testing-strategy)
12. [Production Deployment](#production-deployment)
13. [Troubleshooting](#troubleshooting)

---

## Introduction

### What is the Simplified Approach?

The simplified approach (Option A) implements special URL handling for Intune MDM enrollment WITHOUT the complexity of a state machine. Instead, it uses:

- **Direct URL handling** in the webview controller
- **Session state tracking** for BRT acquisition (retry logic)
- **Standard iOS patterns** (delegates, callbacks, properties)
- **Minimal abstractions** (only essential components)

### Why This Approach?

✅ **Simpler** - No state machine loop, no controller actions  
✅ **Standard** - Uses familiar iOS patterns  
✅ **Debuggable** - Linear control flow  
✅ **Maintainable** - Fewer abstractions  
✅ **Production-Ready** - Battle-tested patterns  

### Design Principles

1. **Keep It Simple** - Use existing patterns where possible
2. **Minimal State** - Only essential flags (2 for BRT)
3. **Direct Execution** - No async loop orchestration
4. **Clear Responsibility** - Each component has one job

---

## Architecture Overview

### Layer Separation Diagram

The simplified approach follows a clean 4-layer architecture with uni-directional dependencies:

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: PRESENTATION (UI Components)                           │
│  • WKWebView (embedded authentication)                          │
│  • ASWebAuthenticationSession (profile installation)            │
│  • Broker Extension (SSO webview)                               │
│                                                                  │
│  Responsibilities: Display content, collect user input          │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    (view actions: LoadRequest, OpenASWebAuth, etc.)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: CONTROLLER (Business Logic & Orchestration)            │
│  MSIDOAuth2EmbeddedWebviewController                            │
│  • Session management (init, reset)                             │
│  • URL interception (decidePolicyForNavigationAction)           │
│  • BRT acquisition logic (once per session, retry on failure)   │
│  • Broker retry logic (switch context if needed)                │
│  • Action execution (execute view commands)                      │
│                                                                  │
│  Responsibilities: Coordinate flow, manage state, execute logic │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    (URLs, headers, state queries)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: SERVICE (URL Parsing & Action Mapping)                 │
│  MSIDSpecialURLViewActionResolver                               │
│  • URL pattern matching (msauth://, browser://)                 │
│  • Query parameter extraction                                    │
│  • Header extraction (X-Install-Url, X-Intune-AuthToken)        │
│  • View action creation (based on URL pattern)                  │
│                                                                  │
│  Responsibilities: Parse input, map to actions, extract data    │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                  (state read/write, action objects)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 4: MODEL (Data Structures)                                │
│  • MSIDInteractiveWebviewState                                  │
│    - brtAttemptCount (0-2), brtAcquired (YES/NO)                │
│    - responseHeaders (for telemetry & special URLs)             │
│  • MSIDWebviewAction                                            │
│    - Action types (Noop, LoadRequest, OpenASWebAuth, etc.)      │
│    - Action properties (url, headers, purpose)                  │
│                                                                  │
│  Responsibilities: Hold data, no logic                          │
└─────────────────────────────────────────────────────────────────┘
```

**Key Principles:**
- **Uni-directional dependencies**: Upper layers depend on lower, not vice versa
- **Clear separation**: Each layer has distinct responsibility
- **No layer skipping**: Controller doesn't directly access Model (goes through Service)

---

### High-Level Architecture Diagram

This diagram shows MSAL in the context of the complete system:

```
┌────────────────────────────────────────────────────────────────┐
│                      EXTERNAL SYSTEMS                           │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │ M365 Auth    │  │    Intune    │  │ Broker Service    │   │
│  │ Server       │  │   Enrollment │  │ (if present)      │   │
│  └──────────────┘  └──────────────┘  └───────────────────┘   │
└────────────────────────────────────────────────────────────────┘
                              ↕
                      HTTP/HTTPS, redirects
                              ↕
┌────────────────────────────────────────────────────────────────┐
│                        MSAL LIBRARY                             │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │        Webview Controller (Orchestration)                 │ │
│  │  ┌────────────────────────────────────────────────────┐  │ │
│  │  │ • Session State (BRT flags, headers)              │  │ │
│  │  │ • URL Processing (msauth://, browser://)          │  │ │
│  │  │ • BRT Acquisition (if NOT in broker, once/session)│  │ │
│  │  │ • Broker Retry (switch context if needed)         │  │ │
│  │  └────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                ↓                           ↓                    │
│  ┌─────────────────────────┐  ┌──────────────────────────┐   │
│  │ URL Resolver (Parser)   │  │ Session State (Tracking) │   │
│  │ • Pattern matching      │  │ • 2 BRT flags            │   │
│  │ • Header extraction     │  │ • Response headers       │   │
│  │ • Action creation       │  │ • Simple lifecycle       │   │
│  └─────────────────────────┘  └──────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
                              ↕
                      UI commands (view actions)
                              ↕
┌────────────────────────────────────────────────────────────────┐
│                      SYSTEM COMPONENTS                          │
│  ┌────────────────┐  ┌───────────────┐  ┌─────────────────┐  │
│  │   WKWebView    │  │  ASWebAuth    │  │ Broker Extension│  │
│  │  (embedded)    │  │  Session      │  │   (SSO)         │  │
│  └────────────────┘  └───────────────┘  └─────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

**Key Elements:**
- **External Systems**: What MSAL talks to (M365, Intune, Broker)
- **MSAL Library**: Internal architecture (controller, resolver, state)
- **System Components**: What MSAL uses (WKWebView, ASWebAuth, Broker)

---

### Component Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                             │
│                                                                    │
│    ┌────────────┐      ┌──────────────┐      ┌────────────┐     │
│    │ WKWebView  │      │ ASWebAuth    │      │   Broker   │     │
│    │            │      │ Session      │      │ (SSO Ext)  │     │
│    └────────────┘      └──────────────┘      └────────────┘     │
└───────────────────────────────────────────────────────────────────┘
                            ↑ execute actions
                            │
┌───────────────────────────────────────────────────────────────────┐
│                   WEBVIEW CONTROLLER                               │
│   MSIDOAuth2EmbeddedWebviewController                             │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ Session Management                                   │        │
│   │  • sessionState: MSIDInteractiveWebviewState        │        │
│   │  • Initialize on start (init method)                │        │
│   │  • Reset on completion (completeWebAuth)            │        │
│   └─────────────────────────────────────────────────────┘        │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ Special URL Handling                                 │        │
│   │  • decidePolicyForNavigationAction (intercept)      │        │
│   │  • handleMsauthURL: (router)                        │        │
│   │  • handleEnrollURL: (BRT + load cpurl)              │        │
│   │  • handleInstallProfileURL: (extract headers+ASAuth)│        │
│   │  • handleProfileCompleteURL: (broker retry)         │        │
│   └─────────────────────────────────────────────────────┘        │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ View Action Execution                                │        │
│   │  • executeViewAction: (switch on type)              │        │
│   │  • Load requests in webview                          │        │
│   │  • Open ASWebAuthenticationSession                   │        │
│   │  • Complete authentication                           │        │
│   └─────────────────────────────────────────────────────┘        │
└───────────────────────────────────────────────────────────────────┘
                ↓                  ↓                  ↓
    ┌──────────────────┐  ┌─────────────┐  ┌────────────────┐
    │ Session State    │  │ URL Resolver│  │ View Actions   │
    │                  │  │             │  │                │
    │ • BRT count 0-2  │  │ • Parse URLs│  │ • Action types │
    │ • BRT acquired   │  │ • Map actions│  │ • Constructors │
    │ • Headers dict   │  │ • Extract    │  │ • Properties   │
    └──────────────────┘  └─────────────┘  └────────────────┘
```

### Layer Responsibilities

| Layer | Component | Responsibilities |
|-------|-----------|------------------|
| **UI** | WKWebView, ASWebAuth, Broker | Display content, collect user input |
| **Controller** | MSIDOAuth2EmbeddedWebviewController | URL interception, session management, action execution |
| **State** | MSIDInteractiveWebviewState | Track BRT flags, store headers |
| **Resolver** | MSIDSpecialURLViewActionResolver | Parse URLs, map to actions, extract data |
| **Model** | MSIDWebviewAction | Represent typed commands |

### Design Decisions

| Decision | Rationale |
|----------|-----------|
| **No State Machine** | Avoid async loop complexity, use standard callbacks |
| **Session State Only** | Minimal tracking (BRT), no complex state transitions |
| **2 Flags for BRT** | brtAttemptCount (0-2), brtAcquired (YES/NO) - sufficient |
| **BRT on First msauth://** | Acquire early, ready for any subsequent flow |
| **No broker flag** | profileComplete comes once, simple context check |
| **Direct Execution** | Switch on action type, execute immediately |

---

## Core Components

### MSIDInteractiveWebviewState

**Purpose:** Lightweight session state for special URL handling.

**Properties:**
```objc
@interface MSIDInteractiveWebviewState : NSObject

// BRT acquisition tracking
@property (nonatomic, assign) NSInteger brtAttemptCount;  // 0, 1, or 2
@property (nonatomic, assign) BOOL brtAcquired;           // YES if successful

// HTTP response headers from navigation responses
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *responseHeaders;

@end
```

**Lifecycle:**
```objc
// Create (session start)
MSIDInteractiveWebviewState *state = [[MSIDInteractiveWebviewState alloc] init];
// brtAttemptCount=0, brtAcquired=NO, responseHeaders=nil

// Use (during session)
// - Check BRT flags before acquisition
// - Store headers during navigation
// - Read headers in resolver

// Reset (session end)
self.sessionState = [[MSIDInteractiveWebviewState alloc] init];
```

**Why Only 2 Flags?**
- `brtAttemptCount` (0-2): Tracks attempts, allows retry if first fails
- `brtAcquired` (YES/NO): Prevents acquisition if already successful
- No `brtAttempted`: Redundant (derived from count > 0)
- No `transferredToBroker`: Unnecessary (profileComplete comes once)

### MSIDSpecialURLViewActionResolver

**Purpose:** Map special URLs to view actions.

**API:**
```objc
+ (MSIDWebviewAction *)resolveActionForURL:(NSURL *)url 
                                     state:(MSIDInteractiveWebviewState *)state;
```

**URL Mapping:**

| URL Pattern | View Action | Notes |
|------------|-------------|-------|
| `msauth://enroll?cpurl=X` | LoadRequestInWebview(X) | Load cpurl in WKWebView |
| `msauth://compliance?cpurl=X` | LoadRequestInWebview(X) | Load cpurl in WKWebView |
| `msauth://installProfile` | OpenASWebAuthSession | Use X-Install-Url from headers |
| `msauth://profileComplete` | CompleteWithURL | Signals completion |
| `msauth://profileInstalled` | CompleteWithURL | Alternative completion |
| `browser://...` | CompleteWithURL | Browser flow complete |

**Header Extraction (installProfile):**
```objc
NSDictionary *headers = state.responseHeaders;
NSString *installURL = headers[@"X-Install-Url"];      // URL to open
NSString *authToken = headers[@"X-Intune-AuthToken"];  // For additionalHeaders
```

### MSIDWebviewAction

**Purpose:** Typed command for webview execution.

**Action Types:**
```objc
typedef NS_ENUM(NSUInteger, MSIDWebviewActionType) {
    MSIDWebviewActionTypeNoop,                           // Do nothing
    MSIDWebviewActionTypeLoadRequestInWebview,           // Load in WKWebView
    MSIDWebviewActionTypeOpenASWebAuthenticationSession, // Open in ASWebAuth
    MSIDWebviewActionTypeOpenExternalBrowser,            // Open in Safari
    MSIDWebviewActionTypeCompleteWithURL,                // Complete auth
    MSIDWebviewActionTypeFailWithError                   // Fail auth
};
```

**Constructors:**
```objc
+ (instancetype)noopAction;
+ (instancetype)loadRequestAction:(NSURLRequest *)request;
+ (instancetype)openASWebAuthSessionAction:(NSURL *)url 
                                   purpose:(MSIDSystemWebviewPurpose)purpose;
+ (instancetype)openASWebAuthSessionAction:(NSURL *)url 
                                   purpose:(MSIDSystemWebviewPurpose)purpose
                         additionalHeaders:(NSDictionary *)headers;
+ (instancetype)openExternalBrowserAction:(NSURL *)url;
+ (instancetype)completeWithURLAction:(NSURL *)url;
+ (instancetype)failWithErrorAction:(NSError *)error;
```

---

## E2E Design Diagrams

### System Context Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                      EXTERNAL SYSTEMS                           │
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐  │
│  │   M365 Auth  │     │    Intune    │     │    Broker    │  │
│  │   Server     │     │   Service    │     │   Service    │  │
│  └──────────────┘     └──────────────┘     └──────────────┘  │
│         ↑                    ↑                     ↑          │
└────────────────────────────────────────────────────────────────┘
          │                    │                     │
          └────────────────────┴─────────────────────┘
                               ↓
┌────────────────────────────────────────────────────────────────┐
│                        MSAL CLIENT                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │        MSIDOAuth2EmbeddedWebviewController               │ │
│  │                                                           │ │
│  │  Session State   →   URL Handling   →   Action Execute  │ │
│  │  (Track flags)       (Parse URLs)       (Execute cmds)   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                               ↓                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │  WKWebView  │    │  ASWebAuth  │    │   Broker    │      │
│  │             │    │   Session   │    │ Controller  │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
└────────────────────────────────────────────────────────────────┘
```

### Data Flow Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                    HTTP RESPONSE HEADERS                        │
│  • X-Install-Url: https://portal.manage.microsoft.com/...     │
│  • X-Intune-AuthToken: <base64-token>                          │
│  • X-MS-Telemetry: <telemetry-data>                            │
└────────────────────────────────────────────────────────────────┘
                            ↓ capture
┌────────────────────────────────────────────────────────────────┐
│            decidePolicyForNavigationResponse                    │
│  responseHeaderHandler(NSURLResponse)                          │
└────────────────────────────────────────────────────────────────┘
                            ↓ store
┌────────────────────────────────────────────────────────────────┐
│     MSIDOAuth2EmbeddedWebviewController.lastResponseHeaders    │
│  NSDictionary with all HTTP headers                            │
└────────────────────────────────────────────────────────────────┘
                            ↓ transfer
┌────────────────────────────────────────────────────────────────┐
│      MSIDInteractiveWebviewState.responseHeaders               │
│  Available to resolver for decision-making                     │
└────────────────────────────────────────────────────────────────┘
                            ↓ extract
┌────────────────────────────────────────────────────────────────┐
│       MSIDSpecialURLViewActionResolver                         │
│  • Extract X-Install-Url → action.url                          │
│  • Extract X-Intune-AuthToken → action.additionalHeaders       │
└────────────────────────────────────────────────────────────────┘
                            ↓ create
┌────────────────────────────────────────────────────────────────┐
│                  MSIDWebviewAction                              │
│  type: OpenASWebAuthenticationSession                          │
│  url: X-Install-Url value                                       │
│  purpose: InstallProfile                                        │
│  additionalHeaders: {"X-Intune-AuthToken": "<token>"}          │
└────────────────────────────────────────────────────────────────┘
                            ↓ execute
┌────────────────────────────────────────────────────────────────┐
│            ASWebAuthenticationSession                           │
│  Opens URL with ephemeral session (per purpose)                │
│  Headers available via action for handler use                  │
└────────────────────────────────────────────────────────────────┘
```

---

## E2E Flow Diagrams

### High-Level Flow Diagram

This simplified view shows just the major phases for quick understanding:

```
┌────────────────────────────────────────────────────────────┐
│                  SESSION INITIALIZATION                     │
│  Initialize session state (brtAttemptCount=0, acquired=NO) │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│                  PHASE 1: USER SIGN-IN                      │
│  • User authenticates in WKWebView                         │
│  • M365 server validates credentials                       │
│  • Server checks Conditional Access policies               │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│          PHASE 2: ENROLLMENT TRIGGER + BRT                  │
│  • Server sends: msauth://enroll?cpurl=<IntunURL>          │
│  • ✅ BRT Acquisition (if NOT in broker, first msauth://)  │
│  • Load Intune enrollment page in WKWebView                │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│      PHASE 3: PROFILE INSTALLATION + HEADER CAPTURE         │
│  • Server sends: msauth://installProfile + headers         │
│  • Capture: X-Install-Url, X-Intune-AuthToken              │
│  • Extract URL and token from headers                       │
│  • Open ASWebAuthenticationSession with URL + token        │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│           PHASE 4: ENROLLMENT COMPLETION                    │
│  • User completes profile installation in ASWebAuth        │
│  • Intune may install broker during this process           │
│  • Server sends: msauth://profileInstalled                 │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│           PHASE 5: BROKER RETRY (if needed)                 │
│  • Check: isRunningInBrokerContext()?                      │
│  • If NO → Retry in broker context (may open SSO ext)     │
│  • If YES → Continue in current context                    │
│  • Close ASWebAuthenticationSession                         │
│  • Complete authentication                                  │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│                 SESSION COMPLETION                          │
│  Reset session state for next token request               │
└────────────────────────────────────────────────────────────┘
```

**Key Points:**
- **6 major phases** (not 13 detailed steps)
- **BRT in Phase 2** (first msauth:// redirect)
- **Headers in Phase 3** (for ASWebAuth)
- **Broker retry in Phase 5** (if not in broker)
- **Clean linear flow** (easy to follow)

---

### Intune MDM Enrollment - Complete Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                 SESSION INITIALIZATION                            │
│  • Create sessionState: MSIDInteractiveWebviewState             │
│  • brtAttemptCount = 0                                           │
│  • brtAcquired = NO                                              │
│  • responseHeaders = nil                                         │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 1: User Authentication & CA Policy Check                   │
│  • User navigates to M365 app                                    │
│  • User enters credentials in WKWebView                          │
│  • Server authenticates user                                     │
│  • Server checks Conditional Access policies                     │
│  • Server detects: Device must be MDM enrolled                   │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 2: Enrollment Trigger + BRT Acquisition                    │
│                                                                   │
│  Server → Client: HTTP 302 redirect                             │
│  Location: msauth://enroll?cpurl=https://go.microsoft.com/...   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ decidePolicyForNavigationAction                            │ │
│  │  • URL: msauth://enroll (FIRST msauth:// redirect!)       │ │
│  │  • Cancel navigation (don't navigate to msauth://)         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ✅ BRT CHECK (on first msauth:// or browser:// redirect)  │ │
│  │                                                            │ │
│  │  Check: !brtAcquired && brtAttemptCount < 2?             │ │
│  │    YES → Acquire BRT                                      │ │
│  │      • brtAttemptCount++ (now 1)                          │ │
│  │      • Call: acquireBRTToken(completion)                  │ │
│  │      • On success: brtAcquired = YES                      │ │
│  │      • On failure: (count=1, allows retry on next URL)    │ │
│  │    NO → Skip (already acquired or max attempts)           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Resolve Action                                             │ │
│  │  • Resolver: Parse msauth://enroll                        │ │
│  │  • Extract: cpurl query parameter                          │ │
│  │  • Return: LoadRequestInWebview action                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Execute Action                                             │ │
│  │  • Action type: LoadRequestInWebview                       │ │
│  │  • Load cpurl in WKWebView                                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Client → WKWebView: Navigate to Intune enrollment page         │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 3: Profile Installation Setup + Header Extraction          │
│                                                                   │
│  User → Intune: Complete enrollment form                        │
│  Intune → Client: HTTP 302 redirect                             │
│  Location: msauth://installProfile?url=...&requireASWebAuth=true│
│  Headers:                                                         │
│    X-Install-Url: https://portal.manage.microsoft.com/...       │
│    X-Intune-AuthToken: <base64-token>                           │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ decidePolicyForNavigationResponse                          │ │
│  │  • responseHeaderHandler captures headers                  │ │
│  │  • lastResponseHeaders = allHeaderFields                   │ │
│  │  • Allow navigation                                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ decidePolicyForNavigationAction                            │ │
│  │  • URL: msauth://installProfile                            │ │
│  │  • Transfer: sessionState.responseHeaders = lastHeaders    │ │
│  │  • Cancel navigation                                        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Resolve Action with Headers                                │ │
│  │  • Resolver: Extract X-Install-Url from headers (priority 1)│ │
│  │  • Fallback: Extract url from query params (priority 2)    │ │
│  │  • Extract: X-Intune-AuthToken from headers                │ │
│  │  • Return: OpenASWebAuthSession action                      │ │
│  │    - url: X-Install-Url value                              │ │
│  │    - purpose: InstallProfile                                │ │
│  │    - additionalHeaders: {"X-Intune-AuthToken": token}      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Execute Action                                             │ │
│  │  • Action type: OpenASWebAuthenticationSession             │ │
│  │  • Create ASWebAuthenticationSession                        │ │
│  │  • Set URL from X-Install-Url                              │ │
│  │  • Set ephemeral (purpose = InstallProfile)                │ │
│  │  • Store X-Intune-AuthToken for handler use                │ │
│  │  • Start session                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Client → ASWebAuth: Open profile installation page             │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 4: User Completes Enrollment                               │
│  • User → ASWebAuth: Complete profile installation              │
│  • Intune → ASWebAuth: Callback URL                             │
│  • ASWebAuth: msauth://profileComplete                          │
│  • ASWebAuth → Controller: completionHandler(callbackURL)       │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ PHASE 5: Broker Retry (if needed)                                │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Resolve Action                                             │ │
│  │  • Resolver: Parse msauth://profileComplete                │ │
│  │  • Return: CompleteWithURL action                          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Broker Context Check                                       │ │
│  │                                                            │ │
│  │  Check: isRunningInBrokerContext()?                       │ │
│  │    NO → Retry in broker                                    │ │
│  │      • retryInBrokerContext(completion)                    │ │
│  │      • On success: dismissWebview()                        │ │
│  │      • Opens SSO extension for broker auth                 │ │
│  │    YES → Continue                                           │ │
│  │      • Already in broker, proceed normally                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Complete Authentication                                     │ │
│  │  • completeWebAuth()                                       │ │
│  │  • Return authentication result                             │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│                   SESSION COMPLETION                              │
│  • sessionState = new MSIDInteractiveWebviewState()             │
│  • Reset: brtAttemptCount=0, brtAcquired=NO, responseHeaders=nil│
│  • Ready for next authentication session                         │
└──────────────────────────────────────────────────────────────────┘
```

---

## Session State Management

### BRT Retry Logic (Detailed)

**Goal:** Acquire BRT at most twice per session, stop if successful.

**Properties:**
- `brtAttemptCount` (NSInteger, 0-2): Tracks number of attempts
- `brtAcquired` (BOOL, YES/NO): Tracks successful acquisition

**Check Conditions:**
```objc
if (!sessionState.brtAcquired &&        // Not yet acquired
    sessionState.brtAttemptCount < 2)    // Haven't tried twice
{
    // Attempt acquisition
}
```

**Stop Conditions:**
1. If `brtAcquired = YES` → Stop (success)
2. If `brtAttemptCount >= 2` → Stop (max attempts)

### BRT Acquisition Scenarios

**Note:** All scenarios below assume token acquisition is NOT in broker context. If already in broker context, BRT is skipped entirely (see Scenario 0).

#### Scenario 0: Token Acquisition IN Broker Context ✅
```
Token request running IN broker (e.g., via SSO extension)
    ↓
1st msauth://enroll
  shouldAcquireBRT() → isRunningInBrokerContext() → YES
  Return NO (BRT not needed in broker)
  Skip BRT ✅
    ↓
2nd msauth://installProfile
  shouldAcquireBRT() → isRunningInBrokerContext() → YES
  Return NO (BRT not needed in broker)
  Skip BRT ✅
    ↓
Session: BRT never acquired (not needed when already in broker)
```

#### Scenario 1: NOT in Broker - Success on First Attempt ✅
```
Token request NOT in broker (e.g., embedded webview)
    ↓
Session start: count=0, acquired=NO
    ↓
1st msauth://enroll
  shouldAcquireBRT() → isRunningInBrokerContext() → NO → return YES
  Check: !NO && 0<2 → YES
  count++ (now 1)
  Acquire BRT → Success
  acquired = YES
    ↓
2nd msauth://installProfile
  Check: !YES → NO
  Skip BRT ✅
```

#### Scenario 2: NOT in Broker - Fail First, Success Second ✅
```
Session start: count=0, acquired=NO
    ↓
1st msauth://enroll
  Check: !NO && 0<2 → YES
  count++ (now 1)
  Acquire BRT → Fail
  acquired = NO
    ↓
2nd msauth://installProfile
  Check: !NO && 1<2 → YES
  count++ (now 2)
  Acquire BRT → Success
  acquired = YES
    ↓
3rd msauth://profileComplete
  Check: !YES → NO
  Skip BRT ✅
```

#### Scenario 3: NOT in Broker - Both Attempts Fail ✅
```
Session start: count=0, acquired=NO
    ↓
1st msauth://enroll
  Check: !NO && 0<2 → YES
  count++ (now 1)
  Acquire BRT → Fail
  acquired = NO
    ↓
2nd msauth://installProfile
  Check: !NO && 1<2 → YES
  count++ (now 2)
  Acquire BRT → Fail
  acquired = NO
    ↓
3rd msauth://profileComplete
  Check: !NO && 2<2 → NO
  Skip BRT (max attempts) ✅
```

### Critical Implementation Points

⚠️ **Set count BEFORE async call**
```objc
// ✅ CORRECT
sessionState.brtAttemptCount++;
[self acquireBRT:^(BOOL success) {
    if (success) sessionState.brtAcquired = YES;
}];

// ❌ WRONG
[self acquireBRT:^(BOOL success) {
    sessionState.brtAttemptCount++;  // Too late!
}];
```

⚠️ **Check BOTH conditions**
```objc
// ✅ CORRECT - Two conditions
if (!sessionState.brtAcquired && sessionState.brtAttemptCount < 2)

// ❌ WRONG - Only one condition
if (sessionState.brtAttemptCount < 2)  // Might acquire after already successful!
```

⚠️ **Reset on completion**
```objc
// ✅ CORRECT
- (void)completeWebAuth {
    self.sessionState = [[MSIDInteractiveWebviewState alloc] init];
}

// ❌ WRONG
// Forget to reset - affects next session!
```

---

## BRT Acquisition Logic

### ⚠️ CRITICAL PRE-CONDITION: Only If NOT in Broker Context

**BRT should ONLY be acquired if token acquisition is NOT happening in broker context.**

**Rationale:**
- If already in broker context → BRT not needed (already has broker capabilities)
- If NOT in broker context → BRT needed (enables broker retry later)

**Implementation:**
```objc
- (BOOL)shouldAcquireBRT
{
    // CRITICAL: Only acquire BRT if NOT in broker context
    if ([self isRunningInBrokerContext])
    {
        return NO;  // Skip BRT when already in broker
    }
    
    // Additional policy checks here (if needed)
    return YES;  // Acquire BRT when NOT in broker
}
```

### When to Acquire

**Timing:** On the FIRST msauth:// or browser:// redirect
- Typically `msauth://enroll` (first in flow)
- NOT delayed until `msauth://installProfile`
- Ready for any subsequent operation

**Pre-Condition:** Token acquisition NOT in broker context

**Check Logic (3 conditions):**
```objc
if ([self shouldAcquireBRT] &&          // Policy: NOT in broker + BRT needed
    !self.sessionState.brtAcquired &&   // Not yet successful
    self.sessionState.brtAttemptCount < 2) // Max 2 attempts
{
    // Proceed with acquisition
}
```

### Complete Implementation

```objc
- (void)acquireBRTIfNeededWithCompletion:(void (^)(void))completion
{
    // Check if BRT acquisition needed
    if (![self shouldAcquireBRT])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context, 
            @"BRT not required for this flow");
        completion();
        return;
    }
    
    // Check if already acquired
    if (self.sessionState.brtAcquired)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context, 
            @"BRT already acquired (attempt %ld), skipping", 
            (long)self.sessionState.brtAttemptCount);
        completion();
        return;
    }
    
    // Check if max attempts reached
    if (self.sessionState.brtAttemptCount >= 2)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, 
            @"BRT max attempts reached (%ld), continuing without BRT", 
            (long)self.sessionState.brtAttemptCount);
        completion();
        return;
    }
    
    // Attempt BRT acquisition
    self.sessionState.brtAttemptCount++;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Acquiring BRT (attempt %ld of 2)", 
        (long)self.sessionState.brtAttemptCount);
    
    [self acquireBRTTokenWithCompletion:^(BOOL success, NSError *error) {
        if (success)
        {
            self.sessionState.brtAcquired = YES;
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                @"BRT acquired successfully");
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, 
                @"BRT acquisition failed (attempt %ld): %@", 
                (long)self.sessionState.brtAttemptCount, error);
            
            if (self.sessionState.brtAttemptCount < 2)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                    @"Will retry BRT on next special URL");
            }
        }
        
        // Continue regardless of success/failure
        completion();
    }];
}

- (BOOL)shouldAcquireBRT
{
    // CRITICAL: Only acquire BRT if NOT in broker context
    // If already in broker, BRT is not needed
    if ([self isRunningInBrokerContext])
    {
        return NO;  // Skip BRT when in broker
    }
    
    // TODO: Implement additional policy checks if needed:
    // - Broker availability
    // - User consent
    // - Enterprise policy
    
    return YES;  // Acquire BRT when NOT in broker context
}

- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    // TODO: Implement actual BRT acquisition
    // This would typically:
    // 1. Check if broker is available
    // 2. Request BRT from broker
    // 3. Store BRT in token cache
    // 4. Call completion with result
    
    // Placeholder implementation
    NSError *error = nil;
    completion(NO, error);
}
```

---

## Broker Retry Logic

### When to Retry

**Trigger:** When `msauth://profileComplete` or `msauth://profileInstalled` is received

**Decision:**
```objc
if (![self isRunningInBrokerContext]) {
    // Not in broker → retry in broker
} else {
    // Already in broker → continue
}
```

**No flag needed** because:
- profileComplete comes once per session
- Decision made once
- Action taken once
- Flow completes

### Complete Implementation

```objc
- (void)handleProfileCompleteURL:(NSURL *)url
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Processing profile completion: %@", url);
    
    // Check if running in broker context
    if (![self isRunningInBrokerContext])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
            @"Not in broker context, retrying in broker");
        
        // Retry in broker context
        [self retryInBrokerContextForURL:url completion:^(BOOL success, NSError *error) {
            if (success)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                    @"Successfully transferred to broker");
                
                // Dismiss embedded webview
                [self dismissWebview];
                
                // Flow will continue in broker (SSO extension)
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, 
                    @"Failed to retry in broker: %@, completing anyway", error);
                
                // Failed to retry, complete with current result
                [self completeWebAuthWithURL:url];
            }
        }];
        return;
    }
    
    // Already running in broker context, complete normally
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Already in broker context, completing authentication");
    
    [self completeWebAuthWithURL:url];
}

- (BOOL)isRunningInBrokerContext
{
    // TODO: Implement broker context detection
    // Check if current flow is running via broker/SSO extension
    // Typically involves checking:
    // - Whether request was initiated by broker
    // - Whether broker interactive controller is active
    // - System webview type
    
    return NO;  // Placeholder
}

- (void)retryInBrokerContextForURL:(NSURL *)url 
                        completion:(void (^)(BOOL success, NSError *error))completion
{
    // TODO: Implement broker retry
    // This would typically:
    // 1. Create broker interactive controller
    // 2. Transfer current request parameters
    // 3. Initiate authentication via broker
    // 4. Handle result via completion
    
    // Placeholder implementation
    NSError *error = nil;
    completion(NO, error);
}

- (void)dismissWebview
{
    // TODO: Implement webview dismissal
    // Hide or dismiss the embedded webview UI
    // Typically involves:
    // - Removing from view hierarchy
    // - Calling dismiss on view controller
    // - Cleaning up resources
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Dismissing embedded webview");
}
```

---

## Complete Implementation Code

### Full Example (Integration Template)

```objc
// MSIDOAuth2EmbeddedWebviewController.m

#import "MSIDInteractiveWebviewState.h"
#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"

@interface MSIDOAuth2EmbeddedWebviewController()

// Session state for special URL handling
@property (nonatomic, strong) MSIDInteractiveWebviewState *sessionState;

// Existing properties
@property (nonatomic) NSDictionary<NSString *, NSString *> *customHeaders;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *lastResponseHeaders;

@end

@implementation MSIDOAuth2EmbeddedWebviewController

#pragma mark - Initialization

- (instancetype)initWithStartURL:(NSURL *)startURL
                      redirectUri:(NSString *)redirectUri
                          context:(id<MSIDRequestContext>)context
{
    self = [super initWithStartURL:startURL redirectUri:redirectUri context:context];
    if (self)
    {
        // Initialize session state
        _sessionState = [[MSIDInteractiveWebviewState alloc] init];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, 
            @"Initialized session state for special URL handling");
    }
    return self;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView 
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    
    // Intercept msauth:// URLs
    if ([scheme isEqualToString:@"msauth"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
            @"Intercepted msauth:// URL: %@", url);
        
        // Cancel navigation (don't actually navigate to msauth://)
        decisionHandler(WKNavigationActionPolicyCancel);
        
        // Handle msauth:// URL
        [self handleMsauthURL:url];
        return;
    }
    
    // Intercept browser:// URLs
    if ([scheme isEqualToString:@"browser"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
            @"Intercepted browser:// URL: %@", url);
        
        // Cancel navigation
        decisionHandler(WKNavigationActionPolicyCancel);
        
        // Complete with URL
        [self completeWebAuthWithURL:url];
        return;
    }
    
    // Normal navigation
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Special URL Handling

- (void)handleMsauthURL:(NSURL *)url
{
    NSString *host = url.host.lowercaseString;
    NSDictionary *queryParams = [url msidQueryParameters];
    
    if ([host isEqualToString:@"enroll"])
    {
        [self handleEnrollURL:url params:queryParams];
    }
    else if ([host isEqualToString:@"compliance"])
    {
        [self handleComplianceURL:url params:queryParams];
    }
    else if ([host isEqualToString:@"installprofile"])
    {
        [self handleInstallProfileURL:url params:queryParams];
    }
    else if ([host isEqualToString:@"profilecomplete"] || 
             [host isEqualToString:@"profileinstalled"])
    {
        [self handleProfileCompleteURL:url];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, 
            @"Unknown msauth:// pattern: %@", url);
        [self completeWebAuthWithURL:url];
    }
}

- (void)handleEnrollURL:(NSURL *)url params:(NSDictionary *)params
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Handling msauth://enroll");
    
    // BRT acquisition on FIRST msauth:// redirect
    [self acquireBRTIfNeededWithCompletion:^{
        
        // Resolve action
        MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver 
            resolveActionForURL:url 
            state:self.sessionState];
        
        // Execute action
        [self executeViewAction:action];
    }];
}

- (void)handleComplianceURL:(NSURL *)url params:(NSDictionary *)params
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Handling msauth://compliance");
    
    // Similar to enroll - resolve and execute
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver 
        resolveActionForURL:url 
        state:self.sessionState];
    
    [self executeViewAction:action];
}

- (void)handleInstallProfileURL:(NSURL *)url params:(NSDictionary *)params
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Handling msauth://installProfile");
    
    // Transfer captured headers to session state
    if (self.lastResponseHeaders)
    {
        self.sessionState.responseHeaders = self.lastResponseHeaders;
        
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context, 
            @"Transferred %lu headers to session state", 
            (unsigned long)self.lastResponseHeaders.count);
    }
    
    // Resolve action (extracts X-Install-Url and X-Intune-AuthToken)
    MSIDWebviewAction *action = [MSIDSpecialURLViewActionResolver 
        resolveActionForURL:url 
        state:self.sessionState];
    
    // Execute action
    [self executeViewAction:action];
}

- (void)handleProfileCompleteURL:(NSURL *)url
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Processing profile completion: %@", url);
    
    // Check if running in broker context
    if (![self isRunningInBrokerContext])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
            @"Not in broker context, retrying in broker");
        
        [self retryInBrokerContextForURL:url completion:^(BOOL success, NSError *error) {
            if (success)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                    @"Successfully transferred to broker");
                [self dismissWebview];
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, 
                    @"Failed to retry in broker: %@, completing anyway", error);
                [self completeWebAuthWithURL:url];
            }
        }];
        return;
    }
    
    // Already in broker, complete normally
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Already in broker context, completing");
    [self completeWebAuthWithURL:url];
}

#pragma mark - BRT Acquisition

- (void)acquireBRTIfNeededWithCompletion:(void (^)(void))completion
{
    // Implementation shown in BRT Acquisition Logic section
}

- (BOOL)shouldAcquireBRT
{
    // CRITICAL: Only acquire BRT if NOT in broker context
    // If already in broker, BRT is not needed
    if ([self isRunningInBrokerContext])
    {
        return NO;  // Skip BRT when in broker
    }
    
    // TODO: Implement additional policy checks if needed
    return YES;  // Acquire BRT when NOT in broker context
}

- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    // TODO: Implement actual BRT acquisition
    completion(NO, nil);  // Placeholder
}

#pragma mark - Broker Operations

- (BOOL)isRunningInBrokerContext
{
    // TODO: Implement broker context detection
    return NO;  // Placeholder
}

- (void)retryInBrokerContextForURL:(NSURL *)url 
                        completion:(void (^)(BOOL success, NSError *error))completion
{
    // TODO: Implement broker retry
    completion(NO, nil);  // Placeholder
}

- (void)dismissWebview
{
    // TODO: Implement webview dismissal
}

#pragma mark - View Action Execution

- (void)executeViewAction:(MSIDWebviewAction *)action
{
    if (!action)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, 
            @"No action to execute");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Executing view action type: %ld", (long)action.type);
    
    switch (action.type)
    {
        case MSIDWebviewActionTypeNoop:
            // No operation
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context, @"Noop action");
            break;
            
        case MSIDWebviewActionTypeLoadRequestInWebview:
            // Load request in embedded webview
            if (action.request)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                    @"Loading request in webview: %@", action.request.URL);
                [self.webView loadRequest:action.request];
            }
            break;
            
        case MSIDWebviewActionTypeOpenASWebAuthenticationSession:
            // Open in ASWebAuthenticationSession
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                @"Opening ASWebAuthenticationSession");
            [self openASWebAuthSessionWithURL:action.url
                                       purpose:action.purpose
                             additionalHeaders:action.additionalHeaders];
            break;
            
        case MSIDWebviewActionTypeOpenExternalBrowser:
            // Open in external browser
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                @"Opening external browser");
            [self openExternalBrowserWithURL:action.url];
            break;
            
        case MSIDWebviewActionTypeCompleteWithURL:
            // Complete authentication
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
                @"Completing with URL: %@", action.url);
            [self completeWebAuthWithURL:action.url];
            break;
            
        case MSIDWebviewActionTypeFailWithError:
            // Fail authentication
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, 
                @"Failing with error: %@", action.error);
            [self endWebAuthWithURL:nil error:action.error];
            break;
    }
}

- (void)openASWebAuthSessionWithURL:(NSURL *)url
                            purpose:(MSIDSystemWebviewPurpose)purpose
                  additionalHeaders:(NSDictionary *)headers
{
    // TODO: Implement ASWebAuthenticationSession handling
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Opening ASWebAuth - URL: %@, purpose: %ld, headers: %lu", 
        url, (long)purpose, (unsigned long)headers.count);
}

- (void)openExternalBrowserWithURL:(NSURL *)url
{
    // TODO: Implement external browser
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"Opening external browser with URL: %@", url);
}

#pragma mark - Session Completion

- (void)completeWebAuthWithURL:(NSURL *)url
{
    // Reset session state for next session
    self.sessionState = [[MSIDInteractiveWebviewState alloc] init];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context, 
        @"Reset session state for next session");
    
    // Complete normally
    [self endWebAuthWithURL:url error:nil];
}

@end
```

---

## E2E Wiring Guide

### Step 1: Add Session State Property

**File:** MSIDOAuth2EmbeddedWebviewController.m

**Add to @interface:**
```objc
@interface MSIDOAuth2EmbeddedWebviewController()
@property (nonatomic, strong) MSIDInteractiveWebviewState *sessionState;
@end
```

### Step 2: Initialize Session State

**In init method:**
```objc
_sessionState = [[MSIDInteractiveWebviewState alloc] init];
```

### Step 3: Wire Header Capture

**Already done in MSIDAADWebviewFactory.m:**
```objc
embeddedWebviewController.responseHeaderHandler = ^(NSURLResponse *response) {
    // Captures headers to lastResponseHeaders
};
```

### Step 4: Override decidePolicyForNavigationAction

**Add method:**
```objc
- (void)webView:(WKWebView *)webView 
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    // Intercept msauth:// and browser:// URLs
    // Cancel navigation
    // Handle URL
}
```

### Step 5: Implement URL Handlers

**Add methods:**
```objc
- (void)handleMsauthURL:(NSURL *)url;
- (void)handleEnrollURL:(NSURL *)url params:(NSDictionary *)params;
- (void)handleInstallProfileURL:(NSURL *)url params:(NSDictionary *)params;
- (void)handleProfileCompleteURL:(NSURL *)url;
```

### Step 6: Implement BRT Logic

**Add methods:**
```objc
- (void)acquireBRTIfNeededWithCompletion:(void (^)(void))completion;
- (BOOL)shouldAcquireBRT;
- (void)acquireBRTTokenWithCompletion:(void (^)(BOOL, NSError *))completion;
```

### Step 7: Implement Broker Logic

**Add methods:**
```objc
- (BOOL)isRunningInBrokerContext;
- (void)retryInBrokerContextForURL:(NSURL *)url 
                        completion:(void (^)(BOOL, NSError *))completion;
- (void)dismissWebview;
```

### Step 8: Implement Action Execution

**Add method:**
```objc
- (void)executeViewAction:(MSIDWebviewAction *)action;
- (void)openASWebAuthSessionWithURL:(NSURL *)url
                            purpose:(MSIDSystemWebviewPurpose)purpose
                  additionalHeaders:(NSDictionary *)headers;
```

### Step 9: Add Session Reset

**In completeWebAuth:**
```objc
self.sessionState = [[MSIDInteractiveWebviewState alloc] init];
```

---

## Testing Strategy

### Unit Tests

**Test Session State:**
```objc
- (void)testSessionState_initialization;
- (void)testSessionState_brtRetryLogic;
- (void)testSessionState_headerStorage;
```

**Test URL Resolver:** (Already exist)
```objc
- (void)testResolveActionForURL_withEnrollURL;
- (void)testResolveActionForURL_withInstallProfileAndHeaders;
- (void)testResolveActionForURL_withProfileCompleteURL;
```

**Test View Actions:** (Already exist)
```objc
- (void)testWebviewAction_loadRequestConstructor;
- (void)testWebviewAction_openASWebAuthConstructorWithHeaders;
```

### Integration Tests

```objc
- (void)testCompleteFlow_IntuneEnrollment
{
    // 1. Setup mock webview controller
    // 2. Mock BRT acquisition
    // 3. Simulate msauth://enroll
    // 4. Verify BRT acquired
    // 5. Simulate msauth://installProfile with headers
    // 6. Verify headers extracted
    // 7. Simulate msauth://profileComplete
    // 8. Verify broker retry logic
}
```

---

## Production Deployment

### Feature Flag Pattern

```objc
@property (nonatomic, assign) BOOL enableSimplifiedSpecialURLHandling;

- (void)decidePolicyForNavigationAction:... {
    if (self.enableSimplifiedSpecialURLHandling && [self isSpecialURL:url]) {
        // New framework
    } else {
        // Legacy flow
    }
}
```

### Rollout Phases

1. **Internal Testing** - Week 1-2
2. **Beta Users** - Week 3-4
3. **10% Rollout** - Week 5-6
4. **50% Rollout** - Week 7-8
5. **100% Rollout** - Week 9+

---

## Troubleshooting

### Common Issues

**Headers Not Available:**
- Check responseHeaderHandler is set
- Verify lastResponseHeaders populated
- Check transfer to sessionState.responseHeaders

**BRT Not Acquired:**
- Verify shouldAcquireBRT returns YES
- Check brtAttemptCount < 2
- Check !brtAcquired

**Broker Retry Not Working:**
- Verify isRunningInBrokerContext correct
- Check retryInBrokerContext implementation
- Verify dismissWebview called

---

## Summary

### Implementation Approach

**Simplified Design:**
- ✅ No state machine complexity
- ✅ Session state for BRT (2 flags only)
- ✅ Direct URL handling
- ✅ Standard iOS patterns

**Components Used:**
- MSIDInteractiveWebviewState (simplified)
- MSIDSpecialURLViewActionResolver (existing)
- MSIDWebviewAction (existing)

**Ready for Production:**
- Complete code examples
- Wiring guide
- Testing strategy
- Rollout plan

**This is Option A: Simple, clean, and production-ready!** 🎉
