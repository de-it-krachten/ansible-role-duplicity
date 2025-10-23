#!/bin/bash
#
#=====================================================================
#
# Name        :
# Version     :
# Author      :
# Description :
#
#
#=====================================================================


##############################################################
#
# Defining standard variables
#
##############################################################

# Set temporary PATH
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

# Get the name of the calling script
FILENAME=$(readlink -f $0)
BASENAME="${FILENAME##*/}"
BASENAME_ROOT=${BASENAME%%.*}
DIRNAME="${FILENAME%/*}"

# Define temorary files, debug direcotory, config and lock file
TMPDIR=$(mktemp -d)
VARTMPDIR=/var/tmp
TMPFILE=${TMPDIR}/${BASENAME}.${RANDOM}.${RANDOM}
DEBUGDIR=${TMPDIR}/${BASENAME_ROOT}_${USER}
CONFIGFILE=${DIRNAME}/${BASENAME_ROOT}.cfg
LOCKFILE=${VARTMP}/${BASENAME_ROOT}.lck

# Logfile & directory
LOGDIR=$DIRNAME
LOGFILE=${LOGDIR}/${BASENAME_ROOT}.log

# Set date/time related variables
DATESTAMP=$(date "+%Y%m%d")
TIMESTAMP=$(date "+%Y%m%d.%H%M%S")

# Figure out the platform
OS=$(uname -s)

# Get the hostname
HOSTNAME=$(hostname -s 2>/dev/null)
HOSTNAME=${HOSTNAME:-`hostname`}



##############################################################
#
# Defining custom variables
#
##############################################################

# Make sure the SSH agent forwarding does not interfere
#unset SSH_AUTH_SOCK SHELL_RUNNING
unset SHELL_RUNNING


##############################################################
#
# Defining standarized functions
#
#############################################################

FUNCTIONS=$DIRNAME/functions.sh
if [[ -f $FUNCTIONS ]]
then
   . $FUNCTIONS
else
   echo "Functions file '$FUNCTIONS' could not be found!" >&2
   exit 1
fi


##############################################################
#
# Defining customized functions
#
#############################################################

function Usage
{

  cat << EOF | grep -v "^#" | sed "s/@#@/#/"

$BASENAME

Usage : $BASENAME <flags>

Flags :

   -d        : Debug mode (set -x)
   -D        : Dry run mode
   -h        : Prints this help message
   -v        : Verbose output

   -b <dir>  : Backup directory
   -s <dir>  : Source directory
   -m <mode> : duplicity action to perform (backup/restore/verify/list/status)

   -a        : Duplicity arguments to pass
   -c <name> : Credential to use
   -e <dir>  : Exclude path
   -E <file> : Exclude file with paths
   -F        : Performs full backup (default = incremental)
   -I <file> : Include file with paths
   -k        : Use public-key instead of symmetric encryption
   -N        : Do not use encryption
   -p        : Use PAR2 (default)
   -P        : Do NOT use PAR2
   -r        : Performs a relative backup (default)
   -R        : Performs an absolute backup
   -S        : Send files to NAS
   -t        : Select time of backup to restore
   -x        : Run backup/restore command through 'sudo'
   -y <r>    : par2 redundancy (default=10%)
   -z <arg>  : Period (yearly/monthly etc)

Examples:

@#@ Private data backup
$BASENAME -m backup -s /data/prive -b /data/backup/prive
$BASENAME -m backup -s /data/profile -b /data/backup/profile
$BASENAME -m backup -s /data/pictures -b /data/backup/pictures
$BASENAME -m backup -s /data/archive -b /data/backup/archive

@#@ Business data backup 
$BASENAME -m backup -s /data/mega/info@de-it-krachten.nl/MEGA -b /data/backup/zakelijk

@#@ Restore
$BASENAME -m restore -a "--tempdir /data/tmp --file-to-restore home" -s /data/prive -b /data/backup/prive/latest
$BASENAME -m restore -s /data/prive -b rsync://backup@192.168.1.20//volume1/Backup/prive/latest

# Restore specific 
$BASENAME -c encryption/duplicity-work-backup -m restore -s /tmp/xxx -b /data/backup_tmp/customers/2024-05-01 -a "--path-to-restore ga/git/azure/CloudErfpacht/json" -t

EOF

}

function Cleanup
{

   cd /
   if [[ -n $Debug ]]
   then
      rm -fr ${DEBUGDIR}
      mkdir -p ${DEBUGDIR}
      cp ${TMPFILE}* ${DEBUGDIR} 2>/dev/null
   fi
   rm -f ${TMPFILE}*

}

function Replace_long_args
{

   New_args_list=`echo "$@" | sed "s/--help/-h/
                                   s/--verbose/-v/
                                   s/--debug/-d/
                                   s/--dry-run/-D/"`

}

function Show_times
{

   local Numbering=true
   [[ $1 == -N ]] && Numbering=false && shift

   # Get all full and incremental backups
   ls ${Backup}/duplicity-full* | awk -F\. '{print $2}' > ${TMPFILE}
   ls ${Backup}/duplicity-inc* 2>/dev/null | awk -F\. '{print $4}' >> ${TMPFILE}

   # Create a list of all timestamps in readable format
   Count=0
   for x in `sort -u ${TMPFILE}`
   do
      Count=$(($Count+1))
      y=`echo $x | sed "s/^..../&-/;s/-../&-/;s/T/ /;s/ ../&:/;s/:../&:/;s/Z//"`
      echo "$Count|$x|$y"
   done > ${TMPFILE}time

   # Display a list of all time stamps to choose from
   if [[ $Numbering == true ]]
   then
     awk -F\| '{print $1") "$3 }' ${TMPFILE}time
   else
     awk -F\| '{print $2 }' ${TMPFILE}time
   fi

}

function Select_time
{

   exec 3>/dev/tty

   # Display all possible backup times
   Show_times >&3

   # Let the user select the appropiate timestamp 
   while true ; do
     echo -e "Select the time you want to restore from : \c" >&3 ; read Select
     exec 3<&-
     Backup_time=`awk -F\| '$1=="'$Select'" {print $2}' ${TMPFILE}time`
     [[ -n $Backup_time ]] && break
   done

   Time="--time $Backup_time"
   exec 3<&-

}

function Create_par2
{

  local Backupdir

  Print_full_line -H -c= -n80 "PAR2"

  if [[ $Backup_mode == full ]]
  then
    Par2file="duplicity-full.\$Timestamp.par2"
  else
    Par2file="duplicity-inc.\$Timestamp.par2"
  fi

  #
  cd $Backup

  # Get all full and incremental backups
  ls duplicity-full* | awk -F\. '{print $2}' > ${TMPFILE}
  ls duplicity-inc* 2>/dev/null | awk -F\. '{print $4}' >> ${TMPFILE}

  # Get the latest timestamp
  Timestamp=$(sort -r ${TMPFILE} | head -1)

  # Create par2 recovery files on full archive
  [[ ! -d par2 ]] && mkdir -p par2
  eval Par2file=$Par2file
  par2 create -r${Par_redundancy} $Par2file *${Timestamp}*
echo $?

  # Move PAR2 files to a seperate directory
  mv *.par2 par2

  cd - >/dev/null

}

function Get_passphrase
{
  if [[ -z $PASSPHRASE ]]
  then

    if [[ -z $Credential ]]
    then
      echo "No credential defined!" >&2
      exit 1
    fi

    if [[ $Credential =~ ^/ ]]
    then
      if [[ -f $Credential ]]
      then
        export PASSPHRASE=$(cat $Credential)
      else
        echo "File '$Credential' does not exist" >&2
        exit 1
      fi
    else 
      [[ -n $SUDO_USER ]] && export PASSWORD_STORE_DIR=/home/$SUDO_USER/.password-store
      export PASSPHRASE="`pass ls $Credential`"
    fi
  fi

}

function Period
{

  # Get current year & month
  Year=$(date +%Y)
  Month=$(date +%m)
  Week=$(date +%U)
  Day=$(date +%d)

  case $Period in
    daily)
      Backup="${Backup}/${Year}-${Month}-${Day}"
      ;;
    weekly)
      Backup="${Backup}/${Year}-W${Week}"
      ;;
    monthly)
      Backup="${Backup}/${Year}-${Month}"
      ;;
    quarterly)
      case $Month in
        01|02|03) Backup="${Backup}/${Year}-Q1" ;;
        04|05|06) Backup="${Backup}/${Year}-Q2" ;;
        07|08|09) Backup="${Backup}/${Year}-Q3" ;;
        10|11|12) Backup="${Backup}/${Year}-Q4" ;;
      esac 
      ;;
    yearly)
      Backup="${Backup}/${Year}"
      ;;
    indefinately)
      Backup="${Backup}"
      ;;
    *)
      echo "Unknown period '$Period' provided" >&2
      exit 1
      ;;      
  esac

  # Create the target directory
  sigtar=$(ls ${Backup}/*.sigtar.gpg 2>/dev/null | wc -l)
  if [[ $sigtar -gt 0 ]]
  then
    Backup_mode=incremental
    Date=$(date -u +%Y%m%d)

    # Search for todays backup files
    Today=`ls $Backup/*to.${Date}T*.sigtar.gpg 2>/dev/null`

    if [[ -n $Today && $Multiple == false ]]
    then
      echo "Today's backup already found!"
      exit 0
    fi

  else
    Backup_mode=full
    mkdir -p ${Backup}
    cd `dirname $Backup`
#    ln -fs `basename $Backup` latest
  fi

}


##############################################################
#
# Main programs
#
#############################################################

# Set the correct PATH
#export PATH=/usr/bin:/usr/sbin:$PATH

# Get shell specifics
Check_shell

# Make sure temporary files are cleaned at exit
#trap 'Cleanup' EXIT
trap 'rm -fr ${TMPDIR}' EXIT
trap 'exit 1' HUP QUIT KILL TERM INT

# Set the defaults
Debug_level=0
Verbose=false
Verbose_level=0
Dry_run=false
Echo=
Backup_mode=incremental
Relative=true
Time=
Select_time=false
#Force=false
Force=true
Par2=false
Par_redundancy=10
Rsync=false
Use_pubkey=false
Sudo=false
Use_encryption=true
Period=quarterly
Multiple=false
Umask=027

# parse command line into arguments and check results of parsing
while getopts :a:b:c:dDe:E:FhI:km:MNpPrRs:StT:u:vxy:z: OPT
do
   case $OPT in
     a) Duplicity_args="$OPTARG"
        ;;
     b) Backup="$OPTARG"
        ;;
     c) Credential=$OPTARG
        ;;
     d) Verbose=true
        Verbose_level=2
        Verbose1="-v"
        Debug_level=$(( $Debug_level + 1 ))
        export Debug="set -vx"
        $Debug
        eval Debug${Debug_level}=\"set -vx\"
        Verbosity="--verbosity debug"
        ;;
     D) Dry_run=true
        Dry_run1="--dry-run"
        Echo=echo
        ;;
     e) Exclude="--exclude '$OPTARG'"
        ;;
     E) Exclude=$(cat $OPTARG | tr '\n' ' ' | sed "s/  *$//" | sed -r "s/([*/_.a-zA-Z0-9-]*)/--exclude '&'/g")
        ;;
     F) Backup_mode=full
        ;;
     h) Usage
        exit 0
        ;;
     I) Include=$(cat $OPTARG | tr '\n' ' ' | sed "s/  *$//" | sed -r "s/([*/_.a-zA-Z0-9-]*)/--include '&'/g")
        ;;
     k) Use_pubkey=true
        ;;
     m) Mode=$OPTARG
        ;;
     M) Multiple=true
        ;;
     N) Use_encryption=false
        ;;
     p) Par2=true
        ;;
     P) Par2=false
        ;;
     r) Relative=true
        ;;
     R) Relative=false
        ;;
     s) Source="$OPTARG"
        ;;
     S) Rsync=true
        ;;
     t) Select_time=true
        ;;
     T) Time="--time $OPTARG"
        ;;
     u) Umask=$OPTARG
        ;;
     v) Verbose=true
        Verbose_level=$(($Verbose_level+1))
        Verbose1="-v"
        Verbosity="--verbosity info"
        Progress="--progress"
        ;;
     x) Sudo=true
        ;;
     y) Par_redundancy=$OPTARG
        ;;
     z) Period=$OPTARG
        ;;
     *) echo "Unknown flag -$OPT given!" >&2
        exit 1
        ;;
   esac

   # Set flag to be use by Test_flag
   eval ${OPT}flag=1

done
shift $(($OPTIND -1))

# Set umask
umask $Umask

#Test_flag req c 
Test_flag req m
Test_flag req b
[[ $Mode != status && $Mode != list && $Mode != times ]] && Test_flag req s

# Load the passphrase to use
Get_passphrase

# Based upon encryption used, set the correct flags
Args="$Duplicity_args $Dry_run1 $Verbosity $Progress --gpg-binary /usr/bin/gpg2"
[[ $Mode == backup ]] && Args="$Args --volsize 100"

# Set specific for non-symmetric encryption 
if [[ $Use_encryption == true ]]
then
  if [[ $Use_pubkey == true ]]
  then
    unset PASSPHRASE
    Args="$Args --use-agent --encrypt-key $GPG_ENCRYPT_KEY --sign-key $GPG_SIGN_KEY"
  else
    unset GNUPGHOME
    Sudo_env="PASSPHRASE"
  fi
else
  Args="$Args --no-encryption"
fi

# Use docker if no duplicity installed
if [[ -z `which duplicity` ]]
then
  > ${TMPFILE}env
  chmod 600 ${TMPFILE}env
  echo "PASSPHRASE=$PASSPHRASE" >> ${TMPFILE}env
  Script_dir=$DIRNAME
  duplicity="docker run --env-file ${TMPFILE}env --user $(id -u) --volume $Script_dir:$Script_dir --volume $Backup:$Backup --volume $Source:$Source --rm dropveter/duplicity:latest duplicity"
  [[ $Mode == backup ]] && duplicity="$duplicity --allow-source-mismatch"
else
  duplicity=duplicity
fi

case $Mode in
  backup)
    # Find out which backup directory to use
    Period

    if [[ $Relative == true ]]
    then
      [[ $Backup == /* ]] && Backup1="file://${Backup}" || Backup1=$Backup
      Cmd="$duplicity $Args $Include $Exclude $Backup_mode '$Source' '$Backup1'"
    else
      [[ $Backup == /* ]] && Backup1="file://${Backup}" || Backup1=$Backup
      Cmd="$duplicity $Args $Include $Exclude $Backup_mode --include '$Source' --exclude '/**' / '$Backup1'"
    fi
    [[ $Use_encryption == true ]] && Create_par2=${Par2}
    ;;
  restore)
    [[ $Select_time == true ]] && Select_time
    if [[ $Force == false ]]
    then
      echo "You are about to restore data from '$Backup' to '$Source'"
      Check_answer Continue "Are you sure you want to continue?"
      [[ $Continue != true ]] && exit 1
    fi
    [[ $Backup == /* ]] && Backup="file://${Backup}"
    Cmd="$duplicity $Args $Time restore $File_to_restore '$Backup' '$Source'"
    ;;
  verify)
    [[ $Select_time == true ]] && Select_time
    [[ $Backup == /* ]] && Backup="file://${Backup}"
    Cmd="$duplicity $Args $Time verify '$Backup' '$Source'"
    ;;
  list)
    [[ $Select_time == true ]] && Select_time
    [[ $Backup == /* ]] && Backup="file://${Backup}"
    Cmd="$duplicity $Args $Time list-current-files '$Backup'"
    ;;
  status)
    [[ $Backup == /* ]] && Backup="file://${Backup}"
    Cmd="$duplicity $Args collection-status '$Backup'"
    ;;
  times)
    Show_times -N
    exit 0
    ;;
  *)
    Usage >&2
    exit 1
    ;;
esac

# Create warning when non-root
if [[ $Mode == restore && `id -un` != root && $Sudo == false ]]
then
  echo "###############################################################" >&2
  echo "Be aware that restoring as non-root can bring issues!!!" >&2
  echo "################################################################" >&2
fi


# Add environment varialbe to pass through sudo
[[ $Sudo == true ]] && Cmd="sudo --preserve-env=$Sudo_env $Cmd"

# Execute duplicity
Print_full_line -H -c= -n80 "Duplicity"
[[ -n $GNUPGHOME ]] && echo "GNUPGHOME : $GNUPGHOME"
echo "Command : $Cmd" | sed "s/  */ /g"
Print_full_line -c= -n80
eval $Cmd
Rc=$?

# Ensure file permissions are ars required
if [[ $Mode == backup ]]
then

  [[ $Umask =~ 077 ]] && Chmod=600
  [[ $Umask =~ 027 ]] && Chmod=640
  [[ $Umask =~ 022 ]] && Chmod=644

  # Get group from parent
  User_name=$(id -un)
  Group_name=$(stat --format %G $Backup)

  if [[ $Sudo == true ]]
  then
    find $Backup -type f -exec sudo chmod $Chmod "{}" \;
    find $Backup -type f -exec sudo chown ${User_name}:${Group_name} "{}" \;
  else
    find $Backup -type f -exec chmod $Chmod "{}" \;
    find $Backup -type f -exec chgrp ${Group_name} "{}" \;
  fi
fi

# Create PAR2 
[[ $Rc -eq 0 && $Create_par2 == true ]] && Create_par2

# Rsync to NAS
[[ $Rsync == true && $Mode == backup ]] && rsync -av -e ssh /data/backup/ backup_local:/volume1/Backup

# Now exit
exit $Rc
