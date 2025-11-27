#!/bin/bash
source /home/serhii/miniconda3/etc/profile.d/conda.sh
conda activate open-webui

open-webui serve
notify-send "open-webui started"

