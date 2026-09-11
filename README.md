# NewMachineSetup

Ansible playbook that bootstraps a fresh Mac (Apple Silicon or Intel) into my
working setup. Supersedes the old Linux-era `Dotfiles` repo.

## Quick start (fresh machine)

```bash
xcode-select --install                       # accept the GUI prompt, wait for it to finish
git clone <this-repo-url> ~/Projects/NewMachineSetup
cd ~/Projects/NewMachineSetup
./bootstrap.sh
```

`bootstrap.sh` installs Homebrew, installs Ansible, pulls the required Ansible
collection, then runs `site.yml` against `localhost`. No sudo password is needed.

When it finishes: open a new terminal (or `source ~/.bash_profile`), and if
iTerm2 was already open, quit and reopen it.

## What it does

| Area | Result |
|------|--------|
| Homebrew | installed if missing, then `brew update` |
| Formulae | `git`, `python`, `rbenv` + `ruby-build`, `nvm`, `awscli`, `docker` + `docker-compose` + `docker-buildx`, `colima`, `neovim` |
| Casks | `iterm2`, `docker-desktop`, `firefox`, `tidal`, `slack`, `claude`, `visual-studio-code` |
| Firefox | `policies.json` dropped into the app bundle so the 1Password extension auto-installs on first launch (`normal_installed` — you can still disable/remove it) |
| Shell | `/bin/bash` set as login shell; scrubbed `~/.bash_profile` dropped in; empty `~/.secrets` created for machine-local env vars |
| Git | scrubbed `~/.gitconfig` dropped in |
| Node | `nvm` + a default Node version (`--lts` by default) |
| Ruby | `rbenv` + `ruby-build`; a global Ruby is installed only if you set `ruby_version` in `vars.yml` |
| Neovim | `~/.config/nvim/init.vim` dropped in, Vundle cloned, `:PluginInstall` run headlessly (Ctrlp, Gruvbox, NERDTree, airline, gitgutter, ...) |
| iTerm2 | "Gruvbox" Dynamic Profile installed (Menlo 14, runs `/bin/bash --login`) and set as the default profile |
| VS Code | `jdinhlife.gruvbox` extension installed; `settings.json` dropped in |

### Gruvbox light/dark

Follows the macOS system appearance automatically, out of the box:

- **iTerm2** – the Gruvbox Dynamic Profile carries separate colour sets
  (`Use Separate Colors for Light and Dark Mode`); iTerm swaps them when the
  system toggles, live, no restart.
- **VS Code** – `window.autoDetectColorScheme: true` with
  `preferredDarkColorTheme = Gruvbox Dark Medium` /
  `preferredLightColorTheme = Gruvbox Light Medium`. Live.
- **Neovim** – `init.vim` reads `AppleInterfaceStyle` at launch and sets
  `background` accordingly. This is **startup-only**; switching the system theme
  while nvim is open won't repaint it (add `f-person/auto-dark-mode.nvim` if you
  want that). Standalone `GruvboxDark.itermcolors` / `GruvboxLight.itermcolors`
  presets are also copied into `~/Library/Application Support/iTerm2/` for manual import.

Existing `~/.bash_profile`, `~/.gitconfig`, `~/.config/nvim/init.vim` and VS Code
`settings.json` are backed up (`.NNNN~` suffix) before being overwritten.

## Running just part of it

```bash
ansible-playbook site.yml --tags neovim
ansible-playbook site.yml --tags "packages,vscode"
ansible-playbook site.yml --list-tags
```

Tags: `homebrew packages firefox git shell languages neovim iterm vscode`.

## Config sources

Everything deployed lives under `files/` and is scrubbed of secrets and
machine-specific paths:

- `files/bash_profile` – aliases, prompt, Homebrew/nvm/rbenv init. API keys are
  **not** here; they belong in `~/.secrets` (git-ignored, sourced at the end).
- `files/gitconfig` – user name/email, aliases, LFS filters, `editor = nvim`.
- `files/nvim/init.vim` – Vundle plugin list + settings. Gruvbox via
  `morhetz/gruvbox`, Ctrlp via the maintained `ctrlpvim/ctrlp.vim` fork.
- `files/vscode/settings.json` – auto light/dark Gruvbox, tab size, rulers,
  whitespace, plus the terminal/python prefs carried over from the current machine.
- `files/firefox/policies.json` – enterprise policy that force-adds the
  1Password extension (`ExtensionSettings`); no secrets involved.
- `files/iterm/gruvbox.json` – iTerm2 Dynamic Profile.
- `files/iterm/GruvboxDark.itermcolors` – the same palette as an importable preset.

To update a config: edit the file in `~/`, copy the change back into `files/`,
commit.

## Manual steps the playbook can't do

- **Sign in** to Slack, Tidal, Claude, Firefox Sync, VS Code (Settings Sync), AWS (`aws configure`).
- **1Password**: the extension auto-installs into Firefox, but you still sign in to
  your 1Password account by hand (Ansible never touches credentials).
- **iTerm2 → "Make iTerm2 the default terminal"** if you want it to own the
  `open` / Terminal role (System Settings has no scriptable switch for this).
- First `docker` run: start **Docker Desktop** once, or `colima start`.
- Gatekeeper may prompt on first launch of a cask app.
- Set `ruby_version` in `vars.yml` and re-run `--tags languages` to install Ruby.

## Notes

- `homebrew_prefix` auto-selects `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel).
- Re-running is safe; tasks are idempotent.
- `community.general` is the only external Ansible dependency (`requirements.yml`).
