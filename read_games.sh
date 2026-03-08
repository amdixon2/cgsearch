#!/bin/bash
set -euo pipefail

input="./results.html"
output="./games.txt"

# truncate file..
: > "$output"

game_index=0
line="";
pager="";
num=-1;
start=-1;
endd=-1;
delimiter=":";

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
done < <(grep -Eon "page [0-9]+ of [0-9]+; games [0-9]+-[0-9]+ of [0-9]+" "$input")

if [ "${pager}" == "" ]; then
  printf "game table not found..\n";
  exit 1;
fi;

sed -n "${start},${endd}p" "${input}" \
  | sed -E 's/<a target="game_[0-9]*" href="\/perl\/chessgame\?gid=([0-9]+)">/gid=\1 /g' \
  | sed -e 's/<[^>]*>/ /g' -e 's/  */ /g' \
  | grep -E "^ [0-9]" \
  | sed "s/$/@/g" \
  | tr -d "\n" \
  | sed -E "s/ @ ([0-9]+\.)/\n \1/g" \
  | sed -e "s/ @ / /g" -e "s/@$/\n/g" 1>./templist.txt;

j=0;
word="";
error="";
while IFS= read -r line; do
  line="${line:1}";
  error="";
  num="";
  gid="";
  title="";
  result="";
  moves="";
  year="";
  eco="";
  opening="";
  event="";
  tail="";
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
done < ./templist.txt;

printf 'Wrote %s games to %s\n' "$game_index" "$output"

rm ./templist.txt;

