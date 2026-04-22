# MDM Onboarding Approach Comparison

## Summary

This document finalizes URL-handling boundaries for in-app MDM onboarding in embedded webview flows and compares two onboarding integration approaches.

The enrollment completion callback URL is:

`msauth://in_app_enrollement_complete`

This callback is **not** intercepted for onboarding work at navigation-time. It must be allowed to propagate to normal response-object parsing so success/failure/cancel outcomes are handled uniformly with existing web response handling.

## Requirements

1. Use `msauth://in_app_enrollement_complete` as the completion callback URL.
2. Intercept `msauth://enroll` and `msauth://compliance` in `WKNavigationAction`.
3. For intercepted onboarding redirects, perform:
   - `Cancel`
   - BRT guard (**once per redirect instruction**)
   - build `nextRequest`
   - load `nextRequest` in the **same** `WKWebView`
4. Do **not** intercept `msauth://in_app_enrollement_complete` for onboarding operations during navigation handling.
5. Keep telemetry/header-based response handling and ASWebAuthenticationSession handoff logic in `WKNavigationResponse`.
6. On ASWebAuthenticationSession completion, resume into the **same** embedded `WKWebView` by loading the callback URL request.

## Existing Pattern Analysis

### PKeyAuth

PKeyAuth is an example of scoped interception where specialized handling occurs only for designated challenge patterns and then control returns to normal auth response parsing. This pattern supports a bounded special-case path while preserving shared completion semantics.

### Switch-browser

Switch-browser handling similarly demonstrates boundary discipline:
- redirect instruction is recognized in navigation
- specialized orchestration executes
- completion returns to standard parsing/response handling paths

The onboarding design should follow this model: only onboarding-instruction redirects are intercepted, while final completion callback handling remains in shared response parsing.

## Approach Comparison

| Area | Approach A: NavAction orchestration for onboarding redirects + propagate completion | Approach B: Intercept completion callback for onboarding finalization |
|---|---|---|
| `msauth://enroll` / `msauth://compliance` | Intercepted in NavAction and orchestrated | Intercepted in NavAction and orchestrated |
| `msauth://in_app_enrollement_complete` | Allowed to propagate to response-object parsing | Intercepted in NavAction |
| Outcome handling | Uniform through existing response-object pipeline | Split logic between onboarding interceptor and response parsing |
| Error/cancel/success consistency | High (single completion path) | Lower (dual completion paths) |
| Extensibility and maintenance | Better bounded responsibilities | Higher coupling and regression risk |

**Decision:** Approach A.

## A1. Navigation-Action URL Handling

`msauth://enroll` and `msauth://compliance` are intercepted at navigation-time.
`msauth://in_app_enrollement_complete` is allowed to propagate to response-object parsing.

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
│ BRT Guard: "once per redirect instruction"                                  │
│ - if already acquired for this instruction: skip                            │
│ - else: acquire BRT (and cache for this instruction)                        │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Build nextRequest                                                           │
│ - compute final URL from query params                                       │
│ - add required query params                                                 │
│ - add required headers (including anything derived from BRT)                │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Resume SAME embedded WKWebView session                                      │
│ - webView.load(nextRequest)                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

## A2. Navigation-Response Header Telemetry + Header-driven ASWebAuth Handoff

Navigation-response logic remains responsible for telemetry extraction and header-driven external handoff behavior.
When ASWebAuthenticationSession returns, the callback URL is loaded into the same embedded webview to continue flow coherently.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController (same WKWebView instance throughout)              │
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

## Boundary Rules

- `WKNavigationAction` interception is only for onboarding instruction redirects:
  - `msauth://enroll`
  - `msauth://compliance`
- For these intercepted redirects: Cancel → BRT guard (once per redirect instruction) → build `nextRequest` → load in same `WKWebView`.
- `msauth://in_app_enrollement_complete` is not intercepted for onboarding work at navigation-time.
- `msauth://in_app_enrollement_complete` must propagate to response-object parsing for uniform outcome handling.
- `WKNavigationResponse` remains the place for telemetry extraction and header-driven ASWebAuthenticationSession handoff decisions.

## References

- Embedded webview navigation-action policy handling in `MSIDOAuth2EmbeddedWebviewController`
- Web response parsing and completion model in `MSIDWebResponse`/`MSIDWebResponseBaseOperation`
- Existing bounded interception patterns: PKeyAuth and switch-browser response handling
