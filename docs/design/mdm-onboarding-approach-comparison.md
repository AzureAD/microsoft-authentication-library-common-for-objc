# Mobile Onboarding: Orchestration Approach Comparison (Delegate vs Response-Object)

## Status

Draft / Design exploration

## Summary (Recommendation)

For Mobile Onboarding in an embedded `WKWebView`, use:

- **Approach A (primary):** navigation-time orchestration for mid-flight redirects and header-driven behavior.
- **Approach B (limited):** response-object parsing for terminal semantic outcomes.

Canonical callback URL used in this design:

- `msauth://in_app_enrollement_complete` (exact spelling)

Handling decision:

- `msauth://enroll` and `msauth://compliance` are intercepted at navigation-time:
  - Cancel -> BRT guard once per redirect instruction -> build `nextRequest` -> load in same `WKWebView`
- `msauth://in_app_enrollement_complete` is **not** intercepted for onboarding work; it is allowed to propagate and parsed into a response object.

## Problem Statement

During an interactive embedded `WKWebView` session, Mobile Onboarding must:

1. Handle mid-flight redirect instructions:
   - `msauth://enroll`
   - `msauth://compliance`
2. Handle terminal callback URL:
   - `msauth://in_app_enrollement_complete`
3. Acquire BRT once per redirect instruction before continuing the same web session.
4. Parse response headers for telemetry and ASWebAuth trigger instructions.
5. Launch ASWebAuth when headers require it and resume the same `WKWebView` by loading returned callback URL.

## Legend

- **NavAction** = `WKNavigationDelegate decidePolicyForNavigationAction`
- **NavResponse** = `WKNavigationDelegate decidePolicyForNavigationResponse`
- **Cancel** = `decisionHandler(WKNavigationActionPolicyCancel)`
- **Allow** = `decisionHandler(WKNavigationActionPolicyAllow)`

## Approach A — Delegate + Navigation-Time Orchestration (Recommended)

Approach A owns all mid-flight instruction handling and header-time orchestration.

### A1. NavAction URL Handling (Enroll/Compliance intercepted; Completion propagates)

```text
WKWebView -> NavAction(url)
                |
                +--> url == msauth://enroll OR msauth://compliance ?
                |         |
                |         +--> Cancel navigation
                |         +--> BRT guard (once per redirect instruction)
                |         +--> Build nextRequest from redirect params
                |         +--> webView.load(nextRequest)   // same WKWebView
                |
                +--> url == msauth://in_app_enrollement_complete ?
                |         |
                |         +--> Allow navigation (no onboarding interception)
                |         +--> Continue to response-object parsing path
                |
                +--> otherwise Allow
```

### A2. NavResponse Header Handling (Telemetry + header-driven ASWebAuth; resume same WKWebView)

```text
WKWebView -> NavResponse(headers)
                |
                +--> Parse/record telemetry headers
                |
                +--> Headers require ASWebAuth handoff?
                          |
                          +--> Yes:
                          |      - Cancel webview navigation if needed
                          |      - Create ASWebAuth operation from headers
                          |      - Start ASWebAuthenticationSession(startURL, callbackScheme)
                          |      - On callbackURL return: webView.load(callbackURL) // same WKWebView
                          |
                          +--> No: Allow response
```

## Approach B — Response-Object / Factory-Driven Orchestration (Comparison)

Approach B is a natural fit for terminal semantic outcomes, but is awkward as the primary mechanism for mid-flight instruction redirects.

### B1. Terminal completion handled as response object

`msauth://in_app_enrollement_complete` is allowed to propagate and is parsed into a response object for uniform outcome handling.

```text
WKWebView -> NavAction(msauth://in_app_enrollement_complete)
                |
                +--> Allow (no onboarding interception)
                        |
                        v
                Web response factory parses URL
                        |
                        v
                Typed completion response object
                        |
                        v
                Uniform completion handling pipeline
```

### B2. Header-driven ASWebAuth illustrated as response/operation

Headers are observed at NavResponse, converted into a synthesized response, then consumed by an operation that launches ASWebAuth and resumes the same embedded `WKWebView` by loading callback URL.

```text
WKWebView -> NavResponse(headers)
                |
                +--> Evaluate headers for handoff + telemetry
                        |
                        v
                Synthesize response object (handoff intent + startURL + callback metadata)
                        |
                        v
                Operation factory -> ASWebAuth operation
                        |
                        v
                Launch ASWebAuthenticationSession
                        |
                        v
                callbackURL returned
                        |
                        v
                webView.load(callbackURL)   // resume same WKWebView session
```

### B3. Why Approach B is awkward for `msauth://enroll` / `msauth://compliance`

These are mid-flight instructions that still require immediate NavAction intercept/cancel behavior, so Approach B introduces a dual-path model.

```text
Mid-flight instruction URL arrives
        |
        +--> Must intercept in NavAction now (Cancel + BRT guard + nextRequest + load)
        |
        +--> If also modeled in response-object pipeline:
                duplicate classification/state/guard logic
                => dual-path complexity and timing risk
```

## Comparison Table

| Dimension | Approach A: Delegate / Navigation-Time | Approach B: Response-Object / Factory |
|---|---|---|
| Fit for `msauth://enroll` / `msauth://compliance` | **Excellent** | Awkward (still needs NavAction intercept) |
| Fit for `msauth://in_app_enrollement_complete` | Works (allow + parse downstream) | **Natural fit** |
| Header-driven ASWebAuth trigger | **Excellent** (native at NavResponse) | Possible via synthesized response + operation |
| Complexity risk | Lower | Higher if used as primary path |

## Final Boundary Rules

1. `msauth://enroll` and `msauth://compliance`:
   - Intercept at NavAction
   - Cancel -> BRT guard once per redirect instruction -> build `nextRequest` -> load same `WKWebView`
2. `msauth://in_app_enrollement_complete`:
   - Do not intercept for onboarding work
   - Allow to propagate and parse via response-object pipeline
3. Header-driven ASWebAuth trigger decision remains at NavResponse boundary.
4. Resume path after ASWebAuth returns loads callback URL in same embedded `WKWebView` session.
