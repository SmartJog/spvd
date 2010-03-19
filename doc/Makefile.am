man8_MANS = spvd.man
man5_MANS = spvd.conf.man

DISTCLEANFILES = $(man8_MANS) $(man5_MANS)
EXTRA_DIST = $(man8_MANS) $(man5_MANS)

SUFFIXES = .t2t

.t2t.man:
	$(TXT2TAGS) -o $@ $<
