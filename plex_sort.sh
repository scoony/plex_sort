#!/bin/bash


## Generate conf
if [[ ! -d ~/.config/plex_sort ]]; then
  mkdir -p ~/.config/plex_sort
  my_config="$HOME/.config/plex_sort/plex_sort.conf"
  touch $my_config
  echo "mount_folder=\"\"" >> $my_config
  echo "plex_folder=\"\"" >> $my_config
  echo "download_folder=\"\"" >> $my_config
  echo "exclude_folder=\"\"" >> $my_config
  echo "log_folder=\"\"" >> $my_config
  echo "" >> $my_config
  filebot_folders=`ls "$download_folder" | grep -i "filebot"`
  for folder in $filebot_folders ; do
    echo $folder"=\"\"" >> $my_config
  done
fi
source $HOME/.config/plex_sort/plex_sort.conf

## Update process
if curl -s -m 3 --head --request GET https://github.com > /dev/null; then 
  remote_md5=`curl -s https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh | md5sum | cut -f1 -d" "`
  local_md5=`md5sum $0 | cut -f1 -d" "`
##  echo "Remote: $remote_md5"
##  echo "Local: $local_md5"
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
  echo "GITHUB unreachable no update."
  echo ""
fi

## Detect Plex folders and select best target
plex_folders=`ls -d $mount_folder/*/$plex_folder/`
for plex_path in $plex_folders ; do
  if [[ ! "$exclude_folders" =~ "$plex_path" ]]; then
##    echo "----"
##    echo "Plex Storage: $plex_path"
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

