#!/bin/bash
set -e

OPTIONS=`getopt -o '' -l per-hour,hours:,days:,404,not-404,all,ip::,extra: -- "$@"`
eval set -- "$OPTIONS"

date1=$(php -r "print gmdate('^Y-m-d\TH', strtotime('now'));")
date2=$(php -r "print gmdate('^Y-m-d\TH', strtotime('-1 hours'));")
date3=$(php -r "print gmdate('^Y-m-d\TH', strtotime('-2 hours'));")
grep_date='| grep -a -E "'"$date1|$date2|$date3"'"'
grep_extra=""
perl_start='| perl -pe "s/'
perl_date='(^\d*[^:]*:[^:]*).*?'
perl_other=' (.*?) (.*?) (.*?) (.*?) (.*?) (.*?) (.*?) (.*)/'
perl_show='\$1'
perl_end='/"'
pipe_extra=
time=now
# extract options and their arguments into variables.
while true ; do
  case "$1" in
    --per-hour)
      date=$(php -r "print gmdate('^Y-m-d', strtotime('$time'));")
      grep_date='| grep -a -e "'"$date"'"'
      perl_date='(^\d*[^:]*).*?'
      per_hour=1
      shift;;
    --hours)
      case "$2" in
        "") time=now ; shift 2 ;;
        *)
          date1=$(php -r "print gmdate('^Y-m-d\TH', strtotime('-$2 hours'));")
          date2=$(php -r "print gmdate('^Y-m-d\TH', strtotime('-$(($2 + 1)) hours'));")
          date3=$(php -r "print gmdate('^Y-m-d\TH', strtotime('-$(($2 + 2)) hours'));")
          grep_date='| grep -a -E "'"$date1|$date2|$date3"'"'
          shift 2 ;;
      esac ;;
    --days)
      if [ -z $per_hour -a -z $allday ]; then
        echo "--days only can be used after --per-hour" ; exit 1
      fi
      case "$2" in
        "") shift 2 ;;
        *)
          time="-$2 days"
          date=$(php -r "print gmdate('^Y-m-d', strtotime('$time'));")
          grep_date='| grep -a -e "'"$date"'"'
          shift 2 ;;
      esac ;;
    --ip)
      perl_show='\$1 - \$2'
      case "$2" in
        "") shift 2 ;;
        *)
          grep_after="| grep -a '$2'"
          shift 2 ;;
      esac ;;
    --all)
      grep_date='' ; shift ;;
    --404)
        grep_extra='| grep -a " 404 "' ; shift ;;
    --not-404)
        grep_extra='| grep -v -a " 404 "' ; shift ;;
    --extra)
          grep_extra="$grep_extra | $2"
          shift 2 ;;
    --) shift ; break ;;
    *) echo "Internal error!" ; exit 1 ;;
  esac
done

cmd='cat /var/log/php.access.log '"$grep_date"' '"$grep_extra"' '"$pipe_extra"' '"$grep_before"' '"$perl_start$perl_date$perl_other$perl_show$perl_end"' '"$grep_after"' | sort | uniq -c'
awk='awk '"'"'{sum += $1; print} END {print "\033[1;35m\n>>", sum, "total <<\n\033[0m" > "/dev/stderr"}'"'"
>&2 printf "\033[0;36mRunning [ %s | %s ]...\033[0m\n" "$cmd" "$awk"
if [ -z "$PLATFORM_APPLICATION_NAME" ]; then
  platform ssh -e ${PLATFORMSH_RECIPES_MAIN_BRANCH-master} "$cmd" | eval $awk
else
  eval $cmd | eval $awk
fi
