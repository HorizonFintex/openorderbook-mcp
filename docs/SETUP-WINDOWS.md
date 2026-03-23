# Windows Setup Guide

## 1. Clone or Download the Repository

Clone the repository or download and unzip from GitHub:

```powershell
git clone https://github.com/HorizonFintex/openorderbook-mcp.git
```

The pre-built binary for Windows is in `releases\win-x64\`.

> **Note:** Windows Defender SmartScreen may warn about an unrecognized publisher the first time you run the binary. Click "More info" → "Run anyway".

## 2. Note the Binary Path

You'll need the full path to the binary for your MCP config. For example:

```
C:\dev\openorderbook-mcp\releases\win-x64\OpenOrderbookSignerMcp.exe
```

> **Important:** The `Contracts\` folder next to the binary must stay in place — the signer loads contract ABIs from it at startup.

## 3. Prepare Your Keystore

Place your Ethereum V3 keystore JSON file in a secure location:

```powershell
New-Item -ItemType Directory -Path $env:USERPROFILE\keys -Force
Move-Item keystore.json $env:USERPROFILE\keys\
```

## 4. Create Your Workspace

VS Code works with **folders** — a folder you open becomes your "workspace". All MCP configuration lives inside that folder.

The workspace is **separate from the cloned repo**. You create a new empty folder for your workspace, then copy the MCP config template from the cloned repo into it.

Create a directory to use as your trading workspace:

```powershell
New-Item -ItemType Directory -Path C:\fro-workspace -Force
```

Then open it in VS Code:

1. Launch VS Code
2. Go to **File → Open Folder…** (or press `Ctrl+K Ctrl+O`)
3. Navigate to the `fro-workspace` folder you just created and click **Select Folder**

This is now your workspace. The MCP config file will go inside a `.vscode` subfolder here.

> **Tip:** You can name the folder anything you like — `fro-workspace` is just a suggestion. You'll use this same folder each time you open VS Code to trade.

## 5. Configure MCP

From your workspace folder, copy the template config:

```powershell
cd C:\fro-workspace
New-Item -ItemType Directory -Path .vscode -Force
Copy-Item C:\dev\openorderbook-mcp\config\mcp.json.template .vscode\mcp.json
```

Open `.vscode/mcp.json` **inside VS Code** (click it in the Explorer panel — do not use Notepad or another external editor, as VS Code detects MCP config changes automatically).

Fill in your values:

```jsonc
{
  "servers": {
    "fro-local-signer": {
      "type": "stdio",
      "command": "C:\\dev\\openorderbook-mcp\\releases\\win-x64\\OpenOrderbookSignerMcp.exe",
      "env": {
        "FRO_EVENT_CONTRACT_ADDRESS": "0x30a803902D381696942C1a369205b6144fC5772f",
        "FRO_ENVIRONMENT": "UAT",
        "FRO_KEYSTORE_PATH": "C:\\Users\\yourname\\keys\\keystore.json",
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
- `C:\\dev\\openorderbook-mcp\\releases\\win-x64\\OpenOrderbookSignerMcp.exe` — full path to the binary
- `C:\\Users\\yourname\\keys\\keystore.json` — full path to your keystore file
- `<your-keystore-password>` — your keystore decryption password
- `<your-client-secret>` — Azure AD B2C client secret (from your team lead)

> **IMPORTANT — Double backslashes:** All Windows paths in JSON must use `\\` (double backslash), not `\` (single backslash). For example:
> - ✅ `"C:\\Dev\\openorderbook-mcp\\releases\\win-x64\\OpenOrderbookSignerMcp.exe"`
> - ❌ `"C:\Dev\openorderbook-mcp\releases\win-x64\OpenOrderbookSignerMcp.exe"`
>
> A single backslash is treated as a JSON escape character and will cause the path to be invalid.

> **IMPORTANT:** Never commit `.vscode/mcp.json` — it contains secrets. The `.gitignore` already excludes it.

## 6. Start the MCP Servers

Close and reopen VS Code (or reload: `Ctrl+Shift+P` → "Developer: Reload Window").

VS Code will discover both MCP servers:
- **fro-local-signer** — the local signing binary
- **fro-uat** — the remote Azure MCP server

**You must start both servers manually:**

1. Open the MCP servers panel (look for the MCP icon in the sidebar, or use `Ctrl+Shift+P` → "MCP: List Servers")
2. You should see both **fro-local-signer** and **fro-uat** listed
3. Click **Start** on each server
4. Wait until both show a **Running** status (a green indicator) before proceeding

> **Note:** Both servers must be running before you can use any trading commands. If either shows an error, check the server output for details.

## 7. Verify Setup

Open Copilot chat and ask:

> "Check signer status"

You should see:
```json
{
  "loaded": true,
  "address": "0x34ad7f0f98ae577db6abcc1e5f9a31e74a42d663",
  "eventContractAddress": "0x30a803902D381696942C1a369205b6144fC5772f",
  "environment": "UAT"
}
```

Then try:

> "Show me all FRO offers"

Copilot will automatically acquire a bearer token (via `acquire_bearer_token`) and then call `GetMarket` to fetch the results. This confirms the remote MCP connection is working.

## 8. Your First Trade

Ask Copilot:

> "Create a Yes offer on FMST at strike $100, premium $5, 2 contracts, collateral $200, writer fee $1, expiring tomorrow"

Copilot will sign locally, authenticate, submit to the remote MCP, and poll for blockchain confirmation.

## Troubleshooting

### Windows Defender SmartScreen warning
Click "More info" → "Run anyway". This happens because the binary isn't code-signed.

### "Signer not loaded"
Check that `FRO_KEYSTORE_PATH` points to a valid file and `FRO_KEYSTORE_PASSWORD` is correct. Use double backslashes in JSON paths.

### "Auth not configured"
Ensure all four auth env vars (`FRO_TENANT_ID`, `FRO_CLIENT_ID`, `FRO_CLIENT_SECRET`, `FRO_SCOPE`) are set.

### "Token acquisition failed"
- Verify `FRO_CLIENT_SECRET` is correct and not expired
- Check internet connectivity

### Binary won't start at all
- Check that the `Contracts\Multilisting\Artifacts\` folder is next to the `.exe`
- Try running it directly in a terminal to see error output

### Path issues
- Always use double backslashes in JSON: `C:\\Users\\...`
- Use the full absolute path including drive letter
