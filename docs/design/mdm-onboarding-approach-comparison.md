# Mobile Onboarding: Orchestration Approach Comparison

## Status

Draft / Design exploration

## Approach 1 — Delegate + Navigation-Action orchestration (your mob_on3)

**Key idea:** Keep orchestration at the embedded `WKWebView` boundary. Intercept mid-flight instruction URLs in navigation delegates, perform required work (including BRT guard), and resume in the same webview session. Let the terminal completion callback propagate to normal response parsing.

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
          │ Extract instruction params from URL query
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ BRT guard: once per redirect instruction                                    │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Build nextRequest + load in SAME WKWebView                                 │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ NavResponse(headers): telemetry + header-driven ASWebAuth handoff          │
│ ASWebAuth callback → webView.load(callbackRequest) on same WKWebView       │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Approach 2 — Response-object orchestration (factory-driven)

**Key idea:** Route terminal callback outcomes through response parsing + factory-generated response objects and optional operations. This is naturally suited for completion semantics.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Embedded WKWebView                                                          │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ Navigation reaches terminal completion callback
                ▼
     msauth://in_app_enrollement_complete   (Allow; do NOT cancel)
                │
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Response parsing / factory                                                  │
│ - classify URL as EnrollmentComplete                                        │
│ - create EnrollmentCompleteResponse object                                  │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Operation (optional)                                                        │
│ - map response to uniform completion result                                 │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Caller receives a uniform terminal outcome                                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Comparison

| Dimension | Approach 1: Delegate / Navigation-Time | Approach 2: Response-Object / Factory |
|---|---|---|
| Fit for `msauth://enroll` / `msauth://compliance` | **Excellent** (cancel/replace navigation) | Weaker (completion semantics for mid-flight events) |
| Handling `msauth://in_app_enrollement_complete` | **Allow to propagate to response** | **Natural fit** |
| Resume same `WKWebView` requirement | **Native** | Possible but requires more plumbing/state |
| Header-driven ASWebAuth trigger | **Excellent** | Requires explicit header propagation |
| Complexity | Lower (single decision boundary for mid-flight) | Higher if used for mid-flight + headers |
| Risk of incorrect timing | Low | Higher |
| Recommended use | **Primary for mid-flight + headers** | **Terminal outcomes** |
