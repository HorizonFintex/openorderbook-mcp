# Architecture

## Overview

The OpenOrderbook MCP system uses a **two-server architecture** to enable AI-assisted trading of fixed-return options (FROs) while keeping private keys secure.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Machine                                 │
│                                                                     │
│  ┌──────────────┐    stdio    ┌──────────────────────────────────┐  │
│  │  VS Code +   │◄──────────►│  Local Signer MCP                │  │
│  │  Copilot     │            │  ┌──────────┐  ┌──────────────┐  │  │
│  │   — or —     │            │  │ Keystore │  │ MSAL Auth    │  │  │
│  │  OpenOrder-  │            │  │ Decrypt  │  │ (B2C tokens) │  │  │
│  │  book AI     │            │  └──────────┘  └──────────────┘  │  │
│  │  (CLI)       │            │  ┌──────────────────────────────┐ │  │
│  │              │            │  │ Transaction Signing          │ │  │
│  │  ┌────────┐  │            │  │ (Feeless: ABIEncodePacked    │ │  │
│  │  │Native  │  │            │  │  + keccak256 + ECDSA)        │ │  │
│  │  │Tools(8)│  │            │  └──────────────────────────────┘ │  │
│  │  │File,Web│  │            └──────────────────────────────────┘  │
│  │  │Profile │  │                                                   │
│  │  └────────┘  │                                                   │
│  └──────┬───────┘                                                   │
│         │                                                           │
└─────────┼───────────────────────────────────────────────────────────┘
          │ HTTPS
          │
┌─────────▼───────────────────────────────────────────────────────────┐
│                     Azure (Remote MCP)                               │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  OpenOrderbook MCP (Azure Functions)                           │  │
│  │  ┌──────────────────┐  ┌────────────────────────────────────┐ │  │
│  │  │ Signature        │  │ Tool Registry (35 tools)           │ │  │
│  │  │ Verification     │  │ • 20 Read (GetMarket, GetOffer..)  │ │  │
│  │  │ (all 11 writes)  │  │ • 11 Write (CreateOffer, Transfer..)│ │  │
│  │  └──────────────────┘  │ • 4 Admin (Settle, Exercise..)     │ │  │
│  │                        └────────────────────────────────────┘ │  │
│  └────────────────────────────┬──────────────────────────────────┘  │
│                               │ HTTPS                                │
│  ┌────────────────────────────▼──────────────────────────────────┐  │
│  │  OpenOrderbook (Blockchain Relay)                              │  │
│  │  • Submits signed transactions to blockchain                   │  │
│  │  • Manages nonce + gas                                         │  │
│  │  • Tracks async tx lifecycle                                   │  │
│  └───────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## Local Signer MCP

The local signer runs as a stdio MCP server process on your machine. It:

- **Decrypts your keystore** at startup (from `FRO_KEYSTORE_PATH` + `FRO_KEYSTORE_PASSWORD`)
- **Signs transactions** using the Feeless signing scheme
- **Acquires bearer tokens** via MSAL client_credentials flow (Azure AD B2C)
- **Generates ecIds** for new offers (timestamp-based unique identifiers)

The signer is a self-contained .NET 8 binary — no runtime installation needed.

### Why Local?

Your private key never leaves your machine. Signing happens locally, and only the resulting signature + callInfo are sent to the remote MCP server. Even if the remote server were compromised, an attacker couldn't sign transactions as you.

## Remote MCP (Azure Functions)

The remote MCP is hosted as Azure Functions and exposed as an HTTP-based MCP endpoint. It:

- **Validates signatures** on all write operations before relaying them
- **Proxies to OpenOrderbook** — the blockchain relay that manages gas, nonces, and transaction submission
- **Exposes 35 tools** — 20 read, 11 write, 4 admin
- **Transfer tools** (TransferDollars, TransferTokens) are synchronous — they return the final result directly without requiring `CheckTxStatus` polling

### Server-Side Signature Verification

Every write tool is wrapped with `WithSignatureValidation()`:

1. Extracts `address`, `callInfo`, and `signature` from the request
2. Reconstructs the signing hash: `keccak256(ABIEncodePacked(eventContractAddress, callInfo))`
3. Adds the Ethereum message prefix: `"\x19Ethereum Signed Message:\n32" + hash`
4. Recovers the signer address from the signature using `EcRecover`
5. Compares the recovered address to the claimed address (case-insensitive)

If verification fails, the request is rejected with a JSON error response:

```json
{
  "error": "SIGNATURE_MISMATCH",
  "message": "Signature verification failed: recovered signer does not match provided address.",
  "recoveredAddress": "0xabc...",
  "providedAddress": "0xdef...",
  "hint": "Ensure the callInfo and signature were produced by the same wallet."
}
```

If the signature bytes are malformed:

```json
{
  "error": "SIGNATURE_INVALID",
  "message": "Signature verification error: Invalid point compression",
  "hint": "Check that callInfo and signature are valid 0x-prefixed hex strings."
}
```

## Feeless Signing Flow

The "Feeless" signing scheme allows users to authorize transactions without paying gas.

### Step-by-step:

1. **Build callInfo** — ABI-encode the smart contract function parameters
2. **Hash** — `keccak256(ABIEncodePacked(eventContractAddress, callInfo))`
3. **Sign** — Ethereum personal sign (adds `\x19Ethereum Signed Message:\n32` prefix, then ECDSA-sign)
4. **Submit** — send `(address, callInfo, signature)` to the remote MCP
5. **Verify** — remote MCP re-derives the hash and recovers the signer via `EcRecover`
6. **Relay** — if valid, the transaction is forwarded to OpenOrderbook → blockchain

The user's wallet never holds ETH or pays gas — the relay submits the transaction on their behalf.

## Authentication

The remote MCP requires bearer token authentication:

1. The local signer acquires an S2S token from Azure AD B2C using client_credentials (MSAL)
2. Each remote MCP tool call includes the token via the `bearerToken` parameter
3. Copilot automatically calls `acquire_bearer_token` before making remote calls

Token flow:
```
Local Signer → Azure AD B2C → access_token → passed to Remote MCP → validates → calls OpenOrderbook
```

If authentication fails with 403, use `acquire_bearer_token(forceRefresh=true)` to flush the MSAL token cache and acquire a fresh token. The server auto-refreshes its OIDC signing key cache on signature validation failures.

## Native Tools (OpenOrderbook AI Client)

The standalone OpenOrderbook AI CLI client adds 8 native tools that run inside the client process (not via MCP). These are unavailable in VS Code + Copilot.

| Category | Tools | Description |
|----------|-------|-------------|
| **File System** | `read_file`, `write_file`, `list_directory` | Local file operations within the workspace |
| **Web Access** | `web_search`, `http_fetch` | DuckDuckGo search and HTTP fetch |
| **Profiles** | `list_profiles`, `switch_profile`, `create_profile` | Multi-user profile switching |

### Profile Switching

Profiles are stored as `config.{Name}.json` in `~/.openorderbook-ai/`. Switching profiles:
1. Saves the current profile's config
2. Loads the target profile (new keystore, wallet, credentials)
3. Reconnects the local signer MCP subprocess with new environment variables
4. Clears the bearer token cache and resets chat history

This enables multi-user operation on shared servers — each user has their own keystore and wallet.

## Binaries

Pre-built self-contained binaries (no .NET runtime required) are included in this repository under the `releases/` directory:

- `releases/osx-arm64/` — Apple Silicon (M1/M2/M3/M4)
- `releases/osx-x64/` — Intel Mac
- `releases/win-x64/` — Windows
- `releases/linux-x64/` — Linux

Each platform directory contains the self-contained executable plus the required contract ABI files (`EventContract.json`, `Feeless.json`) in the `Contracts/Multilisting/Artifacts/` subfolder. The binary and artifacts must remain together.
