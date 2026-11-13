#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# install.sh puts a part in $XYMONHOME/ext/facelift/NAME/, the facelift's
# settings in ext/facelift/xymonserver.cfg, and two links to them,
# $XYMONWWWDIR/facelift and etc/xymonserver.d/facelift.cfg, and writes nothing
# else; installing again replaces the part's directory as a whole and keeps
# the settings; uninstalling the last part leaves the tree as it was, and so
# does removing ext/facelift by hand and then running uninstall-server, which
# removes the links left pointing nowhere. A www/facelift or a facelift.cfg
# that is not the facelift's link is left alone. Run against a
# scratch tree; needs nothing but a POSIX shell. Exit 0 passes, anything else
# fails.

# A && B || fail: fail when either fails, which is what each such line means.
# shellcheck disable=SC2015

cd "$(dirname "$0")/.." || exit 2
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
tree() { (cd "$1" && find . | LC_ALL=C sort); }

# A Xymon tree with a file of its own in www/, an ext/ and the xymonserver.d
# its xymonserver.cfg includes, as an install has.
H=$T/xymon
mkdir -p "$H/www/gifs" "$H/ext" "$H/etc/xymonserver.d"
echo 'Xymon shipped this' > "$H/www/gifs/xymonbody.css"
before=$(tree "$H")

XYMONHOME=$H ./install.sh install-server example > "$T/out" || fail "install-server example: $(cat "$T/out")"
P=$H/ext/facelift/example
cmp -s parts/example/example.css "$P/example.css" || fail "example.css not installed in $P"
[ "$(cat "$P/VERSION")" = "$(sed -n 's/^version: *//p' parts/example/PART)" ] || fail "VERSION is not the PART's version"
[ "$(readlink "$H/www/facelift")" = "$H/ext/facelift" ] || fail "www/facelift is not a link to ext/facelift"
[ "$(readlink "$H/etc/xymonserver.d/facelift.cfg")" = "$H/ext/facelift/xymonserver.cfg" ] || fail "xymonserver.d/facelift.cfg is not a link to ext/facelift/xymonserver.cfg"
[ -f "$H/etc/xymonserver.d/facelift.cfg" ] || fail "the facelift's settings file is not there"
if grep -v '^#' "$H/ext/facelift/xymonserver.cfg" | grep -q .; then fail "the new settings file sets something"; fi
cmp -s parts/example/example.css "$H/www/facelift/example/example.css" || fail "the part is not reachable through www/facelift"
grep -q 'Nothing to switch on' "$T/out" || fail "the PART's installed: message was not printed"
new=$(tree "$H" | grep -v -e '^\./ext/facelift' -e '^\./www/facelift$' -e '^\./etc/xymonserver\.d/facelift\.cfg$')
[ "$new" = "$before" ] || fail "install wrote outside ext/facelift and its two links"
[ "$(cat "$H/www/gifs/xymonbody.css")" = 'Xymon shipped this' ] || fail "a Xymon file changed"

# Installing again replaces the part's directory: a stray file goes; the
# settings the administrator wrote stay.
echo stray > "$P/stray"
echo 'XYMONSKIN="/xymon/facelift/example"' >> "$H/ext/facelift/xymonserver.cfg"
XYMONHOME=$H ./install.sh install-server example > /dev/null || fail "second install-server"
[ ! -e "$P/stray" ] || fail "install again kept a file the part does not ship"
grep -q '^XYMONSKIN=' "$H/ext/facelift/xymonserver.cfg" || fail "install again dropped the settings"

XYMONHOME=$H ./install.sh uninstall-server example > /dev/null || fail "uninstall-server example"
[ "$(tree "$H")" = "$before" ] || fail "uninstall did not leave the tree as before"

# Removing ext/facelift by hand: the link is left pointing nowhere, and
# uninstall-server then removes it; an install puts everything back.
XYMONHOME=$H ./install.sh install-server example > /dev/null || fail "install before the removal by hand"
rm -rf "$H/ext/facelift"
[ -L "$H/www/facelift" ] && [ ! -e "$H/www/facelift" ] || fail "removing ext/facelift did not leave the www link dangling"
[ -L "$H/etc/xymonserver.d/facelift.cfg" ] && [ ! -e "$H/etc/xymonserver.d/facelift.cfg" ] || fail "removing ext/facelift did not leave the settings link dangling"
XYMONHOME=$H ./install.sh install-server example > /dev/null || fail "install after the removal by hand"
[ -f "$H/www/facelift/example/example.css" ] || fail "install after the removal by hand did not reach the part again"
rm -rf "$H/ext/facelift"
XYMONHOME=$H ./install.sh uninstall-server example > /dev/null || fail "uninstall-server after the removal by hand"
[ "$(tree "$H")" = "$before" ] || fail "uninstall-server after the removal by hand did not leave the tree as before"

# XYMONWWWDIR and DESTDIR, given as NAME=value: staged for a package, the
# link names the installed path, not the staging one.
./install.sh install-server XYMONHOME=/usr/lib/xymon/server XYMONWWWDIR=/var/lib/xymon/www DESTDIR="$T/stage" > /dev/null || fail "install with XYMONWWWDIR and DESTDIR"
[ -f "$T/stage/usr/lib/xymon/server/ext/facelift/example/example.css" ] || fail "not staged under DESTDIR\$XYMONHOME/ext/facelift"
[ "$(readlink "$T/stage/var/lib/xymon/www/facelift")" = /usr/lib/xymon/server/ext/facelift ] || fail "the staged link does not name the installed ext/facelift"
[ "$(readlink "$T/stage/usr/lib/xymon/server/etc/xymonserver.d/facelift.cfg")" = /usr/lib/xymon/server/ext/facelift/xymonserver.cfg ] || fail "the staged settings link does not name the installed file"

# A www/facelift that is not the facelift's link is left alone.
mkdir "$H/www/facelift"
XYMONHOME=$H ./install.sh install-server example 2>/dev/null && fail "installed over a www/facelift directory"
[ -d "$H/www/facelift" ] && [ ! -L "$H/www/facelift" ] || fail "the www/facelift directory was touched"
rmdir "$H/www/facelift"
echo 'MINE="admin"' > "$H/etc/xymonserver.d/facelift.cfg"
XYMONHOME=$H ./install.sh install-server example 2>/dev/null && fail "installed over an xymonserver.d/facelift.cfg of the administrator's"
[ "$(cat "$H/etc/xymonserver.d/facelift.cfg")" = 'MINE="admin"' ] || fail "the administrator's facelift.cfg was touched"
rm -f "$H/etc/xymonserver.d/facelift.cfg"

# Refused: no XYMONHOME, a name that is not a part, a path to a part.
env -u XYMONHOME -u XYMONWWWDIR ./install.sh install-server example 2>/dev/null && fail "installed without XYMONHOME"
XYMONHOME=$H ./install.sh install-server nosuchpart 2>/dev/null && fail "installed a part that does not exist"
XYMONHOME=$H ./install.sh install-server ../parts/example 2>/dev/null && fail "took a path to a part as a part name"
[ "$(tree "$H")" = "$before" ] || fail "a refused install wrote something"

echo "PASS: install-server and uninstall-server"
