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

# Files to replace
cp $TOOLS_ROOT/resources/docs/README.md $KANKA_ROOT_DIR/README.md
cp $TOOLS_ROOT/resources/files/.env.example $KANKA_ROOT_DIR/.env.example
cp $TOOLS_ROOT/resources/files/docker-compose.yml $KANKA_ROOT_DIR/docker-compose.yml

# New Files
cp $TOOLS_ROOT/resources/scripts/gen-passwords.sh $KANKA_ROOT_DIR/gen-passwords.sh
cp $TOOLS_ROOT/resources/scripts/prepare-kanka-ce.sh $KANKA_ROOT_DIR/prepare-kanka-ce.sh

# New Folder
cp -r $TOOLS_ROOT/resources/fail2ban $KANKA_ROOT_DIR/.fail2ban
