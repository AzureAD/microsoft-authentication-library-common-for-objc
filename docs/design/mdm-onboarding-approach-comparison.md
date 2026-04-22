# MDM Onboarding Approach Comparison

## Comparison table

| Dimension | Approach 1: Delegate + Navigation Actions (mob_on3) | Approach 2: Response Objects (factory-driven) |
| --- | --- | --- |
| Primary trigger point | `WKNavigationDelegate` callbacks (`decidePolicyForNavigationAction` / `decidePolicyForNavigationResponse`) drive orchestration immediately. | URL/header parsing creates typed responses, then operations execute orchestration steps. |
| Best fit for `msauth://enroll` / `msauth://compliance` | Best fit. Intercept at navigation-time, cancel, acquire BRT once per redirect instruction, build `nextRequest`, and load in the same `WKWebView`. | Not ideal as the primary path. These URLs still need navigation-time interception/cancel to avoid webview navigation loss. |
| Best fit for “ASWebAuth required based on response headers” | Strong fit because headers are naturally available in navigation-response delegate timing. | Possible via header adapter + synthesized response object, but needs extra plumbing before operation dispatch. |
| BRT acquisition integration | Directly integrated in the navigation interception path with redirect guards. | Can be modeled in operations, but mid-flight URL handling still relies on delegate-time control. |
| Layering / separation of concerns | More controller-centric and imperative, with policy and flow control close to webview delegate code. | Cleaner separation through typed responses and operation objects, with clearer domain modeling. |
| Coupling to UI (ASWebAuth, suspend/resume WKWebView) | Higher coupling to webview/session lifecycle; explicit suspend/resume behavior sits in delegate orchestration. | Lower coupling at parsing/model layer, but orchestration still bridges back to concrete UI lifecycle operations. |
| Determinism / timing | Highly deterministic for mid-flight redirects because interception/cancel happens exactly at nav-time. | Deterministic for terminal outcomes; for mid-flight instructions it can become dual-path (nav-time + response execution). |
| Testability | Good for integration-style delegate flow tests; more setup needed for lifecycle and timing cases. | Good unit-testability for parser/factory/operation boundaries; integration tests still needed for UI timing bridges. |
| Extensibility for new special URLs | Add new delegate checks and action handlers; straightforward but can grow branching in one place. | Add new response types and operations; scales well when new events are mostly terminal or object-model driven. |
| Failure modes | Delegate logic can become dense; mistakes usually show up as wrong allow/cancel timing or missed guard checks. | Risk of split-brain handling when both nav-time interception and response-object execution are needed for one flow. |
| Complexity | Lower for current mobile onboarding requirements, especially mid-flight redirect instructions. | Higher initial complexity due to factory/adapter/operation plumbing and coordination points. |
| “Feels like existing MSID patterns” | Feels consistent with existing embedded webview delegate interception patterns. | Feels consistent with existing MSID response/factory abstractions for terminal outcomes. |

For consistency with current decisions in this design:

- `msauth://in_app_enrollement_complete` is a terminal completion URL and is allowed to propagate to response-object parsing.
- `msauth://enroll` and `msauth://compliance` are intercepted at navigation-time.
