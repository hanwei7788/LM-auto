#!/bin/bash

# This script help you edit and run ui_center in SDK virtual machine without
# recompiling ui_center.
# It changes the default.ini configuration file to RD.ini (in /altdata/system/ui/center-configuration/)
# The contents of RD.ini should at least include qmlpath config
# You can add more override config to RD.ini as you want.
# 
# Example of an RD.ini file:
#  [options]
#  hardware=2
#  qmlpath=/home/system/ui_center/src
#  RD_enabled=true
#  demodata=en_US

echo "======================================== Start a new Center ======================================="
sudo /altdata/devel/bin/rsync -a /media/sf_src/ui_center/ /home/system/ui_center
sudo sed -i 's/current\/file=.*/current\/file=\"RD.ini\"/' /altdata/system/ui/center-configurations/configuration-file.ini
sudo chown -R org.c4c.ui_center:systemapps /home/system/ui_center
sudo chown -R org.c4c.ui_center:systemapps /usr/apps/org.c4c.ui_center/bin
echo "=================================================================================================="

# non compiled qml vanila version
/usr/bin/c4c-invoker /usr/apps/org.c4c.ui_center/bin/ui_center_bin -plugin vboxtouch

# compiled qml vanila version
#/usr/bin/c4c-invoker /usr/apps/org.c4c.ui_center/bin/ui_center_compiled -plugin vboxtouch

# non compiled qml B varint version
#/usr/bin/c4c-invoker /usr/apps/org.c4c.ui_center/bin/ui_center_b -plugin vboxtouch

# without invoker (only use this with root user)
#/usr/apps/org.c4c.ui_center/bin/ui_center_bin -plugin vboxtouch
