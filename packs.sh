#!/bin/sh

command_exists() {
    command -v "$1" > /dev/null 2>&1
}

ask_yn() {
    while true
    do
        printf "%s [yn] " "$1"
        read -r answer || exit 1
        [ "$answer" = y   ] && return 0
        [ "$answer" = yes ] && return 0
        [ "$answer" = n   ] && return 1
        [ "$answer" = no  ] && return 1
        echo 'Bad answer; please answer `y` or `n`.'
    done
}

throw_error() {
    echo "error: $1"
    exit 1
}

status_message() {
    echo "$(tput rev)$(tput bold)packs| $1 $(tput sgr0)"
}

[ -z "$PACKS_ROOT" ] && PACKS_ROOT="$HOME/.local/share/packs"

mkdir -p "$PACKS_ROOT"

# Check whether we have to use sudo or doas
if command_exists doas
then
    export SUDO=doas
elif command_exists sudo
then
    export SUDO=sudo
else
    throw_error "No viable sudo/doas binary found"
fi

# Get install methods
ask_yn "Do we have root access?" && {
    # Get environment
    PLATFORM_NAME="$(lsb_release -is)"
    case "$PLATFORM_NAME" in
        Ubuntu)       export VIAS="$VIAS ubuntu" ;;
        ManjaroLinux) export VIAS="$VIAS manjaro" ;;
        *)            throw_error "Unknown system: $PLATFORM_NAME" ;;
    esac
}
command_exists nix   && export VIAS="$VIAS nix"
command_exists guix  && export VIAS="$VIAS guix"
command_exists conda && export VIAS="$VIAS conda"
export VIAS="$VIAS manual"

# Install packages
status_message "Installing packages..."
n="$(find "$PACKS_ROOT/packages" -type f | wc -l)"
k=0
for packfile in "$PACKS_ROOT"/packages/*
do
    packname="$(basename "$packfile")"

    status_message " [$k/$n] Installing '$packname'"

    for VIA in $VIAS
    do
        (
            . "$packfile"

            command_exists "install_$VIA" || exit 2

            case "$VIA" in
                ubuntu)  ( set -ex && install_ubuntu ) ;;
                manjaro) ( set -ex && install_manjaro ) ;;
                nix)     ( set -ex && install_nix ) ;;
                guix)    ( set -ex && install_guix ) ;;
                conda)   ( set -ex && conda activate packs && install_conda ) ;;
                manual)  tmpdir="$(mktemp -d)"; ( set -ex && cd "$tmpdir" && install_manual ); rm -rf "$tmpdir" ;;
                *)       throw_error "Bad install method: $VIA"
            esac || {
                status_message "Failed to install package '$packname'"
                ask_yn "Exit?" && exit 1
                status_message "Continuing..."
            }
        )
        case $? in
            0) break ;;
            1) exit 1 ;;
            2) status_message "No install function 'install_$VIA'; trying next install method..." ;;
        esac
    done
    k=$((k+1))
done
status_message " [$n/$n]"
status_message "Finished installing all packages."
