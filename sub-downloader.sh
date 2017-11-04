#!/bin/bash
set -e
echo `dirname $0`
declare LOG_FILE=`dirname $0`/sub-downloader.log
declare WANTED_FILE=`dirname $0`/wanted/subs.wanted

# Sonarr does not show the stdout as part of the log information displayed by the system,
# So I decided to store the log information by my own.
function doLog {
  echo -e $1
  echo -e $1 >> $LOG_FILE
}

function printUsage {
  msg="Usage: sub-downloader.sh [options]\n\n
    -l, --languages <languages-list>:\n
    \t Specify a comma-separated list of languages to download.\n
    \t example: sub-downloader.sh -l es,en\n\n
    -h, --help: print this help"
  doLog "$msg"
  exit 1
}

if [[ $# -eq 0 ]]; then
  printUsage
fi

while [ "$1" != "" ]; do
  case $1 in
    "-l" | "--languages")
      shift
      declare LANGUAGES=$(echo "-l $1" | sed "s/,/ -l /g")
      ;;
    *)
      printUsage
      ;;
  esac
  shift
done

doLog "###### Process started at: $(date) ######"

declare EPISODE_PATH=${sonarr_episodefile_path}

if [[ -z $EPISODE_PATH ]]; then
  doLog "sonarr_episodefile_path environment variable not found"
  exit 1
fi

doLog "Looking for subtitles for: ${EPISODE_PATH}"

doLog "Executing subliminal"
doLog "subliminal download ${LANGUAGES} ${EPISODE_PATH}"
subliminal download ${LANGUAGES} "${EPISODE_PATH}" >> $LOG_FILE 2>&1

declare LANG_ARRAY=($(echo ${LANGUAGES} | sed "s/-l //g"))

declare SUB_FILES=""
declare SUB_FILE_ARRAY=()
declare FILE=$(echo "${EPISODE_PATH%.*}")
declare OUTPUT_FILE=$(echo "${FILE}[merged].mkv")

for LANG in "${LANG_ARRAY[@]}"; do
  SUB_FILE=$(echo $EPISODE_PATH | sed "s/...$/${LANG}\.srt/g")
  if [[ ! -f $SUB_FILE ]]; then
    doLog "Subtitle ${SUB_FILE} not found, adding it to wanted"
    echo $EPISODE_PATH:$SUB_FILE >> ${WANTED_FILE}
  else 
    SUB_FILES+="${SUB_FILE} "
    SUB_FILE_ARRAY+=(${SUB_FILE})
  fi
done

if [ ${SUB_FILES} != "" ]; then
  doLog "Executing mkvmerge"
  doLog "mkvmerge -o ${OUTPUT_FILE} ${EPISODE_PATH} ${SUB_FILES}"
  mkvmerge -o ${OUTPUT_FILE} ${EPISODE_PATH} ${SUB_FILES}

  THRASH_PATH=$(echo "/home/mra/.local/share/Trash/files")
  mv -f ${EPISODE_PATH} ${THRASH_PATH}
  for SUB_FILE in "${SUB_FILE_ARRAY[@]}"; do
    mv -f ${SUB_FILE} ${THRASH_PATH}
  done
fi