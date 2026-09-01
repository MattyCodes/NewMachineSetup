#!/usr/bin/env bash
#
# NewMachineSetup bootstrap.
#
#   1. Install Xcode Command Line Tools  (once, GUI prompt)
#   2. git clone this repo
#   3. ./bootstrap.sh
#
# Everything after step 1 is handled here: Homebrew, Ansible, then the playbook.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "==> NewMachineSetup bootstrap"

# --- 1. Xcode Command Line Tools -------------------------------------------------
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  echo "==> Installing Xcode Command Line Tools."
  echo "    Accept the GUI dialog that appears, let it finish, then re-run this script."
  /usr/bin/xcode-select --install || true
  exit 1
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
exec ansible-playbook site.yml "$@"
