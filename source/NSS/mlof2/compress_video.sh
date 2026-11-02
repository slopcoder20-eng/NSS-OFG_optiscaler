#!/bin/bash
                                                     
source /home/sh/rocm_env/bin/activate
F=$(python -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')
"$F" -y -loglevel error -i "$1" -vf scale=${3:-2400}:-2 -c:v libx264 -crf 24 "$2"
