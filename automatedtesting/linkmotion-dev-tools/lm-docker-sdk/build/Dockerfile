FROM opensuse

RUN zypper --non-interactive ref
RUN zypper --non-interactive up 
RUN zypper --non-interactive in curl git rsync sudo hostname bsdtar ca-certificates-mozilla

COPY *.rpm /root/
RUN zypper --non-interactive --no-gpg-checks in /root/*.rpm

COPY _oscrc /root/.oscrc
COPY setup_osc.sh /root/
COPY oscbuild.sh /root/

