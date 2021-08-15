#!/bin/sh

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_REVERSE='\033[7m'
C_RED='\033[31m'
C_GREEN='\033[32m'

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
    echo "${C_REVERSE}${C_BOLD}packs| $1 ${C_RESET}"
}

run_action() {
    if [ "$dry_run" = yes ]
    then
        echo "+ $1"
    else
        ( set -ex && eval "$1" )
    fi
}

[ -z "$PACKS_ROOT" ] && PACKS_ROOT="$HOME/.config/packs"

mkdir -p "$PACKS_ROOT"

# Argparse
dry_run=no
force_install=no
while getopts df name
do
    case $name in
        d) dry_run=yes; status_message 'Dry run!' ;;
        f) force_install=yes; status_message 'Forcing install!' ;;
        ?) echo "Bad argv: $name"; exit 2 ;;
    esac
done
# TODO get list of packages to install

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
command_exists pip   && export VIAS="$VIAS pip"
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

    (
        . "$packfile"

        command_exists check || {
            status_message "No 'check' function defined! Assuming that package is not installed."
            exit 0
        }

        [ "$force_install" = no ] && check && {
            status_message "Package is already installed; skipping"
            exit 1
        }
    )
    if [ $? -eq 1 ]
    then
        installed=yes
    else
        installed=no
        for VIA in $VIAS
        do
            (
                . "$packfile"

                command_exists "install_$VIA" || exit 2

                case "$VIA" in
                    ubuntu)  run_action 'install_ubuntu' ;;
                    manjaro) run_action 'install_manjaro' ;;
                    nix)     run_action 'install_nix' ;;
                    guix)    run_action 'install_guix' ;;
                    pip)     run_action 'install_pip' ;;
                    conda)   run_action 'conda activate packs && install_conda' ;;
                    manual)  run_action 'tmpdir="$(mktemp -d)"; ( cd "$tmpdir" && install_manual ); rm -rf "$tmpdir"' ;;
                    *)       throw_error "Bad install method: $VIA"
                esac || {
                    status_message "Failed to install package '$packname'"
                    ask_yn "Exit?" && exit 1
                    status_message "Continuing..."
                }
            )
            case $? in
                0) installed=yes; break ;;
                1) exit 1 ;;
                2) status_message "No install function 'install_$VIA'; trying next install method..." ;;
            esac
        done
    fi

    if [ $installed = yes ]
    then
        INSTALL_SUCCEEDED="$INSTALL_SUCCEEDED $packname"
    else
        status_message "Failed to install '$packname'; no installation method succeeded."
        INSTALL_FAILED="$INSTALL_FAILED $packname"
    fi
    k=$((k+1))
done
status_message " [$n/$n]"
status_message "Finished installing all packages."

echo
echo "${C_BOLD}Summary:${C_RESET}"
echo

[ -n "$INSTALL_SUCCEEDED" ] && {
    echo "  Install succeeded for:"
    echo "$C_GREEN"
    echo "$INSTALL_SUCCEEDED" | tr ' ' '\n' | column
    echo "$C_RESET"
}

[ -n "$INSTALL_FAILED" ] && {
    echo "  Install failed for:"
    echo "$C_RED"
    echo "$INSTALL_FAILED" | tr ' ' '\n' | column
    echo "$C_RESET"
}

true
