#!/bin/bash
#
# Installs systemd units from ./systemd-services/ into /usr/local/lib/systemd/system.
#
# Why copy instead of symlink:
#   systemd watches its unit *search directories* with inotify — it does NOT watch
#   the targets of symlinks. A symlink into this git working tree means that when
#   git replaces or removes the target (pull, checkout, clean, re-clone, an agent
#   re-cloning the repo), no inotify event ever fires in any watched directory.
#   If the target is missing for even a moment while PID 1 is loading units (at
#   boot, or mid git-operation), systemd latches "not-found" and the unit silently
#   stops working until someone runs `systemctl daemon-reload`.
#
#   A real file in /usr/local/lib/systemd/system is stable: git never touches it,
#   and systemd watches the directory directly.
#
# Idempotent: safe to re-run at any time. It removes legacy /etc symlinks from the
# old approach, copies only when content changed, daemon-reloads, enables, and
# (re)applies every unit.

set -euo pipefail

INSTALL_DIR="/usr/local/lib/systemd/system"
LEGACY_ETC_DIR="/etc/systemd/system"

manage_systemd_services() {
    local script_dir source_dir
    script_dir="$(dirname "$(readlink -f "$0")")"
    source_dir="$script_dir/systemd-services"

    if [ ! -d "$source_dir" ]; then
        echo "Error: Source directory $source_dir does not exist." >&2
        return 1
    fi

    sudo mkdir -p "$INSTALL_DIR"

    local units=()
    local unit_file name dest legacy
    for unit_file in "$source_dir"/*.service; do
        # Safely skip if no .service files match the glob
        [ -e "$unit_file" ] || continue

        name="$(basename "$unit_file")"
        dest="$INSTALL_DIR/$name"
        legacy="$LEGACY_ETC_DIR/$name"

        # Drop legacy symlinks from the old symlink-based approach.
        # /etc shadows /usr/local/lib, so leaving one in place would
        # reintroduce the git-fragility bug.
        if [ -L "$legacy" ]; then
            echo "Removing legacy symlink: $legacy"
            sudo rm -f "$legacy"
        fi

        if [ -f "$dest" ] && cmp -s "$unit_file" "$dest"; then
            echo "$name: already installed, up to date."
        else
            echo "Installing $name -> $dest"
            sudo install -m 644 -o root -g root "$unit_file" "$dest"
        fi

        units+=("$name")
    done

    if [ ${#units[@]} -eq 0 ]; then
        echo "No .service files found to manage." >&2
        return 1
    fi

    # Rebuild systemd's unit file cache and register the install dir's watch
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    for name in "${units[@]}"; do
        echo "Enabling $name..."
        sudo systemctl enable "$name"

        # Re-apply immediately (oneshot units without RemainAfterExit re-run on start)
        echo "Applying $name..."
        sudo systemctl start "$name"
    done

    echo "Done. Verify with: systemctl status ${units[*]}"
}

manage_systemd_services
