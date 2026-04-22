# Mobile Onboarding: Orchestration Approach Comparison (Delegate vs Response-Object)

## Status

Draft / Design exploration

## Summary (Recommendation)

For **Mobile Onboarding** in an embedded `WKWebView` flow that must:

- intercept **special redirect URLs** for **mid-flight instructions** (e.g., `msauth://enroll`, `msauth://compliance`),
- perform **BRT acquisition once per redirect instruction** before continuing,
- analyze **HTTP response headers** for telemetry and to trigger a **header-driven ASWebAuthenticationSession (ASWebAuth) handoff**, and
- **resume the same embedded WKWebView session** after the handoff,

the recommended orchestration is:

> **Approach A: Delegate + navigation-time orchestration** as the primary architecture.

At the same time, for **terminal/semantic outcomes** that should be handled uniformly by the normal response parsing pipeline, the recommended approach is:

> **Allow `msauth://in_app_enrollement_complete` to propagate to a response object** (do not intercept it for immediate termination or onboarding work).

---

## Problem Statement

Mobile Onboarding introduces **mid-flight** instructions during an interactive, web-based authentication session hosted in an embedded `WKWebView`. During this interactive session, the client must:

1. Detect and handle **mid-flight instruction redirect URLs**:
   - `msauth://enroll`
   - `msauth://compliance`

2. Handle **terminal completion callback URL** (uniform outcome handling):
   - `msauth://in_app_enrollement_complete` (exact spelling)

3. Perform **BRT (broker refresh token) acquisition** **once per redirect instruction** before continuing the web flow (applies to `enroll`/`compliance`).

4. Parse and record **telemetry** from **HTTP response headers**.

5. If response headers indicate an **ASWebAuth handoff**, launch `ASWebAuthenticationSession` and, upon completion, **resume the same embedded `WKWebView` session** by loading the returned callback URL (callback scheme may be anything: custom scheme, https, etc.).

The key design question is where to place orchestration:

- at the webview boundary (navigation-time delegates), or
- in completion-time “response object + operation” pipelines.

---

## Candidate Approaches

### Approach A — Delegate + Navigation-Time Orchestration (Recommended)

**Core idea:** The embedded webview boundary (navigation delegates) is the single decision point for:

- mid-flight instruction URLs (`msauth://enroll`, `msauth://compliance`),
- response header telemetry,
- header-driven ASWebAuth handoff,
- resumption into the same `WKWebView` session.

**Terminal outcomes** like `msauth://in_app_enrollement_complete` are intentionally left to propagate into response parsing (uniform outcome handling).

---

## Diagrams (Updated)

### Legend

- **NavAction** = `WKNavigationDelegate decidePolicyForNavigationAction`
- **NavResponse** = `WKNavigationDelegate decidePolicyForNavigationResponse`
- **Cancel** = `decisionHandler(WKNavigationActionPolicyCancel)`
- **Allow** = `decisionHandler(WKNavigationActionPolicyAllow)`
- **Same WKWebView** = do not tear down the embedded webview; resume by `webView.load(...)`

---

### A1. NavAction URL Handling (Enroll/Compliance intercepted; Completion propagates)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController (owns WKWebView instance)                         │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavAction(request.URL)
                ▼
       ┌───────────────────────────┐
       │ Classify redirect URL     │
       └───────────────────────────┘
          │              │                          │
          │              │                          │
          ▼              ▼                          ▼
   msauth://enroll   msauth://compliance   msauth://in_app_enrollement_complete
          │              │                          │
          ├───────┬──────┘                          │ Allow (propagate)
          │ Cancel │                                 ▼
          ▼        ▼                      ┌─────────────────────────────────────┐
┌───────────────────────────┐            │ Normal completion / response parsing │
│ OnboardingOrchestrator    │            │ (uniform outcome handling)           │
│ (delegate/controller)     │            └─────────────────────────────────────┘
└───────────────────────────┘
          │
          │ Extract instruction parameters from URL query
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ BRT Guard: "once per redirect instruction"                                   │
│ - if already acquired for this instruction: skip                             │
│ - else: acquire BRT (and cache for this instruction)                         │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Build nextRequest                                                            │
│ - compute final URL from query params                                        │
│ - add required query params                                                  │
│ - add required headers (including anything derived from BRT)                 │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Resume SAME embedded WKWebView session                                       │
│ - webView.load(nextRequest)                                                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### A2. NavResponse Header Handling (Telemetry + header-driven ASWebAuth; resume same WKWebView)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController (same WKWebView instance throughout)               │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavResponse(response.headers)
                ▼
       ┌───────────────────────────┐
       │ Telemetry extraction      │
       │ (read/record headers)     │
       └───────────────────────────┘
                │
                ▼
       ┌───────────────────────────┐
       │ Detect ASWebAuth handoff? │  (strictly header-driven)
       └───────────────────────────┘
          │                 │
          │ No              │ Yes
          ▼                 ▼
        Allow        ┌──────────────────────────────────────────┐
                     │ Suspend embedded flow (do NOT destroy    │
                     │ WKWebView; pause UI/navigation as needed)│
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Launch ASWebAuthenticationSession        │
                     │ - startURL derived from headers          │
                     │ - callbackURL scheme can be anything     │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ ASWebAuth completes → callbackURL        │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Resume SAME embedded WKWebView session   │
                     │ - webView.load(callbackURL request)      │
                     │ - continue normal embedded navigation    │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                                    Allow
```

---

### Approach B — Response-Object / Factory-Driven Orchestration (Comparison)

**Core idea:** Route events into a factory that creates typed response objects; the local controller and operations then perform BRT acquisition, URL construction, and ASWebAuth launching.

This is appropriate for **terminal outcomes** like `msauth://in_app_enrollement_complete`, but it is not recommended as the primary mechanism for:

- mid-flight instruction URLs (`msauth://enroll` / `msauth://compliance`), or
- header-driven triggers (headers are only available in NavResponse and must be acted on at the boundary).

### B1. Response-object classification and factory creation

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController receives events (NavAction/NavResponse/callback)   │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
       ┌──────────────────────────────┐
       │ EventClassifier               │
       │ - URL (scheme/host/path)      │
       │ - response headers (if any)    │
       └──────────────────────────────┘
          │                    │                    │
          ▼                    ▼                    ▼
  Enroll/Compliance      In-app completion     Header handoff signal
(msauth://enroll or      (msauth://in_app_     (switch-browser style)
 msauth://compliance)     enrollement_complete)
          │                    │                    │
          └────────────┬───────┴────────────┬──────┘
                       ▼                    ▼
              ┌─────────────────────────────────────┐
              │ MSIDWebResponseFactory               │
              │ creates typed response object        │
              │ - OnboardingInstructionResponse      │
              │ - CompletionResponse                 │
              │ - SwitchBrowserResponse              │
              └─────────────────────────────────────┘
                       │
                       ▼
              ┌─────────────────────────────────────┐
              │ ResponseOperationDispatcher          │
              │ picks operation by response type     │
              └─────────────────────────────────────┘
```

### B2. Operation execution and return to embedded WKWebView

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ ResponseOperationDispatcher                                                   │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ├── OnboardingInstructionResponse
          │      │
          │      ▼
          │  Cancel current nav → BRT guard (once per instruction)
          │  → build nextRequest (query + headers) → webView.load(nextRequest)
          │
          ├── SwitchBrowserResponse (header-driven)
          │      │
          │      ▼
          │  launch ASWebAuthenticationSession(startURL)
          │  → callbackURL received
          │  → webView.load(callbackURL request)   (return to SAME WKWebView)
          │
          └── CompletionResponse
                 │
                 ▼
             parse terminal result
             (`msauth://in_app_enrollement_complete`)
```

---

## Comparison Table

| Dimension | Approach A: Delegate / Navigation-Time | Approach B: Response-Object / Factory |
|---|---|---|
| Fit for `msauth://enroll` / `msauth://compliance` | **Excellent** (cancel/replace navigation) | Weaker (completion semantics for mid-flight events) |
| Handling `msauth://in_app_enrollement_complete` | **Allow to propagate to response** | **Natural fit** |
| Resume same `WKWebView` requirement | **Native** | Possible but requires more plumbing/state |
| Header-driven ASWebAuth trigger | **Excellent** | Requires explicit header propagation |
| Complexity | Lower (single decision boundary for mid-flight) | Higher if used for mid-flight + headers |
| Risk of incorrect timing | Low | Higher |
| Recommended use | **Primary for mid-flight + headers** | **Terminal outcomes** |

---

## Final Recommendation & Boundary Rules

### Canonical path (Approach A) MUST own:

- `msauth://enroll` (intercept at NavAction; Cancel → BRT guard → build nextRequest → load)
- `msauth://compliance` (intercept at NavAction; Cancel → BRT guard → build nextRequest → load)
- response header telemetry (NavResponse)
- header-driven ASWebAuth handoff trigger/orchestration (NavResponse + ASWebAuth launch)
- resuming the same embedded `WKWebView` session after ASWebAuth by loading the callback URL

### Response-object outcomes MUST include:

- `msauth://in_app_enrollement_complete` (terminal completion callback; allow to propagate and parse as a response object)

### Avoid dual-path complexity

1. **All mid-flight instruction redirects are handled at navigation-time.**
   Do not route `enroll`/`compliance` into completion-time response pipelines.

2. **Terminal completion callback propagates.**
   `msauth://in_app_enrollement_complete` is treated as a terminal outcome and handled uniformly via response parsing.

3. **ASWebAuth trigger stays at webview boundary.**
   Even if ASWebAuth launching can be encapsulated, the decision (based on headers) belongs in NavResponse.

4. **Make BRT gating explicit.**
   Implement a straightforward “once per redirect instruction” guard.

---

## References

- PKeyAuth navigation-time interception pattern (cancel navigation → handler → load request).
- Switch-browser response-object/operation pattern.
- Related context PR (common-for-objc): https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/pull/1782
