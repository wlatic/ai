#!/bin/bash
# Install ai session manager for Claude Code
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "ai — Session Manager for Claude Code"
echo "======================================"
echo ""

# Check requirements
command -v tmux >/dev/null 2>&1 || { echo "Error: tmux is required. Install it first."; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "Error: claude (Claude Code) is required. Install it first."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required."; exit 1; }

# Determine install location
INSTALL_DIR="${HOME}/bin"
mkdir -p "$INSTALL_DIR"

echo "Installing to ${INSTALL_DIR}..."

# Copy scripts
cp "${SCRIPT_DIR}/bin/ai" "${INSTALL_DIR}/ai"
cp "${SCRIPT_DIR}/bin/janitor" "${INSTALL_DIR}/janitor"
cp "${SCRIPT_DIR}/bin/recent-conversations" "${INSTALL_DIR}/recent-conversations"
cp "${SCRIPT_DIR}/bin/name-conversations" "${INSTALL_DIR}/name-conversations"

chmod +x "${INSTALL_DIR}/ai"
chmod +x "${INSTALL_DIR}/janitor"
chmod +x "${INSTALL_DIR}/recent-conversations"
chmod +x "${INSTALL_DIR}/name-conversations"

# Create logs directory
mkdir -p "${SCRIPT_DIR}/logs"

# Check if ~/bin is in PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  echo ""
  echo "Note: ${INSTALL_DIR} is not in your PATH."
  echo "Add this to your .bashrc or .profile:"
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

# Offer to set up system-wide access
echo ""
read -r -p "Create /usr/local/bin/ai symlink for system-wide access? [y/N] " sys_choice
if [[ "$sys_choice" =~ ^[yY]$ ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    ln -sf "${INSTALL_DIR}/ai" /usr/local/bin/ai
    echo "Created /usr/local/bin/ai"
  else
    sudo ln -sf "${INSTALL_DIR}/ai" /usr/local/bin/ai
    echo "Created /usr/local/bin/ai"
  fi
fi

# Offer to set up /etc/ai-agent.conf
echo ""
read -r -p "Create /etc/ai-agent.conf for multi-user support? [y/N] " conf_choice
if [[ "$conf_choice" =~ ^[yY]$ ]]; then
  CURRENT_USER="$(whoami)"
  CURRENT_DIR="$(pwd)"
  read -r -p "  User to run as [${CURRENT_USER}]: " conf_user
  conf_user="${conf_user:-$CURRENT_USER}"
  read -r -p "  Project directory [${CURRENT_DIR}]: " conf_dir
  conf_dir="${conf_dir:-$CURRENT_DIR}"

  CONF="# /etc/ai-agent.conf\nuser=${conf_user}\nproject_dir=${conf_dir}"
  if [[ "$(id -u)" -eq 0 ]]; then
    echo -e "$CONF" > /etc/ai-agent.conf
  else
    echo -e "$CONF" | sudo tee /etc/ai-agent.conf > /dev/null
  fi
  echo "Created /etc/ai-agent.conf"
fi

# Offer to set up janitor cron
echo ""
read -r -p "Add janitor self-healing cron (every 10 min)? [y/N] " cron_choice
if [[ "$cron_choice" =~ ^[yY]$ ]]; then
  CRON_LINE="*/10 * * * * ${INSTALL_DIR}/janitor >> ${SCRIPT_DIR}/logs/janitor-cron.log 2>&1"
  (crontab -l 2>/dev/null | grep -v "janitor"; echo "$CRON_LINE") | crontab -
  echo "Added janitor cron"
fi

# Start the janitor
echo ""
read -r -p "Start the janitor now? [y/N] " start_choice
if [[ "$start_choice" =~ ^[yY]$ ]]; then
  "${INSTALL_DIR}/janitor"
fi

echo ""
echo "Done! Run 'ai' to get started."
