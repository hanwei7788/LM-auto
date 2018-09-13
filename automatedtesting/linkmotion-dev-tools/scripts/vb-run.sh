#!/bin/bash

#
# This script runs the ui_center built with vb-build.sh inside
# virtual machine.
#
# You can set this as run command in QtC.
#
# Should be quite easily adoptable for other packages also.
#

SSH_OPTS="-p 5555"

APP_BINARY="/home/system/src/ui_center/src/ui_center_bin"

xdotool search --onlyvisible --name "Running. - Oracle VM VirtualBox" windowraise

echo Setting binary ownership for $APP_BINARY

ssh $SSH_OPTS root@localhost chown org.c4c.ui_center:systemapps $APP_BINARY

echo Killing any old instances and starting binary..

ssh $SSH_OPTS -tt system@localhost << EOF
  systemctl --user stop skytree-compositor.service
  killall ui_center ui_center-compiled ui_center_b
  killall -9 ui_center_bin ui_center_bin-compiled ui_center_b
  sleep 1s
  export EGL_PLATFORM=fbdev
  export QT_QPA_PLATFORM=eglfs
  export QT_QPA_EGLFS_DEPTH=32
  export QT_QPA_EGLFS_HIDECURSOR=1
  export QT_QPA_EVDEV_MOUSE_PARAMETERS=/dev/nomouse
  export QT_COMPOSITOR_NEGATE_INVERTED_Y=1
  /usr/bin/c4c-invoker $APP_BINARY -plugin vboxtouch --hardware 2 --demodata en
EOF

