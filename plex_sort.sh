#!/bin/bash


## Generate conf and/or load conf
if [[ ! -d ~/.config/plex_sort ]]; then
  mkdir -p ~/.config/plex_sort
  my_config="$HOME/.config/plex_sort/plex_sort.conf"
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
source $HOME/.config/plex_sort/plex_sort.conf

## Install / Check dependencies
my_dependencies="filebot curl wget awk"
for dependency in $my_dependencies ; do
  if $dependency -help > /dev/null 2>/dev/null ; then
    echo "Dependency ok: $dependency"
  else
    echo "Dependency missing: $dependency"
    echo "Trying to install..."
    apt install $dependency -y 2>/dev/null
    if $dependency -help > /dev/null 2>/dev/null ; then
      echo "Dependency ok: $dependency"
    else
      echo "Dependency missing: $dependency"
      echo "Manual install required..."
      exit 1
    fi
  fi
done
echo ""

## Update process
if curl -s -m 3 --head --request GET https://github.com > /dev/null; then 
  remote_md5=`curl -s https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh | md5sum | cut -f1 -d" "`
  local_md5=`md5sum $0 | cut -f1 -d" "`
  if [[ "$remote_md5" != "$local_md5" ]]; then
    echo "Update Available"
    echo "---"
    function script_upgrade {
      wget --quiet https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh -O /opt/scripts/plex_sort.sh
      chmod +x /opt/scripts/plex_sort.sh
      echo "Update Completed, restart script"
## Bonne approche mais fonctionne pas
##      trap 'bash $0' 1
      exit 1
    }
    script_upgrade
  fi
else
  echo "GitHub unreachable no update."
  echo ""
fi

## Detect Plex folders and select best target
plex_folders=`ls -d $mount_folder/*/$plex_folder/`
for plex_path in $plex_folders ; do
  if [[ ! "$exclude_folders" =~ "$plex_path" ]]; then
    plex_path_free=`df -k --output=avail "$plex_path" | tail -n1`
    plex_path_free_human=`df -kh --output=avail "$plex_path" | tail -n1`
    echo "Plex folder: $plex_path (free: $plex_path_free_human)"
    echo "$plex_path_free $plex_path" >> $log_folder/temp.log
##    echo ""
  fi
done
best_plex_target=`sort -n $log_folder/temp.log | awk 'END {print $NF}'`
rm $log_folder/temp.log
best_free=`df -kh --output=avail "$best_plex_target" | tail -n1`
echo ""
echo "Best target: $best_plex_target ($best_free )"
echo ""

## Detect download folders and space required
filebot_folders=`ls "$download_folder" | grep -i "filebot"`
for folder in $filebot_folders ; do
  echo "Folder: $folder"
  folder_path=`echo $download_folder"/"$folder`
  echo "Path: $folder_path"
  folder_usage=`du -s "$folder_path" 2>/dev/null | awk '{ print $1 }'`
  echo $folder_usage >> $log_folder/temp.log
done
space_required=`cat $log_folder/temp.log | paste -sd+ - | bc`
space_required_human=`cat $log_folder/temp.log | paste -sd+ - | bc | numfmt --to=iec --from-unit=K`
rm $log_folder/temp.log
echo ""
echo "Space required to store content: $space_required_human"

## Here we go
for folder in $filebot_folders ; do
  source_folder_path=`echo $download_folder"/"$folder`
  target_conf=${!folder}
  echo ""
  echo "Source: $folder - Target: $target_conf"
  target_folder_path=`echo $best_plex_target""$target_conf`
  echo "Content destination: $target_folder_path"
  if [[ "${folder,,}" =~ "film" ]] || [[ "${folder,,}" =~ "movie" ]]; then
    agent="TheMovieDB"
    format="movieFormat"
    output="{n} ({y})"
  else
    agent="TheTVDB"
    format="seriesFormat"
    output="{n}/{'$filebot_season_folder '+s.pad(2)}/{n} - {sxe} - {t}"
  fi
  echo "Agent used: $agent"
  folder_files=`find "$source_folder_path" -type f -iname '*[avi|mp4|mkv]' > $log_folder/$folder.medias.log`
  check_medias=`cat $log_folder/$folder.medias.log`
  if [[ "$check_medias" != "" ]]; then
    filebot -script fn:amc -non-strict --conflict override --lang $filebot_language --encoding UTF-8 --action move "$source_folder_path" --def "$format=$output" --output "$target_folder_path"
  fi
done
