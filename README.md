<p align="center">
  <img src="src/free_claude_code/api/admin_static/brand/funtikstore-logo.png" width="380" alt="FUNTIKSTORE" />
</p>

# FUNTIKSTORE — Opus 5.5

Local NVIDIA NIM setup for Claude Code, with a FUNTIKSTORE local control panel.

> **Backend disclosure:** this project stores your NVIDIA NIM API key locally and routes requests through the NVIDIA NIM configuration. It does not provide Anthropic API access, an Anthropic subscription, or a guarantee of access to any particular Claude model.

## Install

Choose your system, open its terminal, paste one command, and press Enter.

### Windows

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/kesha666-opt/opus5.5/main/scripts/install-windows.ps1 | iex
```

### macOS

Open **Terminal** and run:

```sh
curl -fsSL https://raw.githubusercontent.com/kesha666-opt/opus5.5/main/scripts/install-macos.sh | sh
```

### Linux

Open **Terminal** and run:

```sh
curl -fsSL https://raw.githubusercontent.com/kesha666-opt/opus5.5/main/scripts/install-linux.sh | sh
```

The installer starts the private local panel at [http://127.0.0.1:8182/admin](http://127.0.0.1:8182/admin). Paste your own NVIDIA API key there; it is stored only on your computer in `~/.opus5.5`.

Then open a second terminal and run:

```sh
fcc-opus
```

## Local commands

```sh
# Start the local server
fcc-server

# Start Claude Code through the local server
fcc-opus
```

The setup panel is available only while `fcc-server` is running and only from the same computer.

## License

Distributed under the [GNU Affero General Public License v3.0](LICENSE).
