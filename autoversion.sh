

#!/bin/bash

#capture script name
scriptname=${0##*/}


underscore='_'
dot='.'
hyphen="-"

getGitVersion () {

  #define default values
  unset fullversion
  unset major
  unset minor
  unset revision
  unset build
  unset hash
  unset variant

  #
  #get the working set fullversion and status
  fullversion=$(git describe --dirty --long)
  [[ $? -ne 0 ]] && debug git describe failed && abort

  debug fullversion: [$fullversion]

  if [[ $fullversion == *"$underscore"* ]]; then
    variant="${fullversion%%_*}"
    variant=$variant$underscore
  fi

  #get the content after underscore, if it exists
  rest=${fullversion#*$underscore}
  rest=$(( ${#fullversion} - ${#rest} - ${#underscore} + 1))
  fullversion="${fullversion:$rest}"
  major="${fullversion%%.*}"
  [[ -z "$major" ]] && debug major does not exist && abort

  rest=${fullversion#*$dot}
  rest=$(( ${#fullversion} - ${#rest} - ${#dot} + 1))
  fullversion="${fullversion:$rest}"
  minor="${fullversion%%.*}"
  [[ -z "$minor" ]] && debug minor does not exist && abort

  rest=${fullversion#*$dot}
  rest=$(( ${#fullversion} - ${#rest} - ${#dot} + 1))
  fullversion="${fullversion:$rest}"
  revision="${fullversion%%-*}"
  [[ -z "$revision" ]] && debug revision does not exist && abort

  rest=${fullversion#*$hyphen}
  rest=$(( ${#fullversion} - ${#rest} - ${#hyphen} + 1))
  fullversion="${fullversion:$rest}"
  build="${fullversion%%-*}"
  [[ -z "$build" ]] && debug build does not exist && abort

  rest=${fullversion#*$hyphen}
  rest=$(( ${#fullversion} - ${#rest} - ${#hyphen} + 1))
  fullversion="${fullversion:$rest}"

  if [[ $fullversion == *"dirty"* ]]; then
  hash="${fullversion%%-*}"
  hash="d${hash:1}"
  else
  hash="$fullversion"
  fi
  [[ -z "$hash" ]] && debug hash does not exist && abort

  initialCommitHash="d81b64cc23bb44612e322f829ce701a9dd752a07"

  gitVersionCode=$(git rev-list --count $initialCommitHash..HEAD)
  debug variant: [$variant]
  debug major: [$major]
  debug minor: [$minor]
  debug revision: [$revision]
  debug build: [$build]
  debug hash: [$hash] - The first character is not part of the commit hash but to indicate whether the build is dirty or not
  debug gitVersionCode: [$gitVersionCode]
}

#
#define debug message
debug () { echo $scriptname': '$*; }

#
#define usage message to dispaly on exit
usage () { echo 'usage: '$scriptname' (this script takes no arguments)'; }

#
#define exit with error
abort () { debug abort && exit 1; }

#confirm requried tools are available in the ennviornment
cmd=grep
which $cmd > /dev/null
[[ $? -ne 0 ]] && debug this script requires $cmd to funciton && abort

cmd=sed
which $cmd > /dev/null
[[ $? -ne 0 ]] && debug this script requires $cmd to funciton && abort
#alias sed command for in-place and macos if required; expand aliases
#https://stackoverflow.com/questions/51694801/bash-scripting-error-on-microsoft-appcenter-for-pre-build-script
shopt -s expand_aliases
[[ "$OSTYPE" == "darwin"* ]] && alias sed="sed -i ''"  #macos
[[ "$OSTYPE" != "darwin"* ]] && alias sed="sed -i"     #!macos
alias sed

#
#funciton to find tag specified in $1 and replace value with $2
updateiOSFile () {
  #define file leaf
  leaf=$(basename $file)

  #confirm tag is in $file
  grep $1 $file > /dev/null
  [[ $? -ne 0 ]] && debug ERROR unable to find $1 in $leaf && abort

  #update $tag in $file
  sed "/$1/{N;s/\(<string>\).*\(<\/string>\)/\1$2\2/;}" $file
  [[ $? -ne 0 ]] && debug ERROR unable to write $1 to $leaf .. failed && abort

  #check $val is written to file
  grep $2 $file > /dev/null
  [[ $? -ne 0 ]] && debug ERROR $2 not written to $leaf && abort

  debug $1 $2 written to $leaf
}

#
#funciton to find tag specified in $1 and replace value with $2
updateAndroidFile () {
  #define regex, replacement and file leaf
 
  find="$1=\"[0-9a-zA-Z._\-]*\"" && replace="$1=\"$2\""
  leaf=$(basename $file)

  #confirm tag is in $file
  grep $find $file > /dev/null
  [[ $? -ne 0 ]] && debug ERROR unable to find $1 in $leaf && abort

  #update $1 in $file
  sed "s/$find/$replace/" $file
  [[ $? -ne 0 ]] && debug ERROR unable to write $1 to $leaf .. failed && abort
  
  #check $val is written to file
  debug looking for $1 in $file
  grep $replace $file > /dev/null
  [[ $? -ne 0 ]] && debug ERROR $replace not written to $leaf && abort

  debug $replace written to $leaf
}

updateAndroid ()
{
  #versionCode
  androidVersionCode=$gitVersionCode

  #
  #android manifest file
  fileConfigAndroid=/Droid/Properties/AndroidManifest.xml
  fileConfigAndroid=$projectroot$fileConfigAndroid

  #confirm android manifest exists
  file=$fileConfigAndroid
  [[ ! -f $fileConfigAndroid ]] && debug $file not found && abort

  #update $file
  updateAndroidFile versionName $variant$major.$minor.$revision-$build-$hash
  updateAndroidFile versionCode $androidVersionCode
}

updateIos()
{
  iosCfBundleVersion=$gitVersionCode
  #
  #iOS plist file
  fileConfigiOS=/IOS/Info.plist
  fileConfigiOS=$projectroot$fileConfigiOS

  #
  #confirm iOS plist file exists
  file=$fileConfigiOS
  [[ ! -f $fileConfigAndroid ]] && debug $file not found && abort

  #update $file
  updateiOSFile CFBundleShortVersionString $major.$minor.$revision
  updateiOSFile CFBundleVersion $iosCfBundleVersion
  updateiOSFile AppFullVersion $variant$major.$minor.$revision-$build-$hash
}






debug starting in $OSTYPE.. apply version number to build

#
#parse cmd line arguments
while getopts "" OPTION; do
    case $OPTION in
    *)
        usage && abort
        ;;
    esac
done

#
#define the root folder for the project
projectroot=$(git rev-parse --show-toplevel)

getGitVersion

updateAndroid

updateIos

#
#script completed - report success
debug success && exit 0
