#!/bin/bash

#######################
## Update Only
if [[ "$@" =~ "--force-update" ]]; then
  echo "PLEX SORT: Force update"
  echo "Script will be overwrited in /opt/script"
  curl -s -m 3 --create-dir -o "/opt/scripts/plex_sort.sh" "https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh"
  echo "Process completed... exit"
  exit 1
fi


printf "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[1m %-62s  \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "PLEX SORT"


#######################
## Check if this script is running
check_dupe=$(ps -ef | grep "$0" | grep -v grep | wc -l | xargs)
if [[ "$check_dupe" > "2" ]]; then
  echo "Script already running"
  exit 1
fi


#######################
## Required for logs and conf
if [[ "$log_folder" == "" ]]; then
  log_folder="$HOME/.config/plex_sort"
fi
if [[ ! -d "$HOME/.config/plex_sort" ]]; then
  mkdir -p "$HOME/.config/plex_sort"
fi
my_config="$HOME/.config/plex_sort/plex_sort.conf"
source $HOME/.config/plex_sort/plex_sort.conf


#######################
## Display Mode
if [[ "$display_mode" == "full" ]] || [[ "$@" =~ "--mode-full" ]]; then
  echo1="echo"
  printf1="printf"
fi


#######################
## Crontab check and/or activation
if [[ "$crontab_activation" == "yes" ]]; then
  if [[ "$crontab_entry" == "" ]]; then
    crontab_entry="*/15 * * * *		/opt/scripts/plex_sort.sh > /var/log/plex_sort.log 2>&1"
  fi
  check_crontab=`crontab -l | grep "plex_sort.sh"`
  if [[ "$check_crontab" == "" ]]; then
    crontab -l > $log_folder/cron-save.txt
    crontab -l | { cat; echo "$crontab_entry"; } | crontab -
    printf "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Script installed in cron" 2>/dev/null
  elif [[ ${check_crontab:0:1} == '#' ]]; then
    $printf1 "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[0m[\e[41m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Script disabled in cron" 2>/dev/null
  else
    $printf1 "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Script activated in cron" 2>/dev/null
  fi
fi


#######################
## Push feature
push-message() {
  push_title=$1
  push_content=$2
  for user in {1..10}; do
    target=`eval echo "\\$target_"$user`
    if [ -n "$target" ]; then
      curl -s \
        --form-string "token=$token_app" \
        --form-string "user=$target" \
        --form-string "title=$push_title" \
        --form-string "message=$push_content" \
        --form-string "html=1" \
        --form-string "priority=0" \
        https://api.pushover.net/1/messages.json > /dev/null
    fi
  done
}


#######################
## MUI Feature
if [[ ! -d $log_folder/MUI ]]; then
  mkdir -p "$log_folder/MUI"
fi
user_lang=$(locale | grep "LANG=" | cut -d= -f2 | cut -d_ -f1)
md5_lang_local=`md5sum $log_folder/MUI/$user_lang.lang | cut -f1 -d" " 2>/dev/null`
md5_lang_remote=`curl -s https://raw.githubusercontent.com/scoony/plex_sort/main/MUI/$user_lang.lang | md5sum | cut -f1 -d" "`
if [[ ! -f $log_folder/MUI/$user_lang.lang ]] || [[ "$md5_lang_local" != "$md5_lang_remote" ]]; then
  printf "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[0m[\e[43m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Language file updated ($user_lang)"
  curl -s -m 3 --create-dir -o "$log_folder/MUI/$user_lang.lang" "https://raw.githubusercontent.com/scoony/plex_sort/main/MUI/$user_lang.lang"
else
  $printf1 "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Language file up to date ($user_lang)" 2>/dev/null
fi
source $log_folder/MUI/$user_lang.lang


#######################
## UI Design
ui_tag_ok="[\e[42m \u2713 \e[0m]"
ui_tag_bad="[\e[41m \u2713 \e[0m]"
ui_tag_warning="[\e[43m \u2713 \e[0m]"
ui_tag_processed="[\e[43m \u2666 \e[0m]"
ui_tag_chmod="[\e[43m \u270E \e[0m]" 
ui_tag_root="[\e[47m \u2713 \e[0m]"
ui_tag_section="\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n"


#######################
## Generate conf and/or load conf
if [[ ! -f "$my_config" ]]; then
  touch $my_config
fi
my_settings_variables="display_mode crontab_entry mount_folder plex_folder download_folder exclude_folders filebot_language filebot_season_folder log_folder token_app target_1 target_2 push_for_move push_for_cleaning update_allowed"
for script_variable in $my_settings_variables ; do
  if [[ ! "${!my_config}" =~ "$script_variable" ]]; then
    echo $script_variable"=\"\"" >> $my_config
    printf "\e[46m\u25B6\u25B6  \e[0m [\e[41m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Config file updated, new variable added ($script_variable)"
    config_updated="1"
  fi
done
filebot_folders=`ls "$download_folder" | grep -i "filebot"`
for folder in $filebot_folders ; do
  if [[ "$my_config" =~ "$folder" ]]; then
    echo $folder"=\"\"" >> $my_config
    printf "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[0m[\e[41m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Config file updated, new folder detected ($folder)"
    echo "... config file updated"
    config_updated="1"
  fi
done
if [[ "$config_updated" != "1" ]]; then
  $printf1 "\e[46m\u25B6\u25B6  \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-56s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Config file is up to date" 2>/dev/null
else
  echo "Edit your config..."
fi

printf "\e[46m\u25B6\u25B6  \e[0m \e[46m  %62s  \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Version: 0.1"
echo ""                                    ## space in between title and sections


#######################
## Check if root for extra features
if [[ "$mui_root_title" == "" ]]; then          ## MUI
  mui_root_title="Check account used"           ##
fi                                              ##
$printf1 "$ui_tag_section" "$mui_root_title" 2>/dev/null
if [[ "$EUID" == "0" ]] || [[ "$sudo" != "" ]]; then
  if [[ "$mui_root_used" == "" ]]; then         ## MUI
    mui_root_used="Root privileges granted"     ##
  fi                                            ##
  $echo1 -e "$ui_tag_ok $mui_root_used" 2>/dev/null
  native_sudo="1"
  $echo1 "" 2>/dev/null
else
  if [[ ! -f $log_folder/.no-root ]] && [[ "$sudo" == "" ]]; then
    if [[ "$mui_root_question" == "" ]]; then                                               ## MUI
      mui_root_question="Type the password of your account (optional, enter to skip): "     ##
    fi                                                                                      ##
    printf '"$mui_root_question"'
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


#######################
## Install / Check dependencies
$printf1 "$ui_tag_section" "Install / Check dependencies" 2>/dev/null
my_dependencies="filebot curl awk trash-put"
for dependency in $my_dependencies ; do
  if $dependency -help > /dev/null 2>/dev/null ; then
    $echo1 -e "$ui_tag_ok Dependency: $dependency" 2>/dev/null
  else
    echo -e "$ui_tag_bad Dependency missing: $dependency"
    echo -e "$tag_ui_warning Installing dependency..."
    echo $sudo | sudo -kS apt install $dependency -y 2>/dev/null
    if $dependency -help > /dev/null 2>/dev/null ; then
      echo -e "$ui_tag_ok Dependency: $dependency"
    else
      echo -e "$ui_tag_bad Dependency missing: $dependency"
      echo -e "... manual install required..."
      exit 1
    fi
  fi
done
$echo1 "" 2>/dev/null


#######################
## Check FileBot Licence
$printf1 "$ui_tag_section" "Check FileBot licence" 2>/dev/null
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
  $echo1 -e "$ui_tag_ok Filebot is activated ($filebot_date" 2>/dev/null
  $echo1 "" 2>/dev/null
fi


#######################
## Update and check web
printf "$ui_tag_section" "Internet availability and Update"
if curl -s -m 3 --head --request GET https://github$update_allowed.com > /dev/null; then 
  remote_md5=`curl -s https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh | md5sum | cut -f1 -d" "`
  local_md5=`md5sum $0 | cut -f1 -d" "`
  if [[ "$remote_md5" != "$local_md5" ]]; then
    echo -e "$ui_tag_bad Update Available"
    echo "... ---"
    function script_upgrade {
      curl -s -m 3 --create-dir -o "/opt/scripts/plex_sort.sh" 'https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh'
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
  TheTVDB="1"
fi
if curl -s -m 3 --head --request GET https://www.themoviedb.org > /dev/null; then
  echo -e "$ui_tag_ok TheMovieDB is online."
else
  echo -e "$ui_tag_bad TheMovieDB unreachable."
  TheMovieDB="1"
fi
echo ""


#######################
## Detect Plex folders and select best target
printf "$ui_tag_section" "Detect Plex folders"
plex_folders=`ls -d $mount_folder/*/$plex_folder/`
for plex_path in $plex_folders ; do
  if [[ ! "$exclude_folders" =~ "$plex_path" ]]; then
    plex_path_free=`df -k --output=avail "$plex_path" | tail -n1`
    plex_path_free_human=`df -kh --output=avail "$plex_path" | tail -n1`
    $echo1 -e "$ui_tag_ok Plex folder: $plex_path (free: $plex_path_free_human)" 2>/dev/null
    if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
      echo $sudo | sudo -kS chmod -R 777 "$plex_path" 2>/dev/null
      $echo1 -e "$ui_tag_chmod new rights (read/write/execute) applied" 2>/dev/null
      $echo1 "" 2>/dev/null
    fi
    echo "$plex_path_free $plex_path" >> $log_folder/temp.log
  fi
done
best_plex_target=`sort -n $log_folder/temp.log | awk 'END {print $NF}'`
rm $log_folder/temp.log
best_free=`df -kh --output=avail "$best_plex_target" | tail -n1`
$echo1 "" 2>/dev/null
echo -e "$ui_tag_ok Best target: $best_plex_target ($best_free )"
echo ""


#######################
## Detect download folders and space required
printf "$ui_tag_section" "Detect download folders"
filebot_folders=`ls "$download_folder" | grep -i "filebot"`
for folder in $filebot_folders ; do
  echo -e "$ui_tag_ok Folder: $folder"
  folder_path=`echo $download_folder"/"$folder`
  $echo1 -e "$ui_tag_ok Path: $folder_path" 2>/dev/null
  if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
    echo $sudo | sudo -kS chmod -R 777 "$folder_path" 2>/dev/null
    $echo1 -e "$ui_tag_chmod new rights (read/write/execute) applied" 2>/dev/null
  fi
  check_conf=`cat $log_folder/plex_sort.conf | grep "$folder"`
  if [[ "$check_conf" != "" ]]; then
    $echo1 -e "$ui_tag_ok Config setting: $check_conf" 2>/dev/null
  else
    echo -e "$ui_tag_bad Folder missing in config"
    echo $folder"=\"\"" >> $my_config
    echo -e "$ui_tag_ok Config updated..."
  fi
  folder_usage=`du -s "$folder_path" 2>/dev/null | awk '{ print $1 }'`
  echo $folder_usage >> $log_folder/temp.log
  $echo1 "" 2>/dev/null
done
space_required=`cat $log_folder/temp.log | paste -sd+ - | bc`
space_required_human=`cat $log_folder/temp.log | paste -sd+ - | bc | numfmt --to=iec --from-unit=K`
rm $log_folder/temp.log
##echo ""
echo -e "$ui_tag_ok Space required to store content: $space_required_human"
echo ""


#######################
## Here we go
printf "$ui_tag_section" "Sorting process"
for folder in $filebot_folders ; do
  source_folder_path=`echo $download_folder"/"$folder`
  target_conf=${!folder}
  echo -e "$ui_tag_ok Source: $folder - Target: $target_conf"
  if [[ "$target_conf" == "" ]]; then
    echo -e "No config provided"
  else
    target_folder_path=`echo $best_plex_target""$target_conf`
    $echo1 -e "$ui_tag_ok Content destination: $target_folder_path" 2>/dev/null
    if [[ "${folder,,}" =~ "film" ]] || [[ "${folder,,}" =~ "movie" ]]; then
      agent="TheMovieDB"
      format="movieFormat"
      output="{n} ({y})"
    else
      agent="TheTVDB"
      format="seriesFormat"
      output="{n}/{'$filebot_season_folder '+s.pad(2)}/{n} - {sxe} - {t}"
    fi
    $echo1 -e "$ui_tag_ok Agent used: $agent" 2>/dev/null
    allow_agent=${!agent}
    if [[ "$allow_agent" != "1" ]]; then
      folder_files=`find "$source_folder_path" -type f -iname '*[avi|mp4|mkv]' > $log_folder/$folder.medias.log`
      check_medias=`cat $log_folder/$folder.medias.log`
      if [[ "$check_medias" != "" ]]; then
        filebot -script fn:amc -non-strict --conflict override --lang $filebot_language --encoding UTF-8 --action move "$source_folder_path" --def "$format=$output" --output "$target_folder_path" 2>/dev/null > $log_folder/filebot_output.txt
        cat "$log_folder/filebot_output.txt" | grep "\[MOVE\]" > $log_folder/move_done.txt
        filebot_moves=()
        while IFS= read -r -d $'\n'; do
        filebot_moves+=("$REPLY")
        done <$log_folder/move_done.txt
        rm $log_folder/move_done.txt
        if [[ "${filebot_moves[@]}" != "" ]]; then
##          echo "DEBUG: Move detected"
          for move_done in "${filebot_moves[@]}"; do
##            echo "DEBUG: $move_done"
            move_source=`echo "$move_done" |  grep -oP '(?<=from \[).*(?=\] to)'`
            move_target=`echo "$move_done" |  grep -oP '(?<=to \[).*(?=\]$)'`
            echo -e "$ui_tag_ok File processed:"
            echo -e "$ui_tag_processed Source: $move_source"
            echo -e "$ui_tag_processed Target: $move_target"
            new_media="1"
            if [[ "$push_for_move" == "yes" ]]; then
              file_source=`basename "$move_source"`
              file_target=`basename "$move_target"`
              target_folder=`dirname "$move_target"`
              my_message=` echo -e "[ <b>MEDIA MOVED</b> ] [ <b>$target_conf</b> ]\n\n<b>Source Name: </b>$file_source\n<b>Target Name: </b>$file_target\n\n<b>Destination: </b>$target_folder"`
              push-message "Plex Sort" "$my_message"
            fi
          done
        fi
      fi
    else
      echo -e "$ui_tag_bad $agent is offline, skipping"
    fi
  fi
  if [[ $echo1 != "" ]]; then
    echo ""
  fi
done
if [[ "$echo1" == "" ]]; then
  echo ""
fi


#######################
## Dupe checker / cleaner
if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
  printf "$ui_tag_section" "Dupe checker/cleaner"
  echo -e "$ui_tag_ok Generating Plex content DBs"
  for folder_db in $plex_folders ; do
    ## RETIRER LES DOSSIERS VIDES - ATTENTION SOUCIS
    ##find "$folder_db" –type d -empty
    disk_db=`echo $folder_db | sed 's/\/Plex\///'`
    disk_db_id="$(basename $disk_db)"
    $echo1 -e "$ui_tag_ok Folder: $folder_db (DB: $disk_db_id.locate.db)" 2>/dev/null
    echo $sudo | sudo -kS updatedb -U "$folder_db" -o "$log_folder/$disk_db_id.locate.db" 2>/dev/null
  done
##  echo -e "$ui_tag_ok Done"
  locate_dbs=`ls $log_folder/*.locate.db`
  locate_path=`echo $locate_dbs | sed 's/ /:/g'`
  echo $sudo | sudo -kS locate -d $locate_path: . 2>/dev/null > $log_folder/full_plex.txt                                                 ## dump the whole dbs in a single file
  cat $log_folder/full_plex.txt | egrep -i ".mkv$|.avi$|.mp4$|.m4v$|.ogm$|.divx$|.ts$|.mp3$|.mpg$" > $log_folder/full_plex_clean.txt      ## remove everything except medias
  my_files=()
  while IFS= read -r -d $'\n'; do
  my_files+=("$REPLY")
  done <$log_folder/full_plex_clean.txt
  touch $log_folder/files_only.txt
  time1=`date +%s`
  echo -e "$ui_tag_ok Extracting filenames... "
  for i in "${my_files[@]}"; do
    basename "$i" >> $log_folder/files_only.txt ## remove paths
    ## remove extension too slow: | rev | cut -f 2- -d '.' | rev
  done
  rm $log_folder/full_plex_clean.txt
  rm $log_folder/full_plex.txt
  cat $log_folder/files_only.txt | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' > $log_folder/files_done.txt                           ## remove extensions and everything lower case
  rm $log_folder/files_only.txt
  time2=`date +%s`
  duration=$(($time2-$time1))
  echo -e "$ui_tag_ok Extraction completed (in "$duration"s)"
  cat $log_folder/files_done.txt | uniq -cd > $log_folder/dupes.txt                                                                       ## search for dupes
  rm $log_folder/files_done.txt
  my_dupes=()
  while IFS= read -r -d $'\n'; do
  my_dupes+=("$REPLY")
  done <$log_folder/dupes.txt
  rm $log_folder/dupes.txt
  if [[ "${my_dupes[@]}" != "" ]]; then
    echo -e "$ui_tag_warning Dupes Found... processing"
    echo "......"
    for j in "${my_dupes[@]}"; do
      my_dupe_file=`echo $j | awk '{for (i=2; i<=NF; i++) printf $i FS}'`
      echo $sudo | sudo -kS locate -i -d $locate_path: $my_dupe_file 2>/dev/null > $log_folder/current_dupe.txt                           ## locate dupes
      this_dupe=()
      while IFS= read -r -d $'\n'; do
      this_dupe+=("$REPLY")
      done <$log_folder/current_dupe.txt
      rm $log_folder/current_dupe.txt
      for k in "${this_dupe[@]}"; do                                                                                                      ## collect infos on each dupe
        date_file=`date -r "$k" "+%Y-%m-%d"`
        echo "$date_file ¤$k¤" >> $log_folder/current_process.txt
        echo -e "$ui_tag_warning Dupe Found: $k Date: $date_file"
      done
      file_remove=`sort $log_folder/current_process.txt | head -n1 | grep -oP '(?<=¤).*(?=¤)'`
      if [[ "$file_remove" != "" ]]; then
        trash-put "$file_remove"
        echo -e "$ui_tag_ok File sent to trash: $file_remove"
        if [[ "$push_for_cleaning" == "yes" ]]; then
          trash_file_date=`date -r "$file_remove" "+%d/%m/%Y"`
          trash_file_format=`mediainfo --Inform="Video;%Format%" "$file_remove"`
          trash_file_resolution=`mediainfo --Inform="Video;%Width% x %Height%" "$file_remove"`
          trash_file_duration=`mediainfo --Inform="Video;%Duration/String3%" "$file_remove"`
          my_push_message=`echo -e "[ <b>DUPE SENT TO TRASH</b> ]\n\n<b>File:</b> $file_remove\n<b>Received: </b>$trash_file_date\n<b>Codec: </b>$trash_file_format\n<b>Resolution: </b>$trash_file_resolution\n<b>Duration: </b>$trash_file_duration"`
          push-message "Plex Sort" "$my_push_message"
        fi
      fi
      rm $log_folder/current_process.txt
      echo "......"
    done
  else
    echo -e "$ui_tag_ok No dupes found"
  fi
  echo ""
fi


#######################
## Clean Download folders
printf "$ui_tag_section" "Clean download folders"
filebot_folders=`ls "$download_folder" | grep -i "filebot"`
for folder in $filebot_folders ; do
  echo -e "$ui_tag_ok Cleaning $folder"
  folder_path=`echo $download_folder"/"$folder`
  find "$folder_path" -type f -not -iregex '.*\.\(mkv\|avi\|mp4\|m4v\|mpg\|divx\|ts\|ogm\)' -delete
  find "$folder_path" -not -path "$folder_path" -type d -empty -delete
done
echo ""


#######################
## Plex Update library
if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
  printf "$ui_tag_section" "Update Plex library"
  if [[ "$plex_token" == "" ]] || [[ "$plex_port" == "" ]]; then
    plex_pref=`locate Preferences.xml | grep plexmediaserver | head -n1`
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
      curl -s '$url_refresh'
  else
    echo -e "$ui_tag_ok No need to update"
  fi
fi