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
ICONS_NAME="$3"

# Colours for progress and error reporting
ERROR="\033[1;31m"
GOOD="\033[1;32m"
WARN="\033[1;35m"
INFO="\033[1;34m"
BOLD="\033[1m"

# Display messages in a specified colour
cecho() {
  COL=$1; shift
  echo -e "${COL}$@\033[0m"
}

# Error codes
E_OK=0
E_USAGE=1
E_UPSTREAM_NOT_FOUND=2
E_OUTPUT_WRITE_FAIL=3
E_PATCH_FAILED=4
E_RESOURCE_FAILED=5
E_STEP_FAILED=6
E_DEPENDENCY_MISSING=7

# Error handling
error() {
    local message="$1"
    local code="${2:-1}"

    cecho ${ERROR} "ERROR: $message" >&2
    exit "$code"
}



# ++============================================================++
# ||                         Settings                           ||
# ++============================================================++
LINE_AWESOME_DIR="${KANKA_ROOT_DIR}/public/vendor/lineawesome"
LINE_AWESOME_VERSION="1.3.0"

FONTAWSOME_BLADE_FILE="${KANKA_ROOT_DIR}/resources/views/layouts/styles/fontawesome.blade.php"

TRANSLATION_TABLE_LINEAWESOME="${TOOLS_ROOT}/patches/icons/translationtable_fontawesome-nonfree-to-lineawesome.sh"
TRANSLATION_TABLE_FONTAWESOME_FREE="${TOOLS_ROOT}/patches/icons/translationtable_fontawesome-nonfree-to-fontawesome-free.sh"

verbose=false



# ++============================================================++
# ||            FIND MISSING FONTAWESOME TRANSLATIONS           ||
# ++============================================================++
find_missing_fontawesome_translations() {
    echo "  Check if icons are missing on the translation table:"

    if [[ $# -eq 0 ]]; then
        error "No translation target provided." 1
    fi

    local TARGET="$1"
    local MAPFILE=""
    local TRANSLATION_NAME=""

    case "$TARGET" in
        fontawesome-free)
            MAPFILE=$TRANSLATION_TABLE_FONTAWESOME_FREE
            TRANSLATION_NAME="fa-solid fa-"
            ;;
        lineawesome)
            MAPFILE=$TRANSLATION_TABLE_LINEAWESOME
            TRANSLATION_NAME="las la-"
            ;;
        *)
            cecho ${ERROR} "ERROR: Unknown translation target '$TARGET'"
            exit 1
            ;;
    esac

    # fontawesome-types:
    types=(
        fa-brands
        fa-duotone
        fa-regular
        fa-solid
    )

    # names to skip
    skip_names=(
        fa-
        fa-2x
        fa-3x
        fa-brands
        fa-duotone
        fa-regular
        fa-solid
    )

    # Build skip set
    declare -A skip=()
    for n in "${skip_names[@]}"; do
        skip["$n"]=1
    done

    results=()

    if [[ ! -f "$MAPFILE" ]]; then
        error "Translation table not found: $MAPFILE" 1
        exit 1
    fi

    for TYPE in "${types[@]}"; do
        declare -A known=()

        # Read the icons-translation-table, ignore everything after ';'
        while IFS=';' read -r left _; do
            # left side is "fa-<type> fa-<name>"
            read -r t n <<< "$left"

            [[ "$t" == "$TYPE" ]] && known["$n"]=1
        done < "$MAPFILE"

        while read -r match; do
            name="${match#"$TYPE "}"

            # Skip all non fontawesome entries that where found by this scipt
            [[ "$name" != fa-* ]] && continue

            # Skip all entries we already know
            [[ -n "${known[$name]}" ]] && continue

            # The script find some items, we do not want to replace, so we have to skip them
            [[ -n "${skip[$name]}" ]] && continue

            results+=("$TYPE $name")
        done < <(grep -RhoE "\b$TYPE [a-zA-Z0-9._-]+" ${KANKA_ROOT_DIR})
    done

    if [ ${#results[@]} -eq 0 ]; then
        cecho ${GOOD} "  No missing icons on the translation table."
    else
        cecho ${WARN} "  Warning: Some icons are missing on the translation table."
        cecho ${INFO} "  Trying to auto-translate."
        {
            echo
            echo "# Missing entries auto‑added by scan on $(date)"
            for entry in "${results[@]}"; do
                # entry = "fa-type fa-name"
                read -r t n <<< "$entry"

                # Generate translation: las la-name
                echo "${t} ${n};${TRANSLATION_NAME}${n#fa-}"
            done
        } >> "$MAPFILE"
    fi
    echo
  }



# ++============================================================++
# ||                   Download Line Awesome                    ||
# ++============================================================++
download_line_awesome() {
    echo "  Downloading Line Awesome:"
    # Check if unzip is installed.
    if ! command -v unzip &>/dev/null; then
        cecho ${INFO} "Please install unzip to proceed:"
        cecho ${INFO} "- Debian/Ubuntu: sudo apt install unzip"
        cecho ${INFO} "- Red Hat/Fedora: sudo dnf install unzip"
        error "unzip is missing." 1
    fi

    if [ -d ${LINE_AWESOME_DIR}/${LINE_AWESOME_VERSION} ]; then
        cecho ${GOOD} "  Line Awesome ${LINE_AWESOME_VERSION} is already presend."
    else
        mkdir -p ${LINE_AWESOME_DIR}

        LINE_AWESOME_URL="https://maxst.icons8.com/vue-static/landings/line-awesome/line-awesome/${LINE_AWESOME_VERSION}/line-awesome-${LINE_AWESOME_VERSION}.zip"
        if command -v curl &>/dev/null; then
            curl -L ${LINE_AWESOME_URL}  -o ${LINE_AWESOME_DIR}/lineawesome-${LINE_AWESOME_VERSION}.zip
        elif command -v wget &>/dev/null; then
            wget ${LINE_AWESOME_URL} -O ${LINE_AWESOME_DIR}/lineawesome-${LINE_AWESOME_VERSION}.zip
        else
            cecho ${INFO} "Please install one of these tools to proceed:"
            cecho ${INFO} "- Debian/Ubuntu: sudo apt install curl  # or wget"
            cecho ${INFO} "- Red Hat/Fedora: sudo dnf install curl  # or wget"
            error "Neither 'curl' nor 'wget' is available on this system." 1
        fi

        unzip -q ${LINE_AWESOME_DIR}/lineawesome-${LINE_AWESOME_VERSION}.zip -d ./public/vendor/lineawesome
        rm ./public/vendor/lineawesome/lineawesome-${LINE_AWESOME_VERSION}.zip

        cecho ${GOOD} "  Line Awesome has been downloaded successfully."
    fi
    echo
}



# ++============================================================++
# ||                  TRANSLATE TO LINE AWESOME                 ||
# ++============================================================++
translate_to_line_awesome() {
    echo "  Translate Font Awesome Non-Free to Line Awesome:"

    local MAPFILE=$TRANSLATION_TABLE_LINEAWESOME

    # fontawesome-types to replace:
    types=(
        fa-brands
        fa-duotone
        fa-regular
        fa-solid
    )

    if [[ ! -f "$MAPFILE" ]]; then
        error "Translation table not found: $MAPFILE" 1
    fi

    cecho ${INFO} "    Start translation, this can take some time!"
    while IFS= read -r line; do
        # Skip empty lines or comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Split at semicolon
        old_value="${line%%;*}"
        new_value="${line#*;}"

        # fontawesome name
        fa_style=$(echo "$old_value" | awk '{print $1}')
        fa_name=$(echo "$old_value" | awk '{print $2}')

        # lineawesome name
        la_style=$(echo "$new_value" | awk '{print $1}')
        la_name=$(echo "$new_value" | awk '{print $2}')

        # Build search + replace patterns
        search="${fa_style} ${fa_name}"
        replace="${la_style} ${la_name}"

        if $verbose; then
            echo "${search} -> ${replace}"
        fi

        # Replace <type> <name>
        grep -RIl --exclude-dir=.git --exclude-dir=vendor --exclude-dir=tools "$search" ${KANKA_ROOT_DIR} | while read -r file; do
            sed -Ei "s/${search}($|[^A-Za-z0-9-])/${replace}\1/g" "$file"
        done

        # Replace only <name> (for that case that any is left)
        grep -RIl --exclude-dir=.git --exclude-dir=vendor --exclude-dir=tools "$fa_name" ${KANKA_ROOT_DIR} | while read -r file; do
            sed -Ei "s/$fa_name($|[^A-Za-z0-9-])/$la_name\1/g" "$file"
        done

    done < "$MAPFILE"

    # Replace only <type> (for that case that any is left)
    la_general_type="las"
    for TYPE in "${types[@]}"; do
        grep -RIl --exclude-dir=.git --exclude-dir=vendor --exclude-dir=tools "$TYPE" ${KANKA_ROOT_DIR} | while read -r file; do
            sed -Ei "s/$TYPE($|[^A-Za-z0-9-])/$la_general_type\1/g" "$file"
        done
    done

    cecho ${GOOD} "    Translation done!"

    # Replace Font Awesome with Line Awesome in the config files
    needle="href=\"/vendor/lineawesome/${LINE_AWESOME_VERSION}/css/line-awesome.min.css\">"
    if grep -Fq "$needle" "${FONTAWSOME_BLADE_FILE}"; then
        cecho ${GOOD} "    Line Awesome already in use."
    else
        if [ -f "${FONTAWSOME_BLADE_FILE}.bak" ]; then
           cecho ${ERROR} "ERROR: $FONTAWSOME_BLADE_FILE.bak already exists. "
           cecho ${INFO} "    To avoid data-loss I am stopping here."
           exit 1
        else
            cp ${FONTAWSOME_BLADE_FILE} ${FONTAWSOME_BLADE_FILE}.bak
            echo "<link rel=\"stylesheet\" ${needle}" > ${FONTAWSOME_BLADE_FILE}
            cecho ${GOOD} "    Updated blade file to use Line Awesome."
        fi
    fi

    echo
}



# ++============================================================++
# ||       REPLACE FONT AWESOME NONFREE WITH LINE AWESOME       ||
# ++============================================================++
# Put all functions together for the actual replace function
replace_font_awesome_nonfree_with_line_awesome() {
    # Check if the translation table for Font Awesome Premium to Line Awesome is complete
    if ! find_missing_fontawesome_translations "lineawesome" "$@"; then
      exit 1
    fi

    # Download Line Awesome
    if ! download_line_awesome "$@"; then
      exit 1
    fi

    # Translate Font Awesome to Line Awesome
    if ! translate_to_line_awesome "$@"; then
      exit 1
    fi
}



# ++============================================================++
# ||               TRANSLATE TO FONT AWESOME FREE               ||
# ++============================================================++
translate_to_font_awesome_free() {
    echo "  Translate Font Awesome Non-Free to Font Awesome Free:"

    local MAPFILE=$TRANSLATION_TABLE_FONTAWESOME_FREE

    # fontawesome-types to replace:
    types=(
        fa-duotone
        fa-regular
    )

    if [[ ! -f "$MAPFILE" ]]; then
        error "Translation table not found: $MAPFILE" 1
    fi

    cecho ${INFO} "    Start translation, this can take some time!"
    while IFS= read -r line; do
        # Skip empty lines or comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Split at semicolon
        old_value="${line%%;*}"
        new_value="${line#*;}"

        # fontawesome non-free name
        fa_style=$(echo "$old_value" | awk '{print $1}')
        fa_name=$(echo "$old_value" | awk '{print $2}')

        # lineawesome free name
        fa_free_style=$(echo "$new_value" | awk '{print $1}')
        fa_free_name=$(echo "$new_value" | awk '{print $2}')

        # We need to catch the case, where $fa_free_style is actually "fa_regular", to avoid the "fa_regular" is replaced in the end with "fa_solid".
        if [[ "$fa_free_style" == "fa_regular" ]]; then
            fa_free_style="FA_REGULAR_LOCK"
        fi

        # Build search + replace patterns
        search="${fa_style} ${fa_name}"
        replace="${fa_free_style} ${fa_free_name}"

        if $verbose; then
            echo "${search} -> ${replace}"
        fi

        # Replace <type> <name>
        if [[ "$search" != "$replace" ]]; then
            grep -RIl --exclude-dir=.git --exclude-dir=vendor --exclude-dir=tools "$search" ${KANKA_ROOT_DIR} | while read -r file; do
                sed -Ei "s/${search}($|[^A-Za-z0-9-])/${replace}\1/g" "$file"
            done
        fi

        # Replace only <name> (for that case that any is left)
        if [[ "$fa_name" != "$fa_free_name" ]]; then
            grep -RIl --exclude-dir=.git --exclude-dir=vendor --exclude-dir=tools "$fa_name" ${KANKA_ROOT_DIR} | while read -r file; do
                sed -Ei "s/$fa_name($|[^A-Za-z0-9-])/$fa_free_name\1/g" "$file"
            done
        fi

    done < "$MAPFILE"

    # Replace fa_regular and fa_duotone that are left
    general_type="fa-solid"
    for TYPE in "${types[@]}"; do
        grep -RIl --exclude-dir=.git --exclude-dir=vendor --exclude-dir=tools "$TYPE" ${KANKA_ROOT_DIR} | while read -r file; do
            sed -Ei "s/$TYPE($|[^A-Za-z0-9-])/$general_type\1/g" "$file"
        done
    done

    # Restore FA_REGULAR_LOCK -> fa_regular
    grep -RIl --exclude-dir=.git --exclude-dir=vendor --exclude-dir=tools "FA_REGULAR_LOCK" ${KANKA_ROOT_DIR} |
    while read -r file; do
        sed -Ei "s/FA_REGULAR_LOCK($|[^A-Za-z0-9-])/fa_regular\1/g" "$file"
    done

    cecho ${GOOD} "    Translation done!"

    echo
}



# ++============================================================++
# ||     REPLACE FONT AWESOME NONFREE WITH FONT AWESOME FREE    ||
# ++============================================================++
# Put all functions together for the actual replace function
replace_font_awesome_nonfree_with_font_awesome_free() {
    # Check if the translation table for Font Awesome Premium to Line Awesome is complete
    if ! find_missing_fontawesome_translations "fontawesome-free" "$@"; then
      exit 1
    fi

    # Translate Font Awesome to Line Awesome
    if ! translate_to_font_awesome_free "$@"; then
      exit 1
    fi
}



# ++============================================================++
# ||                    The actual program                      ||
# ++============================================================++

if [[ "$ICONS_NAME" == "fontawesome-free" ]]; then
  if ! replace_font_awesome_nonfree_with_font_awesome_free "$@"; then
    exit 1
  fi
elif [[ "$ICONS_NAME" == "lineawesome" ]]; then
  if ! replace_font_awesome_nonfree_with_line_awesome "$@"; then
    exit 1
  fi
else
  error "Unkown icon set: ${ICONS_NAME}" 1
fi
