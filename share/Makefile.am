SUBDIRS = plugins

dist_pkgdata_DATA = \
	baseplugin.py \
	basejob.py

nodist_pkgdata_DATA = \
	importerplugin.py

edit = $(SED) \
	-e 's|@PACKAGE_VERSION[@]|$(PACKAGE_VERSION)|g' \
	-e 's|@PACKAGE_NAME[@]|$(PACKAGE_NAME)|g'

importerplugin.py: importerplugin.py.in Makefile
	$(edit) $< > $@

BUILT_SOURCES = importerplugin.py
CLEANFILES = $(BUILT_SOURCES)
EXTRA_DIST = importerplugin.py.in
