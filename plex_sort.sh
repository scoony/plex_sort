#!/bin/bash


#######################
## Advanced command arguments
die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts eushf:cm:l:-: OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "$OPT" in
    h | help )
            echo -e "\033[1mPLEX SORT - help\033[0m"
            echo ""
            echo "Usage : ./plex_sort.sh [option]"
            echo ""
            echo "Available options:"
            echo "[value*] means optional argument"
            echo ""
            echo " -h or --help                              : this help menu"
            echo " -u or --update                            : update this script"
            echo " -m [value] or --mode=[value]              : change display mode (full)"
            echo " -l [value] or --language=[value]          : override language (fr or en)"
            echo " -c or --cron-log                          : display latest cron log"
            echo " -e [value*] or --edit-config=[value*]     : edit config file (default: nano)"
            echo " -s [value*] or --status=[value*]          : status/enable/disable the script"
            echo " -f \"[value]\" or --find=\"[value]\"          : find something in the logs"
            exit 0
            ;;
    f | find )
            needs_arg
            arg_search_value="$OPTARG"
            echo -e "\033[1mPLEX SORT - find feature\033[0m"
            echo "This feature require root privileges"
            echo ""
            echo "Checking for root privileges..."
            source "$HOME/.config/plex_sort/plex_sort.conf" 2>/dev/null
            if [[ "$sudo" == "" ]] && [[ "$EUID" != "0" ]]; then
              echo "No root privileges... exit"
            else
              echo "Root privileges granted"
            fi
            echo "Updating db..."
            echo "$sudo" | sudo -kS updatedb 2>/dev/null
            logs_path=`echo "$sudo" | sudo -kS locate -r "/plex_sort/logs$" 2>/dev/null`
            echo "Searching..."
            for log_path in $logs_path ; do
              my_logs=( `echo "$sudo" | sudo -kS find $log_path -type f 2>/dev/null` )
              for my_log in ${my_logs[@]} ; do
                echo "$sudo" | sudo -kS grep -Hin "$arg_search_value" $my_log 2>/dev/null
              done
            done
            exit 0
            ;;
    u | update )
            echo -e "\033[1mPLEX SORT - Update initiated\033[0m"
            read -n 1 -p "Do you want to proceed [y/N]:" yn $force_update_check
            printf "\r                                                     "
            if [[ "${yn}" == @(y|Y) ]]; then
              echo ""
              this_script=$(realpath -s "$0")
              echo "Script location : "$this_script
              script_remote="https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh"
              if curl -m 2 --head --silent --fail "$script_remote" 2>/dev/null >/dev/null; then
                echo "Script available online on GitHub "
                md5_local=`md5sum "$this_script" | cut -f1 -d" " 2>/dev/null`
                md5_remote=`curl -s "$script_remote" | md5sum | cut -f1 -d" "`
                echo "MD5 local  : "$md5_local
                echo "MD5 remote : "$md5_remote
                if [[ "$md5_local" != "$md5_remote" ]]; then
                  echo "A new version of the script is available... downloading"
                  curl -s -m 3 --create-dir -o "$this_script" "$script_remote"
                  echo "Update completed... exit"
                else
                  echo "The script is up to date... exit"
                fi
              else
                echo ""
                echo "Script offline"
              fi
            else
              echo ""
              echo "Nothing was done"
            fi
            exit 0
            ;;
    c | cron-log )
            echo -e "\033[1mPLEX SORT - latest cron log\033[0m"
            echo ""
            if [[ -f "/var/log/plex_sort.log" ]]; then
              date_log=`date -r "/var/log/plex_sort.log" `
              cat "/var/log/plex_sort.log"
              echo ""
              echo "Log created : "$date_log
            else
              echo "No log found"
            fi
            exit 0
            ;;
    m | mode )
            needs_arg
            arg_display_mode="$OPTARG"
            display_mode_supported=( "full" )
            echo -e "\033[1mPLEX SORT - display mode override\033[0m"
            echo ""
            if [[ "${display_mode_supported[@]}" =~ "$arg_display_mode" ]]; then
              echo "Display mode activated: $arg_display_mode"
            else
              echo "Display mode $arg_display_mode not supported yet"
              exit 0
            fi
            ;;
    l | language )
            needs_arg
            display_language="$OPTARG"
            language_supported=( "fr" "en" )
            echo
            if [[ "${language_supported[@]}" =~ "$display_language" ]]; then
              echo "Language selected : $display_language"
            else
              echo "Language $display_language not supported yet"
              exit 0
            fi
            ;;
    e | edit-config )
            eval next_arg=\${$OPTIND}
            if [[ "$next_arg" == "" ]]; then
              echo -e "\033[1mPLEX SORT - config editor\033[0m"
              echo ""
              echo "No editor specified, using default (nano)"
              nano "$HOME/.config/plex_sort/plex_sort.conf"
              exit 0
            else
              echo -e "\033[1mPLEX SORT - config editor\033[0m"
              echo ""
              if command -v $next_arg ; then
                echo "Editing config with: $next_arg"
                $next_arg "$HOME/.config/plex_sort/plex_sort.conf"
              else
                echo "There is no software called \"$next_arg\" installed"
              fi
              exit 0
            fi
            ;;
    s | status )
            echo -e "\033[1mPLEX SORT - status (cron)\033[0m"
            echo ""
            eval next_arg=\${$OPTIND}
            if [[ "$next_arg" == @(|status) ]]; then
              echo "Checking scheduler status..."
              crontab -l > $HOME/my_old_cron.txt
              cron_check=`cat $HOME/my_old_cron.txt | grep plex_sort`
              if [[ "$cron_check" != "" ]]; then
                echo "- script was added in the cron"
                cron_status=`cat $HOME/my_old_cron.txt | grep plex_sort | grep "^#"`
                if [[ "$cron_status" == "" ]]; then
                  echo "- script is currently enabled"
                else
                  echo "- script is currently disabled"
                fi
              else
                echo "- script wasn't added in the cron"
              fi
            elif [[ "$next_arg" == "enable" ]]; then
              echo "Enabling the script in the cron"
              crontab -l > $HOME/my_old_cron.txt
              safety_check=`cat $HOME/my_old_cron.txt | grep plex_sort | grep "^#"`
              if [[ "$safety_check" != "" ]]; then
                cat $HOME/my_old_cron.txt | grep plex_sort | sed  's/^#//' > $HOME/my_new_cron.txt
                crontab $HOME/my_new_cron.txt
              else
                echo "Script is already enabled"
              fi
            elif [[ "$next_arg" == "disable" ]]; then
              echo "Disabling the script in the cron"
              crontab -l > $HOME/my_old_cron.txt
              safety_check=`cat $HOME/my_old_cron.txt | grep plex_sort | grep "^#"`
              if [[ "$safety_check" == "" ]]; then
                cat $HOME/my_old_cron.txt | grep plex_sort | sed 's/^/#/' > $HOME/my_new_cron.txt
                crontab $HOME/my_new_cron.txt
              else
                echo "Script is already disabled"
              fi
            fi
            rm $HOME/my_old_cron.txt 2>/dev/null
            rm $HOME/my_new_cron.txt 2>/dev/null
            exit 0
            ;;
    ??* )          die "Illegal option --$OPT" ;;  # bad long option
    ? )            exit 2 ;;  # bad short option (error reported via getopts)
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list


#######################
## Fix printf special char issue
Lengh1="55"
Lengh2="61"
lon() ( echo $(( Lengh1 + $(wc -c <<<"$1") - $(wc -m <<<"$1") )) )
lon2() ( echo $(( Lengh2 + $(wc -c <<<"$1") - $(wc -m <<<"$1") )) )


printf "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[1m %-61s  \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "PLEX SORT"


#######################
## Check if this script is running
check_dupe=$(ps -ef | grep "$0" | grep -v grep | wc -l | xargs)
check_cron=`echo $-`
if [[ "$check_cron" =~ "i" ]]; then
  process_number="2"
else
  process_number="3"
fi
if [[ "$check_dupe" > "$process_number" ]]; then
  echo "Script already running ($check_dupe)"
  date
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
if [[ ! -d "$HOME/.config/plex_sort/logs" ]]; then
  mkdir -p "$HOME/.config/plex_sort/logs"
fi
my_config="$HOME/.config/plex_sort/plex_sort.conf"
source $HOME/.config/plex_sort/plex_sort.conf 2>/dev/null


#######################
## Display Mode
if [[ "$display_mode" == "full" ]] || [[ "$arg_display_mode" =~ "full" ]]; then
  echo1="echo"
  printf1="printf"
fi


#######################
## MUI Feature
if [[ ! -d $log_folder/MUI ]]; then
  mkdir -p "$log_folder/MUI"
fi
if [[ "$display_language" == "" ]]; then
  user_lang=$(locale | grep "LANG=" | cut -d= -f2 | cut -d_ -f1)
else
  user_lang=$display_language
fi
md5_lang_local=`md5sum $log_folder/MUI/$user_lang.lang 2>/dev/null | cut -f1 -d" " `
md5_lang_remote=`curl -s https://raw.githubusercontent.com/scoony/plex_sort/main/MUI/$user_lang.lang | md5sum | cut -f1 -d" "`
if [[ ! -f $log_folder/MUI/$user_lang.lang ]] || [[ "$md5_lang_local" != "$md5_lang_remote" ]]; then
  if [[ "$mui_lang_updated" == "" ]]; then                                                  ## MUI
    mui_lang_updated="Language file updated ($user_lang)"                                   ##
  fi                                                                                        ##
  source $log_folder/MUI/$user_lang.lang 2>/dev/null
  printf "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[43m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_lang_updated") "$mui_lang_updated"
  curl -s -m 3 --create-dir -o "$log_folder/MUI/$user_lang.lang" "https://raw.githubusercontent.com/scoony/plex_sort/main/MUI/$user_lang.lang"
else
  if [[ "$mui_lang_ok" == "" ]]; then                                                       ## MUI
    mui_lang_ok="Language file up to date ($user_lang)"                                     ##
  fi                                                                                        ##
  source $log_folder/MUI/$user_lang.lang 2>/dev/null
##  $printf1 "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-55s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "$mui_lang_ok" 2>/dev/null
  $printf1 "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_lang_ok") "$mui_lang_ok" 2>/dev/null
fi
if [[ -f ./MUI/$user_lang.lang ]]; then
  source ./MUI/$user_lang.lang
  my_language_file="./MUI/$user_lang.lang"
else
  source $log_folder/MUI/$user_lang.lang
  my_language_file="$log_folder/MUI/$user_lang.lang"
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
    if [[ "$mui_cron_installed" == "" ]]; then                                              ## MUI
      mui_cron_installed="Script installed in cron"                                         ##
    fi                                                                                      ##
    printf "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_cron_installed") "$mui_cron_installed" 2>/dev/null
  elif [[ ${check_crontab:0:1} == '#' ]]; then
    if [[ "$mui_cron_disabled" == "" ]]; then                                               ## MUI
      mui_cron_disabled="Script disabled in cron"                                           ##
    fi                                                                                      ##
    $printf1 "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[41m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_cron_disabled") "$mui_cron_disabled" 2>/dev/null
  else
    if [[ "$mui_cron_enabled" == "" ]]; then                                                ## MUI
      mui_cron_enabled="Script enabled in cron"                                             ##
    fi                                                                                      ##
    $printf1 "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_cron_enabled") "$mui_cron_enabled" 2>/dev/null
  fi
fi


#######################
## Push feature
push-message() {
  push_title=$1
  push_content=$2
  push_priority=$3
  if [[ "$push_priority" == "" ]]; then
    push_priority="-1"
  fi
  for user in {1..10}; do
    target=`eval echo "\\$target_"$user`
    if [ -n "$target" ]; then
      curl -s \
        --form-string "token=$token_app" \
        --form-string "user=$target" \
        --form-string "title=$push_title" \
        --form-string "message=$push_content" \
        --form-string "html=1" \
        --form-string "priority=$push_priority" \
        https://api.pushover.net/1/messages.json > /dev/null
    fi
  done
}


#######################
## Loading spinner
function display_loading() {
  pid="$*"
#  spin='▁▂▃▄▅▆▇█▇▆▅▄▃▂▁'
#  spin='⠁⠂⠄⡀⢀⠠⠐⠈'
#  spin='-\|/'
#  spin="▉▊▋▌▍▎▏▎▍▌▋▊▉"
#  spin='←↖↑↗→↘↓↙'
#  spin='▖▘▝▗'
#  spin='◢◣◤◥'
#  spin='◰◳◲◱'
#  spin='◴◷◶◵'
#  spin='◐◓◑◒'
#  spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  if [[ "$mui_loading_spinner" == "" ]]; then                                               ## MUI
    mui_loading_spinner="Loading..."                                                        ##
  fi                                                                                        ##
  lengh_spinner=${#mui_loading_spinner}
  if [[ "$loading_spinner" == "" ]]; then
    spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  else
    spin=$loading_spinner
  fi
  charwidth=1
  i=0
  tput civis # cursor invisible
  mon_printf="\r                                                                             "
  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i + $charwidth) % ${#spin}))
    printf "\r[\e[43m \u039E \e[0m] %"$lengh_spinner"s %s" "$mui_loading_spinner" "${spin:$i:$charwidth}"
    sleep .1
  done
  tput cnorm
  printf "$mon_printf" && printf "\r"
}


#######################
## UI Design
ui_tag_ok="[\e[42m \u2713 \e[0m]"
ui_tag_bad="[\e[41m \u2713 \e[0m]"
ui_tag_warning="[\e[43m \u2713 \e[0m]"
ui_tag_processed="[\e[43m \u2794 \e[0m]"
ui_tag_chmod="[\e[43m \u270E \e[0m]" 
ui_tag_root="[\e[47m \u2713 \e[0m]"
ui_tag_section="\e[44m[\u2263\u2263\u2263]\e[0m \e[44m \e[1m %-*s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n"


#######################
## Generate conf and/or load conf
if [[ ! -f "$my_config" ]]; then
  touch $my_config
fi
my_settings_variables="display_mode crontab_entry mount_folder plex_folder download_folder exclude_folders dupe_extensions_filter filebot_language filebot_season_folder log_folder token_app target_1 target_2 push_for_move push_for_cleaning update_allowed"
desc_display_mode=" ## (optional) \"full\" for full display output"
desc_crontab_entry=" ## (optional) custom crontab"
desc_mount_folder=" ## where are mounted your drives (usually \"/mnt\")"
desc_plex_folder=" ## foldername containing your Plex content in each drive (usually \"Plex\")"
desc_download_folder=" ## where your download folders are located (personally \"/mnt/sdb1/Downloads\")"
desc_exclude_folders=" ## Plex folders to exclude (example: \"/mnt/sdb1/Plex\")"
desc_dupe_extensions_filter=" ## (optional) Search only those extensions for dupes, separate by pipes"
desc_filebot_language=" ## \"fr\" for french or \"en\" for english (example)" 
desc_filebot_season_folder=" ## Directory name of the Season folders (\"Saison\" in french, \"Season\" in english...)"
desc_log_folder=" ## (optional) custom log folder location"
desc_token_app=" ## (optional) pushover setting (available on the website)"
desc_target_1=" ## (optional) pushover ID of the primary target"
desc_target_2=" ## (optional) pushover ID of the secondary target"
desc_push_for_move=" ## (optional) \"yes\" to send push message on moves"
desc_push_for_cleaning=" ## (optional) \"yes\" to send push message on cleaning"
desc_update_allowed=" ## put anything to disable script updates"
my_config_file=`cat $my_config`
for script_variable in $my_settings_variables ; do
  if [[ ! "$my_config_file" =~ "$script_variable" ]]; then
    description=`echo "desc_"$script_variable`
    echo $script_variable"=\"\"${!description}" >> $my_config
    if [[ "$mui_config_new_variable" == "" ]]; then                                         ## MUI
      mui_config_new_variable="Config updated, new variable ($script_variable)"             ##
    fi                                                                                      ##
    source $my_language_file
    printf "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[41m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_config_new_variable") "$mui_config_new_variable"
    config_updated="1"
  fi
done
filebot_folders=`ls "$download_folder" 2>/dev/null | grep -i "filebot"`
for folder in $filebot_folders ; do
  if [[ ! "$my_config_file" =~ "$folder" ]]; then
    echo $folder"=\"\"" >> $my_config
    if [[ "$mui_config_new_folder" == "" ]]; then                                           ## MUI
      mui_config_new_folder="Config updated, new folder ($folder)"                          ##
    fi                                                                                      ##
    source $my_language_file
    printf "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[41m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_config_new_folder") "$mui_config_new_folder"
    echo "... config file updated"
    config_updated="1"
  fi
done
if [[ "$config_updated" != "1" ]]; then
  if [[ "$mui_config_ok" == "" ]]; then                                                     ## MUI
    mui_config_ok="Config file is up to date"                                               ##
  fi                                                                                        ##
  $printf1 "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[0m[\e[42m  \e[0m] %-*s  \e[0m]\e[46m \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon "$mui_config_ok") "$mui_config_ok" 2>/dev/null
else
  echo "Edit your config..."
  exit 1
fi


executed_date=$(date)
printf "\e[46m\u23E5\u23E5   \e[0m \e[46m  %*s  \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon2 "$executed_date") "$executed_date"
##printf "\e[46m\u23E5\u23E5   \e[0m \e[46m  %61s  \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "Version: 0.1"
echo ""                                    ## space in between title and sections


#######################
## Check if root for extra features
if [[ "$mui_root_title" == "" ]]; then                                                      ## MUI
  mui_root_title="Check account used"                                                       ##
fi                                                                                          ##
$printf1 "$ui_tag_section" $(lon2 "$mui_root_title") "$mui_root_title" 2>/dev/null
if [[ "$EUID" == "0" ]] || [[ "$sudo" != "" ]]; then
  if [[ "$mui_root_used" == "" ]]; then                                                     ## MUI
    mui_root_used="Root privileges granted"                                                 ##
  fi                                                                                        ##
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
    if [[ "$user_pass" != "" ]]; then
      echo "sudo=\"$user_pass\"" >> $my_config
      sudo=$user_pass
    else
      touch $log_folder/.no-root
      if [[ "$mui_root_disabled" == "" ]]; then                                             ## MUI
        mui_root_disabled="Some optional features are disabled (not root)"                  ##
      fi                                                                                    ##
      echo -e "$ui_tag_bad Smui_root_disabled"
    fi
    if [[ "$mui_root_disabled" == "" ]]; then                                               ## MUI
      mui_root_disabled="Some optional features are disabled (not root)"                    ##
    fi                                                                                      ##
    echo -e "$ui_tag_bad $mui_root_disabled"
  fi
  echo ""
fi


#######################
## Install / Check dependencies
if [[ "$mui_dependencies_title" == "" ]]; then                                              ## MUI
  mui_dependencies_title="Install / Check dependencies"                                     ##
fi                                                                                          ##
$printf1 "$ui_tag_section" $(lon2 "$mui_dependencies_title") "$mui_dependencies_title" 2>/dev/null
my_dependencies="filebot curl awk trash-put"
for dependency in $my_dependencies ; do
  if $dependency -help > /dev/null 2>/dev/null ; then
    if [[ "$mui_dependencies_dep" == "" ]]; then                                            ## MUI
      mui_dependencies_dep="Dependency:"                                                    ##
    fi                                                                                      ##
    $echo1 -e "$ui_tag_ok $mui_dependencies_dep $dependency" 2>/dev/null
  else
    if [[ "$mui_dependencies_dep_missing" == "" ]]; then                                    ## MUI
      mui_dependencies_dep_missing="Dependency missing:"                                    ##
    fi                                                                                      ##
    echo -e "$ui_tag_bad $mui_dependencies_dep_missing $dependency"
    if [[ "$mui_dependencies_install" == "" ]]; then                                        ## MUI
      mui_dependencies_dep_install="Installing dependency..."                               ##
    fi                                                                                      ##
    echo -e "$tag_ui_warning $mui_dependencies_dep_install"
    echo $sudo | sudo -kS apt install $dependency -y 2>/dev/null
    if $dependency -help > /dev/null 2>/dev/null ; then
      echo -e "$ui_tag_ok $mui_dependencies_dep $dependency"
    else
      echo -e "$ui_tag_bad $mui_dependencies_dep_missing $dependency"
      if [[ "$mui_dependencies_manual" == "" ]]; then                                       ## MUI
        mui_dependencies_dep_manual="... manual install required..."                        ##
      fi                                                                                    ##
      echo -e "$mui_dependencies_dep_manual"
      exit 1
    fi
  fi
done
$echo1 "" 2>/dev/null


#######################
## Check FileBot Licence
if [[ "$mui_filebot_title" == "" ]]; then                                                   ## MUI
  mui_filebot_title="Check FileBot licence"                                                 ##
fi                                                                                          ##
$printf1 "$ui_tag_section" $(lon2 "$mui_filebot_title") "$mui_filebot_title" 2>/dev/null
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
  if [[ "$mui_filebot_ok" == "" ]]; then                                                    ## MUI
    mui_filebot_ok="Filebot is activated ("                                                 ##
  fi                                                                                        ##
  $echo1 -e "$ui_tag_ok $mui_filebot_ok$filebot_date" 2>/dev/null
  $echo1 "" 2>/dev/null
fi


#######################
## Update and check web
if [[ "$mui_update_title" == "" ]]; then                                                    ## MUI
  mui_update_title="Internet availability and Update"                                       ##
fi                                                                                          ##
printf "$ui_tag_section" $(lon2 "$mui_update_title") "$mui_update_title"
if curl -s -m 3 --head --request GET https://github$update_allowed.com > /dev/null; then 
  remote_md5=`curl -s https://raw.githubusercontent.com/scoony/plex_sort/main/plex_sort.sh | md5sum | cut -f1 -d" "`
  local_md5=`md5sum $0 | cut -f1 -d" "`
  if [[ "$remote_md5" != "$local_md5" ]]; then
    if [[ "$mui_update_available" == "" ]]; then                                            ## MUI
      mui_update_available="Update available"                                               ##
    fi                                                                                      ##
    echo -e "$ui_tag_bad $mui_update_available"
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
    if [[ "$mui_update_perfect" == "" ]]; then                                              ## MUI
      mui_update_perfect="Script up to date"                                                ##
    fi                                                                                      ##
    echo -e "$ui_tag_ok $mui_update_perfect"
  fi
else
  if [[ "$update_allowed" == "" ]]; then
    if [[ "$mui_update_github_down" == "" ]]; then                                          ## MUI
      mui_update_github_down="GitHub unreachable no update"                                 ##
    fi                                                                                      ##
    echo -e "$ui_tag_bad $mui_update_github_down"
  else
    if [[ "$mui_update_disabled" == "" ]]; then                                             ## MUI
      mui_update_disabled="Update disabled (config)"                                        ##
    fi                                                                                      ##
    echo -e "$ui_tag_warning $mui_update_disabled"
  fi
fi
if curl -s -m 3 --head --request GET https://www.thetvdb.com > /dev/null; then
  if [[ "$mui_update_tvdb_online" == "" ]]; then                                            ## MUI
    mui_update_tvdb_online="TheTVDB is online"                                              ##
  fi                                                                                        ##
  echo -e "$ui_tag_ok $mui_update_tvdb_online"
else
  if [[ "$mui_update_tvdb_offline" == "" ]]; then                                           ## MUI
    mui_update_tvdb_offline="TheTVDB is unreachable"                                        ##
  fi                                                                                        ##
  echo -e "$ui_tag_bad $mui_update_tvdb_offline"
  TheTVDB="1"
fi
if curl -s -m 3 --head --request GET https://www.themoviedb.org > /dev/null; then
  if [[ "$mui_update_moviedb_online" == "" ]]; then                                         ## MUI
    mui_update_moviedb_online="TheMovieDB is online"                                        ##
  fi                                                                                        ##
  echo -e "$ui_tag_ok $mui_update_moviedb_online"
else
  if [[ "$mui_update_moviedb_offline" == "" ]]; then                                        ## MUI
    mui_update_moviedb_offline="TheMovieDB is unreachable"                                  ##
  fi                                                                                        ##
  echo -e "$ui_tag_bad $mui_update_moviedb_offline"
  TheMovieDB="1"
fi
echo ""


#######################
## Detect Plex folders and select best target
if [[ "$mui_plex_folder_title" == "" ]]; then                                               ## MUI
  mui_plex_folder_title="Detect Plex folders"                                               ##
fi                                                                                          ##
printf "$ui_tag_section" $(lon2 "$mui_plex_folder_title") "$mui_plex_folder_title"
plex_folders=`ls -d $mount_folder/*/$plex_folder/`
for plex_path in $plex_folders ; do
  if [[ ! "$exclude_folders" =~ "$plex_path" ]]; then
    plex_path_free=`df -k --output=avail "$plex_path" | tail -n1`
    plex_path_free_human=`df -kh --output=avail "$plex_path" | tail -n1`
    if [[ "$mui_plex_folder_drive" == "" ]]; then                                           ## MUI
      mui_plex_folder_drive="Plex folder: $plex_path (free: $plex_path_free_human)"         ##
    fi                                                                                      ##
    source $my_language_file
    $echo1 -e "$ui_tag_ok $mui_plex_folder_drive" 2>/dev/null
    if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
      echo $sudo | sudo -kS chmod -R 777 "$plex_path" 2>/dev/null
      if [[ "$mui_plex_folder_chmod" == "" ]]; then                                         ## MUI
        mui_plex_folder_chmod="Permissions (read/write/execute) applied"                    ##
      fi                                                                                    ##
      $echo1 -e "$ui_tag_chmod $mui_plex_folder_chmod" 2>/dev/null
      $echo1 "" 2>/dev/null
    fi
    echo "$plex_path_free $plex_path" >> $log_folder/temp.log
  fi
done
best_plex_target=`sort -n $log_folder/temp.log | awk 'END {print $NF}'`
rm $log_folder/temp.log
best_free=`df -kh --output=avail "$best_plex_target" | tail -n1`
$echo1 "" 2>/dev/null
if [[ "$mui_plex_folder_best" == "" ]]; then                                                ## MUI
  mui_plex_folder_best="Best target: $best_plex_target ($best_free )"                       ##
fi                                                                                          ##
  source $my_language_file
echo -e "$ui_tag_ok $mui_plex_folder_best"
echo ""


#######################
## Detect download folders and space required
if [[ "$mui_download_title" == "" ]]; then                                                  ## MUI
  mui_download_title="Detect download folders"                                              ##
fi                                                                                          ##
printf "$ui_tag_section" $(lon2 "$mui_download_title") "$mui_download_title"
filebot_folders=`ls "$download_folder" | grep -i "filebot"`
overall_download_free=`df -k --output=avail "$download_folder" | tail -n1`
if [[ "$overall_download_free" -le "50000000" ]]; then
  if [[ "$mui_download_free" == "" ]]; then                                                 ## MUI
    mui_download_free="Not enough space in download folders (less then 50G)"                ##
  fi                                                                                        ##
  echo -e "$ui_tag_bad $mui_download_free"
  if [[ "$mui_push_message_download_full" == "" ]]; then                                    ## MUI
    mui_push_message_download_full="[ <b>DISK FULL</b> ]\n\nThere is less then 50Gb in the download hard drive" ##
  fi                                                                                        ##
  my_message=` echo -e "$mui_push_message_download_full"`
  push-message "Plex Sort" "$my_message" "1"
fi
for folder in $filebot_folders ; do
  if [[ "$mui_download_folder" == "" ]]; then                                               ## MUI
    mui_download_folder="Folder: $folder"                                                   ##
  fi                                                                                        ##
  source $my_language_file
  echo -e "$ui_tag_ok $mui_download_folder"
  folder_path=`echo $download_folder"/"$folder`
  if [[ "$mui_download_folder_path" == "" ]]; then                                          ## MUI
    mui_download_folder_path="Path: $folder_path"                                           ##
  fi                                                                                        ##
  source $my_language_file
  $echo1 -e "$ui_tag_ok $mui_download_folder_path" 2>/dev/null
  if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
    echo $sudo | sudo -kS chmod -R 777 "$folder_path" 2>/dev/null
    if [[ "$mui_download_rights" == "" ]]; then                                             ## MUI
      mui_download_rights="Permissions (read/write/execute) applied"                        ##
    fi                                                                                      ##
    $echo1 -e "$ui_tag_chmod $mui_download_rights" 2>/dev/null
  fi
  check_conf=`cat $log_folder/plex_sort.conf | grep "$folder"`
  if [[ "$check_conf" != "" ]]; then
    if [[ "$mui_download_conf_ok" == "" ]]; then                                            ## MUI
      mui_download_conf_ok="Config setting: $check_conf"                                    ##
    fi                                                                                      ##
    source $my_language_file
    $echo1 -e "$ui_tag_ok $mui_download_conf_ok" 2>/dev/null
  else
    if [[ "$mui_download_missing" == "" ]]; then                                            ## MUI
      mui_download_missing="Folder missing in config"                                       ##
    fi                                                                                      ##
    echo -e "$ui_tag_bad $mui_download_missing"
    echo $folder"=\"\"" >> $my_config
    if [[ "$mui_download_conf_updated" == "" ]]; then                                       ## MUI
      mui_download_conf_updated="Config updated..."                                         ##
    fi                                                                                      ##
    echo -e "$ui_tag_ok $mui_download_conf_updated"
  fi
  folder_usage=`du -s "$folder_path" 2>/dev/null | awk '{ print $1 }'`
  echo $folder_usage >> $log_folder/temp.log
  $echo1 "" 2>/dev/null
done
space_required=`cat $log_folder/temp.log | paste -sd+ - | bc`
space_required_human=`cat $log_folder/temp.log | paste -sd+ - | bc | numfmt --to=iec --from-unit=K`
rm $log_folder/temp.log
if [[ "$mui_download_df_required" == "" ]]; then                                            ## MUI
  mui_download_df_required="Space required to store content: $space_required_human"         ##
fi                                                                                          ##
source $my_language_file
echo -e "$ui_tag_ok $mui_download_df_required"
echo ""


#######################
## Here we go
if [[ "$mui_sorting_title" == "" ]]; then                                                   ## MUI
  mui_sorting_title="Sorting process"                                                       ##
fi                                                                                          ##
printf "$ui_tag_section" $(lon2 "$mui_sorting_title") "$mui_sorting_title"
for folder in $filebot_folders ; do
  source_folder_path=`echo $download_folder"/"$folder`
  target_conf=${!folder}
  if [[ "$mui_sorting_resume" == "" ]]; then                                                ## MUI
    mui_sorting_resume="Source: $folder - Target: $target_conf"                             ##
  fi                                                                                        ##
  source $my_language_file
  echo -e "$ui_tag_ok $mui_sorting_resume"
  if [[ "$target_conf" == "" ]]; then
    if [[ "$mui_sorting_no_config" == "" ]]; then                                           ## MUI
      mui_sorting_no_config="No config provided"                                            ##
    fi                                                                                      ##
    echo -e "$ui_tag_bad $mui_sorting_no_config"
    ## A VERIFIER PROBABLE ERREUR GRAVE (AURAIT DU ETRE REGLER SECTION PRECEDENTE)
  else
    target_folder_path=`echo $best_plex_target""$target_conf`
    if [[ "$mui_sorting_target_path" == "" ]]; then                                         ## MUI
      mui_sorting_target_path="Content destination: $target_folder_path"                    ##
    fi                                                                                      ##
    source $my_language_file
    $echo1 -e "$ui_tag_ok $mui_sorting_target_path" 2>/dev/null
    if [[ "${folder,,}" =~ "film" ]] || [[ "${folder,,}" =~ "movie" ]]; then
      agent="TheMovieDB"
      format="movieFormat"
      output="{n} ({y})"
      force_mode="--def ut_label=movie "
    elif [[ "${folder,,}" =~ "anime" ]] || [[ "${folder,,}" =~ "animation" ]] || [[ "${folder,,}" =~ "manga" ]]; then
      agent="AniDB"
      format="seriesFormat"
      output="{n}/{'$filebot_season_folder '+s.pad(2)}/{n} - {sxe} - {t}"
      force_mode="--def ut_label=anime "
    else
      agent="TheTVDB"
      format="seriesFormat"
      output="{n}/{'$filebot_season_folder '+s.pad(2)}/{n} - {sxe} - {t}"
      force_mode="--def ut_label=tv "
    fi
    if [[ "$mui_sorting_agent" == "" ]]; then                                               ## MUI
      mui_sorting_agent="Agent used: $agent"                                                ##
    fi                                                                                      ##
    source $my_language_file
    $echo1 -e "$ui_tag_ok $mui_sorting_agent" 2>/dev/null
    allow_agent=${!agent}
    if [[ "$allow_agent" != "1" ]]; then
      folder_files=`find "$source_folder_path" -type f -iregex '.*\.\(mkv$\|avi$\|mp4$\|m4v$\|mpg$\|divx$\|ts$\|ogm$\)'` > $log_folder/$folder.medias.log
##      echo "DEBUG: source_folder_path: "$source_folder_path
##      echo "DEBUG: folder_files: "$folder_files
##      find "$source_folder_path" -type f -iregex '.*\.\(mkv$\|avi$\|mp4$\|m4v$\|mpg$\|divx$\|ts$\|ogm$\)'
      ## PEUT ETRE CHERCHER AUTRES EXTENSIONS
##      check_medias=`cat $log_folder/$folder.medias.log`
      if [[ "$folder_files" != "" ]]; then
        folder_date=`date +%Y-%m-%d`
        mkdir -p "$log_folder/logs/$folder_date"
        timestamp=`date +%H-%M-%S`
        filebot -script fn:amc -non-strict --conflict override --lang $filebot_language --encoding UTF-8 $force_mode--action move "$source_folder_path" --def "$format=$output" --output "$target_folder_path" 2>/dev/null > $log_folder/logs/$folder_date/$timestamp-$folder.txt & display_loading $!
        cat "$log_folder/logs/$folder_date/$timestamp-$folder.txt" | grep "\[MOVE\]" > $log_folder/move_done.txt
        filebot_moves=()
        while IFS= read -r -d $'\n'; do
        filebot_moves+=("$REPLY")
        done <$log_folder/move_done.txt
        rm $log_folder/move_done.txt
        if [[ "${filebot_moves[@]}" != "" ]]; then
          for move_done in "${filebot_moves[@]}"; do
            move_source=`echo "$move_done" |  grep -oP '(?<=from \[).*(?=\] to)'`
            move_target=`echo "$move_done" |  grep -oP '(?<=to \[).*(?=\]$)'`
            if [[ "$mui_sorting_file_found" == "" ]]; then                                  ## MUI
              mui_sorting_file_found="File processed:"                                      ##
            fi                                                                              ##
            echo -e "$ui_tag_ok $mui_sorting_file_found"
            if [[ "$mui_sorting_source" == "" ]]; then                                      ## MUI
              mui_sorting_source="Source: $move_source"                                     ##
            fi                                                                              ##
            source $my_language_file
            echo -e "$ui_tag_processed $mui_sorting_source"
            if [[ "$mui_sorting_target" == "" ]]; then                                      ## MUI
              mui_sorting_target="Target: $move_target"                                     ##
            fi                                                                              ##
            source $my_language_file
            echo -e "$ui_tag_processed $mui_sorting_target"
            new_media="1"
            if [[ "$push_for_move" == "yes" ]]; then
              file_source=`basename "$move_source"`
              file_target=`basename "$move_target"`
              target_folder=`dirname "$move_target"`
              if [[ "$mui_push_message_move" == "" ]]; then                                 ## MUI
                mui_push_message_move="[ <b>MEDIA MOVED</b> ] [ <b>$target_conf</b> ]\n\n<b>Source Name: </b>$file_source\n<b>Target Name: </b>$file_target\n\n<b>Destination: </b>$target_folder" ##
              fi                                                                            ##
              source $my_language_file
              my_message=` echo -e "$mui_push_message_move"`
              push-message "Plex Sort" "$my_message"
            fi
          done
        fi
      fi
    else
      if [[ "$mui_sorting_offline" == "" ]]; then                                           ## MUI
        mui_sorting_offline="$agent is offline, skipping"                                   ##
      fi                                                                                    ##
      source $my_language_file
      echo -e "$ui_tag_bad $mui_sorting_offline"
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
  if [[ "$mui_dupe_title" == "" ]]; then                                                    ## MUI
    mui_dupe_title="Dupe checker/cleaner"                                                   ##
  fi                                                                                        ##
  printf "$ui_tag_section" $(lon2 "$mui_dupe_title") "$mui_dupe_title"
  if [[ "$mui_dupe_generating" == "" ]]; then                                               ## MUI
    mui_dupe_generating="Generating Plex content DBs"                                       ##
  fi                                                                                        ##
  echo -e "$ui_tag_ok $mui_dupe_generating"
  for folder_db in $plex_folders ; do
    ## RETIRER LES DOSSIERS VIDES - ATTENTION SOUCIS
    ##find "$folder_db" –type d -empty
    disk_db=`echo $folder_db | sed 's/\/Plex\///'`
    disk_db_id="$(basename $disk_db)"
    if [[ "$mui_dupe_db" == "" ]]; then                                                     ## MUI
    mui_dupe_db="Folder: $folder_db (DB: $disk_db_id.locate.db)"                            ##
  fi                                                                                        ##
    source $my_language_file
    $echo1 -e "$ui_tag_ok $mui_dupe_db" 2>/dev/null
    echo $sudo | sudo -kS updatedb -U "$folder_db" -o "$log_folder/$disk_db_id.locate.db" 2>/dev/null & display_loading $!
  done
  locate_dbs=`ls $log_folder/*.locate.db`
  locate_path=`echo $locate_dbs | sed 's/ /:/g'`
  echo $sudo | sudo -kS locate -d $locate_path: . 2>/dev/null > $log_folder/full_plex.txt                                                 ## dump the whole dbs in a single file
  if [[ "$dupe_extensions_filter" == "" ]]; then
    dupe_extensions_filter=".mkv$|.avi$|.mp4$|.m4v$|.ogm$|.divx$|.ts$|.mp3$|.mpg$"
  fi
  cat $log_folder/full_plex.txt | egrep -i "$dupe_extensions_filter" > $log_folder/full_plex_clean.txt      ## remove everything except medias
  my_files=()
  while IFS= read -r -d $'\n'; do
  my_files+=("$REPLY")
  done <$log_folder/full_plex_clean.txt
  touch $log_folder/files_only.txt
  time1=`date +%s`
  if [[ "$mui_dupe_extracting" == "" ]]; then                                               ## MUI
    mui_dupe_extracting="Extracting filenames..."                                           ##
  fi                                                                                        ##
  echo -e "$ui_tag_ok $mui_dupe_extracting"
  for i in "${my_files[@]}"; do
    basename "$i" >> $log_folder/files_only.txt ## remove paths
  done & display_loading $!
  rm $log_folder/full_plex_clean.txt
  rm $log_folder/full_plex.txt
  cat $log_folder/files_only.txt | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' > $log_folder/files_done.txt                           ## remove extensions and everything lower case
  rm $log_folder/files_only.txt
  time2=`date +%s`
  duration=$(($time2-$time1))
  if [[ "$mui_dupe_extracting_done" == "" ]]; then                                          ## MUI
    mui_dupe_extracting_done="Extraction completed (in "$duration"s)"                       ##
  fi                                                                                        ##
  source $my_language_file
  echo -e "$ui_tag_ok $mui_dupe_extracting_done"
  cat $log_folder/files_done.txt | sort | uniq -cd > $log_folder/dupes.txt                                                                       ## search for dupes
  rm $log_folder/files_done.txt
  my_dupes=()
  while IFS= read -r -d $'\n'; do
  my_dupes+=("$REPLY")
  done <$log_folder/dupes.txt
  rm $log_folder/dupes.txt
  if [[ "${my_dupes[@]}" != "" ]]; then
    if [[ "$mui_dupe_file_found" == "" ]]; then                                             ## MUI
      mui_dupe_file_found="Dupes Found... processing"                                       ##
    fi                                                                                      ##
    echo -e "$ui_tag_warning $mui_dupe_file_found"
    echo -e "$ui_tag_warning ......"
    for j in "${my_dupes[@]}"; do
      my_dupe_file=`echo $j | awk '{for (i=2; i<=NF; i++) printf $i FS}'`
      echo $sudo | sudo -kS locate -i -d $locate_path: $my_dupe_file 2>/dev/null > $log_folder/current_dupe.txt                           ## locate dupes

      double_check=`cat "$log_folder/current_dupe.txt" | wc -l`
      if [[ "$double_check" -ge "2" ]]; then
        this_dupe=()
        while IFS= read -r -d $'\n'; do
        this_dupe+=("$REPLY")
        done <$log_folder/current_dupe.txt
        rm $log_folder/current_dupe.txt
        for k in "${this_dupe[@]}"; do                                                                                                      ## collect infos on each dupe
          date_file=`date -r "$k" "+%Y-%m-%d"`
          echo "$date_file ¤$k¤" >> $log_folder/current_process.txt
          if [[ "$mui_dupe_file" == "" ]]; then                                               ## MUI
            mui_dupe_file="Dupe Found: $k Date: $date_file"                                   ##
          fi                                                                                  ##
          source $my_language_file
          echo -e "$ui_tag_warning $mui_dupe_file"
        done
        file_remove=`sort $log_folder/current_process.txt | head -n1 | grep -oP '(?<=¤).*(?=¤)'`
        if [[ "$file_remove" != "" ]]; then
          folder_date=`date +%Y-%m-%d`
          mkdir -p "$log_folder/logs/$folder_date"
          timestamp=`date +%H-%M-%S`
          echo "File sent to the trash:  $file_remove" > $log_folder/logs/$folder_date/$timestamp-dupe.txt 
          if [[ "$mui_dupe_trash" == "" ]]; then                                              ## MUI
            mui_dupe_trash="File sent to trash: $file_remove"                                 ##
          fi                                                                                  ##
          source $my_language_file
          echo -e "$ui_tag_ok $mui_dupe_trash"
          if [[ "$push_for_cleaning" == "yes" ]]; then
            trash_file_date=`date -r "$file_remove" "+%d/%m/%Y"`
            trash_file_format=`mediainfo --Inform="Video;%Format%" "$file_remove"`
            trash_file_resolution=`mediainfo --Inform="Video;%Width% x %Height%" "$file_remove"`
            trash_file_duration=`mediainfo --Inform="Video;%Duration/String3%" "$file_remove"`
            if [[ "$mui_push_message_dupe" == "" ]]; then                                     ## MUI
              mui_push_message_dupe="[ <b>DUPE SENT TO TRASH</b> ]\n\n<b>File:</b> $file_remove\n<b>Received: </b>$trash_file_date\n<b>Codec: </b>$trash_file_format\n<b>Resolution: </b>$trash_file_resolution\n<b>Duration: </b>$trash_file_duration" ##
            fi                                                                                ##
            source $my_language_file
            my_message=` echo -e "$mui_push_message_dupe"`
            push-message "Plex Sort" "$my_message"
          fi
          trash-put "$file_remove"
          new_media="1"
        fi
        rm $log_folder/current_process.txt
        echo -e "$ui_tag_warning......"
      else
## No dupes even if script found some
        echo -e "$ui_tag_bad Critical error 02"
        push-message "Plex Sort" "Critical error"
      fi
    done 
  else
    if [[ "$mui_dupe_nothing" == "" ]]; then                                                ## MUI
      mui_dupe_nothing="No dupes found"                                                     ##
    fi                                                                                      ##
    echo -e "$ui_tag_ok $mui_dupe_nothing"
  fi
  echo ""
fi


#######################
## Clean Download folders
if [[ "$mui_cleaning_title" == "" ]]; then                                                  ## MUI
  mui_cleaning_title="Clean download folders"                                               ##
fi                                                                                          ##
printf "$ui_tag_section" $(lon2 "$mui_cleaning_title") "$mui_cleaning_title"
filebot_folders=`ls "$download_folder" | grep -i "filebot"`
for folder in $filebot_folders ; do
  folder_path=`echo $download_folder"/"$folder`
  find "$folder_path" -type f -not -iregex '.*\.\(mkv$\|avi$\|mp4$\|m4v$\|mpg$\|divx$\|ts$\|ogm$\)' -delete & display_loading $!
  find "$folder_path" -not -path "$folder_path" -type d -empty -delete & display_loading $!
  if [[ "$mui_cleaning_folder" == "" ]]; then                                               ## MUI
    mui_cleaning_folder="Cleaning $folder"                                                  ##
  fi                                                                                        ##
  source $my_language_file
  echo -e "$ui_tag_ok $mui_cleaning_folder"
done
echo ""


#######################
## Plex Update library
if ([[ ! -f $log_folder/.no-root ]] && [[ "$sudo" != "" ]]) || [[ "$native_sudo" == "1" ]]; then
  if [[ "$mui_plex_title" == "" ]]; then                                                    ## MUI
    mui_plex_title="Update Plex library"                                                    ##
  fi                                                                                        ##
  printf "$ui_tag_section" $(lon2 "$mui_plex_title") "$mui_plex_title"
  plex_pid=`pidof "Plex Media Server"`
  if [[ "$plex_pid" == "" ]]; then
    if [[ "$mui_plex_service_bad" == "" ]]; then                                            ## MUI
      mui_plex_service_bad="Plex service is not running"                                    ##
    fi                                                                                      ##
    echo -e "$ui_tag_bad $mui_plex_service_bad"
  else
    if [[ "$mui_plex_service_ok" == "" ]]; then                                             ## MUI
      mui_plex_service_ok="Plex service is running (PID: $plex_pid)"                        ##
    fi                                                                                      ##
    source $my_language_file
    $echo1 -e "$ui_tag_ok $mui_plex_service_ok" 2>/dev/null
  fi
  if [[ "$plex_token" == "" ]] || [[ "$plex_port" == "" ]]; then
    plex_pref=`locate Preferences.xml | grep plexmediaserver | head -n1`
    plex_token_new=`echo $sudo | sudo -kS cat "$plex_pref" 2>/dev/null | grep -o 'Token[^ ]*' | cut -d'"' -f 2`
    echo "plex_token=\"$plex_token_new\"" >> $my_config
    if [[ "$mui_plex_token" == "" ]]; then                                                  ## MUI
      mui_plex_token="Plex Token: $plex_token_new"                                          ##
    fi                                                                                      ##
    source $my_language_file
    echo -e "$ui_tag_ok $mui_plex_token"
    plex_port_new=`echo $sudo | sudo -kS cat "$plex_pref" 2>/dev/null | grep -o 'PortMappingPort[^ ]*' | cut -d'"' -f 2`
    if [[ "$plex_port_new" == "" ]]; then
      plex_port_default=`curl -s http://127.0.0.1:32400/web/index.html | grep "<title>Plex</title>"`
      if [[ "$plex_port_default" != "" ]]; then
        plex_port_new="32400"
      else
        tput civis
        for i in {1000..65535} ; do
        check_plex_on_port=`curl -s -m 2 "http://127.0.0.1:$i/web/index.html" | grep "<title>Plex</title>"`
        if [[ "$mui_plex_scanning" == "" ]]; then                                           ## MUI
          mui_plex_scanning="Scanning ports to find Plex: $i"                               ##
        fi                                                                                  ##
        source $my_language_file
        printf "\r$ui_tag_warning $mui_plex_scanning"
        if [[ "$check_plex_on_port" != "" ]]; then
          printf "$mon_printf" && printf "\r"
          if [[ "$mui_plex_port_found" == "" ]]; then                                       ## MUI
            mui_plex_port_found="Plex port found: $i"                                       ##
          fi                                                                                ##
          source $my_language_file
          echo -e "$ui_tag_ok $mui_plex_port_found"
          plex_port_new=$i
          tput cnorm
          break
        fi
        done
      fi
    fi
    echo "plex_port=\"$plex_port_new\"" >> $my_config
    if [[ "$mui_plex_port" == "" ]]; then                                                   ## MUI
      mui_plex_port="Plex Port: $plex_port_new"                                             ##
    fi                                                                                      ##
    source $my_language_file
    echo -e "$ui_tag_ok $mui_plex_port"
  fi
  if [[ "$new_media" == "1" ]]; then
    if [[ "$mui_plex_update" == "" ]]; then                                                 ## MUI
      mui_plex_update="Update Plex library"                                                 ##
    fi                                                                                      ##
    echo -e "$ui_tag_warning $mui_plex_update"
    url_refresh=`echo "http://127.0.0.1:"$plex_port"/library/sections/all/refresh?X-Plex-Token="$plex_token`
    curl -s "$url_refresh"
    rm refresh* 2>/dev/null
  else
    if [[ "$mui_plex_no_update" == "" ]]; then                                              ## MUI
      mui_plex_no_update="No need to update"                                                ##
    fi                                                                                      ##
    echo -e "$ui_tag_ok $mui_plex_no_update"
  fi
fi


##echo ""
##executed_date=$(date)
##printf "\e[46m\u23E5\u23E5   \e[0m \e[46m  %*s  \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" $(lon2 "$executed_date") "$executed_date"