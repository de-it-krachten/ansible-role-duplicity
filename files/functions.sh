#------------------------------------------------------------------
#
# NAME:
#
#        Check_answer - version 1.2 - date 14/dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#        FD : Exit
#
#-----------------------------------------------------------------

function Check_answer
{

   [[ $Debug_level -ge 1 ]] && echo "Starting function Check_answer $* (version 1.2)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define specific local variables and assign values to them
   $Typeset Variable Question Default Answer Single_keystroke AcceptAll
   Single_keystroke=false
   AcceptAll=false
  
   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts aD:s OPT
   do
      case $OPT in
         a) # Accept 'A' as yes for all
            AcceptAll=true
            ;;
         D) case $OPTARG in
               y|Y) Default=y ;;
               n|N) Default=n ;;
                 *) echo "Invalid value given as argument with '-D'" >&2
                    echo "Valid arguments are : y/n" >&2
                    Exit -h 1 ;;
            esac
            ;;
         s) Single_keystroke=true
            ;;
         *) echo "Invalid flag '-$OPT' used with function 'Check_answer'!" >&2
            Exit -h 1
            ;;
      esac
   done
   shift $(($OPTIND -1))
  
   # Define the arguments
   Variable=$1
   Question="$2"
 
   # Check for invalid variable names
   if [[ $Variable = Answer || $Variable = Variable || $Variable = Question ]]
   then
      echo "Answer/Variable/Question are internally used names" >&2
      echo "These values cannot be used for function Check_answer" >&2
      Exit -h 1
   fi
 
   if [[ $AcceptAll = true ]]
   then
      case $Default in
         y) $Print "$Question [Y(es)/n(o)/a(llyes)] \c" ;;
         n) $Print "$Question [y(es)/N(o)/a(llyes)] \c" ;;
         a) $Print "$Question [y(es)/n(o)/A(llyes)] \c" ;;
        '') $Print "$Question [y(es)/n(o)/a(llyes)] \c" ;;
      esac
   else
      case $Default in
         y) $Print "$Question [Y/n] \c" ;;
         n) $Print "$Question [y/N] \c" ;;
        '') $Print "$Question [y/n] \c" ;;
      esac
   fi
 
   if [[ $Single_keystroke = true ]]
   then
      stty raw
      stty -echo
      Answer=`dd bs=1 count=1 2>/dev/null | tr '[A-Z]' '[a-z]'`
      stty echo
      stty -raw
      Answer=`echo $Answer | sed "s///"`
      echo "$Answer"
   else
      read Answer
      Answer=`echo $Answer | tr '[A-Z]' '[a-z]'`
   fi
 
   # Use default is 'enter' was given and default set
   [[ -z $Answer && -n $Default ]] && Answer=$Default
 
   case $Answer in
     y) eval $Variable=true ;;
     n) eval $Variable=false ;;
     a) if [[ $AcceptAll = true ]] 
        then
           eval $Variable=true
           eval ${Variable}_All=true
        else
           Check_answer "$Variable" "$Question"
        fi
        ;;
    ) Exit -h 1 ;;
     *) Check_answer "$Variable" "$Question";;
   esac
 
   # Unset used variables that aren't needed anymore
   unset Variable Question Answer
 
 }
#------------------------------------------------------------------
#
# NAME:
#
#        Check_distro - version 1.0 - date 28/Apr/2017
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#        FD : Exit
#
#-----------------------------------------------------------------

function Check_distro
{

   [[ $Debug_level -ge 1 ]] && echo "Starting Check_distro $* (version 1.0)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define specific local variables and assign values to them
   OS=${OS:-`uname -s`}

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNIG == bash ]] && local OPTIND
   while getopts : OPT
   do
      case $OPT in
        *) echo "Invalid flag '-$OPT' used with function 'Check_distro'!" >&2
           exit 1
           ;;
      esac
   done
   shift $(($OPTIND -1))

   # Getting the info through LSB info
   if `which lsb_release >/dev/null 2>&1`
   then
     Distro=`lsb_release -i -s`
     Release=`lsb_release -r -s`
 
     # Check for upstream
     if lsb_release -u >/dev/null 2>&1
     then
       Distro_upstream=`lsb_release -i -s -u`
       Release_upstream=`lsb_release -r -s -u`
     fi
   else
     # Generic release file
     if [[ -f /etc/os-release ]]
     then
       Distro=`awk -F= '/^NAME=/ {print $2}' /etc/os-release`
       Release=`awk -F= '/^VERSION_ID=/ {print $2}' /etc/os-release`
     # RedHat / CentOS / Fedora
     elif [ -f /etc/redhat-release ]
     then
       Distro=`sed 's/\ release.*//' /etc/redhat-release`
       Release=`sed 's/.*release\ //;s/\ .*//' /etc/redhat-release`
     # SUSE/OpenSUSE 
     elif [ -f /etc/SuSE-release ]
     then
       Distro=`head -1 /etc/SuSE-release | sed "s/[0-9].*//"`
       Version=`grep "^VERSION" /etc/SuSE-release | sed s/.*=\ //`
       Patch=`grep "^PATCHLEVEL" /etc/SuSE-release | sed s/.*=\ //`
       [[ -z $Patch ]] && Release="$Version" || Release="${Version}.${Patch}"
     else
       echo "Unknown Linux distribution found!" >&2
       return 1
     fi 
   fi
 
   # Return from here if /proc/1/exe is not readable
   [[ ! -r /proc/1/exe ]] && return 0
 
   # Discover systemd/upstart/sys-v
   Init=`ls -l /proc/1/exe | awk '{print $NF}'`
 
   # On Debian/Ubuntu, there is no symlink to systemd
   [[ $Init == /sbin/init ]] && Init=`/sbin/init --version 2>/dev/null`
 
   # 
   case $Init in
     *upstart*)
       Sysinit=upstart
       ;;
     *systemd*)
       Sysinit=systemd
       ;;
     '')
       Sysinit=sys-v
       ;;
     *)
       echo "Unsupported Sysinit method '$Init' found!" >&2
       return 1
       ;;
   esac
 
   # Exit the function and call the exit function to display some debuggin help
   # Unfortunately, bash does not support local traps within a function
   Exit
 
}
#------------------------------------------------------------------
#
# NAME:
#
#        Check_os - version 1.0 - date 28/Apr/2017
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_distro
#        FD : Check_shell
#        FD : Exit
#
#-----------------------------------------------------------------

function Check_os
{

   [[ $Debug_level -ge 1 ]] && echo "Starting Check_os $* (version 1.0)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define specific local variables and assign values to them
   OS=`uname -s`
   KERNEL=`uname -r`
   MACH=`uname -m`
   ARCH=`uname -p`

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNIG == bash ]] && local OPTIND
   while getopts : OPT
   do
      case $OPT in
        *) echo "Invalid flag '-$OPT' used with function 'Check_os'!" >&2
           exit 1
           ;;
      esac
   done
   shift $(($OPTIND -1))

   case $OS in
     WindowsNT)
       OS=Windows
       ;;
     CYGWIN*)
       OS=Cygwin
       ;;
     Darwin)
       OS=Mac
       ;;
     AIX)
       OSLEVEL=`oslevel -r`
       ;;
     SunOS)
       OS=Solaris
       ;;
     Linux)
       Check_distro || exit 1
       ;;
     *)
       echo "Unsupported OS '$OS' found!" >&2
       exit 1
       ;;
   esac

   # Exit the function and call the exit function to display some debuggin help
   # Unfortunately, bash does not support local traps within a function
   Exit

}
#-----------------------------------------------------------------
#
# NAME:
#
#        Check_shell - version 1.1 - date 22/Nov/2015
#
# DESCRIPTION:
#
#        This function finds out what shell you are using and 
#
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Exit
#        FD : Follow_link
#
#-----------------------------------------------------------------

function Check_shell
{

   [[ $Debug_level -ge 2 ]] && set -vx
   [[ $Debug_level -ge 1 ]] && echo "Starting function Check_shell $* (version 1.1)" >&2

   # No need to perform any further tasks
   [[ -n $SHELL_RUNNING ]] && return 0

   # Put PID in a variable
   Pid="$$"

   # Get shell based on current process
   Shell=$(ps -o pid,args | awk '$1=="'$Pid'" {print $2}')

   # Follow the symbolic link till we reach the shell itself
   Shell=$(Follow_link $(which $Shell))

   # Ensure the shell is found
   Shell=$(basename $Shell)
   if [[ ! $Shell =~ ^(sh|bash|ash|zsh|ksh|ksh88|ksh93)$ ]]
   then
     echo "Unable to figure out the shell used!" >&2
     exit 1
   fi

   # Set shell specific commands
   case $Shell in
      ksh*)
        Typeset=typeset
        Print=print
        ;;
      bash)
        Typeset=local
        Print='echo -e'
        ;;
      *)
        echo "Unsupported shell '$Shell' found!" >&2
        Exit -h 1
        ;;
   esac

   # Filling SHELL_RUNNING with the actual shell
   export SHELL_RUNNING=$Shell

}
#------------------------------------------------------------------
#
# NAME:
#
#        Check_ssh_connectivity - version 1.2 - date 14/dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Check_ssh_connectivity
{

   $Debug

   [[ $Debug_level -ge 1 ]] && echo "Starting function Check_ssh_connectivity $* (version 1.2)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define the variables as local
   $Typeset Exit User Verbose Port Host 
   Exit=exit
   Verbose=false
   Port=22

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts :Ep:u:v OPT
   do
      case $OPT in
         E) Exit=return
            ;;
         p) Port=$OPTARG
            ;;
         u) User="$OPTARG"
            ;;
         v) Verbose=true
            ;;
         *) echo "Invalid flag '-$OPT' used with function 'Check_ssh_connectivity'!" >&2
	    Exit -h 1
            ;;
      esac
   done
   shift $(($OPTIND -1))

   Host=$1
   Test_command=${2:-"true"}
   [[ -n $User ]] && Host=${User}@${Host}

   Ssh_command="ssh -n -p $Port -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o PreferredAuthentications=publickey"

   if $Ssh_command $Host $Test_command >/dev/null 2>&1
   then
      [[ $Verbose == true ]] && echo "Connection to '$Host' succesfully"
      Exit
      return 0
   else
      echo "Failed to connect to '$Host'!" >&2
      if [[ $Exit == exit ]]
      then
         Exit -h 1 
      else
         Exit
         return 1
      fi
   fi

}
#------------------------------------------------------------------
#
# NAME:
#
#        Display_variables - version 1.2 - date 14/dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Display_variables
{

   [[ $Debug_level -ge 1 ]] && echo "Starting function Display_variables $* (version 1.2)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   $Typeset Mode Append Prepend

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts :A:oP: OPT
   do
      case $OPT in
         A) Mode=append
            Append="_${OPTARG}"
            ;;
         o) Output=normal
            ;;
         P) Mode=prepend
            Prepend="${OPTARG}_"
            ;;
         *) echo "Invalid flag '-$OPT' used with function 'Display_variables'!" >&2
	    Exit -h 1
            ;;
      esac
   done
   shift $(($OPTIND -1))

   $Typeset Var=$1
   eval Vars=\"\$$Var\"

   for Var in $Vars
   do

      case $Mode in
          append) Var=${Var}${Append} ;;
         prepend) Var=${Prepend}${Var} ;;
      esac

      eval Value=\$$Var
      if [[ $Output == normal ]]
      then
         echo "$Var=$Value"
      else
         echo "$Var = $Value" >&2
      fi
   done

}
#------------------------------------------------------------------
#
# NAME:
#
#        Execute_ssh_command - version 1.2 - date 14/dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Execute_ssh_command
{

   $Debug

   [[ $Debug_level -ge 1 ]] && echo "Starting function Execute_ssh_command $* (version 1.2)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define the variables as local
   $Typeset Host Command Retry
   Retry=true

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts :R OPT
   do
      case $OPT in
         R) Retry=false
            ;;
         *) echo "Invalid flag '-$OPT' used with function 'Execute_ssh_command'!" >&2
	    Exit -h 1
            ;;
      esac
   done
   shift $(($OPTIND -1))

   Host=$1
   Command="$2"

   [[ -t 3 && $Verbose_level -ge 2 ]] && echo "`date +"%H:%M:%S"` : Running 'ssh $Host \"$Command\"'" >&3
   ssh -n $Host "$Command" > ${TMPFILE}ssh &
   Pid=$!

   Teller=0
   Maxteller=15
   Step=1
   Finished=false

   # Wait for command to finish
   while [[ $Teller -lt $Maxteller ]]
   do
      if ! ps -p $Pid >/dev/null 2>&1
      then
         Finished=true
         break
      fi
      Teller=$(($Teller+$Step))
      sleep $Step
   done

   if [[ $Finished == true ]]
   then
      cat ${TMPFILE}ssh
   else
      echo "Remote command still not finished ... killing the connection and retrying ..." >&2
      kill -9 $Pid 2>/dev/null
      Ssh_command -R "$Host" "$Command"
   fi

   # Exit the function
   Exit ; return 0
}
#------------------------------------------------------------------
#
# NAME:
#
#        Exit - version 1.0 - date 22/Nov/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#-----------------------------------------------------------------
Exit()
{

   # Using function() so $0 will not be overwritten with the current function name
   Check_shell
   Exit_${SHELL_RUNNING} "$@"
   return $?

}


function Exit_bash
{

   [[ $Debug_level -ge 2 ]] && set -vx

   # parse command line into arguments and check results of parsing
   local OPTIND=1
   local Exit_mode
   while getopts h: OPT
   do
      case $OPT in
        h) Exit_mode=exit
           Rc=$OPTARG
           ;;
        *) echo "Invalid flag '-$OPT' used with function 'Exit'!" >&2
           exit 1
           ;;
      esac
   done
   shift $(($OPTIND -1))

   # Get the name of the calling function and put it in $Function_name
   # ${FUNCNAME[0]} = current function (Exit_bash)
   # ${FUNCNAME[1]} = parent function (Exit)
   # ${FUNCNAME[2]} = grantparent function
   local Function_name
   Function_name=${FUNCNAME[2]}

   # Printing the message
   [[ $Debug_level -ge 1 ]] && echo "Finishing function '$Function_name'" >&2

   # Exit no
   [[ $Exit_mode == exit ]] && exit $Rc

}

Exit_ksh ()
{

   # Using function() so $0 will not be overwritten with the current function name

   [[ $Debug_level -ge 2 ]] && set -vx

   # parse command line into arguments and check results of parsing
   typeset OPTIND=1
   typeset Exit_mode
   while getopts :h: OPT
   do
      case $OPT in
        h) Exit_mode=exit
           Rc=$OPTARG
           ;;
        *) echo "Invalid flag '-$OPT' used with function 'Exit'!" >&2
           exit 1
           ;;
      esac
   done
   shift $(($OPTIND -1))

   # Get the name of the calling function and put it in $Function_name
   typeset Function_name
   Function_name=$0 

   # Printing the message
   [[ $Debug_level -ge 1 ]] && echo "Finishing function '$Function_name'" >&2

   # Exit no
   [[ $Exit_mode == exit ]] && exit $Rc

}
#------------------------------------------------------------------
#
# NAME:
#
#        Follow_link - version 1.2 - date 17/Dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Follow_link
{

   [[ $Debug_level -ge 1 ]] && echo "Starting function Follow_link $* (version 1.2)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   #
   Object=$1

   # Make sure the file exists
   if [[ ! -e $Object ]]
   then
      echo "File/directory/link '$Object' not found!" >&2
      return 1
   fi

   # Keep following the link till you hit the non-symlink
   while [[ -L $Object ]]
   do
      Object1=`ls -l $Object | awk '{print $NF}'`
      [[ $Object1 == /* ]] && Object=$Object1 || Object=`dirname $Object`/$Object1
   done

   # Print the final file
   cd `dirname $Object`
   echo `/bin/pwd`/`basename $Object`

}
#------------------------------------------------------------------
#
# NAME:
#
#        Print_full_line - version 1.1 - date 22/Nov/2015
#
# DESCRIPTION:
#
#        Prints an empty line or phrase and fill the line to the right and
#        left with a user definable character
#        e.g. "---------------- printing --------------------"
#
# FLAGS:
#
#        -c <char>     : Character to use for filling out the line
#        -H            : Print header format
#        -n <nr>       : Defines how many characters per line to use
#                        (Default=width of the terminal)
#
# ARGUMENTS:
#
#        $1 = String to print
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Print_full_line
{

   [[ $Debug_level -ge 1 ]] && echo "Starting function Print_full_line $* (version 1.1)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define the variables as local
   $Typeset Char1 Char2 Tput MaxChar Header

   Header=false
   Char1="-"
   Char2=" "
   Tput=`which tput 2>/dev/null`
   [[ -n $Tput ]] && MaxChar=`tput cols 2>/dev/null`
   MaxChar=${MaxChar:-80}

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts :c:C:Hn: OPT
   do
      case $OPT in
        c) Char1="$OPTARG"
           ;;
        C) Char2="$OPTARG"
           ;;
        H) Header=true
           ;;
        n) MaxChar=$OPTARG
           ;;
        *) echo "Invalid flag '-$OPT' used with function 'Print_full_line'!" >&2
           Exit -h 1
           ;;
      esac
   done
   shift $(($OPTIND -1))

   Text="$@"
   [[ -n $Text ]] && Text=" $Text "

   if [[ $Header == true ]]
   then
      printf "%${MaxChar}s\n" | tr ' ' "$Char1"
      TextChar=$((`echo "$Text" | wc -c` - 1))
      SideChar=$((($MaxChar - $TextChar) / 2))
      SideLine=`printf "%${SideChar}s\n" | tr ' ' "$Char2"`
      echo "${SideLine}${Text}${SideLine}"
      printf "%${MaxChar}s\n" | tr ' ' "$Char1"

   else
      TextChar=$((`echo "$Text" | wc -c` - 1))
      SideChar=$((($MaxChar - $TextChar) / 2))
      SideLine=`printf "%${SideChar}s\n" | tr ' ' "$Char1"`
      echo "${SideLine}${Text}${SideLine}"
   fi

   #
   Exit
   return

}
#-----------------------------------------------------------------
#
# NAME:
#
#        Process_parallel - version 1.3 - date 17/Dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
#        None
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#        FD : Std_message
#
# OUTPUT VARIABLES
#
#        None
#
# RETURN_CODES:
#
#-----------------------------------------------------------------

function Proc_status
{

  $Typeset TMPFILE=${TMPFILE:-"/tmp/Process_parallel.$$"}

  Procs_all=`ps -ef | awk '{print $2}'`
  Procs_all_grep=`echo $Procs_all | sed "s/ /|/g"`
  Procs_started=`awk '{print $2}' ${TMPFILE}run`
  Procs_active=`echo "$Procs_started" | grep -xE "$Procs_all_grep"`
  Procs_active_nr=`echo "$Procs_active" | grep -v "^$" | wc -l`

  # Get amount of parallel processes running
  Concurrent=$Procs_active_nr
#  [[ $Host_count -lt $Host_count_total && $Concurrent -lt $MaxConcurrent && $1 != -F ]] && return
  [[ $Host_count -lt $Host_count_total && $Concurrent -lt $MaxConcurrent ]] && return

  Procs_active_grep=`echo $Procs_active | sed "s/ /|/g"`
  Procs_finished=`echo "$Procs_started" | grep -vxE "$Procs_all_grep|^$"`

  # Find processes no longer running
  for Pid in $Procs_finished
  do
     Host1=`awk '$2=="'$Pid'" {print $1}' ${TMPFILE}run`
     Std_message -dih $Host1 "Command finished"
     sed -i "/^${Host1} /d" ${TMPFILE}run

     # In double verbosity, create logfile
     if [[ $Verbose_level -ge 2 && -z $Process_parallel_file ]]
     then
        Process_parallel_file=${DIRNAME}/${BASENAME}.parlogs
     fi

     # Write parallel log file to new file
     if [[ -n $Process_parallel_file ]]
     then
        Print_full_line -n80 "${Host1}" >> $Process_parallel_file
        cat ${TMPFILE}.${Host1} >> $Process_parallel_file
     fi
  done

}

function Process_parallel
{

   [[ $Debug_level -ge 1 ]] && echo "Starting Process_parallel $* (version 1.3)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define specific local variables and assign values to them
   OS=${OS:-`uname -s`}
   $Typeset TMPFILE=${TMPFILE:-"/tmp/Process_parallel.$$"}

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND

   # Set/unset function variables
   $Typeset MaxConcurrent Hostlist Wait_cycle
   MaxConcurrent=10
   Wait_cycle=5

   # parse command line into arguments and check results of parsing
   while getopts :c:f:o:w: OPT
   do
      case $OPT in
         c) MaxConcurrent=$OPTARG
	    ;;
         f) Hostlist=$OPTARG
            ;;
	 o) Process_parallel_file=$OPTARG
	    ;;
         w) Wait_cycle=$OPTARG
            ;;
         *) echo "Invalid flag '-$OPT' used with function 'Process_parallel'!" >&2
            exit 1
            ;;
       esac
   done
   shift $(($OPTIND -1))

   # Get all arguments
   Cmd="$1"
   shift
   [[ -n $Hostlist ]] && Hosts=`cat $Hostlist` || Hosts="$@"

   # Count the amount of hosts
   Host_count_total=`echo $Hosts | wc -w`

   # Now loop all
   > ${TMPFILE}run
   for Host in $Hosts
   do

      Std_message -dih $Host "Executing '`eval echo $Cmd`' (background)"
      eval $Cmd >${TMPFILE}.${Host} 2>&1 &
      Pid="$!"
      echo "$Host $Pid" >> ${TMPFILE}run
      Host_count=$(($Host_count+1)) 

      # Get status of all running processes issues by this script
      Proc_status

      [[ $Verbose_level -ge 2 ]] && Std_message -dih general "Running $Concurrent of $MaxConcurrent instances"

      while [[ $Concurrent -ge $MaxConcurrent ]]
      do
         Proc_status
         [[ $Concurrent -lt $MaxConcurrent ]] && break
         [[ $Verbose_level -ge 2 ]] && Std_message -dih general "Max concurrent jobs reached ... waiting for jobs to finish"
	 sleep $Wait_cycle
      done

   done

   # Now wait for all nodes to finish
   while [[ $Concurrent -ne 0 ]]
   do
      Proc_status
      [[ $Concurrent -eq 0 ]] && break
      [[ $Verbose_level -ge 2 ]] && Std_message -dih general "Still '$Concurrent' jobs running"
      sleep $Wait_cycle
   done

   # Exit the function and call the exit function to display some debuggin help
   # Unfortunately, bash does not support local traps within a function
   Exit

}
#------------------------------------------------------------------
#
# NAME:
#
#        Random_wait - version 1.1 - date 22/Nov/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Random_wait
{

   $Debug

   [[ $Debug_level -ge 1 ]] && echo "Starting function Random_wait $* (version 1.1)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define the variables as local
   $Typeset Maxtime=60
   
   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts :t: OPT
   do
      case $OPT in
        t) Maxtime=$OPTARG
           ;;
        *) echo "Invalid flag '-$OPT' used with function 'Random_wait'!" >&2
           Exit -h 1
           ;;
      esac
   done
   shift $(($OPTIND -1))

   # Start by randomizing the further execution (0-60 seconds)
   while true
   do
      if [[ $Maxtime -lt 100 ]] ; then
         Time2wait=`echo $RANDOM | sed 's/^.*\(.\{2\}\)$/\1/'`
      elif [[ $Maxtime -lt 1000 ]] ; then
         Time2wait=`echo $RANDOM | sed 's/^.*\(.\{3\}\)$/\1/'`
      elif [[ $Maxtime -lt 10000 ]] ; then
         Time2wait=`echo $RANDOM | sed 's/^.*\(.\{4\}\)$/\1/'`
      fi

      [[ $Time2wait -le $Maxtime ]] && break
   done

   # Now sleep for the amount of time specified
   [[ $Verbose_level -ge 2 ]] && echo "Sleeping for '$Time2wait' seconds"
   sleep $Time2wait

   # Leave the function
   Exit

}

#------------------------------------------------------------------
#
# NAME:
#
#        Read_headers - version 1.2 - date 14/dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Read_headers
{

   [[ $Debug_level -ge 1 ]] && echo "Starting function Read_headers $* (version 1.2)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define the variables as local
   $Typeset Mode Append Prepend Header_line Case Variables

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts :A:cCP: OPT
   do
      case $OPT in
         A) Mode=append
            Append="_${OPTARG}"
            ;;
         c) Case=lower
            ;;
         C) Case=upper
            ;;
#         F) Fs="OPTARG"
#            ;;
         P) Mode=prepend
            Prepend="${OPTARG}_"
            ;;
         *) echo "Invalid flag '-$OPT' used with function 'Read_headers'!" >&2
	    Exit -h 1
            ;;
      esac
   done
   shift $(($OPTIND -1))

   $Typeset Var Fs File
   Var=$1
   Fs="$2"
   File=$3

   # Get the headers and perform some substiutions
   [[ $Fs == " " ]] && Fsx="#@#" || Fsx=" "
   Header_line=`head -1 $File | sed "s/-/_/g;s/$Fsx/_/g;s/$Fs/ /g"`
  
   case $Mode in
      append)
         Variables=`echo "$Header_line" | sed "s/ /${Append} /g;s/$/${Append}/"`
         ;;
      prepend)
         Variables=`echo "$Header_line" | sed "s/ / ${Prepend}/g;s/^/${Prepend}/"`
         ;;
      *)
         Variables=`echo "$Header_line"`
         ;;
   esac

   # Convert to upper/lower case
   case $Case in
      upper)
         Variables=`echo "$Variables" | tr '[a-z]' '[A-Z]'`
         ;;
      lower)
         Variables=`echo "$Variables" | tr '[A-Z]' '[a-z]'`
         ;;
   esac

   # Fill the final variables
#   echo "$Variables" | eval read $Var
   eval $Var=`echo \"$Variables\"`
   
   # Get the field number per header
   set -- `eval echo \\\$$Var`
   Counter=0
   while [[ -n $1 ]]
   do
      Counter=$(($Counter + 1))
      eval ${1}_nr=$Counter
      shift
   done

}
#------------------------------------------------------------------
#
# NAME:
#
#        Read_line - version - 1.1 - date 14/dec/2015
#
# DESCRIPTION:
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-----------------------------------------------------------------

function Read_line
{

   [[ $Debug_level -ge 1 ]] && echo "Starting function  Read_line $* (version 1.1)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   $Typeset Append Prepend Exit_if_not_found Exit Silent Mode Use_row_name 
   Exit_if_not_found=true
   Exit=exit
   Silent=false
   Mode=full
#   Use_row_name=false
   unset Field0 Field1 Field2 Value0 Value1 Value2

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
#   while getopts :A:EnP:Rs OPT
   while getopts :A:EP:Rsz OPT
   do
      case $OPT in
         A) Append="_${OPTARG}"
            ;;
         E) # Do not exit in case no match is found
            Exit_if_not_found=false
            ;;
         n) Use_row_name=true
            ;;
         P) Prepend="${OPTARG}_"
            ;;
         R) Exit=return
            ;;
         s) Silent=true
            ;;
         z) Mode=partly
            ;;
         *) echo "Invalid flag '-$OPT' used with function 'Read_line'!" >&2
	    exit 1
            ;;
      esac
   done
   shift $(($OPTIND -1))
  
   $Typeset Var Fs File
   Var=$1
   Fs=$2
   File=$3
   shift 3

   Nr=0
   while [[ ! -z $1 ]]
   do
#      [[ $Use_row_name == true ]] && eval Field$Nr=`eval echo \${1}_nr` || eval Field$Nr=$1
      eval Field$Nr=$1
      eval Field${Nr}_nr=`eval echo \\$${1}_nr`
      eval Value$Nr=\"$2\"
      Nr=$(($Nr+1))
      shift 2
   done

   # Get the headers
   eval Varx=\$$Var
   if [[ -n $Append ]]
   then
      Varx=`echo $Varx | sed "s/ /${Append} /g;s/$/${Append}/"`
   elif [[ -n $Prepend ]]
   then
      Varx=`echo $Varx | sed "s/ / ${Prepend}/g;s/^/${Prepend}/"`
   fi

   if [[ $Mode == full ]] 
   then
      case $Nr in
         1) awk -F"$Fs" '$'$Field0_nr'=="'$Value0'" {print $0}' $File > ${TMPFILE}readline ;;
         2) awk -F"$Fs" '$'$Field0_nr'=="'$Value0'" && $'$Field1_nr'=="'$Value1'" {print $0}' $File > ${TMPFILE}readline ;;
         3) awk -F"$Fs" '$'$Field0_nr'=="'$Value0'" && $'$Field1_nr'=="'$Value1'" && $'$Field2_nr'=="'$Value2'" {print $0}' $File > ${TMPFILE}readline ;;
      esac
   else
      case $Nr in
         1) awk -F"$Fs" '$'$Field0_nr'~"'$Value0'" {print $0}' $File > ${TMPFILE}readline ;;
         2) awk -F"$Fs" '$'$Field0_nr'~"'$Value0'" && $'$Field1_nr'~"'$Value1'" {print $0}' $File > ${TMPFILE}readline ;;
         3) awk -F"$Fs" '$'$Field0_nr'~"'$Value0'" && $'$Field1_nr'~"'$Value1'" && $'$Field2_nr'~"'$Value2'" {print $0}' $File > ${TMPFILE}readline ;;
      esac
   fi

   # Make sure a match was found
   if [[ ! -s ${TMPFILE}readline ]]
   then
      if [[ $Silent == false ]]
      then
         case $Nr in
            1) echo "No match for '$Field0=$Value0' found in '$File'!" >&2 ;;
            2) echo "No match for '$Field0=$Value0' && '$Field1=$Value1' found in '$File'!" >&2 ;;
            3) echo "No match for '$Field0=$Value0' && '$Field1=$Value1' && '$Field2=$Value2' found in '$File'!" >&2 ;;
         esac
      fi

      [[ $Exit_if_not_found == true ]] && $Exit 1
   fi

   # Read the variables
   IFS="$Fs"
   cat ${TMPFILE}readline | eval read $Varx
   unset IFS

   if [[ $Debug_level -ge 2 ]]
   then
      for Var in $Varx
      do
         eval Value=\$$Var
         echo "$Var = $Value"
      done
   fi

}
#-----------------------------------------------------------------
#
# NAME:
#
#        Std_message - version 1.2 - date 22/feb/2016
#
# DESCRIPTION:
#
#        Write message in default format
#
# FLAGS:
#
#        -e          : Define the message to be an error
#        -f <FD>     : Use this file descriptor
#        -h <string> : String to print between date & category
#        -i          : Define the message to be informative
#        -w          : Define the message to be a warning
#        -o          : Force message to write to stdout
#        -O          : Force message to write to stderr
#        -s          : Removes aditional spaces if more than one is found
#                      Eg 'x    x    x' --> 'x x x'
#        -t <mode>   : Print time stamp in message in format :
#                      1 = YYMMDDThhmmss
#                      2 = DD/MM/YYYY hh:mm:ss
#                      3 = hh:mm:ss
#
# PARAMETERS:
#
#        $1 = Message
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Set_path
#
#-----------------------------------------------------------------

function Std_message
{

  [[ $Debug_level -ge 1 ]] && echo "Starting Std_message $* (version 1.2)" >&2
  [[ $Debug_level -ge 2 ]] && set -vx

  # Get shell specifics
  Check_shell

  # Define specific local variables and assign values to them
  OS=${OS:-`uname -s`}

  # parse command line into arguments and check results of parsing
  [[ $SHELL_RUNNING == bash ]] && local OPTIND

  # Disable debug for this function
  __xtrace=$(shopt -o xtrace | cut -f2)
  __verbose=$(shopt -o verbose | cut -f2)
  [[ $__xtrace == on ]] && set +x
  [[ $__verbose == on ]] && set +v

  # Define local variables
  $Typeset Color Type Message Output Fd Host Force_Fd HostChar x Remove_spacing Timestamp Timestamp_mode
  Fd=1
  HostChar=10
  Remove_spacing=false
  Color_use=true
  # Color=None
  None="\033[0m"
  Green="\033[0;32m"
  Red="\033[0;31m"
  Yellow="\033[1;33m"
  Blue="\033[1;34m"
  Magenta="\033[1;35m"

  # parse command line into arguments and check results of parsing
  while getopts cC:dDef:h:H:ioOst:w OPT
  do
     case $OPT in
        c) Color_use=true
           ;;
        C) Color_use=true
           Color=$OPTARG
           ;;
        d) Timestamp_mode=1
           ;;
        D) Timestamp_mode=2
           ;;
        e) Type=error
           Fd=2
           ;;
        f) Force_Fd="$OPTARG"
           ;;
        h) Host=$OPTARG
           ;;
        H) HostChar="$OPTARG"
           ;;
        i) Type=info
           Fd=1
           ;;
        o) Force_Fd=1
           ;;
        O) Force_Fd=2
           ;;
        s) Remove_spacing=true
           ;;
        t) Timestamp_mode=$OPTARG
           ;;
        w) Type=warning
           Fd=2
           ;;
        *) echo "Invalid flag '-$OPT' used with function 'Std_message'!" >&2
           exit 1
           ;;
     esac
  done
  shift $(($OPTIND -1))

  # Test number of arguments
  [[ $# -ne 1 ]] && echo "Std_message : Invalid amount of arguments given !" >&2 && exit 1

  # Get arguments
  Message="$1"

  # Timestamp
  case $Timestamp_mode in
     1) Timestamp=`date "+%Y %m %d T %H %M %S" | sed "s/ //g"` ;;
     2) Timestamp=`date "+%d/%m/%Y %H:%M:%S"` ;;
     3) Timestamp=`date "+%H:%M:%S"` ;;
     4) Timestamp=`date "+%Y-%m-%d %H:%M:%S"` ;;
  esac

  # Fill out the Host variable if required
  [[ -n $Host ]] && Host=`printf "%-${HostChar}s\n" $Host`

  # Now write the message
  case $Type in
        error) Cat="ERROR"
               Color=${Color:-Red}
               ;; 
         info) Cat="INFO"
               Color=${Color:-None}
               ;;
      warning) Cat="WARN"
               Color=${Color:-Yellow}
               ;;
            *) Color=${Color:-None}
               ;;
  esac

  x=
  [[ -n $Timestamp ]] && x="$Timestamp | "
  [[ -n $Type ]] && x="$x$Cat | "
  [[ -n $Host ]] && x="$x$Host | "

  # Remove obsolete spacing
  [[ $Remove_spacing = true ]] && Message=`echo "$Message" | sed "s/  */ /g"`

  # Now compose the full line to display
  Message="$x$Message"

  # Now print the line
  Fd=${Force_Fd:-$Fd}

  echo -e "$(eval echo \$${Color})${Message}${None}" >&${Fd}

  # Enable debug again for this function
  [[ $__xtrace == on ]] && set -x
  [[ $__verbose == on ]] && set -v

  # Exit the function and call the exit function to display some debuggin help
  # Unfortunately, bash does not support local traps within a function
  Exit

}
#-------------------------------------------------------------------------------
#
# NAME:
#
#        Test_flag - version 1.0 - date 14/dec/2015
#
# DESCRIPTION:
#
#        Function to check the validity of the arguments passed to a script
#        Within the while getopts loop, you will need to define if the flags was
#        use. To do this, set a variable '<flag>flag=1'.
#
#        Examples : 
#
#        -x => xflag=1
#        -T => Tflag=1
#
#        $1 = function (req = required, for = forbidden, inc = incompatible)
#        $2 = first flag
#        $3 = second flag (only needed w/ inc)
#
# FLAGS:
#
# ARGUMENTS:
#
# VARIABLE_DEPENDENCIES:
#
#        None
#
# FUNCTION_DEPENDENCIES:
#
#        FD : Check_shell
#
#-------------------------------------------------------------------------------

function Test_flag
{

   [[ $Debug_level -ge 1 ]] && echo "Starting Test_flag $* (version 1.0)" >&2
   [[ $Debug_level -ge 2 ]] && set -vx

   # Get shell specifics
   Check_shell

   # Define specific local variables and assign values to them
   OS=${OS:-`uname -s`}

   Conditional=false

   # parse command line into arguments and check results of parsing
   [[ $SHELL_RUNNING == bash ]] && local OPTIND
   while getopts :c:C: OPT
   do
      case $OPT in
        c) Conditional=true
	   Condition1="eq"
	   Condition2="$OPTARG"
           ;;
        C) Conditional=true
	   Condition1="ne"
	   Condition2="$OPTARG"
           ;;
        *) echo "Invalid flag '-$OPT' used with function 'Test_flag'!" >&2
           exit 1
           ;;
      esac
   done
   shift $(($OPTIND -1))

   # Get the arguments from input
   Function=$1
   Flag1=$2
   Flag2=$3
   eval Flag1_value=\$${Flag1}flag
   eval Flag2_value=\$${Flag2}flag

   # Some test depend upon extra conditions
   if [[ $Conditional == true ]]
   then

      # Strip
      x1=`echo "$Condition2" | cut -f1 -d:`
      x2=`echo "$Condition2" | cut -f2 -d:`
      eval x3=\$$x1

      case $Condition1 in
        eq) echo "$x3" | grep -q "$x2" && Condition_met=true || Condition_met=false
	    ;;
        ne) echo "$x3" | grep -q "$x2" && Condition_met=false || Condition_met=true
	    ;;
      esac

#      if test $x3 $Condition $x2
      if [[ $Condition_met == true ]]
      then
         [[ $Verbose_level -ge 2 ]] && echo "Condition found!"
	 Append_string=" when $x1 $Condition1 $x2"
      else
         [[ $Verbose_level -ge 2 ]] && echo "Condition not found!"
	 return 0
      fi
   fi

   # Now do the testing
   case $Function in
      # Required flag
      req) if [[ $Flag1_value -ne 1 ]]
           then
              echo "Flag -$Flag1 is required${Append_string}!" >&2
              exit 1
           fi
           ;;
      # Forbidden flags
      for) if [[ $Flag1_value -eq 1 ]]
           then
              echo "Flag -$Flag1 cannot be used${Append_string}" >&2
              exit 1
           fi
           ;; 
      # Incompatibe flags
      inc) if [[ $Flag1_value -eq 1 && $Flag2_value -eq 1 ]]
           then
              echo "Flag -$Flag1 cannot be used together with -$Flag2${Append_string}" >&2
              exit 1
           fi
           ;;
        *) echo "Improper use of function 'Test_flag' found!" >&2
           exit 1
           ;;
   esac

   # Exit the function and call the exit function to display some debuggin help
   # Unfortunately, bash does not support local traps within a function
   Exit

}
