# Opus 5.5

Local NVIDIA API setup for Claude Code on macOS.

## Install on macOS

Open **Terminal**, paste this command, and press Return:

```sh
curl -fsSL https://raw.githubusercontent.com/kesha666-opt/opus5.5/main/scripts/install-macos.sh | sh
```

The installer starts the local setup page at [http://127.0.0.1:8182/admin](http://127.0.0.1:8182/admin).

1. Paste your NVIDIA API key into the page and select **Save and continue**.
2. Keep the first Terminal window open: it runs `fcc-server`.
3. Open a second Terminal window and run:

   ```sh
   fcc-opus
   ```

The key is stored locally in `~/.opus5.5` and is not sent to this repository.

## Commands

```sh
# Start the local server
fcc-server

# Start Claude Code through the local server
fcc-opus
```

The local panel is available at `http://127.0.0.1:8182/admin` while the server is running.

## License

This project is distributed under the [GNU Affero General Public License v3.0](LICENSE).
