# xymon-facelift specification

The rules for the facelift, from the goal down to each rule and the test that
enforces it. A rule changes through a pull request to this file; the
discussion behind it is in issue #1.

## Goal

A facelift of the Xymon web interface: it changes how the pages look, not what
they show or how they work. It is not a redesign. A redesign would first need
an analysis of what users need and of what other monitoring tools do; that is
out of scope here.

## Principles

- **Xymon's default does not change.** Without a setting from this project, the
  pages Xymon generates are byte for byte what they are today.
- **Everything is opt-in.** An administrator installs the facelift, switches each
  part on per installation, and can switch it off again.
- **Xymon itself gets only small changes, off by default**, each as its own pull
  request in the Xymon repository.
- **Every rule is enforced by a test**, so a change that breaks a rule fails at
  once.
- **Two levels of rules.** Every part meets the rules for every part, which is
  enough to be switched on by choice. A part that could one day replace the
  classic look as the default also meets the stricter rules of "Safe as the
  default". Making a part the default is still a separate decision, because it
  changes the default that the first principle keeps.

## Scope

In scope:

- **Skins:** icon sets beside the classic GIFs, selected with `XYMONSKIN`.
- **Layouts:** stylesheets and scripts that restyle the pages, loaded through
  `XYMONBODYFOOTER`. This includes moving the info, trends and clientlog
  columns, which are not tests, to the start or the end, or merging them: a
  change to the page in the browser, allowed in a layout that is switched on
  by choice, not in one that is safe as the default (rule 18).
- **The Look and feel page:** previews a layout and a skin on a real Xymon page,
  and shows the commands that make the choice permanent.
- **xymonsettings.sh:** shows and changes `xymonserver.cfg` settings, and
  switches skins and layouts.
- **In Xymon, off by default:** the page refresh as a setting, and icon classes.

Parked for later (label `later`):

- **Text icons**, drawing each status icon as a character. Proposed so that a
  page can be copied into an LLM for analysis. For that use case, the status
  board (`xymondboard`) is the better source; a read-only API or MCP server on
  top of it would be a separate project. If text icons return, they come as a
  separate opt-in, and rule 9 applies to them.

Out of scope:

- What the pages show (hosts, tests, colours) and how the CGIs work.
- A redesign of the interface; see Goal.

## Rules

Each rule names the test that enforces it and where that test lives. "Not
written yet" means the rule holds by review until its test exists. Rules 1 to
17 hold for every part; rules 18 to 22 are the stricter level for a part that
is safe as the default.

### Xymon itself (tests in the Xymon repository)

**1. The default output does not change.**
With the default configuration, the pages Xymon generates are byte for byte
the same as before the change. First every page that goes through the code a
pull request changes: the pages that write status icons, and the headers with
the META refresh. The rest (snapshot, reports, WML, RSS) is added step by step.
Test: render the pages from the shared status board in
`tests/lib/xymongen-board.sh` (xymon-monitoring/xymon#605), mask date, time
and version, and compare them with reference pages stored in the Xymon tree.
A pull request that changes the HTML on purpose regenerates the reference with
the test's update mode, so the change shows in its diff, where the reviewer
judges it. The update mode refuses to save the pages of a run that failed.
Besides the comparison, the test checks a few things on its own, so that a
broken reference does not become the norm unnoticed: each status in its colour,
and the META refresh of rule 2. Not written yet.

**2. The META refresh stays.**
Every page that refreshes today carries exactly the same
`<META HTTP-EQUIV="REFRESH" ...>` line with the default configuration.
Test: check that line in each refreshing page. Not written yet.

**3. No extra files are loaded by default.**
With the default configuration, a page references no stylesheet, script or
image that it did not reference before.
Test: compare the `href` and `src` references with those of the reference
pages of rule 1. Not written yet.

**4. Every new setting is off by default.**
Its default reproduces today's output, and it is documented in
`xymonserver.cfg(5)`. The planned settings: the page refresh, whose default is
today's META line, and opt-in icon classes.
Test: rules 1 to 3 cover the default; each setting also gets a test of what it
does when switched on. Not written yet.

### The facelift (tests in this repository)

**5. No Xymon template changes.**
Layouts are loaded through `XYMONBODYFOOTER`, skins through `XYMONSKIN`. The
facelift does not edit or replace a Xymon header or footer template.
Test: install the facelift into a scratch Xymon tree and check that no file
Xymon installed changed. Not written yet.

**6. Opt-in and reversible.**
Installing the facelift changes nothing visible until a part is switched on. It
never overwrites a file Xymon ships; a setting in `xymonserver.cfg` is changed
only as rule 12 says. Switching a part off brings back the default pages
unchanged. So does removing the facelift's directory, `ext/facelift`, by hand:
a part keeps everything it needs there, its settings included, which Xymon
reads through a link in `etc/xymonserver.d` and skips once the link points
nowhere; Xymon's own `XYMONSKIN` and `XYMONBODYFOOTER` then apply again.
Xymon reads `xymonserver.d` from 4.3.31 on; with an older one the settings go
into `xymonserver.cfg` by hand, and come out of it the same way.
Test: install, render, switch on and off again, render, and compare with the
pages before installing; then switch on again, remove `ext/facelift`, render,
and compare again. Not written yet.

**7. Works on a plain Xymon 4.3.x.**
Skins and layouts work without the new Xymon settings of rule 4. A layout finds
the status icons by their file name when the icon classes are off.
Test: run the layout tests against pages from an unmodified Xymon 4.3.x. Not
written yet.

**8. The page keeps refreshing when something fails.**
With a layout on, a page keeps its META refresh, unless the administrator has
chosen a script refresh through the refresh setting. Then the timer is inline in
the page, not in the layout file, with the META refresh inside `<noscript>` as a
fallback, so a layout file that fails to load cannot stop the refresh. An inline
script blocked by a Content-Security-Policy is a known limit of that opt-in.
Test: render each refreshing page with every layout, and check for the META
refresh, or for the inline timer and the `<noscript>` fallback when the script
refresh is chosen. Not written yet.

**9. No information is lost.**
Every skin and layout shows everything today's icons show: colour,
acknowledged, recent, nopropagate, age, and dial-up and reverse tests. Today,
dial-up and reverse tests have their own icon set (`--dialupskin`,
`--reverseskin`), and nopropagate and age are in the ALT and TITLE text; every
mode keeps both.
Test: render a status board that holds each of these states with every skin
and layout, and check that each state is still shown. Not written yet.

**10. Nothing is loaded from the internet.**
No CDN, no web fonts, no external script, stylesheet or image: everything a
page loads comes from the Xymon server itself. Many Xymon servers have no
internet access, and a monitoring page must not depend on a third party.
Test: check every shipped HTML, CSS and JavaScript file for references to
another host. Not written yet.

**11. Plain ASCII files.**
Every shipped stylesheet, script and HTML file is plain ASCII. The character
set of the Xymon pages is a setting, `HTMLCONTENTTYPE`: UTF-8 by default, but
the shipped `xymonserver.cfg` suggests another one, such as iso-8859-1, where
the hosts send that; stylesheets and scripts get whatever character set the
web server sends with them. Plain ASCII reads the same in each. A character outside
ASCII is written as an escape (`\u2713` in JavaScript and CSS, `&#x2713;` in
HTML).
Test: check every shipped text file for bytes outside ASCII. Not written yet.

**12. An existing setting is added to, never replaced.**
When the facelift switches a part on, it adds to a setting the administrator
already has: a layout is added to an existing `XYMONBODYFOOTER`, not put in its
place. Switching the part off removes only what the facelift added.
Test: start from a `xymonserver.cfg` with a local `XYMONBODYFOOTER`, switch a
layout on and off, and check that the local value is kept and then restored.
Not written yet.

**13. The page still works when a file fails.**
Rule 8 covers the refresh; this covers the page itself. If a stylesheet,
script or icon of the facelift does not load, the page shows the same
information as without the facelift, and every link and form still works.
Test: render each page with every layout and skin, with their files missing,
and check that every status and link of the board is still there. Not written
yet.

**14. Light on large pages, and still unless chosen otherwise.**
No selector that scans the whole page for each element, and no script whose
work grows faster than the number of hosts and tests: a slow page delays an
alarm. Icons move only when the administrator chose moving icons: every skin
has a still variant, used when a still set is chosen, and a still directory
is never made to move. The Debian and Ubuntu packages point `XYMONSKIN` at
`gifs/static` by default and own that directory, so the facelift leaves it
as it is (rule 6).
Test: review for the selectors and scripts, as a time bound would be flaky in
CI; a check that no file of a still set is animated. Not written yet.

**15. No status hidden at any width.**
A layout may rearrange a page for a small screen, but never hides a status; a
column it moves or merges stays reachable, and a large table scrolls instead of
breaking.
Test: render each page at a narrow width with every layout, and check that
every status of the board is in the page and visible. Not written yet.

**16. One layout, every page.**
A layout reaches the status pages, the reports, the administration pages and
the CGIs alike, and must not break the pages it was not written for.
Test: render every page type with every layout, and check that its forms and
tables are intact. Not written yet.

**17. No positional selectors.**
A layout finds what it styles by what it is (a class, a `SUMMARY` attribute, an
icon's file name), not by its position in the page, which moves with the
number of hosts and tests.
Test: review, until a check for it exists.

### Safe as the default (tests in this repository)

A part that could replace the classic look as the default meets rules 1 to 17
and these, with still icons only. Meeting them makes a part a candidate; it
does not make it the default (see Principles).

**18. The page is not changed in the browser.**
Stylesheets only: no script adds, removes or moves an element, and every table
keeps its rows, columns and cells as Xymon writes them. Scripts and parsers
that read the page see what they see today.
Test: render each page with the part on, and compare its structure in the
browser with the page Xymon wrote. Not written yet.

**19. Works without JavaScript.**
With scripts switched off or blocked, a Content-Security-Policy included, the
page shows everything and refreshes as it does today.
Test: render each page with the part on and scripts disabled, and check the
statuses and the META refresh. Not written yet.

**20. Not by colour alone.**
Each status can be told apart without seeing colour, by its shape or its text,
and every status keeps enough contrast against its background.
Test: render each status with the part on, and check that each has a
distinct shape or text and meets a contrast ratio. Not written yet.

**21. Every page type, older browsers included.**
The part is checked on every page type, and in older browsers, including the
pages' deprecated attributes and inline styles.
Test: the tests of rules 16, 18 and 19 run in each supported browser; which
browsers are supported is decided with the first candidate. Not written yet.

**22. Proven by choice first.**
A part is proposed as the default only after it has been used as an opt-in,
with the feedback of the people who used it.
Test: none; checked by the decision that would make it the default.
