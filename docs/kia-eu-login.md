---
read_when:
  - Diagnosing Kia EU sign-in failures or changing web login navigation
---

# Kia EU web login

The configured legacy Kia EU authorization URL was checked on October 11, 2026.
After redirects it returned HTTP 200 containing an error page with the description
"classified as an abusing request and blocked." HTTP status alone does not identify
this failure: the identity provider redirects to `/error?status=400`.

Web login now surfaces that rejection, HTTP errors, WebKit navigation failures,
and a terminated web process. Login callbacks without a code or successful result
also produce a visible failure. Callbacks must match the configured API scheme,
host, port, and redirect path before their authorization code is accepted.

SwiftUI updates preserve the coordinator and do not restart the initial request
after an OAuth redirect. URL construction failures are reported rather than
discarded with `try?`.

This change improves diagnostics; it does not restore access to the blocked
legacy authorization flow. The authentication and refresh implementation remains
available only for existing legacy sessions. A replacement requires a
Kia-authorized client and documented access to the appropriate authentication
service. The private OneApp client identity used by upstream workarounds is not
copied here.

## Authorized token import

Kia login now opens an authorization-bundle importer by default. It accepts JSON
issued by an approved Kia integration or a local broker. The token must be
valid for this app's configured EU vehicle API; importing a token does not
translate between Kia API generations:

```json
{
  "accessToken": "token from the approved provider",
  "expiresIn": 3600,
  "refreshToken": "optional provider refresh token",
  "deviceId": "optional UUID",
  "isCcuCCS2Supported": true
}
```

The importer removes an optional `Bearer` prefix, validates the token and expiry,
marks the session as externally managed, clears stored Kia passwords, and hands
the authorization to the existing Keychain storage. Externally managed sessions
never send their refresh token to the legacy Kia refresh endpoint. When such a
session expires, the app returns to login for a replacement bundle.

Older Keychain records decode as legacy sessions. Stored credentials no longer
skip the login screen when no authorization exists, preventing an automatic call
to the blocked login flow.

References checked October 11, 2026:

- [Python API EU authentication change, v4.26.3](https://github.com/Hyundai-Kia-Connect/hyundai_kia_connect_api/releases/tag/v4.26.3)
- [Current Python API release, v4.35.1](https://github.com/Hyundai-Kia-Connect/hyundai_kia_connect_api/releases/tag/v4.35.1)
- [Home Assistant integration, v3.17.0](https://github.com/Hyundai-Kia-Connect/kia_uvo/releases/tag/v3.17.0)

Offline regressions: `KiaTests/AuthorizationImportTests.swift` and
`KiaTests/WebLoginNavigationTests.swift`. These exercise bundle validation,
backward-compatible authorization decoding, the blocked redirect, callback
validation, repeated view updates, and navigation failures without signing in
or issuing vehicle requests.

## Verification

On October 11, 2026, `xcodebuild build-for-testing` succeeded for the generic iOS
Simulator destination, compiling the app and tests for arm64 and x86_64. An
existing date-formatter test needed a `throws` annotation for `XCTUnwrap` to allow
the test target to compile.

The focused authorization-import and web-navigation suites passed 14 of 14 tests
on an iPhone 18 Pro simulator running iOS 27.0. The first execution exposed a
bare `Bearer` normalization bug; the parser was corrected and the repeated run
passed. A subsequent full-suite attempt stalled before XCTest launched and was
stopped after three minutes. No account login or vehicle communication was
tested.
