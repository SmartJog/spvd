SUBDIRS = plugins

dist_pkgdata_PYTHON = \
	baseplugin.py \
	basejob.py

nodist_pkgdata_PYTHON = \
	importerplugin.py

edit = $(SED) \
	-e 's|@PACKAGE_VERSION[@]|$(PACKAGE_VERSION)|g'

importerplugin.py: importerplugin.py.in Makefile
	$(edit) $< > $@

BUILT_SOURCES = importerplugin.py
CLEANFILES = $(BUILT_SOURCES)
EXTRA_DIST = importerplugin.py.in
