# Verification Notes — October 9, 2026

## Confirmed

- The product and package use the `Opus 5.5` / `opus5.5` name.
- Its settings live in `~/.opus5.5` and its local service uses `127.0.0.1:8182`. The original FCC installation at `~/.fcc` and port `8082` is separate.
- The `/admin` page contains a password-type key field. Keys are masked, and rejected keys are not saved.
- The Windows, macOS, and Linux installers check `/health` and `/admin`. The familiar commands are `fcc-server` and `fcc-opus`.
- GitHub Actions confirmed a clean install, server health, setup page, and client version check on Windows, macOS, and Ubuntu at merge commit `0766e444cde30d054d291d9098440321f54547d6`.
- The full test suite passed on macOS and Ubuntu at that commit. The Windows full-suite run still has test-environment failures; this does not change the successful Windows installer smoke test.

## Limitations

- Automated installation checks do not use a customer NVIDIA API key or make a live model-generation request. Enter a key locally in the setup page to validate provider access.
- Windows PowerShell execution was verified in GitHub Actions; the development Mac does not include PowerShell for a separate local run.

## License

This project modifies [Free Claude Code](https://github.com/Alishahryar1/free-claude-code), upstream commit `9194f157af6beb663cf3e6035f9cdadb09e8917b`, by Ali Khokhar. See [AGPL-3.0-only](LICENSE) and [NOTICE](NOTICE).
