# Contributing

Thank you for helping improve Lenovo Vantage for Linux.

## Getting started
- Use X11 when developing or testing (touchpad controls rely on xinput).
- Run `make lint` and `make format` before submitting changes.
- Use `./scripts/self-check.sh` to validate dependencies on your test machine.

## Coding standards
- Shell scripts must pass ShellCheck and shfmt (`shfmt -i 4 -ci -bn`).
- Quote variables, avoid backticks, and guard privileged operations with confirmations.
- Prefer small, reviewable changesets with clear commit messages.

## Testing changes
- Manual sanity check: run `vantage`, toggle one setting per category (power, input, radio) on supported hardware.
- For installation changes, run `make dry-run` first, then `sudo make install` on a disposable environment.

## Pull requests
- Describe the problem and the fix clearly.
- Note any limitations (e.g., Wayland not supported) in the PR description.
- Update documentation and changelog entries when user-facing behavior changes.
