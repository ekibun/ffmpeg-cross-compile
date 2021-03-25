#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

for comp in "fdk-aac" "x264" "x265" "ffmpeg" 
do
  for arc in "arm" "arm64" "x86" "x86_64" 
  do
    $DIR/build.config.sh $comp android $arc
  done
  for arc in "x86_64" 
  do
    $DIR/build.config.sh $comp win32 $arc
  done
done