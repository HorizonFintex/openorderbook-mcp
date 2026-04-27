# OpenOrderbook MCP — Copilot Instructions

This workspace contains the OpenOrderbook MCP system for trading fixed-return options (FROs) and three-outcome events (1X2) via VS Code and GitHub Copilot.

## Key Context
- Read `docs/SKILL.md` for the complete trading skill — workflows, parameter formats, validation rules, and error handling
- Read `docs/TOOLS-REFERENCE.md` for the full list of local signer and remote MCP tools
- Read `docs/ARCHITECTURE.md` for the two-server signing architecture
- Read `.github/skills/azure-devops/SKILL.md` for sprint queries and task creation — always use `scripts/query-sprint.ps1` and `scripts/create-task.ps1` instead of raw `az boards` commands

## Critical Rules
- **Bearer token**: Always include the `bearerToken` parameter when calling any tool on the `fro-uat` remote MCP server. Acquire it via `acquire_bearer_token` on the local signer. If you get a 403 error, retry with `acquire_bearer_token(forceRefresh=true)` to flush the MSAL cache.
- **ECID generation**: Use the `generate_ecid` tool on the local signer to generate ecId values. Do not use shell commands for timestamp generation.
- **Quantity**: Must be a multiple of 100 (lot size). Validate before signing.
- **Signing before submitting**: All write operations require signing locally first (e.g., `sign_create_offer`), then submitting the `callInfo` + `signature` to the remote MCP.
- **Parameter consistency**: Use the exact same values for signing and submission — do not recalculate between steps. The server decodes callInfo and cross-validates against request parameters.
- **Fresh ecId/expiry**: Always call `generate_ecid` immediately before signing. Never reuse values from a previous session — stale expiry causes "Expiry in the past" reverts on-chain.
- **Poll after writes**: After most write operations (CreateOffer, Purchase, etc.), poll `CheckTxStatus` until status is `Mined` or `Failed`. Exception: TransferDollars and TransferTokens are synchronous and return the result directly.
- **Transfer operations**: TransferDollars requires `DOLLAR_CONTRACT_ADDRESS` in env vars. TransferTokens requires looking up the token contract address via `GetTokenDetails` first.

## 1X2 Tools (Three-Outcome Events)
- The remote MCP includes 18 `OneX2*` tools for three-outcome event betting (Home/Draw/Away).
- **No client-side signing** — 1X2 tools are pure pass-through proxies. Just pass `bearerToken` + business parameters.
- **No ecId/callInfo/signature** — the 1X2 API handles signing server-side.
- **No CheckTxStatus polling** — results return directly.
- **Same bearer token** — acquire via `acquire_bearer_token` on the local signer, same as EC tools.
- Tool categories: User Management (`OneX2CreateUser`, `OneX2PauseUser`), Money (`OneX2OmnibusTransaction`, `OneX2TransferMoney`), Events (`OneX2ListEvent`, `OneX2GetEvent`), Orders (`OneX2Maker`, `OneX2Taker`, `OneX2Cancel`, `OneX2Void`, `OneX2SecondaryMaker`), Settlement (`OneX2SettleEvent`), Queries (`OneX2Orderbook`, `OneX2CashPosition`, `OneX2OpenPositions`, `OneX2ClosedPositions`, `OneX2Exposure`), Operations (`OneX2PauseOrderbook`).

## Native Tools (OpenOrderbook AI Client)
- The standalone AI client provides 8 native tools: `read_file`, `write_file`, `list_directory`, `web_search`, `http_fetch`, `list_profiles`, `switch_profile`, `create_profile`.
- Profile switching (`switch_profile`) reconnects the signer MCP, clears bearer token cache, and resets chat history.
- These tools are NOT available in VS Code + Copilot — they only exist in the OpenOrderbook AI CLI client.
