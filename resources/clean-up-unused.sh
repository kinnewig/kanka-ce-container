#!/usr/bin/env bash

# ---------------------------------------------------------------------
# 
# Copyright (C) 2026 @Sebastian Kinnewig
#
# This file is part of the Kanka CE toolchain.
# It is NOT part of the official Kanka project and is not affiliated
# with or endorsed by the Kanka developers.
#
# The code in this file is licensed under the GNU Lesser General
# Public License v2.1 (LGPL-2.1) as published by the Free Software
# Foundation.
#
# The full text of the license can be found in the file LICENSE.md.
#
# ---------------------------------------------------------------------

# ++============================================================++
# ||                         Premilaris                         ||
# ++============================================================++
set -e

TOOLS_ROOT="$1"
KANKA_ROOT_DIR="$2"

source "$TOOLS_ROOT/core/lib.sh"

# -- Folder that are not required by the CE version ---
rm -rf $KANKA_ROOT_DIR/.claude
rm -rf $KANKA_ROOT_DIR/.github                    # We replace the workflows with our own
rm -rf $KANKA_ROOT_DIR/.mariadb
rm -rf $KANKA_ROOT_DIR/docker
rm -rf $KANKA_ROOT_DIR/docs                       # We want to provide different documents than the upstream.
rm -rf $KANKA_ROOT_DIR/public/vendor/fontawesome  # The included fontawesome version is to old and does not provide all icons.

# --- Files that are not required by the CE version ---
rm -f $KANKA_ROOT_DIR/.env.testing
rm -f $KANKA_ROOT_DIR/CLAUDE.md

