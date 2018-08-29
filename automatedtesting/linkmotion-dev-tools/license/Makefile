SHELL = /bin/bash
INSTALLPATH:=$(DESTDIR)/opt/linkmotion/license

all:

venv: venv/bin/activate

venv/bin/activate:
	test -d venv ||	virtualenv venv
	venv/bin/pip install -Ur requirements.txt
	touch venv/bin/activate

setup: venv

check:
	pep8 scripts

install:
	mkdir -p $(INSTALLPATH)
	cp -rf . $(INSTALLPATH)

clean:
	rm -Rf venv
