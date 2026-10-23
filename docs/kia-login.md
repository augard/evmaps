---
summary: Kia EU OneApp authentication, protocol references, and verification.
read_when:
  - Debugging Kia login or updating Kia authentication endpoints and signing.
---

# Kia EU login

Kia blocks the legacy CCSP OAuth client (`fdc85c00-…`). On 2026-10-23,
a public authorization request followed redirects to `/error` with an
"abusing request" page. The OneApp client reached `/web/v1/user/authorize`.
This affects both the previous Web Login URL and password login.

`KiaOneAppAuthentication` uses the current EU flow:

1. Authorize the OneApp client `01b36c86-79e8-486c-8009-15f2ad88d670`.
2. For password login, fetch the RSA certificate and encrypt with PKCS#1 v1.5.
3. Receive the code at `https://oneapp.kia.com/redirect`, validating OAuth state.
   OneApp does not return the legacy `login_success=y` parameter.
4. Exchange the code at `https://cci-api-eu.kia.com/auth/v1/token`.
5. Exchange OneApp tokens at `/auth/v1/token-exchange?serviceType=CCS`.
   Store the resulting vehicle token without a `Bearer` prefix; existing API
   headers add that prefix.

The CCI POSTs require `X-Timestamp` and an HMAC-SHA256 `X-Fingerprint` bound
to the OneApp 1.4.0 Android client identity. These public app constants can
rotate with Kia releases. The login does not depend on legacy push device
registration. Hyundai and Genesis retain their existing authentication paths.

Protocol references:
[KiaUvoApiEU.py](https://github.com/Hyundai-Kia-Connect/hyundai_kia_connect_api/blob/master/hyundai_kia_connect_api/KiaUvoApiEU.py),
[cci_fingerprint.py](https://github.com/Hyundai-Kia-Connect/hyundai_kia_connect_api/blob/master/hyundai_kia_connect_api/cci_fingerprint.py),
[PyPI package](https://pypi.org/project/hyundai-kia-connect-api/).

## Verification

Run the `KiaMaps` scheme's tests on an available iOS simulator. The
`KiaOneAppAuthenticationTests` suite covers the on-wire password/code flows,
form encoding, callback validation, a reference HMAC vector, token conversion,
and error handling. `ApiRequestTests` verifies shared form and status handling.

Set `KIAMAPS_LIVE_AUTH_CHECK=1` in the test runner environment to enable
`testLiveKiaLoginBootstrap`. It loads the real public login page and RSA key
without sending account credentials. Normal tests use local HTTP fixtures.

For UI verification, open Web Login and check that the Kia account form loads.
Account sign-in and vehicle access require a real Kia account. Credentials,
callback codes, response bodies, and token headers are never logged by the
new authentication client. OneApp sessions have a distinct stored source so
their refresh tokens never reach the legacy OAuth endpoint. Automatic recovery
reauthenticates using saved email/password; Web Login requires signing in again
after expiry because it does not save those credentials. Full CCI token-set
refresh is not implemented.

Web Login is the default. The Sign-in options menu also provides email/password
login and the existing authorization-bundle importer. Imported sessions retain
their externally managed refresh behavior.
