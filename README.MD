# plex_sort

This script is designed to handle downloads, rename and store properly...

This script can be used without Plex, it store your medias for you automatically.

## Features
- auto-update (no need to git pull or git clone)
- detect download folders ("filebot" in folder name)
- detect best drive (according to free space)
- rename and move media properly

## Features for root only
- chmod source folders
- chmod target folders
- install automatically script dependencies

## Requirements
- Filebot (a licence might be required)

## Install (will be automated soon)
- download plex_sort.sh
- put it in /opt/scripts
- chmod +x /opt/scripts/plex_sort.sh
- run it
- edit config (~/.config/plex_sort/plex_sort.conf)
- add it to cron
