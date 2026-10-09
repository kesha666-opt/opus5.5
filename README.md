# Opus 5.5

Run Claude Code with your NVIDIA API key on Windows, macOS, or Linux.

<p align="center">
  <a href="#windows"><img alt="Windows 10 and 11" src="https://img.shields.io/badge/Windows%2010%20%2F%2011-Install-0078D4?logo=windows&logoColor=white"></a>
  <a href="#macos"><img alt="macOS" src="https://img.shields.io/badge/macOS-Install-222222?logo=apple&logoColor=white"></a>
  <a href="#linux"><img alt="Linux" src="https://img.shields.io/badge/Linux-Install-FCC624?logo=linux&logoColor=black"></a>
</p>

Choose your operating system above, then copy the single command in its section. Use the copy button at the top-right of the code block.

## Install

### Windows

1. Open **Windows Terminal** or **PowerShell**.
2. Copy this command, paste it, and press Enter:

```powershell
irm https://raw.githubusercontent.com/kesha666-opt/opus5.5/main/scripts/install.ps1 | iex
```

No Python, Git, or `winget` setup is required. The installer prepares Git Bash and the required components for you.

### macOS

1. Open **Terminal**.
2. Copy this command, paste it, and press Enter:

```sh
curl -fsSL https://raw.githubusercontent.com/kesha666-opt/opus5.5/main/scripts/install.sh | sh
```

### Linux

1. Open your terminal.
2. Copy this command, paste it, and press Enter:

```sh
curl -fsSL https://raw.githubusercontent.com/kesha666-opt/opus5.5/main/scripts/install.sh | sh
```

The installer starts Opus 5.5 and opens the setup page at <http://127.0.0.1:8182/admin>.

## Connect your NVIDIA API key

Enter your NVIDIA API key on the setup page and select **Save and continue**. Do not paste the key into the terminal or share it in chat.

After the key is verified, open two terminal windows:

In the first window, start the server and keep it open:

```sh
fcc-server
```

In the second window, start Claude Code:

```sh
fcc-opus
```

The server's green status confirms the local service is running. The green indicator on the setup page appears after NVIDIA accepts the key. Use the setup page address above; do not open a downloaded HTML file.

Claude Code is the client. The configured model is `moonshotai/kimi-k3`, served through the NVIDIA API.

## Response speed

Requests use the fast `low` reasoning mode by default. For a more involved task, you can select a higher effort:

```sh
fcc-opus --effort high
```

Response time depends on NVIDIA service load and task size. The `high` and `max` modes take longer. NVIDIA controls service availability and quotas; this installer does not provide an Anthropic subscription or unlimited requests.

The installers support Windows, macOS, and Linux. Installing the terminal client directly on iPhone or iPad is not supported.

## If the setup page does not open

Open your browser and go to <http://127.0.0.1:8182/admin>.

## Reinstall or update

Run the same install command again. If the installer reports that port 8182 is in use or another installation already exists, stop the existing Opus 5.5 server and rerun the command. Do not delete files manually.

## License

This project modifies [Free Claude Code](https://github.com/Alishahryar1/free-claude-code), upstream commit `9194f157af6beb663cf3e6035f9cdadb09e8917b`, by Ali Khokhar. Licensed under [AGPL-3.0-only](LICENSE). See [NOTICE](NOTICE).
