# OpenOrderbook MCP Trading Skill

## Overview
This skill covers working with the OpenOrderbook MCP (Model Context Protocol) system for creating and managing fixed-return option (FRO) offers on the Horizon Fintex platform. The system uses a dual MCP architecture: a local signing server for cryptographic operations and a remote Azure-hosted server for blockchain interactions. The standalone OpenOrderbook AI client adds 8 native tools for file I/O, web access, and user profile switching — bringing the total to 59 tools.

## When to Use This Skill
- Creating, purchasing, or canceling FRO offers
- Managing positions (exercise, transfer, list for sale)
- Querying market data, portfolios, or transaction history
- Any interaction with FMST or other FRO markets
- User mentions: "create offer", "buy option", "check portfolio", "FRO", "FMST", "fixed-return options"

---

## Architecture & Setup

### Dual MCP Server Architecture
The system requires TWO MCP servers working together:

1. **fro-local-signer** (stdio server)
   - Runs locally on user's machine
   - Handles cryptographic signing operations
   - Manages keystore decryption
   - Acquires Azure AD B2C bearer tokens
   - Never communicates directly with blockchain

2. **fro-uat** (HTTP server)
   - Hosted on Azure (https://openorderbookmcp-uat.azurewebsites.net/api/mcp)
   - Handles all blockchain read/write operations
   - Requires bearer token authentication
   - Verifies signatures before submitting transactions

### Configuration Location
- Config file: `.vscode/mcp.json` in workspace root (NOT in the openorderbook-mcp repo)
- Template location: `~/path/to/openorderbook-mcp/config/mcp.json.template`
- Never commit `mcp.json` - it contains secrets

### Authentication Flow
1. Local signer generates signatures using private key
2. Local signer acquires Azure AD B2C bearer token via `acquire_bearer_token`
3. Bearer token passed to remote MCP server with each API call
4. Remote server verifies both the token AND the cryptographic signature

**CRITICAL**: Bearer tokens are acquired separately from signing operations. Always use the `bearerToken` parameter on remote MCP tools.

---

## Core Workflows

### 1. Creating an FRO Offer (Complete Flow)

**Steps:**
1. **Generate Event Contract ID (ECID)**
   ```
   Tool: mcp_fro-local-sig_generate_ecid
   Parameters: 
     - expiryDays: Optional, defaults to 1 (tomorrow midnight UTC)
   Returns: { ecId, expiry (unix timestamp), expiryIso }
   ```

2. **Sign the Offer**
   ```
   Tool: mcp_fro-local-sig_sign_create_offer
   Parameters:
     - ecId: From step 1
     - writer: Signer's address (get from get_signer_status)
     - side: "Yes" or "No"
     - symbol: Underlying asset (e.g., "FMST")
     - strike: Strike price in dollars (decimal)
     - premium: Premium per contract in dollars (decimal)
     - qty: Number of contracts (MUST be multiple of 100)
     - collateral: Total collateral in dollars (decimal)
     - writerFee: Writer fee in dollars (decimal)
     - expiry: Unix timestamp from step 1
   Returns: { callInfo, signature, signerAddress }
   ```

3. **Acquire Bearer Token** (if not already acquired)
   ```
   Tool: mcp_fro-local-sig_acquire_bearer_token
   Parameters: None (uses environment variables)
   Returns: { accessToken, expiresIn, environment }
   ```

4. **Submit the Offer**
   ```
   Tool: mcp_fro-uat_CreateOffer
   Parameters:
     - address: Writer address
     - callInfo: From step 2
     - signature: From step 2
     - eventContractId: ecId from step 1
     - side: "Yes" or "No"
     - underlyingSymbol: Same as symbol in step 2
     - strikePrice: Same as strike in step 2
     - premium: Same as premium in step 2
     - quantity: Same as qty in step 2
     - collateral: Same as collateral in step 2
     - writerFee: Same as writerFee in step 2
     - expiry: ISO 8601 string (use expiryIso from step 1)
     - bearerToken: accessToken from step 3
   Returns: { TrackingId, Status: "Queued" }
   ```

5. **Poll Transaction Status**
   ```
   Tool: mcp_fro-uat_CheckTxStatus
   Parameters:
     - trackingId: From step 4
     - bearerToken: Same token from step 3
   Monitor until status changes from "Queued" → "Mining" → "Mined"
   Returns: { status, transactionHash, gasUsed, offerId, errorMessage }
   ```

### 2. Purchasing an FRO Offer

**CRITICAL**: The purchase flow requires TWO separate EC IDs — one for the new position (`posEcId`) and one to identify the offer (`offerEcId`). These must be different values. Passing the same value causes the position's on-chain ID to be lost, breaking auto-settlement.

**Steps:**
1. **Generate Position ECID** (for the new position)
   ```
   Tool: mcp_fro-local-sig_generate_ecid
   Returns: { ecId (posEcId), expiry, expiryIso }
   ```

2. **Look up the offer's EC ID**
   ```
   Tool: mcp_fro-uat_GetOffer
   Parameters:
     - offerId: The offer to purchase
     - bearerToken: Required
   Returns: Offer details including eventContractId (this is the offerEcId)
   ```

3. **Sign the purchase** (uses BOTH EC IDs)
   ```
   Tool: mcp_fro-local-sig_sign_purchase
   Parameters:
     - posEcId: ecId from step 1 (NEW position ID)
     - offerEcId: eventContractId from step 2 (EXISTING offer ID)
     - buyer: Buyer wallet address
     - qty: Number of contracts
     - payment: Total payment in dollars
     - buyerFee: Buyer fee (payment * 0.01)
   Returns: { callInfo, signature }
   ```

4. **Submit the purchase**
   ```
   Tool: mcp_fro-uat_PurchaseOffer
   Parameters:
     - address: Buyer wallet address
     - callInfo: From step 3
     - signature: From step 3
     - positionEcId: ecId from step 1 (MUST match posEcId in step 3)
     - offerEcId: eventContractId from step 2 (MUST match offerEcId in step 3)
     - offerId: Offer ID to purchase from
     - quantity: Same as qty in step 3
     - bearerToken: Required
   Returns: { TrackingId, Status: "Queued", PositionId }
   ```

5. **Poll Transaction Status**
   ```
   Tool: mcp_fro-uat_CheckTxStatus
   Parameters:
     - trackingId: From step 4
     - bearerToken: Required
   Returns: { status, transactionHash, gasUsed, positionId, errorMessage }
   ```

### 3. Querying Market Data

**Get All Offers or Filter by Symbol:**
```
Tool: mcp_fro-uat_GetMarket
Parameters:
  - symbol: Optional filter (e.g., "FMST")
  - skip: Pagination offset (default 0)
  - take: Results per page (default 50)
  - bearerToken: Required
```

**Get User Portfolio:**
```
Tool: mcp_fro-uat_GetPortfolio
Parameters:
  - address: Wallet address (0x-prefixed)
  - bearerToken: Required
```

### 4. Checking Signer Status

**Always verify signer is loaded before operations:**
```
Tool: mcp_fro-local-sig_get_signer_status
Returns: { loaded: true/false, address, eventContractAddress, environment }
```

### 5. Transferring USD (Dollars)

**Steps:**
1. **Acquire Bearer Token** (if not already acquired)
   ```
   Tool: mcp_fro-local-sig_acquire_bearer_token
   Returns: { accessToken, expiresIn, environment }
   ```

2. **Generate ECID**
   ```
   Tool: mcp_fro-local-sig_generate_ecid
   Returns: { ecId, expiry, expiryIso }
   ```

3. **Sign the Transfer**
   ```
   Tool: mcp_fro-local-sig_sign_transfer_dollars
   Parameters:
     - toAddress: Recipient wallet address (0x-prefixed)
     - quantity: Amount in dollars (decimal)
     - expiry: Unix timestamp from step 2
   Requires: DOLLAR_CONTRACT_ADDRESS env var configured
   Returns: { callInfo, signature, signerAddress }
   ```

4. **Submit the Transfer**
   ```
   Tool: mcp_fro-uat_TransferDollars
   Parameters:
     - address: Sender wallet address
     - callInfo: From step 3
     - signature: From step 3
     - toAddress: Same as step 3
     - quantity: Same as step 3
     - bearerToken: Required
   Returns: { success, transactionHash, status } — synchronous, no polling needed
   ```

### 6. Transferring Security Tokens

**Steps:**
1. **Acquire Bearer Token** (if not already acquired)
   ```
   Tool: mcp_fro-local-sig_acquire_bearer_token
   Returns: { accessToken, expiresIn, environment }
   ```

2. **Look up Token Contract Address**
   ```
   Tool: mcp_fro-uat_GetTokenDetails
   Parameters:
     - symbol: Token symbol (e.g., "BREA")
     - bearerToken: Required
   Returns: { tokenAddress, name, symbol, decimals }
   ```

3. **Generate ECID**
   ```
   Tool: mcp_fro-local-sig_generate_ecid
   Returns: { ecId, expiry, expiryIso }
   ```

4. **Sign the Transfer**
   ```
   Tool: mcp_fro-local-sig_sign_transfer_tokens
   Parameters:
     - tokenContractAddress: tokenAddress from step 2
     - toAddress: Recipient wallet address (0x-prefixed)
     - quantity: Number of tokens (integer)
     - expiry: Unix timestamp from step 3
   Returns: { callInfo, signature, signerAddress }
   ```

5. **Submit the Transfer**
   ```
   Tool: mcp_fro-uat_TransferTokens
   Parameters:
     - address: Sender wallet address
     - callInfo: From step 4
     - signature: From step 4
     - tokenContractAddress: Same as step 4
     - toAddress: Same as step 4
     - quantity: Same as step 4
     - bearerToken: Required
   Returns: { success, transactionHash, status } — synchronous, no polling needed
   ```

> **Note:** Transfer operations (TransferDollars and TransferTokens) are synchronous — they return the final result directly. No `CheckTxStatus` polling is needed.

### 7. Switching User Profiles (OpenOrderbook AI Client)

The OpenOrderbook AI client supports named profiles stored as `config.{Name}.json` files in the `~/.openorderbook-ai/` directory. Each profile has its own keystore, wallet, and credentials.

**Steps:**
1. **List available profiles**
   ```
   Tool: list_profiles
   Returns: list of profile names (e.g., Andy, Brian)
   ```

2. **Switch to a profile**
   ```
   Tool: switch_profile
   Parameters:
     - name: Profile name (e.g., "Brian")
   Effect: Saves current config, loads target profile, reconnects signer MCP,
           refreshes wallet address, clears bearer token cache, resets chat history.
   Returns: confirmation with new wallet address
   ```

3. **Create a new profile**
   ```
   Tool: create_profile
   Parameters:
     - name: Profile name to create
   Effect: Copies current config to config.{Name}.json
   Returns: confirmation, file path
   ```

> **Note:** Profile switching is only available in the OpenOrderbook AI CLI client. VS Code + Copilot users configure profiles via separate `.vscode/mcp.json` configuration blocks.

---

## 1X2 Tools (Three-Outcome Event Betting)

The MCP server includes 18 tools for the **1X2 API** — a separate system for three-outcome event betting (Home Win / Draw / Away Win), typically used for sports markets.

### Key Differences from EC Tools

| Aspect | EC Tools (existing) | 1X2 Tools (new) |
|--------|-------------------|-----------------|
| Signing | Client-side (`sign_*` → callInfo + signature) | Server-side (1X2 API signs internally) |
| Workflow | generate_ecid → sign → submit → poll CheckTxStatus | acquire_bearer_token → call tool → done |
| Parameters | callInfo, signature, address, device metadata | Simple business parameters only |
| Auth | S2S bearer token (Server2Server scheme) | S2S bearer token (same) |
| Base URL | `FRO_BASE_URL` (Talketh) | `ONEX2_API_BASE_URL` (1X2 Function App) |

### 1X2 Workflow (Simplified)

1. `acquire_bearer_token` on local signer → get `bearerToken`
2. Call any `OneX2*` tool with `bearerToken` parameter → done

No `generate_ecid`, no `sign_*`, no `CheckTxStatus` polling needed.

### Example: List Event → Maker → Taker → Settle

```
1. acquire_bearer_token → bearerToken
2. OneX2ListEvent(category="football", homeLabel="Celta Vigo", awayLabel="Freiburg",
     eventType="1X2 - Full Time", settleDate="2026-04-15T17:00:00Z", bearerToken=...)
   → eventId=5
3. OneX2Maker(wallet="0x...", eventId=5, outcome="1", makerProbability=0.45,
     quantity=200, expiry="2026-04-15T17:00:00Z", bearerToken=...)
   → orderId=42
4. OneX2Taker(wallet="0x...", orderId=42, quantity=100, bearerToken=...)
   → positionId=7
5. OneX2SettleEvent(eventId=5, outcome="1", bearerToken=...)
   → all three ECs settled
```

### 1X2 Tool Listing

**User Management:** `OneX2CreateUser`, `OneX2PauseUser`
**Money:** `OneX2OmnibusTransaction`, `OneX2TransferMoney`
**Events:** `OneX2ListEvent`, `OneX2GetEvent`
**Orders:** `OneX2Maker`, `OneX2Taker`, `OneX2Cancel`, `OneX2Void`, `OneX2SecondaryMaker`
**Settlement:** `OneX2SettleEvent`
**Queries:** `OneX2Orderbook`, `OneX2CashPosition`, `OneX2OpenPositions`, `OneX2ClosedPositions`, `OneX2Exposure`
**Operations:** `OneX2PauseOrderbook`

> See [TOOLS-REFERENCE.md](TOOLS-REFERENCE.md) for full parameter details for each tool.

---

## Critical Constraints & Validation Rules

### Lot Size Requirement
- **Quantity MUST be a multiple of 100**
- Common error: "Quantity must be a multiple of 100 (lot size)"
- If user requests 2 contracts, inform them it will be adjusted to 200 (minimum lot)
- Always validate quantity before signing: `qty % 100 === 0`

### Parameter Formats
- **Addresses**: 42-character hex strings with "0x" prefix
- **Decimal values**: Use decimal type (prices, fees, collateral)
- **Timestamps**: Unix seconds (not milliseconds) for API calls
- **ECID**: Unix milliseconds (generated by generate_ecid tool)
- **Expiry format**: 
  - Signing: Unix timestamp in seconds (long)
  - API submission: ISO 8601 string (e.g., "2026-03-25T00:00:00Z")

### Side Values
- Must be exactly "Yes" or "No" (case-sensitive)
- Represents the direction of the option position

---

## Error Handling & Troubleshooting

### Authentication Errors

**Error: "No Authorization header provided"**
- Cause: Bearer token not passed to remote MCP tool
- Solution: Always include `bearerToken` parameter from acquire_bearer_token

**Error: "The issuer is invalid" (403)**
- Cause: Bearer token expired, malformed, or MSAL cache corrupted
- Solution: Acquire fresh token with `acquire_bearer_token(forceRefresh=true)` to flush the MSAL cache and get a new token from Azure AD
- If 403 persists after forceRefresh, the Talketh server's OIDC key cache may be stale — a second request usually self-heals as the server auto-refreshes signing keys on signature failure

### Transaction Errors

**Error: "Quantity must be a multiple of 100"**
- Cause: qty parameter not divisible by 100
- Solution: Round up to nearest 100 (e.g., 2 → 200)

**Status: "Failed" in CheckTxStatus**
- Check errorMessage field for details
- Common causes: Insufficient balance, invalid signature, contract validation failure

**Error: "CALLINFO_VALIDATION_ERROR"**
- Cause: The ABI-encoded callInfo contains values that don't match the API request parameters
- The error message lists every mismatched field (e.g., `expiry: callInfo=1774458000, request=1774544400`)
- Solution: Ensure the exact same values are used for both signing and submission. Regenerate ecId/expiry via `generate_ecid` if stale

### Signer Errors

**"Signer not loaded"**
- Check keystore path and password in mcp.json
- Verify FRO_KEYSTORE_PATH and FRO_KEYSTORE_PASSWORD environment variables

**"Auth not configured"**
- Missing Azure AD B2C credentials in environment variables
- Verify: FRO_TENANT_ID, FRO_CLIENT_ID, FRO_CLIENT_SECRET, FRO_SCOPE

---

## Best Practices

### 1. Token Management
- Acquire bearer token once and reuse for multiple operations
- Tokens last ~1 hour (3600 seconds)
- If 403 error occurs, acquire new token with `acquire_bearer_token(forceRefresh=true)`
- The `forceRefresh` parameter flushes the MSAL cache and gets a fresh token from Azure AD

### 2. Expiry Handling
- Default expiry is tomorrow midnight UTC (expiryDays=1)
- Always use the expiry returned by generate_ecid (ensures consistency)
- Present expiry to user in readable format (expiryIso)
- **CRITICAL**: The expiry in callInfo (Unix timestamp) must match the expiry in the API request (ISO 8601). The server decodes callInfo and cross-validates — a mismatch rejects the request immediately
- Never reuse an expiry from a previous generate_ecid call — always generate fresh to avoid "Expiry in the past" reverts on-chain

### 3. Transaction Polling
- After CreateOffer, always poll with CheckTxStatus
- Expected flow: Queued (immediate) → Mining (~10-30s) → Mined (final)
- Report offerId to user once status is "Mined"

### 4. Parameter Consistency
- Sign and submit with EXACT same values
- Use variables to ensure consistency across steps
- Don't recalculate or transform values between signing and submission
- The remote MCP server decodes callInfo and cross-checks embedded values against request parameters — mismatches are rejected with `CALLINFO_VALIDATION_ERROR`

### 5. User Communication
- Always inform user of lot size adjustments upfront
- Show transaction hash and offerId when mined
- If quantity adjusted from 2 to 200, clearly state the change

---

## Common User Requests & Responses

### "Create a Yes offer on FMST at strike $100, premium $5"
**Workflow:**
1. Ask for quantity (if not specified) and remind about lot size (multiples of 100)
2. Generate ECID
3. Sign offer
4. Acquire token (if needed)
5. Submit offer
6. Poll status
7. Report offerId and transaction hash

### "Show me my portfolio"
**Workflow:**
1. Get signer address from get_signer_status
2. Acquire token (if needed)
3. Call GetPortfolio with address
4. Format and present offers written + positions held

### "Check if my offer went through"
**Workflow:**
1. Request trackingId from user (or use last known)
2. Call CheckTxStatus with fresh token
3. Report status, offerId, and transaction details

---

## Tool Categories Quick Reference

### Local Signer Tools (16 — No Bearer Token Needed)
- `get_signer_status` - Check signer configuration
- `generate_ecid` - Generate event contract ID
- `acquire_bearer_token` - Get Azure AD token (supports `forceRefresh=true`)
- `sign_create_offer` - Sign offer creation
- `sign_create_market` - Sign market creation
- `sign_purchase` - Sign offer purchase
- `sign_cancel_offer` - Sign offer cancellation
- `sign_exercise` - Sign position exercise
- `sign_transfer` - Sign position transfer
- `sign_list_for_sale` - Sign secondary market listing
- `sign_delist_for_sale` - Sign secondary market delisting
- `sign_release_collateral` - Sign collateral release
- `sign_transfer_dollars` - Sign USD transfer (requires `DOLLAR_CONTRACT_ADDRESS` env var)
- `sign_transfer_tokens` - Sign token transfer (requires `tokenContractAddress` from `GetTokenDetails`)

### Remote API Tools (38 EC — Bearer Token Required)
**Read Operations:**
- `GetMarket` - Query offers and listings
- `GetPortfolio` - Get user's offers and positions
- `GetOffer` - Get single offer details
- `GetPosition` - Get single position details
- `GetOfferHistory` - Offer event history
- `GetPositionHistory` - Position event history
- `GetWalletHistory` - All wallet events
- `GetPositionsForSale` - Secondary market listings
- `GetBalance` - Wallet fiat balance
- `CheckTxStatus` - Transaction status polling
- `GetSettings` - User permissions and market schedule
- `GetMarketSchedule` - Market open/close times
- `GetTokenDetails` - Token contract address and metadata lookup

**Public Market Data (No Auth Required):**
- `GetMarketData` - Real-time quote (last, bid, ask, volume, change)
- `GetOrderbook` - Bid/ask depth
- `GetTimeAndSales` - Trade tape
- `GetSecurityPortfolio` - Wallet holdings (stocks, tokens)
- `GetOptionsMarket` - All options contracts
- `GetNews` - News articles
- `GetWarrants` - Warrant contracts
- `GetClosingReport` - End-of-day prices
- `Faucet` - Top up test USD (test environments only)

**Write Operations:**
- `CreateOffer` - Submit signed offer
- `PurchaseOffer` - Submit signed purchase
- `CancelOffer` - Submit signed cancellation
- `ExercisePosition` - Submit signed exercise
- `TransferPosition` - Submit signed transfer
- `ListForSale` - Submit signed secondary listing
- `DelistForSale` - Submit signed delisting
- `PurchaseSecondary` - Buy from secondary market
- `CreateMarket` - Create prediction market
- `TransferDollars` - Transfer USD between wallets (synchronous)
- `TransferTokens` - Transfer security tokens between wallets (synchronous)

### Native Tools (8 — OpenOrderbook AI Client Only)

These tools are built into the OpenOrderbook AI CLI client (not part of either MCP server). They run locally in the client process.

**File System:**
- `read_file` - Read file contents from the workspace
- `write_file` - Write content to a file in the workspace
- `list_directory` - List files and directories

**Web Access:**
- `web_search` - Search the web via DuckDuckGo
- `http_fetch` - Fetch a URL and return the content

**Profile Management:**
- `list_profiles` - List available user profiles (config.*.json files)
- `switch_profile` - Switch to a different profile (reloads config, reconnects signer, resets chat)
- `create_profile` - Save the current configuration as a new named profile

### Remote 1X2 API Tools (18 — Bearer Token Required, No Signing)
**User Management:** `OneX2CreateUser`, `OneX2PauseUser`
**Money:** `OneX2OmnibusTransaction`, `OneX2TransferMoney`
**Events:** `OneX2ListEvent`, `OneX2GetEvent`
**Orders:** `OneX2Maker`, `OneX2Taker`, `OneX2Cancel`, `OneX2Void`, `OneX2SecondaryMaker`
**Settlement:** `OneX2SettleEvent`
**Queries:** `OneX2Orderbook`, `OneX2CashPosition`, `OneX2OpenPositions`, `OneX2ClosedPositions`, `OneX2Exposure`
**Operations:** `OneX2PauseOrderbook`

---

## Environment Variables Reference

Required in `.vscode/mcp.json` under fro-local-signer env block:
```jsonc
{
  "FRO_EVENT_CONTRACT_ADDRESS": "0x30a803902D381696942C1a369205b6144fC5772f",
  "FRO_ENVIRONMENT": "UAT",
  "FRO_KEYSTORE_PATH": "/absolute/path/to/keystore.json",
  "FRO_KEYSTORE_PASSWORD": "your-password",
  "FRO_TENANT_ID": "058820ef-8462-4935-a840-6e5582798862",
  "FRO_CLIENT_ID": "ce48291b-5ea7-4f15-a5c4-78e6bbfffe89",
  "FRO_CLIENT_SECRET": "your-secret-from-team-lead",
  "FRO_SCOPE": "https://upstreamdev.onmicrosoft.com/mobileaccess-uat/.default",
  // Optional — required only for TransferDollars operations
  "DOLLAR_CONTRACT_ADDRESS": "0xeC9e37E9E0cCe08754958B06a4362dACAD4a5474"
}
```

Required on the remote MCP server (`openorderbookmcp-uat`) for 1X2 tools:
```
ONEX2_API_BASE_URL=https://onex2api-uat.azurewebsites.net
```
Defaults to the UAT endpoint if not set.

---

## Testing & Verification

### Verify Setup
1. Check signer status: `get_signer_status` → should return loaded=true
2. Acquire token: `acquire_bearer_token` → should return accessToken
3. Query market: `GetMarket` with bearerToken → should return offers

### Test Create Flow (Minimal)
1. Generate ECID with default expiry
2. Sign offer with qty=100 (minimum)
3. Submit with fresh bearer token
4. Poll until Mined status
5. Verify offerId returned

---

## Important Reminders

1. **Always validate quantity is multiple of 100** before signing
2. **Always pass bearerToken** to remote MCP tools
3. **Reuse bearer tokens** across operations (valid for ~1 hour)
4. **Poll CheckTxStatus** after write operations until status is Mined or Failed
5. **Use ISO 8601 format** for expiry in CreateOffer API call
6. **Use Unix timestamp** for expiry in sign_create_offer
7. **Both servers must be running** - check MCP server status if tools not responding
8. **Never commit mcp.json** - contains private keys and secrets
9. **Generate fresh ecId/expiry** immediately before signing — never reuse values from a previous session
10. **CallInfo is cross-validated** — the server decodes ABI-encoded callInfo and rejects mismatches against request parameters before calling the API
11. **Profile switching resets state** — bearer token cache and chat history are cleared when switching profiles in the AI client
12. **Native tools are client-only** — file, web, and profile tools exist only in the OpenOrderbook AI client, not in VS Code + Copilot

---

## Future Enhancements to Watch For

- Exercise workflow automation when positions become exercisable
- Batch transfer operations
- Production environment support

---

## Documentation Locations

- Setup Guide: `~/path/to/openorderbook-mcp/docs/SETUP-MACOS.md`
- Tools Reference: `~/path/to/openorderbook-mcp/docs/TOOLS-REFERENCE.md`
- Architecture: `~/path/to/openorderbook-mcp/docs/ARCHITECTURE.md`
- Config Template: `~/path/to/openorderbook-mcp/config/mcp.json.template`
