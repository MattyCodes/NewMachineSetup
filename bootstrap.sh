#!/usr/bin/env bash
#
# NewMachineSetup bootstrap.
#
#   1. git clone this repo
#   2. ./bootstrap.sh
#
# This script installs Xcode Command Line Tools (if needed), Homebrew,
# Ansible, then runs the playbook. It asks for your admin password once, up
# front, then grants itself temporary passwordless sudo for the rest of the
# run (revoked on exit) — never run this script itself with sudo.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "==> NewMachineSetup bootstrap"

# --- 0. Refuse to run as root, then authenticate once for the whole run ----
#
# Homebrew refuses to install anything while running as root, but several
# steps below (Command Line Tools, some Homebrew casks like docker-desktop)
# shell out to `sudo` internally. Running this script with `sudo` breaks
# Homebrew; a plain cached `sudo -v` timestamp isn't enough either, because
# Ansible runs each module in a subprocess with no controlling terminal, so
# `sudo` inside a cask's installer can't find (or refresh) that timestamp
# and fails with "a terminal is required to read the password" instead of
# prompting. The reliable fix — the same one github/strap uses — is a
# scoped, temporary NOPASSWD sudoers rule for this user, installed after
# one real password prompt and removed unconditionally on exit.
if [ "$(id -u)" -eq 0 ]; then
  echo "==> Don't run this script with sudo (e.g. 'sudo ./bootstrap.sh')." >&2
  echo "    It asks for your admin password itself, once, when it's needed." >&2
  echo "    Just run: ./bootstrap.sh" >&2
  exit 1
fi

sudoers_dropin="/etc/sudoers.d/99-newmachinesetup"

cleanup_sudoers() {
  sudo rm -f "$sudoers_dropin" >/dev/null 2>&1 || true
}
trap cleanup_sudoers EXIT

echo "==> This needs admin access for a few steps (Command Line Tools, some"
echo "    Homebrew casks). Enter your password once below; this script then"
echo "    grants itself passwordless sudo for the rest of the run and"
echo "    revokes it again when it exits, however it exits."
sudo -v

user="$(id -un)"
tmp_dropin="$(mktemp)"
echo "${user} ALL=(ALL) NOPASSWD: ALL" > "$tmp_dropin"
chmod 0440 "$tmp_dropin"
if ! visudo -cf "$tmp_dropin" >/dev/null; then
  echo "==> Generated sudoers drop-in failed validation; aborting." >&2
  rm -f "$tmp_dropin"
  exit 1
fi
sudo cp "$tmp_dropin" "$sudoers_dropin"
sudo chown root:wheel "$sudoers_dropin"
sudo chmod 0440 "$sudoers_dropin"
rm -f "$tmp_dropin"

# --- 1. Xcode Command Line Tools -------------------------------------------
install_clt() {
  echo "==> Installing Xcode Command Line Tools"

  # Fake the "on demand" trigger file so `softwareupdate` will list and
  # install Command Line Tools headlessly, without the interactive GUI
  # prompt (which the plain `xcode-select --install` flow requires and
  # which can silently do nothing when it's already showing).
  local placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$placeholder"

  # softwareupdate's label line format has changed across macOS versions
  # ("* Command Line Tools for Xcode-12.4" vs. "* Label: Command Line Tools
  # for Xcode-16.2") — match either and strip down to the bare label.
  local label
  label="$(softwareupdate -l 2>/dev/null \
    | grep -E '^\s*\*.*Command Line Tools' \
    | sed -E 's/^\s*\*\s*(Label:\s*)?//' \
    | sort -V \
    | tail -n1)"

  if [ -n "$label" ]; then
    echo "    Found '$label' via softwareupdate; installing headlessly."
    if sudo softwareupdate -i "$label" --verbose; then
      sudo rm -f "$placeholder"
      return 0
    fi
    echo "    'softwareupdate -i' failed; falling back to the GUI installer." >&2
  else
    echo "    Software Update isn't offering a Command Line Tools package" >&2
    echo "    right now. This usually means macOS itself is out of date —" >&2
    echo "    Apple's catalog often won't serve Command Line Tools until you" >&2
    echo "    install pending OS updates first (System Settings > General >" >&2
    echo "    Software Update, or: softwareupdate -i -a --restart)." >&2
  fi

  sudo rm -f "$placeholder"
  echo "    Falling back to the interactive installer — accept the GUI dialog" >&2
  echo "    that appears." >&2
  /usr/bin/xcode-select --install || true

  echo "==> Waiting for Command Line Tools to finish installing..."
  echo "    (Ctrl-C and re-run this script if the GUI dialog reports an error" >&2
  echo "    instead of progressing — see the message above about OS updates.)" >&2
  until /usr/bin/xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
}

if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  install_clt
fi

# --- 2. Homebrew --------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for the rest of this script.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# --- 3. Ansible ---------------------------------------------------------------
if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "==> Installing Ansible"
  brew install ansible
fi

# --- 4. Ansible collections -------------------------------------------------------
echo "==> Installing required Ansible collections"
ansible-galaxy collection install -r requirements.yml

# --- 5. Run the playbook -------------------------------------------------------
echo "==> Running the playbook"
ansible-playbook site.yml "$@"
