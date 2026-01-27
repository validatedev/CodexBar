---
summary: "Antigravity provider notes: OAuth credentials, local LSP probing, port discovery, quota parsing, and UI mapping."
read_when:
  - Adding or modifying the Antigravity provider
  - Debugging Antigravity port detection or quota parsing
  - Adjusting Antigravity menu labels or model mapping
  - Working with Antigravity OAuth credentials
---

# Antigravity provider

Antigravity supports both OAuth-authorized API access and local language server probing.

## Usage source modes

- **Auto** (default): Try authorized credentials first, fallback to local server
- **Authorized**: Use OAuth credentials to fetch quota from Cloud Code API
- **Local**: Use local Antigravity language server only

## Credential acquisition

### Fallback order (Auto mode)

1. **Keychain OAuth credentials** - Previously saved credentials from OAuth flow or import
2. **Manual token** - Token pasted in settings (refresh token or access token)
3. **Local DB import** - Import from `state.vscdb` (Antigravity app's local storage)
4. **Local server** - Direct probe to running Antigravity language server

### OAuth browser flow

Opens Google OAuth in browser with local callback server (port 11451+). Returns refresh token for long-term storage.

### Local DB import (`state.vscdb`)

Path: `~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb`

- **Refresh token**: `jetskiStateSync.agentManagerInitState` (protobuf field 6)
- **Access token + email**: `antigravityAuthStatus` JSON (`apiKey`, `email` fields)

### Manual token import

Accepts:
- Raw access token (`ya29.xxx`)
- Raw refresh token (`1//xxx`)
- JSON payload: `{"apiKey": "...", "email": "...", "refreshToken": "..."}`

### Cloud Code API endpoints

- Primary: `https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels`
- Fallback: `https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels`

## Local server data sources + fallback order

1) **Process detection**
   - Command: `ps -ax -o pid=,command=`.
   - Match process name: `language_server_macos` plus Antigravity markers:
     - `--app_data_dir antigravity` OR path contains `/antigravity/`.
   - Extract CLI flags:
     - `--csrf_token <token>` (required).
     - `--extension_server_port <port>` (HTTP fallback).

2) **Port discovery**
   - Command: `lsof -nP -iTCP -sTCP:LISTEN -p <pid>`.
   - All listening ports are probed.

3) **Connect port probe (HTTPS)**
   - `POST https://127.0.0.1:<port>/exa.language_server_pb.LanguageServerService/GetUnleashData`
   - Headers:
     - `X-Codeium-Csrf-Token: <token>`
     - `Connect-Protocol-Version: 1`
   - First 200 OK response selects the connect port.

4) **Quota fetch**
   - Primary:
     - `POST https://127.0.0.1:<connectPort>/exa.language_server_pb.LanguageServerService/GetUserStatus`
   - Fallback:
     - `POST https://127.0.0.1:<connectPort>/exa.language_server_pb.LanguageServerService/GetCommandModelConfigs`
   - If HTTPS fails, retry over HTTP on `extension_server_port`.

## Request body (summary)
- Minimal metadata payload:
  - `ideName: antigravity`
  - `extensionName: antigravity`
  - `locale: en`
  - `ideVersion: unknown`

## Parsing and model mapping
- Source fields:
  - `userStatus.cascadeModelConfigData.clientModelConfigs[].quotaInfo.remainingFraction`
  - `userStatus.cascadeModelConfigData.clientModelConfigs[].quotaInfo.resetTime`
- Mapping priority:
  1) Claude (label contains `claude` but not `thinking`)
  2) Gemini Pro Low (label contains `pro` + `low`)
  3) Gemini Flash (label contains `gemini` + `flash`)
  4) Fallback: lowest remaining percent
- `resetTime` parsing:
  - ISO-8601 preferred; numeric epoch seconds as fallback.
- Identity:
  - `accountEmail` and `planName` only from `GetUserStatus`.

## UI mapping
- Provider metadata:
  - Display: `Antigravity`
  - Labels: `Claude` (primary), `Gemini Pro` (secondary), `Gemini Flash` (tertiary)
- Status badge: Google Workspace incidents for the Gemini product.

## Constraints
- Internal protocol; fields may change.
- Requires `lsof` for port detection.
- Local HTTPS uses a self-signed cert; the probe allows insecure TLS.

## Key files

### OAuth/Credentials
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuth/AntigravityOAuthCredentials.swift`
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuth/AntigravityTokenRefresher.swift`
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuth/AntigravityLocalImporter.swift`
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuth/AntigravityCloudCodeClient.swift`
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuth/AntigravityOAuthFlow.swift`
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuth/AntigravityAuthorizedFetchStrategy.swift`
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuth/AntigravityUsageSource.swift`

### Local Server
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityStatusProbe.swift`
- `Sources/CodexBarCore/Providers/Antigravity/AntigravityProviderDescriptor.swift`

### App Integration
- `Sources/CodexBar/Providers/Antigravity/AntigravityProviderImplementation.swift`
- `Sources/CodexBar/Providers/Antigravity/AntigravitySettingsStore.swift`

### Tests
- `Tests/CodexBarTests/AntigravityOAuthTests.swift`
- `Tests/CodexBarTests/AntigravityStatusProbeTests.swift`
