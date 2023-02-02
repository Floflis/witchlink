#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
flouser=$(logname)

is_root=false
if [ "$([[ $UID -eq 0 ]] || echo "Not root")" = "Not root" ]
   then
      is_root=false
   else
      is_root=true
fi
maysudo=""
if [ "$is_root" = "false" ]
   then
      maysudo="sudo"
   else
      maysudo=""
fi

echo "Installing mimetypes and their icons..." # this is continuously adding the same entries to /etc/mime.types and have to be fixed
cat >> /etc/mime.types <<EOF
application/x-wl			        wl
EOF
#-<- should check if line is already added, before re-adding!
cat > /usr/share/mime/packages/x-wl.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns='http://www.freedesktop.org/standards/shared-mime-info'>
  <mime-type type="application/x-wl">
    <comment>Witchlink link file</comment>
    <generic-icon name="application-x-wl"/>
    <glob pattern="*.wl"/>
  </mime-type>
</mime-info>

EOF
$maysudo update-mime-database /usr/share/mime

echo "Installing icons for .wl files..."
cp include/application-x-wl.svg /usr/share/icons/hicolor/scalable/mimetypes/
$maysudo gtk-update-icon-cache /usr/share/icons/gnome/ -f
