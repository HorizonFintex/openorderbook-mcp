# OpenOrderbook MCP — Copilot Instructions

This workspace contains the OpenOrderbook MCP system for trading fixed-return options (FROs) via VS Code and GitHub Copilot.

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
