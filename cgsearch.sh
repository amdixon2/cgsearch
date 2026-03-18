#!/bin/bash

set -euo pipefail

if [ $# -ne 2 ]; then
  printf "Usage: ./cgsearch.sh search page_num\n";
  exit 1;
fi;

function check_response
{
  local file="$1";
  local count=0;
  printf "checking response ${file}\n";
  if [ -s "${file}" ]; then
    # file is nonzero size
    :
  else
    # file is empty
    printf "response is empty..\n";
    exit 1;
  fi;
  count=$(grep -En "face=\"verdana,arial\" size=-1>\&nbsp;page [0-9]+ of [0-9]+;" "${file}" | head -n 1 | wc -l);
  case $count in
    0)
      printf "missing pagecount..\n";
      exit 1;
      ;;
    1|2)
      :
      ;;
    *)
      printf "excess pagecount indicators..\n";
      exit 1;
      ;;
  esac
}

function get_pagecounters
{
  local file="$1";
  local line="";
  line=$(grep -En "face=\"verdana,arial\" size=-1>\&nbsp;page [0-9]+ of [0-9]+;" "${file}" \
            | head -n 1 \
            | sed -E 's/^.+page ([0-9]+) of ([0-9]+);.+$/\1,\2/g');
  response_page=$(printf "${line}\n" | cut -d, -f1);
  response_last_page=$(printf "${line}\n" | cut -d, -f2);
  :
}

function get_template
{
  local file="$1";
  local match="";
  match=$(grep -E "endf?\.gif" "${file}" | head -n 1 || true);
  if [[ "${match}" == *endf\.gif* ]] || [[ "${match}" == "" ]]; then
    printf "no template..\n";
    template="";
  else
    template=$(printf "${match}\n" | sed -E 's/^.+<a href="([^"]+)"><img src="[^"]+end\.gif".+$/\1/g');
    template="https://www.chessgames.com${template}";
    template=$(printf "${template}\n" | sed -E 's/^(.+)page=[0-9]+(.*)$/\1page=#page#\2/g');
  fi;
}

function write_games
{
  local input="$1";
  local output="$2";
  local game_index=0 line="" pager="";
#  local line="" pager="";
  local start=-1 endd=-1 i=0 j=0;
  local delimiter=":" word="";
  local num="" gid="" title="" result="";
  local moves="" year="" eco="" error="";
  local opening="" event="" tail="";
  local prefix="";

  # truncate file
  : > "$output"

  while IFS= read -r line; do
    num="${line%:*}";
    line="${line#*:}";
    if [ "${pager}" == "" ]; then
      pager="${line}";
    else
      if [ "${pager}" != "${line}" ]; then
        printf "inconsistent pager..\n";
        exit 1;
      fi;
    fi;
    if [ ${start} -eq -1 ]; then
      start=${num};
    else
      if [ ${endd} -ne -1 ]; then
        printf "too many pagers..\n";
        exit 1;
      fi;
      endd=${num};
    fi;
#  done < <(grep -Eon "page [0-9]+ of [0-9]+; games [0-9]+-[0-9]+ of [0-9]+" "$input")
  done < <(grep -En "face=\"verdana,arial\" size=-1>\&nbsp;page [0-9]+ of [0-9]+;" "${input}" \
         | sed 's/^\([0-9]\+\):[^;]\+;\([^;]\+\);.\+$/\1:\2/g');

  if [[ ${start} -ne -1 ]] && [[ ${endd} -eq -1 ]]; then
    line="";
    line=$(grep -on "</table>" "${input}" | tail -n 1 | cut -d: -f1);
    if [[ $line =~ ^[0-9]+$ ]]; then
      endd="${line}";
    fi;
  fi;

  if [[ "${pager}" == "" ]] || [[ ${endd} -eq -1 ]] || [[ ${start} -eq -1 ]]; then
    printf "game table not found..\n";
    printf "pager=${pager}\n";
    printf "start=${start}\n";
    printf "endd=${endd}\n";
    exit 1;
  fi;

  sed -n "${start},${endd}p" "${input}" \
    | sed -E 's/<a target="game_[0-9]*" href="\/perl\/chessgame\?gid=([0-9]+)">/gid=\1 /g' \
    | sed -e 's/<[^>]*>/ /g' -e 's/  */ /g' -e 's/&#189;/1\/2/g' \
    | grep -E "^ [0-9]" \
    | sed "s/$/@/g" \
    | tr -d "\n" \
    | sed -E "s/ @ ([0-9]+\.)/\n \1/g" \
    | sed -e "s/ @ / /g" -e "s/@$/\n/g" 1>./templist.txt;

  while IFS= read -r line; do
    line="${line:1}";
    #  printf "${line}\n";
    j=$((j + 1));
    i=0;
    word="${line%% *}";
    if [[ "${word}" =~ ^([0-9]+)\.\&nbsp\;gid=([0-9]+)$ ]]; then
      num="${BASH_REMATCH[1]}";
      gid="${BASH_REMATCH[2]}";
    else
      error="lineformat";
      continue;
    fi;
    line="${line#* }";
    line="${line//\&nbsp\; + /}";
    line="${line//\&nbsp\;/}";
    line=$(echo ${line});
    #  printf ",${line}\n";
    #      printf "${word}\n";
    if [ "${error}" != "" ]; then
      continue;
    fi;
    #    printf "num=${num}, gid=${gid}..\n";
    if [[ "${line}" =~ ^(.+)\ vs\ (.+)\ (1-0|0-1|1/2-1/2|\*)\ ([^ ]{3,}\ )?([0-9]{1,3})\ ([0-9]{4})\ (.+)$ ]]; then
      result="${BASH_REMATCH[3]}";
      title="${BASH_REMATCH[1]} vs ${BASH_REMATCH[2]}";
      moves="${BASH_REMATCH[5]}";
      year="${BASH_REMATCH[6]}";
      tail="${BASH_REMATCH[7]}";
      glub="${BASH_REMATCH[4]}";
    else
      error="lineformat";
      continue;
    fi;
    #  printf "${tail}\n";
    if [[ "${tail}" =~ ^(.+)\ ([A-E0][0-9][0-9])\ (.+)$ ]]; then
      eco="${BASH_REMATCH[2]}";
      event="${BASH_REMATCH[1]}";
      opening="${BASH_REMATCH[3]}";
    else
      error="ecomissing";
      continue;
    fi;
    #  printf "num=${num}, gid=${gid}, title=${title}, result=${result}, moves=${moves}, year=${year}, glub=${glub}\n, event=${event}, eco=${eco}, opening=${opening}\n";
    game_index=$((game_index + 1))
    prefix="game${num}"
    {
      printf '%s.number=%s\n' "${prefix}" "${num}"
      printf '%s.gid=%s\n' "${prefix}" "${gid}"
      printf '%s.title=%s\n' "${prefix}" "${title}"
      printf '%s.result=%s\n' "${prefix}" "${result}"
      printf '%s.moves=%s\n' "${prefix}" "${moves}"
      printf '%s.year=%s\n' "${prefix}" "${year}"
      printf '%s.event=%s\n' "${prefix}" "${event}"
      printf '%s.eco=%s\n' "${prefix}" "${eco}"
      printf '%s.opening=%s\n' "${prefix}" "${opening}"
    } >> "$output"
#  done;
  done < ./templist.txt;

  printf "Wrote %s games to %s\n" "$game_index" "$output";

  rm ./templist.txt;
}

ogquery="$1";
pnumb="$2";
query=$(printf "%s\n" "${ogquery}" | sed 's/ /+/g');
foldr=$(printf "%s\n" "./${ogquery}" | sed 's/ /-/g');
output="";
context="";
template="";
url="";
output="";
has_folder="false";
has_search="false";
has_output="false";
current_page=0;
last_page=0;
response_page=0;
response_last_page=0;
search_file="";

if ! [[ $pnumb =~ ^[0-9]+$ ]]; then
  printf "page_number not numeric\n";
  exit 1;
fi;

output="${foldr}/page${pnumb}.txt";

if [ -e "${foldr}" ]; then
  has_folder="true";
  if [ -e "${foldr}/search.txt" ]; then
    has_search="true";
  fi;
  if [ -e "${output}" ]; then
    # output already exists..
    has_output="true";
  fi;
fi;

search_file="${foldr}/search.txt";

if [ "${has_search}" == "true" ]; then
  context=$(head -n 1 "${foldr}/search.txt");
  template=$(printf "${context}\n" | cut -d, -f3 | sed 's/^template=//g');
  current_page=$(printf "${context}\n" | cut -d, -f1 | sed 's/^page=//g');
  last_page=$(printf "${context}\n" | cut -d, -f2 | sed 's/^lastpage=//g');
#  printf "template=%s\n" "${template}";
  if [ ${pnumb} -gt ${last_page} ]; then
    printf "page out of bounds..\n";
    exit 1;
  fi;
  url=$(printf "${template}\n" | sed "s/#page#/${pnumb}/g")
#  printf "url=%s\n" "${url}";
  if ! [ "${has_output}" == "true" ]; then
    printf "fetching page from ${url}\n";
    ./fetch_page.py "${url}"
    check_response ./response.html;
    get_pagecounters ./response.html;
    printf "response_page=${response_page}\n";
    printf "response_last_page=${response_last_page}\n";
    if [ "${response_page}" != "${pnumb}" ]; then
      printf "got wrong page?\n";
      exit 1;
    fi;
    if [ "${response_last_page}" != "${last_page}" ]; then
      printf "last page count has changed..\n";
    fi;
    mv ./response.html "${foldr}/page${pnumb}.html";
    write_games "${foldr}/page${pnumb}.html" "${foldr}/page${pnumb}.txt";
    :
  fi;
else
  pnumb=1;
  output="${foldr}/page${pnumb}.txt";
  url="https://www.chessgames.com/perl/ezsearch.pl?search=${query}";
  printf "fetching page from ${url}\n";
  ./fetch_page.py "${url}"
  check_response ./response.html;
  get_pagecounters ./response.html;
  printf "response_page=${response_page}\n";
  printf "response_last_page=${response_last_page}\n";
  if [ "${response_page}" != "${pnumb}" ]; then
    printf "got wrong page?\n";
    exit 1;
  fi;
  last_page="${response_last_page}";
  get_template ./response.html;
  if ! [ -e "${foldr}" ]; then
    mkdir "${foldr}";
  fi;
  mv ./response.html "${foldr}/page${pnumb}.html";
  write_games "${foldr}/page${pnumb}.html" "${foldr}/page${pnumb}.txt";
  :
fi;


# truncate seearch file and write context..
: > "${search_file}";
printf "page=%s,lastpage=%s,template=%s\n" "${pnumb}" "${last_page}" "${template}" 1>>"${search_file}";

