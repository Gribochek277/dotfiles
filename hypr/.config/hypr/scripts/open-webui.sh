#! /bin/bash

# PORT=1234
#
# if ! ss -ltn | grep -q ":$PORT"; then
#     echo "Server not running. Starting..."
#     /home/serhii/.lmstudio/bin/lms server start &
# else
#     echo "Server is already running on port $PORT."
# fi

flatpak run com.brave.Browser --app=http://100.110.77.11:3000/
