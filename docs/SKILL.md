# OpenOrderbook MCP Trading Skill

## Overview
This skill covers working with the OpenOrderbook MCP (Model Context Protocol) system for creating and managing fixed-return option (FRO) offers on the Horizon Fintex platform. The system uses a dual MCP architecture: a local signing server for cryptographic operations and a remote Azure-hosted server for blockchain interactions.

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

### 2. Querying Market Data

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

### 3. Checking Signer Status

**Always verify signer is loaded before operations:**
```
Tool: mcp_fro-local-sig_get_signer_status
Returns: { loaded: true/false, address, eventContractAddress, environment }
```

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
- Cause: Bearer token expired or malformed
- Solution: Acquire fresh token with acquire_bearer_token

### Transaction Errors

**Error: "Quantity must be a multiple of 100"**
- Cause: qty parameter not divisible by 100
- Solution: Round up to nearest 100 (e.g., 2 → 200)

**Status: "Failed" in CheckTxStatus**
- Check errorMessage field for details
- Common causes: Insufficient balance, invalid signature, contract validation failure

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
- If 403 error occurs, acquire new token immediately

### 2. Expiry Handling
- Default expiry is tomorrow midnight UTC (expiryDays=1)
- Always use the expiry returned by generate_ecid (ensures consistency)
- Present expiry to user in readable format (expiryIso)

### 3. Transaction Polling
- After CreateOffer, always poll with CheckTxStatus
- Expected flow: Queued (immediate) → Mining (~10-30s) → Mined (final)
- Report offerId to user once status is "Mined"

### 4. Parameter Consistency
- Sign and submit with EXACT same values
- Use variables to ensure consistency across steps
- Don't recalculate or transform values between signing and submission

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

### Local Signer Tools (No Bearer Token Needed)
- `get_signer_status` - Check signer configuration
- `generate_ecid` - Generate event contract ID
- `sign_create_offer` - Sign offer creation
- `sign_purchase` - Sign offer purchase
- `sign_cancel_offer` - Sign offer cancellation
- `sign_exercise` - Sign position exercise
- `sign_transfer` - Sign position transfer
- `sign_list_for_sale` - Sign secondary market listing
- `sign_delist_for_sale` - Sign secondary market delisting
- `acquire_bearer_token` - Get Azure AD token

### Remote API Tools (Bearer Token Required)
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

**Write Operations:**
- `CreateOffer` - Submit signed offer
- `PurchaseOffer` - Submit signed purchase
- `CancelOffer` - Submit signed cancellation
- `ExercisePosition` - Submit signed exercise
- `TransferPosition` - Submit signed transfer
- `ListForSale` - Submit signed secondary listing
- `PurchaseSecondary` - Buy from secondary market

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
  "FRO_SCOPE": "https://upstreamdev.onmicrosoft.com/mobileaccess-uat/.default"
}
```

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

---

## Future Enhancements to Watch For

- Admin operations (AdminSettle, AdminBatchSettle, AdminReleaseCollateral)
- Market creation (sign_create_market, CreateMarket)
- Secondary market purchases (PurchaseSecondary after ListForSale)
- Exercise workflow when positions are exercisable
- Collateral release after expiry

---

## Documentation Locations

- Setup Guide: `~/path/to/openorderbook-mcp/docs/SETUP-MACOS.md`
- Tools Reference: `~/path/to/openorderbook-mcp/docs/TOOLS-REFERENCE.md`
- Architecture: `~/path/to/openorderbook-mcp/docs/ARCHITECTURE.md`
- Config Template: `~/path/to/openorderbook-mcp/config/mcp.json.template`
