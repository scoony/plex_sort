#!/bin/bash

## LOG FOLDER missing

## Check if this script is running
check_dupe=$(ps -ef | grep "$0" | grep -v grep | wc -l | xargs)
if [[ "$check_dupe" > "2" ]]; then
  echo "Script already running"
  exit 1
fi

## UI Design
ui_tag_ok="[\e[42m \u2713 \e[0m]"
ui_tag_bad="[\e[41m \u2713 \e[0m]"
ui_tag_warning="[\e[43m \u2713 \e[0m]"
ui_tag_root="[\e[47m \u2713 \e[0m]"

my_config="$HOME/.config/plex_sort/plex_sort.conf"
source $HOME/.config/plex_sort/plex_sort.conf


## Check if root for extra features
printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Check account used"
if [[ "$EUID" == "0" ]] || [[ "$sudo" != "" ]]; then
  echo -e "$ui_tag_ok Root account used"
  native_sudo="1"
  echo ""
else
  if [[ ! -f $log_folder/.no-root ]] && [[ "$sudo" == "" ]]; then
    printf 'Type the password of your account (optional, enter to skip):'
    read user_pass
    echo $user_pass
    if [[ "$user_pass" != "" ]]; then
      echo "sudo=\"$user_pass\"" >> $my_config
      sudo=$user_pass
    else
      touch $log_folder/.no-root
      echo -e "$ui_tag_bad Some optional features are disabled (not root)"
    fi
    echo -e "$ui_tag_bad Some optional features are disabled (not root)"
  fi
  echo ""
fi

## Generate conf and/or load conf
if [[ ! -d ~/.config/plex_sort ]]; then
  mkdir -p ~/.config/plex_sort
  touch $my_config
  echo "mount_folder=\"\"" >> $my_config
  echo "plex_folder=\"\"" >> $my_config
  echo "download_folder=\"\"" >> $my_config
  echo "exclude_folder=\"\"" >> $my_config
  echo "filebot_language=\"\" ## \"en\" in english, \"fr\" in french" >> $my_config
  echo "filebot_season_folder=\"\" ## \"Season\" in english, \"Saison\" in french" >> $my_config
  echo "log_folder=\"\"" >> $my_config
  echo "" >> $my_config
  filebot_folders=`ls "$download_folder" | grep -i "filebot"`
  for folder in $filebot_folders ; do
    echo $folder"=\"\"" >> $my_config
  done
fi

## Install / Check dependencies
printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Install / Check dependencies"
my_dependencies="filebot curl wget awk"
for dependency in $my_dependencies ; do
  if $dependency -help > /dev/null 2>/dev/null ; then
    echo -e "$ui_tag_ok Dependency: $dependency"
  else
    echo -e "$ui_tag_bad Dependency missing: $dependency"
    echo "... trying to install..."
    apt install $dependency -y 2>/dev/null
    if $dependency -help > /dev/null 2>/dev/null ; then
      echo -e "$ui_tag_ok Dependency: $dependency"
    else
      echo -e "$ui_tag_bad Dependency missing: $dependency"
      echo -e "... manual install required..."
      exit 1
    fi
  fi
done
echo ""

## Check FileBot Licence
printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Check FileBot licence"
if [[ ! -f $log_folder/.licence ]]; then
  echo ""
  check_local_licence=`filebot -script fn:sysinfo script | grep "Valid-Until"`
  if [[ "$check_local_licence" == "" ]]; then
    locate_filebot_licence=`locate -ir "filebot*.*.psm$"`
    for licence in $locate_filebot_licence ; do
      filebot_licence_validity=`cat $locate_filebot_licence | grep "Valid-Until" | awk '{ print $2 }'`
      echo "$filebot_licence_validity $locate_filebot_licence" >> $log_folder/licences-choice.log     
    done
    licence_final=`sort $log_folder/licences-choice.log | tail -n1 | awk '{ print $2 }'`
    filebot --license $licence_final
    ## une petite vérification 
  else
    touch $log_folder/.licence
    echo $check_local_licence > $log_folder/.licence
  fi
else
  filebot_date=`cat $log_folder/.licence | awk 'END {print $NF}'`
  echo -e "$ui_tag_ok Filebot is activated ($filebot_date"
  echo ""
fi

## Update and check web
printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Internet availability and Update"
if curl -s -m 3 --head --request GET https://github$update_allowed.com > /dev/null; then 
  remote_md5=`curl -s https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh | md5sum | cut -f1 -d" "`
  local_md5=`md5sum $0 | cut -f1 -d" "`
  if [[ "$remote_md5" != "$local_md5" ]]; then
    echo -e "$ui_tag_bad Update Available"
    echo "... ---"
    function script_upgrade {
      wget --quiet https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh -O /opt/scripts/plex_sort.sh
      chmod +x /opt/scripts/plex_sort.sh
      echo -e "$ui_tag_ok Update Completed, restart script"
## Bonne approche mais fonctionne pas
##      trap 'bash $0' 1
      exit 1
    }
    script_upgrade
  else
    echo -e "$ui_tag_ok Script up to date."
  fi
else
  if [[ "$update_allowed" == "" ]]; then
    echo -e "$ui_tag_bad GitHub unreachable no update."
  else
    echo -e "$ui_tag_warning Update Disabled (config)"
  fi
fi
if curl -s -m 3 --head --request GET https://www.thetvdb.com > /dev/null; then
  echo -e "$ui_tag_ok TheTVDB is online."
else
  echo -e "$ui_tag_bad TheTVDB unreachable."
fi
if curl -s -m 3 --head --request GET https://www themoviedb.org.com > /dev/null; then
  echo -e "$ui_tag_ok TheMovieDB is online."
else
  echo -e "$ui_tag_bad TheMovieDB unreachable."
fi
echo ""

## Detect Plex folders and select best target
printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Detect Plex folders"
plex_folders=`ls -d $mount_folder/*/$plex_folder/`
for plex_path in $plex_folders ; do
  if [[ ! "$exclude_folders" =~ "$plex_path" ]]; then
    plex_path_free=`df -k --output=avail "$plex_path" | tail -n1`
    plex_path_free_human=`df -kh --output=avail "$plex_path" | tail -n1`
    echo -e "$ui_tag_ok Plex folder: $plex_path (free: $plex_path_free_human)"
    echo "$plex_path_free $plex_path" >> $log_folder/temp.log
##    echo ""
  fi
done
best_plex_target=`sort -n $log_folder/temp.log | awk 'END {print $NF}'`
rm $log_folder/temp.log
best_free=`df -kh --output=avail "$best_plex_target" | tail -n1`
echo ""
echo -e "$ui_tag_ok Best target: $best_plex_target ($best_free )"
echo ""

## Detect download folders and space required
printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Detect download folders"
filebot_folders=`ls "$download_folder" | grep -i "filebot"`
for folder in $filebot_folders ; do
  echo -e "$ui_tag_ok Folder: $folder"
  folder_path=`echo $download_folder"/"$folder`
  echo -e "$ui_tag_ok Path: $folder_path"
  check_conf=`cat $log_folder/plex_sort.conf | grep "$folder"`
  if [[ "$check_conf" != "" ]]; then
    echo -e "$ui_tag_ok Config setting: $check_conf"
  else
    echo -e "$ui_tag_bad Folder missing in config"
    echo $folder"=\"\"" >> $my_config
    echo -e "$ui_tag_ok Config updated..."
  fi
  folder_usage=`du -s "$folder_path" 2>/dev/null | awk '{ print $1 }'`
  echo $folder_usage >> $log_folder/temp.log
  echo ""
done
space_required=`cat $log_folder/temp.log | paste -sd+ - | bc`
space_required_human=`cat $log_folder/temp.log | paste -sd+ - | bc | numfmt --to=iec --from-unit=K`
rm $log_folder/temp.log
echo ""
echo -e "$ui_tag_ok Space required to store content: $space_required_human"
echo ""

## Here we go
printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Sorting process"
for folder in $filebot_folders ; do
  source_folder_path=`echo $download_folder"/"$folder`
  target_conf=${!folder}
  echo -e "$ui_tag_ok Source: $folder - Target: $target_conf"
  target_folder_path=`echo $best_plex_target""$target_conf`
  echo -e "$ui_tag_ok Content destination: $target_folder_path"
  if [[ "${folder,,}" =~ "film" ]] || [[ "${folder,,}" =~ "movie" ]]; then
    agent="TheMovieDB"
    format="movieFormat"
    output="{n} ({y})"
  else
    agent="TheTVDB"
    format="seriesFormat"
    output="{n}/{'$filebot_season_folder '+s.pad(2)}/{n} - {sxe} - {t}"
  fi
  echo -e "$ui_tag_ok Agent used: $agent"
  folder_files=`find "$source_folder_path" -type f -iname '*[avi|mp4|mkv]' > $log_folder/$folder.medias.log`
  check_medias=`cat $log_folder/$folder.medias.log`
  if [[ "$check_medias" != "" ]]; then
    filebot -script fn:amc -non-strict --conflict override --lang $filebot_language --encoding UTF-8 --action move "$source_folder_path" --def "$format=$output" --output "$target_folder_path"
    new_media="1"
  fi
  echo ""
done

if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
  ## Plex Update library
  printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "Update Plex library"
  if [[ "$plex_token" == "" ]] || [[ "$plex_port" == "" ]]; then
    plex_pref=`locate Preferences.xml | grep plexmediaserver`
    plex_token_new=`echo $sudo | sudo -kS cat "$plex_pref" 2>/dev/null | grep -o 'Token[^ ]*' | cut -d'"' -f 2`
    echo "plex_token=\"$plex_token_new\"" >> $my_config
    echo -e "$ui_tag_ok Plex Token: $plex_token_new"
    plex_port_new=`echo $sudo | sudo -kS cat "$plex_pref" 2>/dev/null | grep -o 'PortMappingPort[^ ]*' | cut -d'"' -f 2`
    echo "plex_port=\"$plex_port_new\"" >> $my_config
    echo -e "$ui_tag_ok Plex Port: $plex_port_new"
  fi
  if [[ "$new_media" == "1" ]]; then
    echo -e "$ui_tag_warning Update Plex library"
    url_refresh=`echo "http://127.0.0.1:"$plex_port"/library/sections/all/refresh?X-Plex-Token="$plex_token`
      wget -q "$url_refresh"
      rm refresh*
  else
    echo -e "$ui_tag_ok No need to update"
  fi
fi