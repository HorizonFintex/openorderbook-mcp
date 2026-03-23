# macOS Setup Guide

## 1. Clone or Download the Repository

```bash
git clone https://github.com/user/openorderbook-mcp.git
```

Or download and unzip from GitHub. The pre-built binary for your Mac is in the `releases/` folder.

> **Tip:** Not sure which chip? Apple menu → About This Mac. If it says "Apple M1/M2/M3/M4", use `osx-arm64`. If it says "Intel", use `osx-x64`.

## 2. Make It Executable

```bash
# Apple Silicon (M1/M2/M3/M4):
chmod +x openorderbook-mcp/releases/osx-arm64/OpenOrderbookSignerMcp

# Intel Mac:
chmod +x openorderbook-mcp/releases/osx-x64/OpenOrderbookSignerMcp
```

## 3. Remove macOS Gatekeeper Quarantine

macOS blocks unsigned binaries downloaded from the internet. Remove the quarantine flag:

```bash
# Apple Silicon:
xattr -d com.apple.quarantine openorderbook-mcp/releases/osx-arm64/OpenOrderbookSignerMcp

# Intel:
xattr -d com.apple.quarantine openorderbook-mcp/releases/osx-x64/OpenOrderbookSignerMcp
```

If you skip this step, you'll get a "cannot be opened because the developer cannot be verified" error.

## 4. Note the Binary Path

You'll need the full path to the binary for your MCP config. For example, if you cloned to your home directory:

```bash
# Apple Silicon:
/Users/yourname/openorderbook-mcp/releases/osx-arm64/OpenOrderbookSignerMcp

# Intel:
/Users/yourname/openorderbook-mcp/releases/osx-x64/OpenOrderbookSignerMcp
```

> **Important:** The `Contracts/` folder next to the binary must stay in place — the signer loads contract ABIs from it at startup.

## 5. Prepare Your Keystore

You need an Ethereum V3 keystore JSON file. Your team lead will provide one. Place it somewhere safe:

```bash
mkdir -p ~/keys
mv keystore.json ~/keys/
chmod 600 ~/keys/keystore.json
```

## 6. Create Your Workspace

VS Code works with **folders** — a folder you open becomes your "workspace". All MCP configuration lives inside that folder.

Create a directory to use as your trading workspace:

```bash
mkdir -p ~/fro-workspace
```

Then open it in VS Code:

1. Launch VS Code
2. Go to **File → Open Folder…** (or press `Cmd+O`)
3. Navigate to the `fro-workspace` folder you just created and click **Open**

This is now your workspace. The MCP config file will go inside a `.vscode` subfolder here.

> **Tip:** You can name the folder anything you like — `fro-workspace` is just a suggestion. You'll use this same folder each time you open VS Code to trade.

## 7. Configure MCP

From your workspace folder, copy the template config:

```bash
cd ~/fro-workspace
mkdir -p .vscode
cp ~/openorderbook-mcp/config/mcp.json.template .vscode/mcp.json
```

Edit `.vscode/mcp.json` and fill in your values:

```jsonc
{
  "servers": {
    "fro-local-signer": {
      "type": "stdio",
      "command": "/Users/yourname/openorderbook-mcp/releases/osx-arm64/OpenOrderbookSignerMcp",
      "env": {
        "FRO_EVENT_CONTRACT_ADDRESS": "0x30a803902D381696942C1a369205b6144fC5772f",
        "FRO_ENVIRONMENT": "UAT",
        "FRO_KEYSTORE_PATH": "/Users/yourname/keys/keystore.json",
        "FRO_KEYSTORE_PASSWORD": "<your-keystore-password>",
        "FRO_TENANT_ID": "058820ef-8462-4935-a840-6e5582798862",
        "FRO_CLIENT_ID": "ce48291b-5ea7-4f15-a5c4-78e6bbfffe89",
        "FRO_CLIENT_SECRET": "<your-client-secret>",
        "FRO_SCOPE": "https://upstreamdev.onmicrosoft.com/mobileaccess-uat/.default"
      }
    },
    "fro-uat": {
      "type": "http",
      "url": "https://openorderbookmcp-uat.azurewebsites.net/api/mcp"
    }
  }
}
```

Replace:
- `/Users/yourname/openorderbook-mcp/releases/osx-arm64/OpenOrderbookSignerMcp` — full path to the binary (use `osx-x64` for Intel)
- `/Users/yourname/keys/keystore.json` — full path to your keystore file
- `<your-keystore-password>` — your keystore decryption password
- `<your-client-secret>` — Azure AD B2C client secret (from your team lead)

> **IMPORTANT:** Never commit `.vscode/mcp.json` — it contains secrets. The `.gitignore` already excludes it.

## 8. Restart VS Code

Close and reopen VS Code (or reload the window: `Cmd+Shift+P` → "Developer: Reload Window").

VS Code will discover both MCP servers:
- **fro-local-signer** — the local signing binary
- **fro-uat** — the remote Azure MCP server

## 9. Verify Setup

Open Copilot chat and ask:

> "Check signer status"

You should see a response like:
```json
{
  "loaded": true,
  "address": "0x34ad7f0f98ae577db6abcc1e5f9a31e74a42d663",
  "eventContractAddress": "0x30a803902D381696942C1a369205b6144fC5772f",
  "environment": "UAT"
}
```

Then try:

> "Show me the current FRO market"

This will call the remote MCP to fetch open offers, confirming everything is connected.

## 10. Your First Trade

Try asking Copilot:

> "Create a Yes offer on FMST at strike $100, premium $5, 2 contracts, collateral $200, writer fee $1, expiring tomorrow"

Copilot will:
1. Call `generate_ecid` to get a unique ID and expiry
2. Call `sign_create_offer` locally to sign the transaction
3. Call `acquire_bearer_token` to get an auth token
4. Call `CreateOffer` on the remote MCP with the signature
5. Call `CheckTxStatus` to poll until the transaction is confirmed

## Troubleshooting

### "cannot be opened because the developer cannot be verified"
Run `xattr -d com.apple.quarantine /path/to/openorderbook-mcp/releases/osx-arm64/OpenOrderbookSignerMcp`

### "Signer not loaded"
Check that `FRO_KEYSTORE_PATH` points to a valid file and `FRO_KEYSTORE_PASSWORD` is correct.

### "Auth not configured. Missing environment variables"
Ensure `FRO_TENANT_ID`, `FRO_CLIENT_ID`, `FRO_CLIENT_SECRET`, and `FRO_SCOPE` are all set in the `env` block.

### "Token acquisition failed"
- Verify `FRO_CLIENT_SECRET` is correct (they expire — get a fresh one from your team lead)
- Check your internet connection

### Binary won't start at all
- Verify you're using the correct architecture binary (arm64 vs x64)
- Check that the `Contracts/Multilisting/Artifacts/` folder is next to the binary
- Try running it directly in Terminal to see error output

### Remote MCP not connecting
- The remote server URL must be exactly: `https://openorderbookmcp-uat.azurewebsites.net/api/mcp`
- Ensure your network allows HTTPS outbound connections
