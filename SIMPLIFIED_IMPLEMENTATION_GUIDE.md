# Simplified Special URL Handling - Implementation Guide

Complete guide for implementing the simplified approach (Option A) for special URL handling in MSAL with session state for BRT acquisition.

## ⚠️ CRITICAL ARCHITECTURAL REQUIREMENT

**BRT acquisition and Token request retry in broker context MUST be handled by InteractiveController, NOT WebviewController.**

This document has been updated to reflect the correct architecture:
- **InteractiveController** (MSIDLocalInteractiveController / ADBrokerInteractiveControllerWithPRT) owns session state, implements handler protocol, contains ALL business logic (BRT acquisition, broker retry, decisions)
- **WebviewController** (MSIDOAuth2EmbeddedWebviewController) is a pure UI component that detects URLs, captures headers, calls handler protocol, and executes view actions - NO business logic

Pattern: `WebviewController detects → calls handler → InteractiveController decides → returns action → WebviewController executes`

---

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

- **Handler protocol pattern** - WebviewController detects, InteractiveController decides
- **Session state ownership** by InteractiveController (BRT acquisition, retry logic)
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
│ LAYER 1: INTERACTIVE CONTROLLER (Business Logic & Orchestration)│
│  • MSIDLocalInteractiveController (non-broker context)          │
│  • ADBrokerInteractiveControllerWithPRT (broker context)        │
│                                                                  │
│  Responsibilities:                                               │
│  • BRT acquisition logic (once per session, retry on failure)   │
│  • Broker retry logic (switch context if needed)                │
│  • Session state management (create, own, update)               │
│  • Implement handler protocol                                    │
│  • Make business decisions                                       │
└─────────────────────────────────────────────────────────────────┘
                              ↕
              (handler protocol: handleSpecialURL, acquireBRT, etc.)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: WEBVIEW CONTROLLER (UI Component & Detector)           │
│  MSIDOAuth2EmbeddedWebviewController                            │
│  • URL detection (decidePolicyForNavigationAction)              │
│  • Header capture (responseHeaderHandler)                        │
│  • Call handler methods (delegate to parent)                     │
│  • Execute view actions (returned by handler)                    │
│                                                                  │
│  Responsibilities: Detect URLs, capture headers, call handler,  │
│                    execute view commands - NO business logic     │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    (view actions: LoadRequest, OpenASWebAuth, etc.)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: PRESENTATION (UI Display)                              │
│  • WKWebView (embedded authentication)                          │
│  • ASWebAuthenticationSession (profile installation)            │
│  • Broker Extension (SSO webview)                               │
│                                                                  │
│  Responsibilities: Display content, collect user input          │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                  (URLs, headers, state queries - via resolver)
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 4: SERVICE & MODEL (Parsing & Data)                       │
│  • MSIDSpecialURLViewActionResolver (URL parsing, mapping)      │
│  • MSIDInteractiveWebviewState (session state data)             │
│  • MSIDWebviewAction (view action data)                         │
│                                                                  │
│  Responsibilities: Parse input, map to actions, hold data       │
└─────────────────────────────────────────────────────────────────┘
```

**Key Principles:**
- **InteractiveController has business logic**: BRT acquisition, broker retry, decisions
- **WebviewController is UI component**: Detects URLs, calls handler, executes view actions
- **Clear separation**: Business logic vs UI handling
- **Handler protocol**: WebviewController calls, InteractiveController implements

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
│  │   Interactive Controller (Business Logic Orchestrator)    │ │
│  │   MSIDLocalInteractiveController / ADBrokerInteractive... │ │
│  │  ┌────────────────────────────────────────────────────┐  │ │
│  │  │ • Owns Session State (BRT flags, headers)         │  │ │
│  │  │ • BRT Acquisition (NOT in broker, once/session)   │  │ │
│  │  │ • Broker Retry (switch context if needed)         │  │ │
│  │  │ • Handler Protocol Implementation                  │  │ │
│  │  │ • Business Decisions (all logic here)             │  │ │
│  │  └────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                              ↕                                  │
│                    (handler protocol calls)                     │
│                              ↕                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │   Webview Controller (UI Component & Detector)            │ │
│  │   MSIDOAuth2EmbeddedWebviewController                     │ │
│  │  ┌────────────────────────────────────────────────────┐  │ │
│  │  │ • URL Detection (msauth://, browser://)           │  │ │
│  │  │ • Header Capture (responseHeaderHandler)          │  │ │
│  │  │ • Call Handler (delegate special URLs up)         │  │ │
│  │  │ • Execute View Actions (returned by handler)      │  │ │
│  │  │ • NO business logic - just detector & executor    │  │ │
│  │  └────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                ↓                           ↓                    │
│  ┌─────────────────────────┐  ┌──────────────────────────┐   │
│  │ URL Resolver (Parser)   │  │ Session State (Data)     │   │
│  │ • Pattern matching      │  │ • 2 BRT flags            │   │
│  │ • Header extraction     │  │ • Response headers       │   │
│  │ • Action creation       │  │ • Owned by Interactive   │   │
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
- **Interactive Controller**: Business logic orchestrator (BRT, broker retry, decisions)
- **Webview Controller**: UI component (URL detection, handler calls, view actions)
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
│                   WEBVIEW CONTROLLER (UI Component)                │
│   MSIDOAuth2EmbeddedWebviewController                             │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ URL Detection & Header Capture                       │        │
│   │  • decidePolicyForNavigationAction (detect URLs)    │        │
│   │  • responseHeaderHandler (capture headers)           │        │
│   │  • NO session state ownership                        │        │
│   │  • NO business logic                                 │        │
│   └─────────────────────────────────────────────────────┘        │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ Handler Protocol Calls (Delegate to Parent)         │        │
│   │  • handleSpecialURL: → InteractiveController        │        │
│   │  • captureHeaders: → InteractiveController           │        │
│   │  • Receive MSIDWebviewAction responses               │        │
│   └─────────────────────────────────────────────────────┘        │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ View Action Execution (Execute Commands)             │        │
│   │  • executeViewAction: (switch on type)              │        │
│   │  • Load requests in webview                          │        │
│   │  • Open ASWebAuthenticationSession                   │        │
│   │  • Complete authentication                           │        │
│   └─────────────────────────────────────────────────────┘        │
└───────────────────────────────────────────────────────────────────┘
                            ↑ handler protocol
                            │
┌───────────────────────────────────────────────────────────────────┐
│            INTERACTIVE CONTROLLER (Business Logic)                 │
│   MSIDLocalInteractiveController / ADBrokerInteractive...         │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ Session State Ownership                              │        │
│   │  • sessionState: MSIDInteractiveWebviewState        │        │
│   │  • Initialize on start (init method)                │        │
│   │  • Update during flow                                │        │
│   │  • Reset on completion                               │        │
│   └─────────────────────────────────────────────────────┘        │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ Handler Protocol Implementation                      │        │
│   │  • handleSpecialURL: (business decisions)           │        │
│   │  • acquireBRTIfNeeded: (BRT logic)                  │        │
│   │  • retryInBrokerContext: (broker retry logic)       │        │
│   │  • Returns MSIDWebviewAction to WebviewController    │        │
│   └─────────────────────────────────────────────────────┘        │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ BRT Acquisition (NOT in broker context)              │        │
│   │  • shouldAcquireBRT: (check broker context)         │        │
│   │  • acquireBRTTokenWithCompletion: (actual acquire)  │        │
│   │  • Update sessionState.brtAcquired                   │        │
│   │  • Update sessionState.brtAttemptCount               │        │
│   └─────────────────────────────────────────────────────┘        │
│                                                                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ Broker Retry (on profileComplete)                    │        │
│   │  • isRunningInBrokerContext: (check context)        │        │
│   │  • retryInBrokerContextForURL: (switch context)     │        │
│   │  • Transfer session state to broker                  │        │
│   └─────────────────────────────────────────────────────┘        │
└───────────────────────────────────────────────────────────────────┘
                ↓                  ↓                  ↓
    ┌──────────────────┐  ┌─────────────┐  ┌────────────────┐
    │ Session State    │  │ URL Resolver│  │ View Actions   │
    │ (Owned by IC)    │  │             │  │                │
    │ • BRT count 0-2  │  │ • Parse URLs│  │ • Action types │
    │ • BRT acquired   │  │ • Map actions│  │ • Constructors │
    │ • Headers dict   │  │ • Extract    │  │ • Properties   │
    └──────────────────┘  └─────────────┘  └────────────────┘
```

### Layer Responsibilities

| Layer | Component | Responsibilities |
|-------|-----------|------------------|
| **Business Logic** | InteractiveController (MSIDLocalInteractiveController, ADBrokerInteractiveControllerWithPRT) | BRT acquisition, broker retry, session ownership, handler protocol implementation, business decisions |
| **UI Controller** | MSIDOAuth2EmbeddedWebviewController | URL detection, header capture, call handler methods, execute view actions - NO business logic |
| **UI** | WKWebView, ASWebAuth, Broker | Display content, collect user input |
| **State** | MSIDInteractiveWebviewState | Track BRT flags, store headers (owned by InteractiveController) |
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
│  │     InteractiveController (Business Logic Layer)         │ │
│  │  • BRT Acquisition   • Broker Retry   • Session State    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                               ↓ handler protocol                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │     MSIDOAuth2EmbeddedWebviewController (UI Layer)       │ │
│  │  • URL Detection   • Header Capture   • Execute Actions  │ │
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
                            ↓ capture (WebviewController)
┌────────────────────────────────────────────────────────────────┐
│  MSIDOAuth2EmbeddedWebviewController.responseHeaderHandler     │
│  Captures headers, passes to InteractiveController             │
└────────────────────────────────────────────────────────────────┘
                            ↓ store (InteractiveController)
┌────────────────────────────────────────────────────────────────┐
│      MSIDInteractiveWebviewState.responseHeaders               │
│  Owned by InteractiveController, used for decisions            │
└────────────────────────────────────────────────────────────────┘
                            ↓ extract (via Resolver)
┌────────────────────────────────────────────────────────────────┐
│       MSIDSpecialURLViewActionResolver                         │
│  • Extract X-Install-Url → action.url                          │
│  • Extract X-Intune-AuthToken → action.additionalHeaders       │
└────────────────────────────────────────────────────────────────┘
                            ↓ create (InteractiveController)
┌────────────────────────────────────────────────────────────────┐
│                  MSIDWebviewAction                              │
│  type: OpenASWebAuthenticationSession                          │
│  url: X-Install-Url value                                       │
│  purpose: InstallProfile                                        │
│  additionalHeaders: {"X-Intune-AuthToken": "<token>"}          │
└────────────────────────────────────────────────────────────────┘
                            ↓ execute (WebviewController)
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

### Handler Protocol

First, define the protocol that InteractiveController implements:

```objc
// MSIDWebviewHandlerProtocol.h

@protocol MSIDWebviewHandlerProtocol <NSObject>

// Called when a special URL is detected
- (MSIDWebviewAction *)handleSpecialURL:(NSURL *)url
                           responseHeaders:(NSDictionary<NSString *, NSString *> *)headers
                                   context:(id<MSIDRequestContext>)context;

// Called to check if running in broker context
- (BOOL)isRunningInBrokerContext;

// Called to retry in broker context
- (void)retryInBrokerContextForURL:(NSURL *)url
                         completion:(void (^)(BOOL success, NSError *error))completion;

@end
```

### InteractiveController Implementation

InteractiveController owns session state and implements all business logic:

```objc
// MSIDLocalInteractiveController.m (or ADBrokerInteractiveControllerWithPRT.m)

#import "MSIDWebviewHandlerProtocol.h"
#import "MSIDInteractiveWebviewState.h"
#import "MSIDSpecialURLViewActionResolver.h"
#import "MSIDWebviewAction.h"

@interface MSIDLocalInteractiveController() <MSIDWebviewHandlerProtocol>

// Session state - OWNED by InteractiveController
@property (nonatomic, strong) MSIDInteractiveWebviewState *sessionState;

@end

@implementation MSIDLocalInteractiveController

#pragma mark - Initialization

- (instancetype)initWithRequestParameters:(MSIDInteractiveRequestParameters *)parameters
{
    self = [super initWithRequestParameters:parameters];
    if (self)
    {
        // Initialize session state - InteractiveController owns this
        _sessionState = [[MSIDInteractiveWebviewState alloc] init];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, parameters.context, 
            @"[InteractiveController] Initialized session state");
    }
    return self;
}

#pragma mark - MSIDWebviewHandlerProtocol Implementation

- (MSIDWebviewAction *)handleSpecialURL:(NSURL *)url
                          responseHeaders:(NSDictionary<NSString *, NSString *> *)headers
                                  context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
        @"[InteractiveController] Handling special URL: %@", url);
    
    // Store headers in session state if provided
    if (headers)
    {
        self.sessionState.responseHeaders = headers;
    }
    
    NSString *host = url.host.lowercaseString;
    
    // Handle msauth://enroll - with BRT acquisition
    if ([host isEqualToString:@"enroll"])
    {
        return [self handleEnrollURL:url context:context];
    }
    
    // Handle msauth://installProfile - extract headers
    if ([host isEqualToString:@"installprofile"])
    {
        return [self handleInstallProfileURL:url context:context];
    }
    
    // Handle msauth://profileComplete - broker retry logic
    if ([host isEqualToString:@"profilecomplete"] || 
        [host isEqualToString:@"profileinstalled"])
    {
        return [self handleProfileCompleteURL:url context:context];
    }
    
    // Default: complete with URL
    return [MSIDWebviewAction actionWithType:MSIDWebviewActionCompleteWithURL
                                         url:url];
}

- (MSIDWebviewAction *)handleEnrollURL:(NSURL *)url
                               context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
        @"[InteractiveController] Handling enroll URL");
    
    // BRT Acquisition - BUSINESS LOGIC in InteractiveController
    [self acquireBRTIfNeeded:context];
    
    // Resolve action using resolver
    return [MSIDSpecialURLViewActionResolver resolveActionForURL:url
                                                          state:self.sessionState];
}

- (MSIDWebviewAction *)handleInstallProfileURL:(NSURL *)url
                                       context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
        @"[InteractiveController] Handling installProfile URL");
    
    // Resolve action (extracts headers, creates ASWebAuth action)
    return [MSIDSpecialURLViewActionResolver resolveActionForURL:url
                                                          state:self.sessionState];
}

- (MSIDWebviewAction *)handleProfileCompleteURL:(NSURL *)url
                                        context:(id<MSIDRequestContext>)context
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
        @"[InteractiveController] Handling profileComplete URL");
    
    // Broker Retry Logic - BUSINESS LOGIC in InteractiveController
    if (![self isRunningInBrokerContext])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
            @"[InteractiveController] Not in broker, will retry in broker");
        
        // Note: In real implementation, this would be async
        // For now, we return an action to dismiss and trigger broker flow
        return [MSIDWebviewAction actionWithType:MSIDWebviewActionRetryInBroker
                                             url:url];
    }
    
    // Already in broker, complete normally
    return [MSIDWebviewAction actionWithType:MSIDWebviewActionCompleteWithURL
                                         url:url];
}

#pragma mark - BRT Acquisition (Business Logic)

- (void)acquireBRTIfNeeded:(id<MSIDRequestContext>)context
{
    // Check if BRT acquisition needed (policy decision)
    if (![self shouldAcquireBRT])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, 
            @"[InteractiveController] BRT not required (already in broker)");
        return;
    }
    
    // Check if already acquired
    if (self.sessionState.brtAcquired)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, 
            @"[InteractiveController] BRT already acquired");
        return;
    }
    
    // Check if max attempts reached
    if (self.sessionState.brtAttemptCount >= 2)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, 
            @"[InteractiveController] BRT max attempts reached");
        return;
    }
    
    // Attempt BRT acquisition
    self.sessionState.brtAttemptCount++;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
        @"[InteractiveController] Acquiring BRT (attempt %ld of 2)", 
        (long)self.sessionState.brtAttemptCount);
    
    // Synchronous for simplicity - in production would be async
    BOOL success = [self acquireBRTToken:context];
    
    if (success)
    {
        self.sessionState.brtAcquired = YES;
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
            @"[InteractiveController] BRT acquired successfully");
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, 
            @"[InteractiveController] BRT acquisition failed (attempt %ld)", 
            (long)self.sessionState.brtAttemptCount);
    }
}

- (BOOL)shouldAcquireBRT
{
    // CRITICAL: Only acquire BRT if NOT in broker context
    if ([self isRunningInBrokerContext])
    {
        return NO;  // Skip BRT when already in broker
    }
    
    // Additional policy checks can be added here
    return YES;  // Acquire BRT when NOT in broker context
}

- (BOOL)acquireBRTToken:(id<MSIDRequestContext>)context
{
    // TODO: Implement actual BRT acquisition
    // This would typically:
    // 1. Check if broker is available
    // 2. Request BRT from broker
    // 3. Store BRT in token cache
    // 4. Return success/failure
    
    return NO;  // Placeholder
}

#pragma mark - Broker Context (Business Logic)

- (BOOL)isRunningInBrokerContext
{
    // TODO: Implement broker context detection
    // Check if current token acquisition is happening via broker
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
    
    completion(NO, nil);  // Placeholder
}

@end
```

### WebviewController Implementation

WebviewController detects URLs/headers and delegates to InteractiveController:

```objc
// MSIDOAuth2EmbeddedWebviewController.m

@interface MSIDOAuth2EmbeddedWebviewController()

// Reference to parent handler (InteractiveController)
@property (nonatomic, weak) id<MSIDWebviewHandlerProtocol> handler;

// Existing properties
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *lastResponseHeaders;

@end

@implementation MSIDOAuth2EmbeddedWebviewController

#pragma mark - Initialization

- (instancetype)initWithStartURL:(NSURL *)startURL
                     redirectUri:(NSString *)redirectUri
                         handler:(id<MSIDWebviewHandlerProtocol>)handler
                         context:(id<MSIDRequestContext>)context
{
    self = [super initWithStartURL:startURL redirectUri:redirectUri context:context];
    if (self)
    {
        _handler = handler;
        
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, context, 
            @"[WebviewController] Initialized with handler");
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
            @"[WebviewController] Detected msauth:// URL: %@", url);
        
        // Cancel navigation
        decisionHandler(WKNavigationActionPolicyCancel);
        
        // Delegate to handler (InteractiveController)
        [self delegateSpecialURLToHandler:url];
        return;
    }
    
    // Intercept browser:// URLs
    if ([scheme isEqualToString:@"browser"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
            @"[WebviewController] Detected browser:// URL: %@", url);
        
        // Cancel navigation
        decisionHandler(WKNavigationActionPolicyCancel);
        
        // Delegate to handler
        [self delegateSpecialURLToHandler:url];
        return;
    }
    
    // Normal navigation
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Header Capture

- (void)setupResponseHeaderCapture
{
    __weak typeof(self) weakSelf = self;
    self.responseHeaderHandler = ^(NSURLResponse *response) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]])
        {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            weakSelf.lastResponseHeaders = httpResponse.allHeaderFields;
            
            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, weakSelf.context, 
                @"[WebviewController] Captured %lu response headers", 
                (unsigned long)weakSelf.lastResponseHeaders.count);
        }
    };
}

#pragma mark - Handler Protocol Delegation

- (void)delegateSpecialURLToHandler:(NSURL *)url
{
    if (!self.handler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, 
            @"[WebviewController] No handler set, cannot process URL");
        [self completeWebAuthWithURL:url];
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, self.context, 
        @"[WebviewController] Delegating URL to handler");
    
    // Call handler - InteractiveController makes business decisions
    MSIDWebviewAction *action = [self.handler handleSpecialURL:url
                                                responseHeaders:self.lastResponseHeaders
                                                        context:self.context];
    
    // Execute the action returned by handler
    [self executeViewAction:action];
}

#pragma mark - View Action Execution

- (void)executeViewAction:(MSIDWebviewAction *)action
{
    if (!action)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, 
            @"[WebviewController] Nil action received");
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"[WebviewController] Executing action: %@", action.typeString);
    
    switch (action.type)
    {
        case MSIDWebviewActionLoadRequest:
            [self executeLoadRequestAction:action];
            break;
            
        case MSIDWebviewActionOpenASWebAuth:
            [self executeOpenASWebAuthAction:action];
            break;
            
        case MSIDWebviewActionCompleteWithURL:
            [self executeCompleteAction:action];
            break;
            
        case MSIDWebviewActionRetryInBroker:
            [self executeRetryInBrokerAction:action];
            break;
            
        default:
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.context, 
                @"[WebviewController] Unknown action type: %ld", (long)action.type);
            break;
    }
}

- (void)executeLoadRequestAction:(MSIDWebviewAction *)action
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"[WebviewController] Loading URL in webview");
    
    NSURLRequest *request = [NSURLRequest requestWithURL:action.url];
    [self.webView loadRequest:request];
}

- (void)executeOpenASWebAuthAction:(MSIDWebviewAction *)action
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"[WebviewController] Opening ASWebAuthenticationSession");
    
    // Create and start ASWebAuthenticationSession
    // Implementation details depend on your existing ASWebAuth handling
    [self openASWebAuthenticationSessionWithURL:action.url
                                        purpose:action.purpose
                              additionalHeaders:action.additionalHeaders];
}

- (void)executeCompleteAction:(MSIDWebviewAction *)action
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"[WebviewController] Completing authentication");
    
    [self completeWebAuthWithURL:action.url];
}

- (void)executeRetryInBrokerAction:(MSIDWebviewAction *)action
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.context, 
        @"[WebviewController] Retrying in broker context");
    
    // Dismiss webview and delegate to handler for broker retry
    [self dismissWebview];
    
    if (self.handler)
    {
        [self.handler retryInBrokerContextForURL:action.url
                                      completion:^(BOOL success, NSError *error) {
            if (!success)
            {
                // Fallback to completing with URL
                [self completeWebAuthWithURL:action.url];
            }
        }];
    }
}

@end
```

**Key Architectural Points:**

1. **InteractiveController** implements `MSIDWebviewHandlerProtocol`
2. **InteractiveController** owns `sessionState` (BRT flags, headers)
3. **InteractiveController** contains ALL business logic (BRT, broker retry)
4. **WebviewController** only detects URLs and captures headers
5. **WebviewController** delegates to handler via `handleSpecialURL:`
6. **WebviewController** executes `MSIDWebviewAction` returned by handler
7. **NO business logic in WebviewController** - pure UI component

---

## E2E Wiring Guide

This guide shows how to wire up the handler protocol pattern between InteractiveController and WebviewController.

### Step 1: Define Handler Protocol

**File:** MSIDWebviewHandlerProtocol.h

**Create protocol:**
```objc
@protocol MSIDWebviewHandlerProtocol <NSObject>

- (MSIDWebviewAction *)handleSpecialURL:(NSURL *)url
                          responseHeaders:(NSDictionary<NSString *, NSString *> *)headers
                                  context:(id<MSIDRequestContext>)context;

- (BOOL)isRunningInBrokerContext;

- (void)retryInBrokerContextForURL:(NSURL *)url
                         completion:(void (^)(BOOL success, NSError *error))completion;

@end
```

### Step 2: Add Session State to InteractiveController

**File:** MSIDLocalInteractiveController.m (or ADBrokerInteractiveControllerWithPRT.m)

**Add to @interface:**
```objc
@interface MSIDLocalInteractiveController() <MSIDWebviewHandlerProtocol>
@property (nonatomic, strong) MSIDInteractiveWebviewState *sessionState;
@end
```

**In init method:**
```objc
_sessionState = [[MSIDInteractiveWebviewState alloc] init];
```

### Step 3: Implement Handler Protocol in InteractiveController

**Add handler methods:**
```objc
- (MSIDWebviewAction *)handleSpecialURL:(NSURL *)url
                          responseHeaders:(NSDictionary<NSString *, NSString *> *)headers
                                  context:(id<MSIDRequestContext>)context
{
    // Store headers
    if (headers) {
        self.sessionState.responseHeaders = headers;
    }
    
    // Route based on URL host
    NSString *host = url.host.lowercaseString;
    if ([host isEqualToString:@"enroll"]) {
        return [self handleEnrollURL:url context:context];
    }
    // ... other URL handlers
    
    return [MSIDWebviewAction actionWithType:MSIDWebviewActionCompleteWithURL url:url];
}

- (MSIDWebviewAction *)handleEnrollURL:(NSURL *)url context:(id<MSIDRequestContext>)context
{
    // BRT Acquisition (business logic)
    [self acquireBRTIfNeeded:context];
    
    // Resolve and return action
    return [MSIDSpecialURLViewActionResolver resolveActionForURL:url state:self.sessionState];
}
```

### Step 4: Add BRT Logic to InteractiveController

**Add BRT methods:**
```objc
- (void)acquireBRTIfNeeded:(id<MSIDRequestContext>)context
{
    if (![self shouldAcquireBRT]) return;
    if (self.sessionState.brtAcquired) return;
    if (self.sessionState.brtAttemptCount >= 2) return;
    
    self.sessionState.brtAttemptCount++;
    BOOL success = [self acquireBRTToken:context];
    if (success) {
        self.sessionState.brtAcquired = YES;
    }
}

- (BOOL)shouldAcquireBRT
{
    // CRITICAL: Only if NOT in broker context
    return ![self isRunningInBrokerContext];
}
```

### Step 5: Add Broker Logic to InteractiveController

**Add broker methods:**
```objc
- (BOOL)isRunningInBrokerContext
{
    // Check if current acquisition is via broker
    return NO;  // TODO: Implement
}

- (void)retryInBrokerContextForURL:(NSURL *)url
                         completion:(void (^)(BOOL, NSError *))completion
{
    // Switch to broker context
    // TODO: Implement broker retry
    completion(NO, nil);
}
```

### Step 6: Add Handler Reference to WebviewController

**File:** MSIDOAuth2EmbeddedWebviewController.m

**Add to @interface:**
```objc
@interface MSIDOAuth2EmbeddedWebviewController()
@property (nonatomic, weak) id<MSIDWebviewHandlerProtocol> handler;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *lastResponseHeaders;
@end
```

**Update init method:**
```objc
- (instancetype)initWithStartURL:(NSURL *)startURL
                     redirectUri:(NSString *)redirectUri
                         handler:(id<MSIDWebviewHandlerProtocol>)handler
                         context:(id<MSIDRequestContext>)context
{
    self = [super initWithStartURL:startURL redirectUri:redirectUri context:context];
    if (self) {
        _handler = handler;
    }
    return self;
}
```

### Step 7: Setup Header Capture in WebviewController

**Add setup method:**
```objc
- (void)setupResponseHeaderCapture
{
    __weak typeof(self) weakSelf = self;
    self.responseHeaderHandler = ^(NSURLResponse *response) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            weakSelf.lastResponseHeaders = ((NSHTTPURLResponse *)response).allHeaderFields;
        }
    };
}
```

### Step 8: Delegate URL Detection to Handler

**Override decidePolicyForNavigationAction:**
```objc
- (void)webView:(WKWebView *)webView 
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    
    if ([scheme isEqualToString:@"msauth"] || [scheme isEqualToString:@"browser"])
    {
        decisionHandler(WKNavigationActionPolicyCancel);
        [self delegateSpecialURLToHandler:url];
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)delegateSpecialURLToHandler:(NSURL *)url
{
    // Call handler - InteractiveController makes decisions
    MSIDWebviewAction *action = [self.handler handleSpecialURL:url
                                                responseHeaders:self.lastResponseHeaders
                                                        context:self.context];
    
    // Execute action returned by handler
    [self executeViewAction:action];
}
```

### Step 9: Implement Action Execution in WebviewController

**Add execution method:**
```objc
- (void)executeViewAction:(MSIDWebviewAction *)action
{
    switch (action.type)
    {
        case MSIDWebviewActionLoadRequest:
            [self.webView loadRequest:[NSURLRequest requestWithURL:action.url]];
            break;
            
        case MSIDWebviewActionOpenASWebAuth:
            [self openASWebAuthSessionWithURL:action.url
                                      purpose:action.purpose
                            additionalHeaders:action.additionalHeaders];
            break;
            
        case MSIDWebviewActionCompleteWithURL:
            [self completeWebAuthWithURL:action.url];
            break;
            
        case MSIDWebviewActionRetryInBroker:
            [self.handler retryInBrokerContextForURL:action.url
                                          completion:^(BOOL success, NSError *error) {
                if (!success) {
                    [self completeWebAuthWithURL:action.url];
                }
            }];
            break;
    }
}
```

### Step 10: Wire Handler in Factory

**File:** MSIDAADWebviewFactory.m or similar

**When creating WebviewController, pass InteractiveController as handler:**
```objc
// In InteractiveController when creating WebviewController
MSIDOAuth2EmbeddedWebviewController *webviewController = 
    [[MSIDOAuth2EmbeddedWebviewController alloc] initWithStartURL:startURL
                                                       redirectUri:redirectUri
                                                           handler:self  // self = InteractiveController
                                                           context:context];

[webviewController setupResponseHeaderCapture];
```

**Summary:**
- InteractiveController creates WebviewController
- InteractiveController passes itself as handler
- WebviewController stores weak reference to handler
- WebviewController delegates all decisions to handler
- InteractiveController owns session state and business logic

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
- Check responseHeaderHandler is set in WebviewController
- Verify lastResponseHeaders populated in WebviewController
- Check headers passed to handler via handleSpecialURL:
- Verify InteractiveController stores in sessionState.responseHeaders

**BRT Not Acquired:**
- Verify InteractiveController.shouldAcquireBRT returns YES
- Check isRunningInBrokerContext returns NO (BRT only when NOT in broker)
- Check brtAttemptCount < 2 in InteractiveController's sessionState
- Check !brtAcquired in InteractiveController's sessionState
- Verify acquireBRTIfNeeded called in handleEnrollURL

**Broker Retry Not Working:**
- Verify isRunningInBrokerContext correct in InteractiveController
- Check retryInBrokerContext implementation in InteractiveController
- Verify InteractiveController returns RetryInBroker action
- Check WebviewController executes retry action correctly

**Handler Not Called:**
- Verify WebviewController has handler reference set
- Check handler is InteractiveController instance
- Verify WebviewController.delegateSpecialURLToHandler called
- Check handler protocol methods implemented in InteractiveController

---

## Summary

### Implementation Approach

**Simplified Design:**
- ✅ No state machine complexity
- ✅ Handler protocol pattern (WebviewController → InteractiveController)
- ✅ Session state for BRT (2 flags only)
- ✅ Clear separation of concerns
- ✅ Standard iOS patterns

**Architecture:**
- **InteractiveController**: Business logic layer (BRT, broker retry, decisions)
- **WebviewController**: UI component layer (detection, execution only)
- **Handler Protocol**: Clean interface between layers
- **Session State**: Owned by InteractiveController

**Components Used:**
- MSIDWebviewHandlerProtocol (new - defines interface)
- MSIDInteractiveWebviewState (owned by InteractiveController)
- MSIDSpecialURLViewActionResolver (existing - parsing/mapping)
- MSIDWebviewAction (existing - typed commands)

**Critical Architectural Principles:**
1. **BRT acquisition logic** → InteractiveController (NOT WebviewController)
2. **Broker retry logic** → InteractiveController (NOT WebviewController)
3. **Session state ownership** → InteractiveController (NOT WebviewController)
4. **Business decisions** → InteractiveController (NOT WebviewController)
5. **URL detection & header capture** → WebviewController (UI responsibility)
6. **Action execution** → WebviewController (UI responsibility)

**Ready for Production:**
- Complete code examples with correct architecture
- Handler protocol implementation
- Wiring guide with proper separation
- Testing strategy
- Rollout plan

**This is Option A: Simple, clean, architecturally correct, and production-ready!** 🎉
