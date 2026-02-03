# State Machine Implementation and Flow

## Yes, There IS a State Machine in This PR!

The PR implements a comprehensive state machine for handling special URLs (`msauth://` and `browser://`) in embedded webviews. The state machine is located in **`MSIDInteractiveWebviewStateMachine`**.

---

## Table of Contents

1. [Overview](#overview)
2. [Core Concepts](#core-concepts)
3. [State Machine Components](#state-machine-components)
4. [Flow Diagram](#flow-diagram)
5. [Detailed Flow Explanation](#detailed-flow-explanation)
6. [State Transitions](#state-transitions)
7. [Controller Actions](#controller-actions)
8. [View Actions](#view-actions)
9. [Example Flows](#example-flows)
10. [State Transition Table](#state-transition-table)

---

## Overview

The state machine implements a **controller-action pattern** where:
- **Controller Actions**: Async operations that update state (e.g., AcquireBRT, RetryInBroker)
- **View Actions**: Commands for the webview controller to execute (e.g., LoadRequest, OpenASWebAuth)

### Key Design Principle: "Run Until Stable"

The state machine runs controller actions in a loop until reaching a **stable state** (no more controller actions needed), then returns a view action.

---

## Core Concepts

### 1. Entry Point

```objc
[stateMachine handleSpecialURL:url
                navigationAction:navigationAction
                      completion:^(MSIDWebviewAction *action, NSError *error) {
    // Execute the returned view action
}];
```

### 2. Two Types of Actions

**Controller Actions** (Internal State Changes):
- Execute asynchronously
- Update state flags
- Can trigger additional controller actions
- Examples: `AcquireBRTOnce`, `RetryInBroker`

**View Actions** (External Commands):
- Returned to caller for execution
- Tell webview controller what to do
- Examples: `LoadRequest`, `OpenASWebAuth`, `CompleteWithURL`

### 3. State Object

`MSIDInteractiveWebviewState` tracks:
- BRT acquisition status (`brtAttempted`, `brtAcquired`)
- Current URL and query parameters
- Broker transfer status (`transferredToBroker`)
- HTTP response headers
- Context flags (`isGateScheme`, `isRunningInBrokerContext`)

---

## State Machine Components

### Main Class: MSIDInteractiveWebviewStateMachine

**Location**: `IdentityCore/src/webview/embeddedWebview/MSIDInteractiveWebviewStateMachine.h/m`

**Key Methods**:

1. **`initWithHandler:`** - Initialize with a handler
2. **`handleSpecialURL:navigationAction:completion:`** - Entry point
3. **`runUntilStableWithCompletion:`** - Execute controller actions loop
4. **`nextControllerActionForState:`** - Determine next action
5. **`resolveViewActionForURL:`** - Get final view action

### Supporting Classes

1. **`MSIDInteractiveWebviewState`** - State tracking
2. **`MSIDInteractiveWebviewHandler`** (Protocol) - Policy decisions
3. **`MSIDWebviewControllerAction`** (Protocol) - Controller action interface
4. **`MSIDAcquireBRTOnceControllerAction`** - BRT acquisition
5. **`MSIDRetryInBrokerControllerAction`** - Broker retry
6. **`MSIDWebviewAction`** - View action model

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                   handleSpecialURL:completion:                      │
│                    (State Machine Entry Point)                      │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Update State with URL Context                    │
│  - Set pendingURL, queryParams                                      │
│  - Extract isGateScheme (msauth:// or browser://)                   │
│  - Check isRunningInBrokerContext                                   │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    runUntilStableWithCompletion                     │
│              (Execute controller actions loop)                       │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ Get Next Action │
                    └─────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ nextController  │
                    │ ActionForState  │
                    └─────────────────┘
                              ↓
        ┌─────────────────────┴─────────────────────┐
        │                                           │
    [Action?]                                  [No Action]
        │                                           │
        YES                                         NO
        ↓                                           ↓
┌─────────────────────┐                 ┌──────────────────────┐
│ Execute Controller  │                 │   State is Stable    │
│      Action         │                 │   (Exit Loop)        │
└─────────────────────┘                 └──────────────────────┘
        ↓                                           ↓
┌─────────────────────┐                            │
│  Update State Flags │                            │
│  (brtAttempted,     │                            │
│   transferredTo-    │                            │
│   Broker, etc.)     │                            │
└─────────────────────┘                            │
        ↓                                           │
        │                                           │
        └───────────► (Loop Back) ◄─────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    resolveViewActionForURL                          │
│          (Determine what webview should do)                         │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ Ask Handler for │
                    │   View Action   │
                    └─────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ Return View     │
                    │ Action to Caller│
                    └─────────────────┘
```

---

## Detailed Flow Explanation

### Step 1: Entry Point - `handleSpecialURL:navigationAction:completion:`

**Triggered when**: Webview controller intercepts a special URL (msauth:// or browser://)

**Actions**:
1. Validate URL (error if nil)
2. Update state with URL context:
   ```objc
   state.pendingURL = url;
   state.queryParams = [url msidQueryParameters];
   state.isGateScheme = [scheme isEqualToString:@"msauth"] || [scheme isEqualToString:@"browser"];
   state.isRunningInBrokerContext = [handler isRunningInBrokerContext];
   ```
3. Call `runUntilStableWithCompletion:`

### Step 2: Run Until Stable - `runUntilStableWithCompletion:`

**Purpose**: Execute controller actions in a loop until no more actions are needed.

**Algorithm**:
```
LOOP:
1. Call nextControllerActionForState(state)
2. If action returned:
   a. Execute action
   b. Update state based on result
   c. Check failure policy
   d. Go to LOOP
3. If no action (state is stable):
   a. Exit loop
   b. Proceed to view action resolution
```

**Implementation**:
```objc
- (void)runUntilStableWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    // Get next controller action based on current state
    id<MSIDWebviewControllerAction> nextAction = [self nextControllerActionForState:self.state];
    
    if (!nextAction)
    {
        // State is stable - no more controller actions
        completion(YES, nil);
        return;
    }
    
    // Execute the controller action
    [nextAction executeWithState:self.state
                         handler:self.handler
                      completion:^(BOOL success, NSError *error) {
        if (!success && self.state.brtFailurePolicy == MSIDInteractiveWebviewBRTFailurePolicyFail)
        {
            completion(NO, error);
            return;
        }
        
        // Recursively continue until stable
        [self runUntilStableWithCompletion:completion];
    }];
}
```

### Step 3: Determine Next Action - `nextControllerActionForState:`

**Purpose**: Decides which controller action (if any) should execute next based on state.

**Decision Logic**:

```objc
- (id<MSIDWebviewControllerAction>)nextControllerActionForState:(MSIDInteractiveWebviewState *)state
{
    // Priority 1: Check if BRT acquisition needed
    if (state.isGateScheme &&
        [handler shouldAcquireBRTForSpecialURL:state.pendingURL state:state] &&
        !state.brtAttempted)  // Prevent retry loops
    {
        state.brtFailurePolicy = [handler brtFailurePolicyForSpecialURL:state.pendingURL state:state];
        return [[MSIDAcquireBRTOnceControllerAction alloc] init];
    }
    
    // Priority 2: Check if broker retry needed
    if ([handler shouldRetryInBrokerForSpecialURL:state.pendingURL state:state] &&
        !state.transferredToBroker)  // Prevent retry loops
    {
        return [[MSIDRetryInBrokerControllerAction alloc] initWithURL:state.pendingURL];
    }
    
    // State is stable - no more actions
    return nil;
}
```

**Priority Order**:
1. **AcquireBRTOnce** - If BRT needed and not yet attempted
2. **RetryInBroker** - If broker retry needed and not yet transferred
3. **nil** - State is stable

### Step 4: Execute Controller Action

Each controller action implements the `MSIDWebviewControllerAction` protocol:

```objc
@protocol MSIDWebviewControllerAction <NSObject>

- (void)executeWithState:(MSIDInteractiveWebviewState *)state
                 handler:(id<MSIDInteractiveWebviewHandler>)handler
              completion:(void (^)(BOOL success, NSError *error))completion;

@end
```

**Example - AcquireBRTOnce**:
```objc
- (void)executeWithState:(MSIDInteractiveWebviewState *)state
                 handler:(id<MSIDInteractiveWebviewHandler>)handler
              completion:(void (^)(BOOL success, NSError *error))completion
{
    // Prevent duplicate attempts
    if (state.brtAttempted)
    {
        completion(YES, nil);
        return;
    }
    
    // Mark as attempted (prevents retry loop)
    state.brtAttempted = YES;
    
    // Call handler to acquire BRT
    [handler acquireBRTTokenWithCompletion:^(BOOL success, NSError *error) {
        if (success)
        {
            state.brtAcquired = YES;
        }
        completion(success, error);
    }];
}
```

**Example - RetryInBroker**:
```objc
- (void)executeWithState:(MSIDInteractiveWebviewState *)state
                 handler:(id<MSIDInteractiveWebviewHandler>)handler
              completion:(void (^)(BOOL success, NSError *error))completion
{
    // Call handler to retry in broker context
    [handler retryInteractiveRequestInBrokerContextForURL:self.url
                                               completion:^(BOOL success, NSError *error) {
        if (success)
        {
            // Mark as transferred (prevents retry loop)
            state.transferredToBroker = YES;
            
            // Dismiss embedded webview
            [handler dismissEmbeddedWebviewIfPresent];
        }
        completion(success, error);
    }];
}
```

### Step 5: Resolve View Action - `resolveViewActionForURL:`

**Purpose**: After state is stable, determine what the webview should do.

**Logic**:
```objc
- (MSIDWebviewAction *)resolveViewActionForURL:(NSURL *)url
{
    // Ask handler to resolve view action
    MSIDWebviewAction *action = [handler viewActionForSpecialURL:url state:self.state];
    
    if (action)
    {
        return action;
    }
    
    // Default safe behavior: complete with URL
    return [MSIDWebviewAction completeWithURLAction:url];
}
```

**Handler typically delegates to**:
- `MSIDSpecialURLViewActionResolver` for URL-based resolution
- Can access `state.responseHeaders` for header-based decisions

### Step 6: Return to Caller

The view action is returned via completion block:
```objc
completion(action, nil);
```

---

## State Transitions

### State Flags and Their Meanings

| Flag | Initial | After Action | Purpose |
|------|---------|--------------|---------|
| `brtAttempted` | NO | YES (after AcquireBRTOnce) | Prevents BRT retry loops |
| `brtAcquired` | NO | YES (if successful) | Tracks BRT acquisition success |
| `transferredToBroker` | NO | YES (after RetryInBroker) | Prevents broker retry loops |
| `isGateScheme` | Computed | - | Identifies msauth:// or browser:// URLs |
| `isRunningInBrokerContext` | From handler | - | Context awareness |

### State Transition Diagram

```
┌────────────┐
│  Initial   │
│   State    │
└────────────┘
      ↓
  [URL Intercepted]
      ↓
┌────────────────────────┐
│ pendingURL set         │
│ isGateScheme computed  │
│ isRunningInBroker...   │
└────────────────────────┘
      ↓
  [Should Acquire BRT?]
      ↓
    YES → ┌──────────────────────┐
          │ Execute AcquireBRT   │
          │ brtAttempted = YES   │
          │ brtAcquired = YES/NO │
          └──────────────────────┘
                   ↓
    NO  → [Should Retry In Broker?]
                   ↓
          YES → ┌───────────────────────┐
                │ Execute RetryInBroker │
                │ transferredToBroker   │
                │     = YES             │
                └───────────────────────┘
                         ↓
          NO  → [State is Stable]
                         ↓
                ┌────────────────────┐
                │ Resolve View Action│
                │ Return to Caller   │
                └────────────────────┘
```

---

## Controller Actions

### 1. MSIDAcquireBRTOnceControllerAction

**Purpose**: Acquire Broker Refresh Token exactly once

**When Triggered**:
- `state.isGateScheme == YES`
- `handler.shouldAcquireBRTForSpecialURL:state: == YES`
- `state.brtAttempted == NO`

**State Changes**:
- Sets `state.brtAttempted = YES`
- Sets `state.brtAcquired = YES` (if successful)

**Failure Handling**:
- Respects `state.brtFailurePolicy`
- If policy is `Fail` and acquisition fails, entire flow fails
- If policy is `Continue`, flow continues despite failure

**Prevents**: Infinite BRT acquisition loops

### 2. MSIDRetryInBrokerControllerAction

**Purpose**: Transfer flow to broker context

**When Triggered**:
- `handler.shouldRetryInBrokerForSpecialURL:state: == YES`
- `state.transferredToBroker == NO`

**State Changes**:
- Sets `state.transferredToBroker = YES`
- Calls `handler.dismissEmbeddedWebviewIfPresent`

**Effect**:
- Dismisses embedded webview
- Initiates broker interactive controller
- May open SSO extension webview

**Prevents**: Infinite broker retry loops

---

## View Actions

View actions are returned to the webview controller for execution.

### Action Types

| Type | Purpose | Properties Used |
|------|---------|----------------|
| `Noop` | Do nothing | - |
| `LoadRequestInWebview` | Load URL in embedded webview | `request` |
| `OpenASWebAuthenticationSession` | Open system webview | `url`, `purpose`, `additionalHeaders` |
| `OpenExternalBrowser` | Open Safari | `url` |
| `CompleteWithURL` | Complete flow with URL | `url` |
| `FailWithError` | Fail flow with error | `error` |

### View Action Resolution

The handler's `viewActionForSpecialURL:state:` typically delegates to `MSIDSpecialURLViewActionResolver`:

```objc
// msauth://enroll?cpurl=...
→ LoadRequestInWebview (load cpurl)

// msauth://installProfile?url=...
→ OpenASWebAuthenticationSession (with X-Install-Url from headers)

// msauth://profileComplete
→ CompleteWithURL

// browser://...
→ CompleteWithURL
```

---

## Example Flows

### Example 1: Simple Completion (No Controller Actions)

**URL**: `browser://success`

**Flow**:
```
1. handleSpecialURL("browser://success")
2. Update state:
   - pendingURL = "browser://success"
   - isGateScheme = YES
3. runUntilStable:
   - nextControllerActionForState → nil (no actions needed)
   - State is stable immediately
4. resolveViewAction:
   - handler.viewActionForSpecialURL → CompleteWithURL
5. Return: CompleteWithURL action
```

**State Changes**: None

**Result**: Flow completes with URL

---

### Example 2: BRT Acquisition Flow

**URL**: `msauth://compliance?cpurl=https://...`

**Handler Policies**:
- `shouldAcquireBRTForSpecialURL` → YES
- `brtFailurePolicyForSpecialURL` → Continue

**Flow**:
```
1. handleSpecialURL("msauth://compliance?cpurl=...")
2. Update state:
   - pendingURL = "msauth://compliance?cpurl=..."
   - queryParams = {"cpurl": "https://..."}
   - isGateScheme = YES
3. runUntilStable (Iteration 1):
   - nextControllerActionForState:
     → AcquireBRTOnceControllerAction (brtAttempted=NO)
   - Execute AcquireBRTOnce:
     → Set brtAttempted = YES
     → Call handler.acquireBRTTokenWithCompletion
     → Success: Set brtAcquired = YES
4. runUntilStable (Iteration 2):
   - nextControllerActionForState:
     → nil (brtAttempted=YES, no more actions)
   - State is stable
5. resolveViewAction:
   - handler.viewActionForSpecialURL:
     → Resolver: LoadRequestInWebview(cpurl)
6. Return: LoadRequestInWebview action
```

**State Changes**:
- `brtAttempted`: NO → YES
- `brtAcquired`: NO → YES

**Result**: Webview loads compliance URL (after BRT acquired)

---

### Example 3: Broker Retry Flow

**URL**: `msauth://profileComplete`

**Context**: Not in broker context

**Handler Policies**:
- `isRunningInBrokerContext` → NO
- `shouldRetryInBrokerForSpecialURL` → YES

**Flow**:
```
1. handleSpecialURL("msauth://profileComplete")
2. Update state:
   - pendingURL = "msauth://profileComplete"
   - isGateScheme = YES
   - isRunningInBrokerContext = NO
3. runUntilStable (Iteration 1):
   - nextControllerActionForState:
     → RetryInBrokerControllerAction (transferredToBroker=NO)
   - Execute RetryInBroker:
     → Call handler.retryInteractiveRequestInBrokerContext
     → Success: Set transferredToBroker = YES
     → Call handler.dismissEmbeddedWebviewIfPresent
4. runUntilStable (Iteration 2):
   - nextControllerActionForState:
     → nil (transferredToBroker=YES, no more actions)
   - State is stable
5. resolveViewAction:
   - handler.viewActionForSpecialURL:
     → Resolver: CompleteWithURL
6. Return: CompleteWithURL action
```

**State Changes**:
- `transferredToBroker`: NO → YES

**Side Effects**:
- Embedded webview dismissed
- Broker interactive controller initiated

**Result**: Flow transferred to broker

---

### Example 4: Complex Flow (BRT + Broker Retry)

**URL**: `msauth://installProfile`

**Context**: Not in broker context

**Handler Policies**:
- `shouldAcquireBRTForSpecialURL` → YES
- `brtFailurePolicyForSpecialURL` → Continue
- `shouldRetryInBrokerForSpecialURL` → YES (after BRT)

**Flow**:
```
1. handleSpecialURL("msauth://installProfile")
2. Update state:
   - pendingURL = "msauth://installProfile"
   - isGateScheme = YES
   - isRunningInBrokerContext = NO
3. runUntilStable (Iteration 1):
   - nextControllerActionForState:
     → AcquireBRTOnceControllerAction (priority 1)
   - Execute: brtAttempted = YES, brtAcquired = YES
4. runUntilStable (Iteration 2):
   - nextControllerActionForState:
     → RetryInBrokerControllerAction (priority 2)
   - Execute: transferredToBroker = YES
5. runUntilStable (Iteration 3):
   - nextControllerActionForState:
     → nil (both actions completed)
   - State is stable
6. resolveViewAction:
   - handler.viewActionForSpecialURL:
     → Resolver: OpenASWebAuthenticationSession
       (with X-Install-Url from headers)
7. Return: OpenASWebAuthenticationSession action
```

**State Changes**:
- `brtAttempted`: NO → YES
- `brtAcquired`: NO → YES
- `transferredToBroker`: NO → YES

**Result**: Opens ASWebAuth, then retries in broker

---

## State Transition Table

Complete state transition matrix showing all possible paths:

| Initial State | URL Type | BRT Needed | Broker Retry | Controller Actions | Final State | View Action |
|--------------|----------|------------|--------------|-------------------|-------------|-------------|
| Clean | `browser://` | N/A | No | None | No changes | CompleteWithURL |
| Clean | `msauth://enroll` | No | No | None | No changes | LoadRequest |
| Clean | `msauth://enroll` | Yes | No | AcquireBRT | brtAttempted=Y, brtAcquired=Y | LoadRequest |
| Clean | `msauth://installProfile` | No | No | None | No changes | OpenASWebAuth |
| Clean | `msauth://installProfile` | Yes | No | AcquireBRT | brtAttempted=Y, brtAcquired=Y | OpenASWebAuth |
| Clean | `msauth://profileComplete` | No | Yes | RetryInBroker | transferredToBroker=Y | CompleteWithURL |
| Clean | `msauth://profileComplete` | Yes | Yes | AcquireBRT, RetryInBroker | brtAttempted=Y, brtAcquired=Y, transferredToBroker=Y | CompleteWithURL |
| brtAttempted=Y | `msauth://` | Yes | No | None (skip) | No changes | Per URL type |
| transferredToBroker=Y | Any | No | Yes | None (skip) | No changes | Per URL type |

**Legend**:
- Y = YES/True
- N/A = Not Applicable
- Clean = Initial state with all flags set to NO/nil

---

## Key Insights

### 1. Loop Prevention

The state machine prevents infinite loops through state flags:
- `brtAttempted` prevents repeated BRT acquisition
- `transferredToBroker` prevents repeated broker retries

### 2. Recursive "Run Until Stable"

The loop continues until no more controller actions are needed:
```
LOOP:
  action = nextControllerActionForState(state)
  if action:
    execute(action)
    goto LOOP  // Recursive call
  else:
    break  // State is stable
```

### 3. Separation of Concerns

- **Controller Actions**: Internal state management (async operations)
- **View Actions**: External commands (what webview should do)
- **State**: Data container (no logic)
- **Handler**: Policy provider (decisions without implementation)

### 4. Extensibility

Easy to add new controller actions:
1. Implement `MSIDWebviewControllerAction` protocol
2. Add logic to `nextControllerActionForState:`
3. Add corresponding state flags (if needed)

### 5. Safety

Default behavior is safe:
- If handler returns nil, defaults to `CompleteWithURL`
- Existing flows unaffected (placeholder framework)
- Controller actions are optional (can all return nil)

---

## Summary

**Q: Is there a state machine implementation?**  
**A: YES!** `MSIDInteractiveWebviewStateMachine`

**Q: How does it work?**  
**A: "Run until stable" loop:**
1. Updates state with URL context
2. Executes controller actions (BRT, broker retry) until stable
3. Resolves and returns view action for webview to execute

**Q: What makes it a state machine?**  
**A: State-driven behavior:**
- Current state determines next action
- Actions update state
- State transitions are explicit
- Loop until stable (no more state changes needed)

**Q: Why is it useful?**  
**A: Clean separation:**
- Complex async operations (controller actions) isolated from UI
- Webview only receives simple commands (view actions)
- Extensible: easy to add new actions
- Testable: state-based logic easy to unit test

---

## Related Files

- `MSIDInteractiveWebviewStateMachine.h/m` - State machine implementation
- `MSIDInteractiveWebviewState.h/m` - State model
- `MSIDInteractiveWebviewHandler.h` - Handler protocol
- `MSIDWebviewControllerAction.h` - Controller action protocol
- `MSIDAcquireBRTOnceControllerAction.h/m` - BRT acquisition
- `MSIDRetryInBrokerControllerAction.h/m` - Broker retry
- `MSIDWebviewAction.h/m` - View action model
- `MSIDSpecialURLViewActionResolver.h/m` - URL-to-action resolver
- `END_TO_END_WIRING.md` - Production wiring guide
