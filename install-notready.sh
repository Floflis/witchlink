#!/bin/bash

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
sudo update-mime-database /usr/share/mime

echo "Installing icons for .wl files..."
cp include/application-x-wl.svg /usr/share/icons/hicolor/scalable/mimetypes/
sudo gtk-update-icon-cache /usr/share/icons/gnome/ -f
