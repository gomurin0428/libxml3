#!/bin/sh
set -eu

# Ubuntu 22.04 dependencies used by the reproducible development setup.
sudo -n apt-get update
sudo -n apt-get install -y libxml2-dev pkg-config build-essential unzip curl

# Official Alire release and pinned crates. The prefix is intentionally
# separate from any existing default Alire toolchain.
ALIRE_HOME="${ALIRE_HOME:-$HOME/.local/share/alire-2.1.1}"
PREFIX="${ADA_PREFIX:-$HOME/.local/share/ada/candidate-14}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$PREFIX"
mkdir -p "$ALIRE_HOME"
curl -fsSL \
  https://github.com/alire-project/alire/releases/download/v2.1.1/alr-2.1.1-bin-x86_64-linux.zip \
  -o "$WORK/alr.zip"
unzip -q "$WORK/alr.zip" -d "$ALIRE_HOME"
"$ALIRE_HOME/bin/alr" install --prefix="$PREFIX" \
  gnat_native=14.2.1 gprbuild=26.0.1 gnatprove=14.1.1

cat <<EOF
Toolchain installed under: $PREFIX
export PATH="$PREFIX/bin:\$PATH"
Alire installed under: $ALIRE_HOME/bin
GNAT:      gnat_native=14.2.1
GPRbuild:  gprbuild=26.0.1
GNATprove: gnatprove=14.1.1
EOF
