###
# This file is required for building a debian package.
#
# Author(s): Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#
# (C) 2016 LinkMotion Oy
# All Rights Reserved.
###

INSTALLPATH:=$(DESTDIR)/opt/linkmotion/lm-docker-sdk

all:

install:
	mkdir -p $(INSTALLPATH)
	cp -f docker* $(INSTALLPATH)
	cp -f device* $(INSTALLPATH)
	cp -r build $(INSTALLPATH)
	cp README $(INSTALLPATH)
