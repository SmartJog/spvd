
toolsdir = $(pkgdatadir)/tools
tools_DATA = \
	checks-list.py

edit = sed \
	-e 's|@pkgdatadir[@]|$(pkgdatadir)|g' \
	-e 's|@datadir[@]|$(datadir)|g' \
	-e 's|@exec_prefix[@]|$(exec_prefix)|g' \
	-e 's|@prefix[@]|$(prefix)|g'

$(tools_DATA): $(tools_DATA:=.in) Makefile
	$(edit) $@.in > $@

CLEANFILES = $(tools_DATA)

EXTRA_DIST = $(tools_DATA:=.in)
