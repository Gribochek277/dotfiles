#!/bin/bash

SESSION_NAME="split_session"
CMD_LEFT="bluetuith"
CMD_RIGHT="btop"

# Проверяем, запущен ли уже tmux
if ! tmux has-session -t $SESSION_NAME 2>/dev/null; then
    # Создаём новую сессию в tmux с первым окном
    tmux new-session -d -s $SESSION_NAME -n main

    # Разделяем окно вертикально пополам
    tmux split-window -h

    # Запускаем команды в каждой из панелей
    tmux send-keys -t $SESSION_NAME:0.0 "$CMD_LEFT" C-m
    tmux send-keys -t $SESSION_NAME:0.1 "$CMD_RIGHT" C-m
fi

# Подключаемся к сессии
exec tmux attach -t $SESSION_NAME
