# xymon-facelift

Optional skins, page layouts and tools for the
[Xymon](https://github.com/xymon-monitoring/xymon) web interface.

It is a facelift, not a redesign: it changes how the pages look, not what
they show or how they work. A redesign would need an analysis of what users
need first, and is out of scope here.

## Rules

Xymon's default stays as it is, and everything here is opt-in. The rules, and
the test that enforces each, are in [SPEC.md](SPEC.md).

## Planned contents

| Part | What it does |
| --- | --- |
| skins | Icon sets beside the classic GIFs: accessible and vector (SVG), each with a still variant |
| layouts | Page layouts (modern, minimal), loaded through `XYMONBODYFOOTER`, so no Xymon template changes |
| lookandfeel | A page that previews a layout and an icon set on a real Xymon page, and shows the commands to keep it |
| xymonsettings.sh | A script that shows and changes `xymonserver.cfg` settings, and switches skins and layouts |

## Installing

On the Xymon server, as the user that may write its directory:

```sh
XYMONHOME=/usr/lib/xymon/server ./install.sh install-server [PART...]
XYMONHOME=/usr/lib/xymon/server ./install.sh uninstall-server [PART...]
```

With no PART, every part. The commands are those of
[xymon-plugins](https://github.com/xymon-monitoring/xymon-plugins), and so is
the place: everything goes under `$XYMONHOME/ext/facelift/`, one directory
per part, and the facelift's settings in `ext/facelift/xymonserver.cfg`. Two
links make them seen: the browser reaches the parts through
`$XYMONWWWDIR/facelift`, and Xymon reads the settings through
`$XYMONHOME/etc/xymonserver.d/facelift.cfg`, after its own `xymonserver.cfg`.
Nothing else is written: installing changes no page until you switch a part
on, as the message after the install says. Installing again keeps the
settings.

`XYMONWWWDIR` is `$XYMONHOME/www`; give it only when `xymonserver.cfg` sets it
elsewhere. `DESTDIR` stages the install for a package. Settings can also be
given as `NAME=value` arguments.

To remove the facelift, run `uninstall-server`, or remove
`$XYMONHOME/ext/facelift` by hand: the settings go with the directory, Xymon
skips the link in `xymonserver.d` that now points nowhere, and its pages are
its own again. The next `uninstall-server` removes the two links left behind.
Xymon reads `xymonserver.d` from 4.3.31 on; with an older one, add the
facelift's settings to `xymonserver.cfg` yourself, and remove them with it.

## Contributing

Discussion happens in the issues of this repository. Changes come as pull
requests; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

GNU General Public License version 2, the same as Xymon; see [LICENSE](LICENSE).
