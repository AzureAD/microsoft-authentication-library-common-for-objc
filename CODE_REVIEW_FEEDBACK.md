# Code Review Feedback: ameyapat/add-get-device-token-api vs dev

**Branch:** `ameyapat/add-get-device-token-api`
**Reviewed against:** `dev`
**Date:** 2026-04-26

---

## Summary

This PR adds a new device token grant request flow (`MSIDDeviceTokenGrantRequest`) and its associated response handler (`MSIDDeviceTokenResponseHandler`), along with a new `MSID_OAUTH2_DEVICE_TOKEN` constant. The implementation creates a JWT-bearer grant request that retrieves a server nonce, builds a signed JWT payload, and handles the token response without caching (device tokens are not tied to user accounts).

**Files changed:** 8 (2 modified, 4 new, 2 constants files)

---

## Findings

### Warning: Strong `self` capture in completion blocks — potential retain cycle (FIXED)
**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.m` (lines ~141, ~194)
**Issue:** Both `executeRequestWithCompletion:` and `tokenRequestWithCompletionBlock:` capture `self` strongly in completion blocks passed to `executeRequestWithCompletion:` (nonce request) and `sendWithBlock:` (token request). The codebase convention (seen in `MSIDSSORemoteSilentTokenRequest`, `MSIDInteractiveAuthorizationCodeRequest`, etc.) is to use `__weak typeof(self) weakSelf = self;` / `__strong typeof(weakSelf) strongSelf = weakSelf;`.
**Impact:** If the block is retained by the nonce request or network layer while also retaining `self`, this creates a retain cycle, preventing deallocation.
**Recommendation:** Use the weakSelf/strongSelf pattern.
**Status:** ✅ Fixed in this review PR.

---

### Warning: Missing nil check after `tokenResponseFromJSON:` deserialization (FIXED)
**File:** `IdentityCore/src/requests/MSIDDeviceTokenResponseHandler.m` (lines ~60-70)
**Issue:** After calling `[self.oauthFactory tokenResponseFromJSON:context:error:]`, the result `serializedTokenResponse` is never checked for nil before being passed to `validateAndSaveTokenResponse:`. If deserialization fails, a nil response is passed downstream, which could cause unexpected behavior or crashes.
**Impact:** A malformed server response would not be gracefully handled — instead of returning a clear error, it would propagate nil through the validation pipeline.
**Recommendation:** Add a nil check and early return with the error.
**Status:** ✅ Fixed in this review PR.

---

### Warning: Unused import of `MSIDThumbprintCalculatable.h` (FIXED)
**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.h` (line 26)
**Issue:** `MSIDThumbprintCalculatable.h` is imported but the class does not conform to the protocol and does not implement any thumbprint methods (`fullRequestThumbprint`, `strictRequestThumbprint`).
**Impact:** Dead import adds unnecessary coupling and confusion. Other grant requests that import this protocol (e.g., `MSIDRefreshTokenGrantRequest`) actually implement the protocol methods.
**Recommendation:** Remove the import unless thumbprint support is planned as a follow-up.
**Status:** ✅ Fixed in this review PR.

---

### Suggestion: Missing unit tests for new classes
**File:** `IdentityCore/tests/` (no new test files)
**Issue:** No unit tests were added for `MSIDDeviceTokenGrantRequest` or `MSIDDeviceTokenResponseHandler`. The review checklist requires new/changed behavior to have corresponding tests in `IdentityCore/tests/`.
**Impact:** Regressions cannot be caught automatically. Key behaviors to test include:
- Init validation (nil registration info, blank clientId, blank resource, blank redirectUri, empty scopes, "aza" scope rejection)
- Nonce retrieval failure handling
- JWT signing failure handling
- Response deserialization error handling
- Successful end-to-end flow with mocked network
**Recommendation:** Add test classes `MSIDDeviceTokenGrantRequestTests.m` and `MSIDDeviceTokenResponseHandlerTests.m`.

---

### Suggestion: Inconsistent coding style — mixed dot notation and `setObject:forKey:`
**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.m` (lines ~226-241)
**Issue:** The `getTokenRedemptionJwtForResource:` method mixes bracket-based `[jwtPayload setObject:... forKey:...]` with subscript-style `jwtPayload[@"aud"] = ...`. The code style guidelines recommend dot notation for properties and consistent literal/subscript syntax.
**Impact:** Readability — inconsistent style makes the code harder to scan.
**Recommendation:** Use subscript syntax consistently: `jwtPayload[MSID_OAUTH2_SCOPE] = scopeString;` instead of `[jwtPayload setObject:scopeString forKey:MSID_OAUTH2_SCOPE];`.

---

### Suggestion: `tokenResponseHandler` property type mismatch between header and class extension
**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.m` (line 53) vs `.h` init parameter
**Issue:** The private property `tokenResponseHandler` is declared as `MSIDTokenResponseHandler *` (parent type) in the class extension, but the init method accepts `MSIDDeviceTokenResponseHandler *` (subclass type). In `tokenRequestWithCompletionBlock:`, the property is cast back with `(MSIDDeviceTokenResponseHandler *)self.tokenResponseHandler`.
**Impact:** The explicit downcast is a code smell. If the property type matched the init parameter type, the cast would be unnecessary.
**Recommendation:** Declare the private property as `MSIDDeviceTokenResponseHandler *tokenResponseHandler` in the class extension.

---

### Suggestion: Constant alignment in `MSIDOAuth2Constants.m` (FIXED)
**File:** `IdentityCore/src/MSIDOAuth2Constants.m` (line 47)
**Issue:** `MSID_OAUTH2_DEVICE_TOKEN` had misaligned `=` compared to surrounding constants.
**Impact:** Minor readability issue — breaks the visual alignment pattern.
**Status:** ✅ Fixed in this review PR.

---

### Suggestion: Blank line removed before `#pragma mark - Internal` (FIXED)
**File:** `IdentityCore/src/cache/accessor/MSIDDefaultTokenCacheAccessor.m` (line 992)
**Issue:** A blank line before `#pragma mark - Internal` was removed. The code style guideline says "One blank line between methods" and pragma marks conventionally have a blank line before them for readability.
**Impact:** Minor readability issue.
**Status:** ✅ Fixed in this review PR.

---

## Issue Counts

| Severity   | Count | Auto-fixed |
|------------|-------|------------|
| Warning    | 3     | 3          |
| Suggestion | 4     | 2          |
| **Total**  | **7** | **5**      |
