###
# This file is required for building a debian package.
#
# Author(s): Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#
# (C) 2016 LinkMotion Oy
# All Rights Reserved.
###
DISTRO:=xenial
ARCH:=amd64

all:
	cd hardware-setup && make
	cd lm-docker-sdk && make
	cd scripts && make
	cd license && make

install:
	cd hardware-setup && make install
	cd lm-docker-sdk && make install
	cd scripts && make install
	cd license && make install

###
# a helper for building a debian package
deb:
	debuild -S -uc -us
	cowbuilder-dist $(DISTRO) $(ARCH) build ../linkmotion-dev-tools_0.2-1.dsc
	cp $(HOME)/pbuilder/$(DISTRO)_result/linkmotion-dev-tools_0.2-1_$(ARCH).* ..

###
# a helper target for setting up the package build environment
deb-env:
	sudo apt-get install ubuntu-dev-tools cowbuilder
	cowbuilder-dist $(DISTRO) $(ARCH) create
