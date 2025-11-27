#!/bin/bash

# Параметры
FTP_URL="ftp://serhii:48097989Epox@192.168.50.90"
MOUNT_POINT="./mnt/ftp"

# Создаем точку монтирования если нет
mkdir -p "$MOUNT_POINT"

# Проверяем, смонтировано ли уже
if mountpoint -q "$MOUNT_POINT"; then
  fusermount -u "$MOUNT_POINT"
  if mountpoint -q "$MOUNT_POINT"; then
    notify-send "FTP Toggle" "Ошибка: не удалось размонтировать FTP"
  else
    notify-send "FTP Toggle" "FTP успешно размонтирован"
  fi
else
  curlftpfs "$FTP_URL" "$MOUNT_POINT"
  if mountpoint -q "$MOUNT_POINT"; then
    notify-send "FTP Toggle" "FTP успешно смонтирован"
  else
    notify-send "FTP Toggle" "Ошибка при монтировании FTP"
  fi
fi
