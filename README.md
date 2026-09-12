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

`bootstrap.sh` installs Xcode Command Line Tools (if the manual step above
didn't already finish), Homebrew, Ansible, pulls the required Ansible
collection, then runs `site.yml` against `localhost`.

**Never run `bootstrap.sh` with `sudo`.** It asks for your admin password
itself, once, up front, then installs a temporary `NOPASSWD` sudoers rule for
your user (`/etc/sudoers.d/99-newmachinesetup`) so every later admin-requiring
step — Command Line Tools, Homebrew casks like `docker-desktop` that shell out
to `sudo` mid-install — can do so without prompting again, even from inside an
Ansible subprocess that has no controlling terminal. That drop-in is removed
again as soon as the script exits, success or failure (`trap ... EXIT`).
Running the whole script under `sudo` instead makes Homebrew refuse to install
anything, since Homebrew won't run as root.

When it finishes: open a new terminal (or `source ~/.bash_profile`), and if
iTerm2 was already open, quit and reopen it.

### Troubleshooting: "Can't install ... not currently available from the
### Software Update server"

If `xcode-select --install` (or `bootstrap.sh`'s own headless attempt) fails
with this error, it's almost always because **macOS itself is out of date** —
Apple's catalog frequently won't serve Command Line Tools packages for a
build that's several point releases behind. Install pending OS updates first
(System Settings > General > Software Update, or `softwareupdate -i -a
--restart`), then re-run `xcode-select --install` / `bootstrap.sh`.

## What it does

| Area | Result |
|------|--------|
| Homebrew | installed if missing, then `brew update` |
| Formulae | `git`, `python`, `rbenv` + `ruby-build`, `nvm`, `awscli`, `docker` + `docker-compose` + `docker-buildx`, `colima`, `neovim` |
| Casks | `iterm2`, `docker-desktop`, `firefox`, `tidal`, `slack`, `claude`, `visual-studio-code` |
| Firefox | `policies.json` dropped into the app bundle so 1Password + Dark Reader auto-install on first launch (`normal_installed` — you can still disable/remove either) |
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
- `files/firefox/policies.json` – enterprise policy that auto-adds the
  1Password and Dark Reader extensions (`ExtensionSettings`); no secrets involved.
- `files/iterm/gruvbox.json` – iTerm2 Dynamic Profile.
- `files/iterm/GruvboxDark.itermcolors` – the same palette as an importable preset.

To update a config: edit the file in `~/`, copy the change back into `files/`,
commit.

## Manual steps the playbook can't do

- **Sign in** to Slack, Tidal, Claude, Firefox Sync, VS Code (Settings Sync), AWS (`aws configure`).
- **1Password**: the extension auto-installs into Firefox, but you still sign in to
  your 1Password account by hand (Ansible never touches credentials).
- **Dark Reader**: auto-installs enabled by default; per-site toggling/exceptions
  are still yours to set up in the extension's own settings.
- **iTerm2 → "Make iTerm2 the default terminal"** if you want it to own the
  `open` / Terminal role (System Settings has no scriptable switch for this).
- First `docker` run: start **Docker Desktop** once, or `colima start`.
- Gatekeeper may prompt on first launch of a cask app.
- Set `ruby_version` in `vars.yml` and re-run `--tags languages` to install Ruby.

## Notes

- `homebrew_prefix` auto-selects `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel).
- Re-running is safe; tasks are idempotent.
- `community.general` is the only external Ansible dependency (`requirements.yml`).
