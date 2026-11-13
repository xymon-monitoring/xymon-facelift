#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Install and remove the parts of the facelift on a Xymon server, with
# nothing but a POSIX shell and the usual tools: no make. The commands are
# those of xymon-plugins' install.sh, so both install the same way.
#
#   XYMONHOME=/usr/lib/xymon/server ./install.sh install-server [PART...]
#   XYMONHOME=/usr/lib/xymon/server ./install.sh uninstall-server [PART...]
#
# With no PART, every part. Settings come from the environment, or as
# NAME=value arguments: XYMONHOME; XYMONWWWDIR, the directory the web server
# serves Xymon's pages from, $XYMONHOME/www unless xymonserver.cfg sets it
# elsewhere; DESTDIR, which stages the install for a package.
#
# Everything the facelift installs is under $XYMONHOME/ext/facelift, as a
# plugin is under ext/: part NAME in ext/facelift/NAME/, the files its
# parts/NAME/PART lists and its version in VERSION, and the facelift's
# settings in ext/facelift/xymonserver.cfg. Two links make them seen: the
# browser reaches the parts through $XYMONWWWDIR/facelift, and Xymon reads
# the settings through $XYMONHOME/etc/xymonserver.d/facelift.cfg, the
# directory its xymonserver.cfg includes (Xymon 4.3.31 and later). Installing
# a part again replaces its directory as a whole and keeps the settings.
# Nothing else is written (SPEC.md, rules 5 and 6): switching a part on is
# the administrator's step, which the message printed after the install
# describes.
#
# uninstall-server removes a part, and the directory and the links once no
# part is left. Removing ext/facelift by hand removes the facelift too,
# settings included: Xymon skips a link in xymonserver.d that points
# nowhere. The next install or uninstall replaces or removes the links.

# A && B || die: die when either fails, which is what each such line means.
# shellcheck disable=SC2015

ROOT=$(cd "$(dirname "$0")" && pwd)

die() { echo "install.sh: $*" >&2; exit 1; }
usage() {
	echo "usage: ./install.sh install-server|uninstall-server [PART...] [NAME=value...]" >&2
	exit 2
}

[ $# -ge 1 ] || usage
ACTION=$1; shift
NAMES=
# A NAME=value argument is exported as given.
# shellcheck disable=SC2163
for a in "$@"; do
	case $a in
		*=*) export "$a" ;;
		*) NAMES="$NAMES $a" ;;
	esac
done

case $ACTION in
	install-server|uninstall-server) ;;
	*) usage ;;
esac

[ -n "${XYMONHOME:-}" ] || die "XYMONHOME is not set: XYMONHOME=<the Xymon server directory> ./install.sh $ACTION [PART...]"
XYMONWWWDIR=${XYMONWWWDIR:-$XYMONHOME/www}
# The link names where ext/facelift will be once installed, not where DESTDIR
# stages it.
EXTDIR=$XYMONHOME/ext/facelift
TARGET=${DESTDIR:-}$EXTDIR
WWWLINK=${DESTDIR:-}$XYMONWWWDIR/facelift
CFGLINK=${DESTDIR:-}$XYMONHOME/etc/xymonserver.d/facelift.cfg

# field PART KEY -- the values of KEY in parts/PART/PART, one per line.
field() { sed -n "s/^$2: *//p" "$ROOT/parts/$1/PART"; }

all_parts() {
	for p in "$ROOT"/parts/*/PART; do
		[ -f "$p" ] || continue
		p=${p%/PART}; echo "${p##*/}"
	done
}

check_name() {
	case $1 in ""|*/*|.*) die "not a part name: '$1'" ;; esac
	[ -f "$ROOT/parts/$1/PART" ] || die "no part $1 here: the parts are $(all_parts | tr '\n' ' ')"
	[ "$(field "$1" name)" = "$1" ] || die "parts/$1/PART does not name itself $1"
}

# ours LINK DEST -- true when LINK is the link this script makes to DEST,
# dangling or not.
ours() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }

# free LINK DEST -- refuse when something other than the link to DEST is at
# LINK. Checked for both links before anything is written.
free() {
	ours "$1" "$2" && return 0
	[ -e "$1" ] || [ -L "$1" ] \
		&& die "$1 exists and is not the facelift's link to $2: left alone"
	return 0
}

# link LINK DEST -- make LINK point at DEST.
link() {
	ours "$1" "$2" && return 0
	mkdir -p "${1%/*}" && ln -s "$2" "$1" || die "cannot create $1"
}

# settings -- the facelift's settings file, created empty the first time and
# kept afterwards: it holds what the administrator switched on.
settings() {
	[ -f "$TARGET/xymonserver.cfg" ] && return 0
	mkdir -p "$TARGET" && cat > "$TARGET/xymonserver.cfg" <<'SETTINGS' || die "cannot write $TARGET/xymonserver.cfg"
# The xymon facelift's settings. Xymon reads this file through
# etc/xymonserver.d/facelift.cfg, after xymonserver.cfg, so a setting here
# takes the place of the one there. Switching a part on adds its line here;
# removing ext/facelift removes them all, and Xymon its own settings again.
SETTINGS
	chmod 644 "$TARGET/xymonserver.cfg"
}

install_part() {
	version=$(field "$1" version)
	[ -n "$version" ] || die "parts/$1/PART has no version"
	files=$(field "$1" files)
	[ -n "$files" ] || die "parts/$1/PART lists no files"
	for f in $files; do
		case $f in */*|.*) die "parts/$1/PART: not a file name: '$f'" ;; esac
		[ -f "$ROOT/parts/$1/$f" ] || die "parts/$1/PART lists $f, which is not there"
	done

	# Built beside its place, then swapped in, so that a failed copy leaves
	# the part as it was installed before.
	mkdir -p "$TARGET" || die "cannot create $TARGET"
	new=$TARGET/.$1.new
	rm -rf "$new" && mkdir "$new" || die "cannot create $new"
	for f in $files; do
		cp "$ROOT/parts/$1/$f" "$new/$f" && chmod 644 "$new/$f" || die "cannot copy $f to $new"
	done
	printf '%s\n' "$version" > "$new/VERSION" && chmod 644 "$new/VERSION" || die "cannot write $new/VERSION"
	rm -rf "${TARGET:?}/$1" && mv "$new" "$TARGET/$1" || die "cannot replace $TARGET/$1"

	echo "Installed $1 $version in $TARGET/$1."
	field "$1" installed
}

uninstall_part() {
	if [ -d "$TARGET/$1" ]; then
		rm -rf "${TARGET:?}/$1" || die "cannot remove $TARGET/$1"
		echo "Uninstalled $1 from $TARGET/$1."
	else
		echo "$1 is not installed in $TARGET."
	fi
}

[ -n "$NAMES" ] || NAMES=$(all_parts)
[ -n "$NAMES" ] || die "no parts here"
for n in $NAMES; do check_name "$n"; done

case $ACTION in
	install-server)
		free "$WWWLINK" "$EXTDIR"
		free "$CFGLINK" "$EXTDIR/xymonserver.cfg"
		settings
		link "$WWWLINK" "$EXTDIR"
		link "$CFGLINK" "$EXTDIR/xymonserver.cfg"
		for n in $NAMES; do install_part "$n"; done
		;;
	uninstall-server)
		for n in $NAMES; do uninstall_part "$n"; done
		# Once no part is left, the directory, its settings and the links go
		# too: the facelift leaves nothing behind.
		left=$(all_parts | while read -r p; do [ -d "$TARGET/$p" ] && echo "$p"; done)
		if [ -z "$left" ]; then
			rm -f "$TARGET/xymonserver.cfg"
			rmdir "$TARGET" 2>/dev/null
		fi
		if [ ! -d "$TARGET" ]; then
			ours "$WWWLINK" "$EXTDIR" && rm -f "$WWWLINK"
			ours "$CFGLINK" "$EXTDIR/xymonserver.cfg" && rm -f "$CFGLINK"
		fi
		;;
esac
exit 0
