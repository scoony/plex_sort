![script icon](https://github.com/scoony/plex_sort/raw/main/Icons/plex_sort.png)

# plex_sort

This script is designed to handle downloads, rename and store properly...

This script can be used without Plex, it store your medias for you automatically.

## Features
- [x] auto-install filebot licence if file in the computer
- [x] auto-update (no need to git pull or git clone)
- [x] detect download folders ("filebot" in folder name)
- [x] detect best drive (according to free space)
- [x] rename and move media properly
- [x] update Plex library
- [x] check dupes
- [x] auto-clean download folders
- [x] send push messages
- [ ] send mails
- [x] root features thru sudo or root cron

## Features for root only (need to check)
- chmod source folders
- chmod target folders
- install automatically script dependencies
- check for dupes and remove older file (medias only)

## Requirements
- filebot (a licence might be required)
- awk
- wget
- curl

## Install (will be automated soon)
- download plex_sort.sh
- put it in /opt/scripts
- chmod +x /opt/scripts/plex_sort.sh
- run it
- edit config (~/.config/plex_sort/plex_sort.conf)
- add it to cron

