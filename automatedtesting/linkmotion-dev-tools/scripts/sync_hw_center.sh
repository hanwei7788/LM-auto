#!/bin/bash
# This scripts help:
#  - scp ui_center source code to HW
#  - change ui_center to run non compiled qml version
#  - make ui_center load qml from custom location scp into HW
#
# So you can edit code from your host machine and run this scripts to re-run ui_center
# without re-compiling.
#
# Please change the path to your environment.

echo "SCP ui_center/src to /usr/apps/org.c4c.ui_center/src"
scp -r /home/mdk/src/ui_center/src root@$1:/usr/apps/org.c4c.ui_center/
ssh root@$1 chown -R org.c4c.ui_center:systemapps /usr/apps/org.c4c.ui_center/src

echo "Changing qmlpath to /usr/apps/org.c4c.ui_center/src"
echo 'sed -i "s|qmlpath=.*|qmlpath=/usr/apps/org.c4c.ui_center/src|" /altdata/system/ui/center-configurations/default.ini' | ssh root@$1 /bin/bash
echo 'sed -i "s|hardware=.*|hardware=2|" /altdata/system/ui/center-configurations/default.ini' | ssh root@$1 /bin/bash

echo "Changing ui_center_compiled to ui_center_bin in /usr/lib/systemd/user/skytree-compositor.service"
echo 'sed -i "s|ui_center_compiled|ui_center_bin|" /usr/lib/systemd/user/skytree-compositor.service' | ssh root@$1 /bin/bash

echo "Restarting user@20000...."
ssh root@$1 sync
ssh root@$1 systemctl restart user\@20000

