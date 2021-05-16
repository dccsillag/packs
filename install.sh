#!/bin/sh -ex

[ -z "$PREFIX" ] && PREFIX=/usr

cp packs.sh "$PREFIX/bin/packs"
