dist_man8_MANS = spvd.man sjconf-spvd.man
dist_man5_MANS = spvd.conf.man spvd-plugins.man

CLEANFILES = $(dist_man8_MANS) $(dist_man5_MANS)
EXTRA_DIST = $(wildcard $(srcdir)/*.t2t)

SUFFIXES = .t2t

.t2t.man:
	$(TXT2TAGS) -o $@ $<
