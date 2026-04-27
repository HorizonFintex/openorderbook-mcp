# Tools Reference

Complete reference for all MCP tools and native tools available in the OpenOrderbook system. Total: 16 local signer + 38 remote EC + 18 remote 1X2 + 8 native = **80 tools**.

## Local Signer MCP Tools (16 tools)

These tools run locally on your machine via the `fro-local-signer` MCP server.

### Keystore & Status

#### `get_signer_status`
Check whether the signer is loaded and which environment/contract it targets.

**Parameters:** None

**Returns:** `{ loaded, address, eventContractAddress, environment }`

---

#### `decrypt_keystore`
Decrypt an Ethereum V3 keystore file and load the signer. If no parameters provided, uses `FRO_KEYSTORE_PATH` and `FRO_KEYSTORE_PASSWORD` from environment.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `keystorePath` | string | No | Path to keystore JSON file (falls back to env var) |
| `password` | string | No | Keystore decryption password (falls back to env var) |

---

#### `load_private_key`
Load a hex private key directly into the signer (with or without 0x prefix).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `privateKeyHex` | string | Yes | Hex-encoded private key |

---

### Authentication

#### `acquire_bearer_token`
Acquire an S2S bearer token from Azure AD B2C using client_credentials flow (MSAL). All config is read from environment variables. Returns the access token and expiry. Pass `forceRefresh=true` to flush the MSAL token cache and acquire a fresh token from Azure AD — use this when getting persistent 403 errors.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `forceRefresh` | bool | No | Set to `true` to discard the MSAL token cache and force a fresh token from Azure AD. Defaults to `false`. |

**Environment Variables Required:** `FRO_TENANT_ID`, `FRO_CLIENT_ID`, `FRO_CLIENT_SECRET`, `FRO_SCOPE`

**Returns:** `{ accessToken, expiresIn, signatureVerified, cacheCleared, environment }`

---

### Utility

#### `generate_ecid`
Generate a unique event contract ID (ecId) based on UTC time in Unix milliseconds. Also returns a default expiry timestamp for convenience.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `expiryDays` | int | No | Days from now for expiry (default: 1 = tomorrow midnight UTC) |

**Returns:** `{ ecId, expiry, expiryIso, generatedAt }`

---

### Signing Tools

All signing tools require the signer to be loaded first. They return `{ callInfo, signature, signerAddress, environment }`.

#### `sign_create_offer`
Sign a createOffer transaction for the Feeless relay.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ecId` | long | Yes | Event Contract ID for this offer |
| `writer` | string | Yes | Writer wallet address (0x-prefixed) |
| `side` | string | Yes | Side: Yes or No |
| `symbol` | string | Yes | Underlying symbol (e.g. AAPL, FMST) |
| `strike` | decimal | Yes | Strike price in dollars |
| `premium` | decimal | Yes | Premium per contract in dollars |
| `qty` | int | Yes | Number of contracts |
| `collateral` | decimal | Yes | Total collateral in dollars |
| `writerFee` | decimal | Yes | Writer fee in dollars |
| `expiry` | long | Yes | Expiry as Unix timestamp (seconds) |

---

#### `sign_create_market`
Sign a createMarket transaction (creates an event contract).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ecId` | long | Yes | Event Contract ID for this market |
| `creator` | string | Yes | Creator wallet address (0x-prefixed) |
| `symbol` | string | Yes | Underlying symbol (e.g. AAPL, FMST) |
| `strike` | decimal | Yes | Strike price in dollars |
| `expiry` | long | Yes | Expiry as Unix timestamp (seconds) |

---

#### `sign_purchase`
Sign a purchase transaction for the Feeless relay.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `posEcId` | long | Yes | Position EC ID (new position) |
| `offerEcId` | long | Yes | Offer EC ID being purchased from |
| `buyer` | string | Yes | Buyer wallet address (0x-prefixed) |
| `qty` | int | Yes | Number of contracts to purchase |
| `payment` | decimal | Yes | Total payment in dollars |
| `buyerFee` | decimal | Yes | Buyer fee in dollars |

---

#### `sign_cancel_offer`
Sign a cancelOffer transaction for the Feeless relay.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `offerEcId` | long | Yes | Offer EC ID to cancel |
| `writerFee` | decimal | Yes | Writer fee in dollars |

---

#### `sign_exercise`
Sign an exercise transaction for the Feeless relay.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `posEcId` | long | Yes | Position EC ID to exercise |
| `payout` | decimal | Yes | Payout amount in dollars |

---

#### `sign_transfer`
Sign a transferPosition transaction for the Feeless relay.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `posEcId` | long | Yes | Position EC ID to transfer |
| `oldHolder` | string | Yes | Current holder wallet address (0x-prefixed) |
| `newHolder` | string | Yes | New holder wallet address (0x-prefixed) |
| `salePrice` | decimal | Yes | Sale price in dollars |
| `buyerFee` | decimal | Yes | Buyer fee in dollars |
| `sellerProceeds` | decimal | Yes | Seller proceeds in dollars |

---

#### `sign_release_collateral`
Sign a releaseCollateral transaction for the Feeless relay.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `offerEcId` | long | Yes | Offer EC ID to release collateral for |

---

#### `sign_list_for_sale`
Sign a listForSale transaction for the Feeless relay. Uses keccak256-computed function selector (ABI doesn't include this method yet).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `positionId` | int | Yes | Position ID to list for sale |
| `askingPrice` | decimal | Yes | Asking price in dollars |

---

#### `sign_delist_for_sale`
Sign a delistForSale transaction for the Feeless relay. Uses keccak256-computed function selector (ABI doesn't include this method yet).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `positionId` | int | Yes | Position ID to delist from sale |

---

### Transfer Signing Tools

These tools sign transfer operations for test/admin environments. They target specific token contracts rather than the FRO event contract.

#### `sign_transfer_dollars`
Sign a transferDollars transaction against the USD stablecoin contract. Requires the `DOLLAR_CONTRACT_ADDRESS` environment variable to be set.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `toAddress` | string | Yes | Recipient wallet address (0x-prefixed, 42 chars) |
| `amount` | decimal | Yes | Amount in dollars to transfer |
| `expiry` | long | Yes | Expiry as Unix timestamp (seconds) — from `generate_ecid` |

**Environment Variable Required:** `DOLLAR_CONTRACT_ADDRESS`

**Returns:** `{ callInfo, signature, signerAddress, targetContract, environment }`

---

#### `sign_transfer_tokens`
Sign a transferTokens transaction against a specific token contract. The token contract address must be looked up first via `GetTokenDetails` on the remote MCP.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `tokenContractAddress` | string | Yes | On-chain token contract address (0x-prefixed, 42 chars) — from `GetTokenDetails` |
| `toAddress` | string | Yes | Recipient wallet address (0x-prefixed, 42 chars) |
| `quantity` | int | Yes | Number of tokens to transfer |
| `expiry` | long | Yes | Expiry as Unix timestamp (seconds) — from `generate_ecid` |

**Returns:** `{ callInfo, signature, signerAddress, targetContract, environment }`

---

## Remote MCP Tools (35 tools)

These tools are exposed by the `fro-uat` remote MCP server hosted on Azure. All tools accept an optional `bearerToken` parameter for authentication.

### Read Tools (20)

#### `GetMarket`
Get the current market of fixed-return option offers, optionally filtered by underlying symbol. Returns open offers and secondary market listings.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | No | Filter by underlying symbol (e.g. AAPL, BTC). Leave empty for all. |
| `skip` | integer | No | Number of results to skip for pagination (default: 0) |
| `take` | integer | No | Maximum number of results to return (default: 50) |

---

#### `GetPortfolio`
Get a user's portfolio of written offers and held positions.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Wallet address (0x-prefixed, 42 chars) |

---

#### `GetOffer`
Get details of a specific offer by ID.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `offerId` | integer | Yes | The offer ID to look up |

---

#### `GetPosition`
Get details of a specific position by ID.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `positionId` | integer | Yes | The position ID to look up |

---

#### `GetOfferHistory`
Get the chronological event history for a specific offer.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `offerId` | integer | Yes | The offer ID to get history for |

---

#### `GetPositionHistory`
Get the chronological event history for a specific position.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `positionId` | integer | Yes | The position ID to get history for |

---

#### `GetWalletHistory`
Get all events for a wallet address.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Wallet address (0x-prefixed, 42 chars) |

---

#### `GetPositionsForSale`
Get positions listed for secondary market sale, optionally filtered by symbol.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | No | Filter by underlying symbol. Leave empty for all. |
| `skip` | integer | No | Number of results to skip for pagination (default: 0) |
| `take` | integer | No | Maximum number of results to return (default: 50) |

---

#### `GetBalance`
Get the fiat balance for a wallet address.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Wallet address (0x-prefixed, 42 chars) |

---

#### `CheckTxStatus`
Check the status of an async blockchain transaction by tracking ID. Use this to poll after submitting a write operation. Statuses: Queued → Mining → Mined (success) or Failed.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `trackingId` | string | Yes | The tracking GUID returned from a write operation |

---

#### `GetSettings`
Get user settings, permissions, balances, market schedule, and KYC status.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Wallet address (0x-prefixed, 42 chars) |

---

#### `GetMarketSchedule`
Get the current market schedule — next open/close times and time remaining.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Wallet address (0x-prefixed, 42 chars) |

---

### Public Market Data Tools (No Authentication Required)

These tools return cached market data and do not require a bearer token.

#### `GetMarketData`
Get real-time quote data for a symbol: last, close, open, high, low, volume, bid, ask, change.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | Yes | Symbol to look up (e.g. FMST, BREA) |

---

#### `GetOrderbook`
Get the bid/ask depth for a symbol.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | Yes | Symbol to look up |

---

#### `GetTimeAndSales`
Get the time-and-sales trade tape for a symbol.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | Yes | Symbol to look up |
| `pageStart` | integer | No | Pagination start offset |

---

#### `GetSecurityPortfolio`
Get a wallet's security holdings (stocks, tokens, options). Does not require authentication.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Wallet address (0x-prefixed, 42 chars) |

---

#### `GetOptionsMarket`
Get all options contracts with strikes, premiums, and open interest.

**Parameters:** None

---

#### `GetNews`
Get news articles, optionally filtered by symbol.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | No | Filter by symbol. Leave empty for all news. |

---

#### `GetWarrants`
Get warrant contracts for a symbol.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | Yes | Symbol to look up |

---

#### `GetClosingReport`
Get end-of-day closing prices for a record date, optionally filtered by symbol.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `recordDate` | string | Yes | Record date (YYYY-MM-DD) |
| `symbol` | string | No | Filter by symbol. Leave empty for all. |

---

#### `GetTokenDetails`
Look up the on-chain token contract address and metadata for a symbol. Use the returned `tokenAddress` as input to `sign_transfer_tokens`.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `symbol` | string | Yes | Token symbol (e.g. BREA, FMST) |
| `address` | string | Yes | Wallet address (0x-prefixed, 42 chars) |

**Returns:** `{ tokenAddress, tokenSymbol, tokenIssuer, tokenType, currency, totalSupply, currentPrice, bestBid, bestOffer, canBuy, canSell }`

---

#### `Faucet`
Top up a wallet with test USD. *(Test environments only.)*

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Wallet address to fund |
| `amount` | number | Yes | Amount of test USD to add |

---

### Write Tools (11)

All write tools require `address`, `callInfo`, and `signature` from the local signer. Each is protected by two layers of server-side validation before reaching the blockchain:

1. **Signature verification** — Recovers the signer from (callInfo, signature) and rejects if it doesn't match `address`.
2. **CallInfo cross-validation** — Decodes the ABI-encoded callInfo and verifies that embedded values (ecId, address, side, strikePrice, premium, quantity, collateral, writerFee, expiry, etc.) match the corresponding request parameters. This catches bugs where signed calldata was produced with different values than the submission (e.g., a stale expiry).

If cross-validation fails, the tool returns a `CALLINFO_VALIDATION_ERROR` listing every mismatched field *before* the API call is made.

#### `CreateOffer`
Create a new fixed-return option offer.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Writer wallet address (0x-prefixed, 42 chars) |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool (0x hex) |
| `signature` | string | Yes | ECDSA signature from signing tool (0x hex) |
| `eventContractId` | integer | Yes | Event contract ID on the smart contract |
| `side` | string | Yes | Side: Yes or No |
| `underlyingSymbol` | string | Yes | Underlying asset symbol (e.g. AAPL, BTC) |
| `strikePrice` | number | Yes | Strike price in fiat |
| `premium` | number | Yes | Premium per contract in fiat |
| `quantity` | integer | Yes | Number of contracts to offer |
| `collateral` | number | Yes | Total collateral locked by writer |
| `writerFee` | number | Yes | Writer fee in fiat |
| `expiry` | string | Yes | Offer expiry (ISO 8601 UTC, e.g. 2025-12-31T23:59:59Z) |
| `marketId` | integer | No | Optional market ID to associate with |
| `displayLabel` | string | No | Optional display label |

---

#### `PurchaseOffer`
Purchase contracts from an existing offer.

**IMPORTANT**: `positionEcId` and `offerEcId` are two **different** EC IDs — do NOT pass the same value for both. `positionEcId` is the new position's EC ID (from `sign_purchase` `posEcId`), `offerEcId` is the offer's EC ID (from `sign_purchase` `offerEcId`).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Buyer wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `positionEcId` | integer | Yes | Position EC ID for the new position (must differ from offerEcId) |
| `offerEcId` | integer | Yes | Offer EC ID being purchased from |
| `offerId` | integer | Yes | Offer ID to purchase from |
| `quantity` | integer | Yes | Number of contracts to purchase |

---

#### `CancelOffer`
Cancel an unfilled offer (writer only).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Writer wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `eventContractId` | integer | Yes | Event contract ID |
| `offerId` | integer | Yes | Offer ID to cancel |

---

#### `ExercisePosition`
Exercise a held position (holder only, must be exercisable).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Position holder wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `eventContractId` | integer | Yes | Event contract ID |
| `positionId` | integer | Yes | Position ID to exercise |

---

#### `TransferPosition`
Transfer a position to a new holder (secondary market direct transfer).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Current holder wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `eventContractId` | integer | Yes | Event contract ID |
| `positionId` | integer | Yes | Position ID to transfer |
| `newHolder` | string | Yes | New holder wallet address |
| `salePrice` | number | Yes | Sale price in fiat |
| `buyerFee` | number | Yes | Buyer fee in fiat |
| `sellerProceeds` | number | Yes | Net proceeds to seller in fiat |

---

#### `ListForSale`
List a position for secondary market sale at an asking price.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Position holder wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from `sign_list_for_sale` |
| `signature` | string | Yes | ECDSA signature from `sign_list_for_sale` |
| `positionId` | integer | Yes | Position ID to list for sale |
| `askingPrice` | number | Yes | Asking price in fiat |

---

#### `DelistForSale`
Remove a position from secondary market sale.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Position holder wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from `sign_delist_for_sale` |
| `signature` | string | Yes | ECDSA signature from `sign_delist_for_sale` |
| `positionId` | integer | Yes | Position ID to delist |

---

#### `PurchaseSecondary`
Purchase a position from the secondary market. Server computes fees from the asking price.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Buyer wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `eventContractId` | integer | Yes | Event contract ID |
| `positionId` | integer | Yes | Position ID to purchase |

---

#### `CreateMarket`
Create a new prediction market with a title, category, and optional resolution details.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Market creator wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `title` | string | Yes | Market title/question |
| `category` | string | Yes | Market category (e.g. Crypto, Stocks) |
| `description` | string | No | Detailed description |
| `resolutionCriteria` | string | No | Criteria for resolving the market |
| `resolutionSource` | string | No | Source for resolution (e.g. CoinGecko) |
| `resolutionDate` | string | No | Resolution date (ISO 8601 UTC) |

---

### Transfer Tools

These tools perform **synchronous** on-chain transfers — they wait for the transaction to be mined and return the result directly. No `CheckTxStatus` polling is needed.

#### `TransferDollars`
Transfer USD between wallets. Signature is validated against the `DOLLAR_CONTRACT_ADDRESS` configured on the remote MCP server.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Sender wallet address (0x-prefixed, 42 chars) |
| `callInfo` | string | Yes | ABI-encoded call data from `sign_transfer_dollars` |
| `signature` | string | Yes | ECDSA signature from `sign_transfer_dollars` |
| `toAddress` | string | Yes | Recipient wallet address (0x-prefixed, 42 chars) |
| `amount` | number | Yes | Amount in dollars to transfer |

---

#### `TransferTokens`
Transfer security tokens between wallets. The remote MCP server dynamically looks up the token contract address via `GetTokenDetails` for signature validation.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Sender wallet address (0x-prefixed, 42 chars) |
| `callInfo` | string | Yes | ABI-encoded call data from `sign_transfer_tokens` |
| `signature` | string | Yes | ECDSA signature from `sign_transfer_tokens` |
| `toAddress` | string | Yes | Recipient wallet address (0x-prefixed, 42 chars) |
| `symbol` | string | Yes | Token symbol (e.g. BREA, FMST) |
| `quantity` | integer | Yes | Number of tokens to transfer |

---

### Admin Tools (4)

These tools require admin-level authorization.

#### `AdminSetExercisable`
Mark an offer as exercisable or not.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `offerId` | integer | Yes | Offer ID to update |
| `isExercisable` | boolean | Yes | True to mark exercisable |

---

#### `AdminSettle`
Settle a single position with a specified payout amount.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `positionId` | integer | Yes | Position ID to settle |
| `payout` | number | Yes | Payout amount in fiat |

---

#### `AdminBatchSettle`
Batch settle multiple positions in a single transaction.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `settlementsJson` | string | Yes | JSON array of settlements: `[{"positionId":1,"payout":100.00}]` |

---

#### `AdminReleaseCollateral`
Release collateral back to the writer after all positions have been settled. Requires signing.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `eventContractId` | integer | Yes | Event contract ID |
| `offerId` | integer | Yes | Offer ID to release collateral for |

---

## 1X2 API Tools (18 tools)

These tools call the **1X2 Function App** (`ONEX2_API_BASE_URL`) for three-outcome event betting. Unlike the EC write tools above, **no client-side signing is required** — the 1X2 API handles all blockchain signing server-side. Authentication is via the same S2S bearer token passed in `bearerToken`.

### User Management

#### `OneX2CreateUser`
Register a new retail user. Generates a Web3 key pair, submits KYC, and enables the wallet for trading.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `web2UserId` | string | Yes | Unique user ID within the member's scope (1–100 chars) |
| `dateOfBirth` | string | Yes | ISO date (YYYY-MM-DD), user must be 18+ |
| `domicile` | string | Yes | ISO 3166-1 alpha-2 country code |
| `memberKycCertified` | boolean | Yes | Must be `true` |
| `firstName` | string | No | User's first name |
| `lastName` | string | No | User's last name |
| `email` | string | No | User's email address |
| `phoneNumber` | string | No | User's phone number |
| `nationality` | string | No | ISO 3166-1 alpha-2 country code |
| `profilePictureUrl` | string | No | URL to profile picture (downloaded server-side) |
| `identityDocumentUrl` | string | No | URL to identity document (downloaded server-side) |
| `utilityBillUrl` | string | No | URL to utility bill (downloaded server-side) |
| `videoInterviewUrl` | string | No | URL to video interview (downloaded server-side) |

---

#### `OneX2PauseUser`
Temporarily suspend a user's trading ability (consumer protection).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | User wallet address |
| `durationSeconds` | integer | Yes | Pause duration in seconds; 0 = indefinite |

---

### Money Management

#### `OneX2OmnibusTransaction`
Credit or debit the member's omnibus account. Positive = credit, negative = debit.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `amount` | number | Yes | Amount (positive = credit, negative = debit; non-zero) |
| `memberReference` | string | Yes | Free text reference for reconciliation (1–200 chars) |

---

#### `OneX2TransferMoney`
Move funds between the member's omnibus account and a user wallet.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `userWallet` | string | Yes | User wallet address |
| `amount` | number | Yes | Positive = omnibus→user, negative = user→omnibus |

---

### Event Lifecycle

#### `OneX2ListEvent`
Create a new 1X2 event with three outcomes (Home Win / Draw / Away Win).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `category` | string | Yes | Event category (e.g. football) |
| `homeLabel` | string | Yes | Home team/participant name |
| `awayLabel` | string | Yes | Away team/participant name |
| `eventType` | string | Yes | e.g. "1X2 - Full Time", "1X2 - First Half" |
| `settleDate` | string | Yes | ISO 8601 UTC; must be in the future |

---

#### `OneX2GetEvent`
Get event details including status and summary of all three outcomes.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `eventId` | integer | Yes | The 1X2 event ID |

---

### Order Management

#### `OneX2Maker`
Create a maker order on a specific outcome. Collateral = quantity × makerProbability. Fee = 1% of collateral.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | User wallet (must belong to this member) |
| `eventId` | integer | Yes | The 1X2 event ID |
| `outcome` | string | Yes | `"1"` (Home), `"X"` (Draw), or `"2"` (Away) |
| `makerProbability` | number | Yes | Implied probability (0.01–0.99) |
| `quantity` | integer | Yes | Number of contracts; multiple of 100 |
| `expiry` | string | Yes | ISO 8601 UTC; must not exceed settle date |

---

#### `OneX2Taker`
Take (buy) contracts from an existing maker order. Payment = quantity × (1 - makerProbability). Fee = 1% of payment.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | User wallet (must belong to this member) |
| `orderId` | integer | Yes | Maker order ID to take from |
| `quantity` | integer | Yes | Contracts to take; multiple of 100, ≤ remaining |

---

#### `OneX2Cancel`
Cancel an unfilled maker order. Returns collateral + fee to the maker.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Must be the order creator's wallet |
| `orderId` | integer | Yes | Maker order ID to cancel |

---

#### `OneX2Void`
Void a taker position. Returns collateral + fees to both maker and taker.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `positionId` | integer | Yes | Position ID to void |
| `reason` | string | No | Free text reason for audit trail |

---

#### `OneX2SecondaryMaker`
List an existing position for resale on the secondary market.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Must be the position holder's wallet |
| `positionId` | integer | Yes | Position ID to list for resale |
| `makerProbability` | number | Yes | Asking price as probability (0.01–0.99) |
| `quantity` | integer | Yes | Must match position quantity (V1: full position only) |

---

### Settlement

#### `OneX2SettleEvent`
Declare the outcome and settle all three event contracts in the 1X2 triplet.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `eventId` | integer | Yes | The 1X2 event ID to settle |
| `outcome` | string | Yes | `"1"` (Home), `"X"` (Draw), `"2"` (Away), or `"0"` (Void) |

---

### Query Endpoints

#### `OneX2Orderbook`
Get the full orderbook for a 1X2 event, organized by outcome.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `eventId` | integer | Yes | The 1X2 event ID |

---

#### `OneX2CashPosition`
Get the cash balance for a wallet.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Wallet address |

---

#### `OneX2OpenPositions`
Get all open positions for a wallet, grouped by 1X2 event.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Wallet address |

---

#### `OneX2ClosedPositions`
Get settled positions for a wallet within an optional date range.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Wallet address |
| `from` | string | No | Start date filter (ISO 8601 UTC) |
| `to` | string | No | End date filter (ISO 8601 UTC) |

---

#### `OneX2Exposure`
Calculate hypothetical P&L for a wallet's positions on an event across all three outcomes.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | Yes | Wallet address |
| `eventId` | integer | Yes | The 1X2 event ID |

---

### Orderbook Management

#### `OneX2PauseOrderbook`
Pause an event's orderbook (e.g. when a match starts). No new orders while paused.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `eventId` | integer | Yes | The 1X2 event ID |
| `durationSeconds` | integer | Yes | Pause duration in seconds; 0 = until settled |
| `rejectQueuedOrders` | boolean | No | If true, cancel pending unfilled orders |

---

## Native Tools (8 tools) — OpenOrderbook AI Client Only

These tools are built into the OpenOrderbook AI CLI client process. They are **not** part of either MCP server and are unavailable in VS Code + Copilot. They run locally and require no authentication.

### File System Tools

#### `read_file`
Read the contents of a file from the workspace directory.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | File path (relative to workspace or absolute) |

**Returns:** File contents as text.

---

#### `write_file`
Write content to a file in the workspace directory. Creates the file if it doesn't exist; overwrites if it does.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | File path (relative to workspace or absolute) |
| `content` | string | Yes | Content to write |

**Returns:** Confirmation message.

---

#### `list_directory`
List files and subdirectories in a directory.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Directory path (relative to workspace or absolute) |

**Returns:** List of entries with type indicators (file/directory).

---

### Web Access Tools

#### `web_search`
Search the web using DuckDuckGo and return results.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Search query |

**Returns:** Search results with titles and URLs.

---

#### `http_fetch`
Fetch the content of a URL via HTTP GET.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | string | Yes | URL to fetch |

**Returns:** Response body as text.

---

### Profile Management Tools

#### `list_profiles`
List all available user profiles. Scans for `config.*.json` files in `~/.openorderbook-ai/`.

**Parameters:** None

**Returns:** List of profile names and which one is currently active.

---

#### `switch_profile`
Switch to a different user profile. Saves the current config, loads the target profile's config, reconnects the local signer MCP with the new keystore/credentials, refreshes wallet address, clears the bearer token cache, and resets chat history.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Profile name to switch to (e.g., "Brian") |

**Returns:** Confirmation with new wallet address and profile name.

---

#### `create_profile`
Save the current configuration as a new named profile. Creates `config.{name}.json` in `~/.openorderbook-ai/`.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Profile name to create |

**Returns:** Confirmation with file path.
