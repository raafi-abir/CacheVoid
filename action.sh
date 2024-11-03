#!/system/bin/sh

if [ -e "/system/bin/cleaner" ]; then
  cleaner
  sleep 2
else
  echo "file /system/bin/cleaner not found"
  exit
fi