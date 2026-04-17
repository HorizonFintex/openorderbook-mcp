# macOS Setup — OpenOrderbook AI Client

Setup guide for running the OpenOrderbook AI client locally on a Mac.

---

## 1. Clone the Repository

### Get a Personal Access Token (PAT)

1. Log in to [horizonfintex.ghe.com](https://horizonfintex.ghe.com)
2. Click your avatar (top-right) → **Settings**
3. Scroll down the left sidebar → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
4. Click **Generate new token (classic)**
5. Give it a name (e.g. `openorderbook-mcp`) and set an expiry
6. Under **Select scopes**, tick **`repo`** (read access is sufficient)
7. Click **Generate token** — copy it immediately, it won't be shown again

### Clone

```bash
git clone https://horizonfintex.ghe.com/horizon/openorderbook-mcp.git
cd openorderbook-mcp
```


> Contact your administrator if your account doesn't have access to the `horizon` org.

---

## 2. Make Binaries Executable

> **Which chip?** Apple menu → About This Mac. "Apple M…" = arm64. "Intel" = x64.

**Apple Silicon (M1/M2/M3/M4):**
```bash
chmod +x releases/osx-arm64/OpenOrderbookAi
chmod +x releases/osx-arm64/OpenOrderbookSignerMcp
xattr -d com.apple.quarantine releases/osx-arm64/OpenOrderbookAi
xattr -d com.apple.quarantine releases/osx-arm64/OpenOrderbookSignerMcp
```

**Intel Mac:**
```bash
chmod +x releases/osx-x64/OpenOrderbookAi
chmod +x releases/osx-x64/OpenOrderbookSignerMcp
xattr -d com.apple.quarantine releases/osx-x64/OpenOrderbookAi
xattr -d com.apple.quarantine releases/osx-x64/OpenOrderbookSignerMcp
```

The `xattr` step is required — macOS blocks unsigned binaries downloaded from the internet without it.

---

## 3. Place Your Keystore File

You will be provided with an Ethereum keystore file. Place it somewhere safe:

```bash
mkdir -p ~/keys
mv keystore_UAT_iOS_Upstream_71c.txt ~/keys/
chmod 600 ~/keys/keystore_UAT_iOS_Upstream_71c.txt
```

---

## 4. First Run — Setup Wizard

Run the AI client:

```bash
# Apple Silicon:
./releases/osx-arm64/OpenOrderbookAi

# Intel:
./releases/osx-x64/OpenOrderbookAi
```

The setup wizard launches automatically on first run. Answer the prompts:

| Prompt | Value |
|--------|-------|
| **Provider** | `Anthropic` (or `Ollama` if you want free local inference — requires a powerful GPU) |
| **Anthropic API key** | Your `sk-ant-...` key from [console.anthropic.com](https://console.anthropic.com) |
| **Model** | Accept the default (`claude-sonnet-4-5`) |
| **Signer binary path** | Full path, e.g. `/Users/yourname/openorderbook-mcp/releases/osx-arm64/OpenOrderbookSignerMcp` |
| **Remote MCP URL** | `https://openorderbookmcp-uat.azurewebsites.net/api/mcp` |
| **Keystore path** | `/Users/yourname/keys/keystore_UAT_iOS_Upstream_71c.txt` |
| **Keystore password** | Your keystore password (provided separately) |
| **Azure AD Tenant ID** | `058820ef-8462-4935-a840-6e5582798862` |
| **Azure AD Client ID** | `ce48291b-5ea7-4f15-a5c4-78e6bbfffe89` |
| **Azure AD Client Secret** | Provided separately by your administrator |
| **Environment** | `UAT` |

Config is saved to `~/.openorderbook-ai/config.json`. Subsequent runs go straight to the REPL.

---

## 5. Verify Setup

Once in the REPL, run:

```
> check signer status
```

Expected output:
```
loaded: true
address: 0x365b...571c
environment: UAT
```

Then:

```
> what's my balance?
```

If you see a USD balance, everything is connected.

---

## 6. Subsequent Runs

```bash
./releases/osx-arm64/OpenOrderbookAi
```

No wizard — goes straight to the trading REPL.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "cannot be opened because the developer cannot be verified" | Run the `xattr -d com.apple.quarantine` command from step 2 |
| "Signer not loaded" | Check keystore path and password in `~/.openorderbook-ai/config.json` |
| 403 authentication error | Say "refresh my bearer token" in the REPL |
| "Token acquisition failed" | Verify `ClientSecret` in config — secrets expire; ask your admin for a fresh one |
| Re-run setup wizard | `./releases/osx-arm64/OpenOrderbookAi --setup` |
