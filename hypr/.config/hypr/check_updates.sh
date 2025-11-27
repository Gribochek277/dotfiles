#!/bin/bash

sleep 20
# Проверка обновлений с помощью checkupdates
pacman_updates=$(checkupdates | wc -l)

# Проверка обновлений AUR с помощью yay
yay_updates=$(yay -Qu | wc -l)

# Проверка обновлений Flatpak с помощью flatpak
flatpak_updates=$(flatpak remote-update --list-updates | grep -c "available")

# Общее количество обновлений
total_updates=$((pacman_updates + yay_updates))

# Отправка всплывающего сообщения с помощью dunst
if [ "$total_updates" -gt 0 ]; then
  notify-send "Updates available" "Found $total_updates packages."
else
  notify-send "System is updated"
fi
