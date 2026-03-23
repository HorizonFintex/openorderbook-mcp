# Tools Reference

Complete reference for all MCP tools available in the OpenOrderbook system.

## Local Signer MCP Tools (14 tools)

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
Acquire an S2S bearer token from Azure AD B2C using client_credentials flow (MSAL). All config is read from environment variables. Returns the access token and expiry.

**Parameters:** None

**Environment Variables Required:** `FRO_TENANT_ID`, `FRO_CLIENT_ID`, `FRO_CLIENT_SECRET`, `FRO_SCOPE`

**Returns:** `{ accessToken, expiresIn, environment }`

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

## Remote MCP Tools (23 tools)

These tools are exposed by the `fro-uat` remote MCP server hosted on Azure. All tools accept an optional `bearerToken` parameter for authentication.

### Read Tools (10)

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

### Write Tools (9)

All write tools require `address`, `callInfo`, and `signature` from the local signer. Each is protected by server-side signature verification — invalid signatures are rejected before reaching the blockchain.

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

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | Yes | Buyer wallet address |
| `callInfo` | string | Yes | ABI-encoded call data from signing tool |
| `signature` | string | Yes | ECDSA signature from signing tool |
| `eventContractId` | integer | Yes | Event contract ID |
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
