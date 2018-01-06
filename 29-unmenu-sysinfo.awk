BEGIN {
#define ADD_ON_URL     sys_info
#define ADD_ON_MENU    System Info
#define ADD_ON_STATUS  NO
#define ADD_ON_TYPE    awk
#define ADD_ON_VERSION 1.2 - contributed by bubbaQ
#define ADD_ON_VERSION 1.3 - modified to better deal with utilities not yet installed Joe L.
#define ADD_ON_VERSION 1.4 - Added new buttons for free space, mounted file systems -  Joe L.
#define ADD_ON_VERSION 1.5 - Added class for sysinfo button. mvdzwaan
#define ADD_ON_VERSION 1.6 - Added -l option to free to show "low" memory. Joe L.
#define ADD_ON_VERSION 1.7 - Major rewrite and expansion
#define ADD_ON_HEAD <STYLE type='text/css'>.db {color:red;}</STYLE>
#UNMENU_RELEASE $Revision$ $Date$

  CGI_setup()
  num_commands=0;

  LoadCmds("CPU Info",
           "CPU 64-bit check;ACPI CPU Info;CPU Info;Sensor Info;CPU Freq Info;DMI",
           "",
           "cat /proc/cpuinfo | grep -Gq \"flags.* lm \"  && echo '64-bit capable' || echo '32-bit only';acpitool -c;cat /proc/cpuinfo;sensors;cpufreq-info;dmidecode --type=processor",
           ";;;Consider installing the lm-sensors package, if your kernel supports hardware monitoring or you have the proper modules (.ko files) available.;;DMI Decode can be installed from the <a href=\"pkg_manager\">unMENU Package Manager.</a>",
           "CPU Info" )
  LoadCmds("Memory Info",
           "Memory Info;DMI",
           "",
           "free -l;dmidecode --type memory",
           ";DMI Decode can be installed from the <a href=\"pkg_manager\">unMENU Package Manager.</a>",
           "Memory Info" )
  LoadCmds("Ethernet Info",
           "NIC 0 Info;NIC 0 Driver Info;NIC 0 Ethernet Config Info;"\
           "NIC 1 Info;NIC 1 Driver Info;NIC 1 Ethernet Config Info;"\
           "NIC 2 Info;NIC 2 Driver Info;NIC 2 Ethernet Config Info;"\
           "NIC 3 Info;NIC 3 Driver Info;NIC 3 Ethernet Config Info;"\
           "NIC 4 Info;NIC 4 Driver Info;NIC 4 Ethernet Config Info;"\
           "NIC 5 Info;NIC 5 Driver Info;NIC 5 Ethernet Config Info;"\
           "NIC 6 Info;NIC 6 Driver Info;NIC 6 Ethernet Config Info;"\
           "NIC 7 Info;NIC 7 Driver Info;NIC 7 Ethernet Config Info;"\
           "NIC 8 Info;NIC 8 Driver Info;NIC 8 Ethernet Config Info;"\
           "NIC 9 Info;NIC 9 Driver Info;NIC 9 Ethernet Config Info",
           "test -d '/sys/class/net/eth0';test -d '/sys/class/net/eth0';test -d '/sys/class/net/eth0';"\
           "test -d '/sys/class/net/eth1';test -d '/sys/class/net/eth1';test -d '/sys/class/net/eth1';"\
           "test -d '/sys/class/net/eth2';test -d '/sys/class/net/eth2';test -d '/sys/class/net/eth2';"\
           "test -d '/sys/class/net/eth3';test -d '/sys/class/net/eth3';test -d '/sys/class/net/eth3';"\
           "test -d '/sys/class/net/eth4';test -d '/sys/class/net/eth4';test -d '/sys/class/net/eth4';"\
           "test -d '/sys/class/net/eth5';test -d '/sys/class/net/eth5';test -d '/sys/class/net/eth5';"\
           "test -d '/sys/class/net/eth6';test -d '/sys/class/net/eth6';test -d '/sys/class/net/eth6';"\
           "test -d '/sys/class/net/eth7';test -d '/sys/class/net/eth7';test -d '/sys/class/net/eth7';"\
           "test -d '/sys/class/net/eth8';test -d '/sys/class/net/eth8';test -d '/sys/class/net/eth8';"\
           "test -d '/sys/class/net/eth9';test -d '/sys/class/net/eth9';test -d '/sys/class/net/eth9'",
           "ethtool eth0;ethtool -i eth0;ifconfig eth0;"\
           "ethtool eth1;ethtool -i eth1;ifconfig eth1;"\
           "ethtool eth2;ethtool -i eth2;ifconfig eth2;"\
           "ethtool eth3;ethtool -i eth3;ifconfig eth3;"\
           "ethtool eth4;ethtool -i eth4;ifconfig eth4;"\
           "ethtool eth5;ethtool -i eth5;ifconfig eth5;"\
           "ethtool eth6;ethtool -i eth6;ifconfig eth6;"\
           "ethtool eth7;ethtool -i eth7;ifconfig eth7;"\
           "ethtool eth8;ethtool -i eth8;ifconfig eth8;"\
           "ethtool eth9;ethtool -i eth9;ifconfig eth9",
           "Information about your network interface");
  LoadCmds("Ps Info",
           "Ps Info",
           "",
           "ps -eaf",
           "",
           "A current Process Listing");
  LoadCmds("Fuser info",
           "Fuser info",
           "",
           "fuser -mv /mnt/disk* /mnt/user/*",
           "You don't appear to have fuser installed.",
           "File systems and user-shares in use");
  LoadCmds("Uptime",
           "Uptime;Uname;;Slackware;Unraid",
           ";;test -f /proc/version;test -f /etc/slackware-version;test -f /etc/unraid-version",
           "uptime;uname -a;cat /proc/version;cat /etc/slackware-version;cat /etc/unraid-version",
           "",
           "Up-time");
  LoadCmds("Top Processes",
           "Top Processes",
           "",
           "top -b -n1",
           "",
           "Processes using the most system resources");
  LoadCmds("Open Files",
           "Open Files From Array Drives;Open Files From Flash Drive;All Open Files",
           "",
           "/usr/bin/lsof /dev/md*;/usr/bin/lsof /boot;/usr/bin/lsof",
           "You don't appear to have lsof installed.;You don't appear to have lsof installed.;You don't appear to have lsof installed.",
           "A list of open files");
  LoadCmds("Kernel Parameters",
           "Kernel Parameters",
           "",
           "sysctl -a | sort",
           "",
           "Kernel Parameters");
  LoadCmds("Samba Status",
           "Samba Status;smb.conf;smb-names.conf;smb-shares.conf;smb-extra.conf;Parameters",
           "",
           "smbstatus;cat /etc/samba/smb.conf;cat /etc/samba/smb-names.conf;cat /etc/samba/smb-shares.conf;cat /boot/config/smb-extra.conf;testparm -sv",
           "",
           "Samba Status");
  LoadCmds("Cron",
           "Crontab;Hourly;Daily;Weekly;Monthly",
           "",
           "crontab -l;ls -l /etc/cron.hourly;ls -l /etc/cron.daily;ls -l /etc/cron.weekly;ls -l /etc/cron.monthly",
           "",
           "Job schedule list");
  LoadCmds("Mounted File Systems",
           "Mounted File Systems",
           "",
           "mount",
           "",
           "A list of mounted file systems");
  LoadCmds("File System Space",
           "File System Space;File System Space",
           "",
           "df -khT;df -TB 1 | awk -v sq=\"'\" '{if ($1 == \"Filesystem\") {printf( \"%-12s %-12s %20s %20s %20s %4s %s\\n\", $1, $2, $3, $4, $5, $6, $7)} else {printf( \"%-12s %-12s %\" sq \"20d %\" sq \"20d %\" sq \"20d %4s %s\\n\", $1, $2, $3, $4, $5, $6, $7)}}'",
           "",
           "A list of file system usage statistics");
  LoadCmds("List Devices",
           "List Devices",
           "",
           "lsdev",
           "You don't appear to have lsdev installed",
           "A listing of the devices on your server");
  LoadCmds("UPS Status",
           "UPS Status",
           "",
           "apcaccess status",
           "You don't appear to have a UPS monitoring program installed.",
           "UPS Status");
  LoadCmds("PCI Devices",
           "PCI Devices",
           "",
           "lspci -v",
           "PCI Utilities can be installed from the <a href=\"pkg_manager\">unMENU Package Manager.</a>",
           "A listing of the PCI devices on your server");
  LoadCmds("Loaded Modules",
           "Loaded Modules",
           "",
           "lsmod",
           "",
           "Loaded Kernel Modules");

  buttons = ""
  results = ""
  instructs = ""
  num_buttons_on_row = 9

  ###########################################################
  # Did the user press a command button?
  ###########################################################
  sysarg = GETARG["option"]

  for (stg=1; stg <= num_commands; stg++) {

    # If the command was matched, set the flag to run it
    if (sysarg == gensub(/ /, "+", "g", commands[stg, "button"] )) {
       results = runcmd( commands[ stg, "button"], commands[ stg, "precheck" ], commands[ stg, "command" ], commands[ stg, "descr"], commands[ stg, "err_msg"])
    }

    buttons = buttons "<td ><input class=\"sysinfo_button\" type=submit name='option' value='" commands[ stg, "button"] "'"
    if ( commands[stg, "tool_tip" ] != "" ) {
       buttons = buttons " title='"  commands[stg, "tool_tip"] "'"
    }

    # If we defined an error message, we need to determine if the command exists.
    if ( commands[ stg, "err_msg" ] != "" ) {
      # get first command
      file_to_check = commands[ stg, "command" ]
      cmd_index = index( file_to_check, ";")
      if ( cmd_index != 0 ) {
        file_to_check = substr( file_to_check, 1, cmd_index -1)
      }
      # get first command filename
      cmd_index = index( file_to_check, " ")
      if ( cmd_index != 0 ) {
        file_to_check = substr( file_to_check, 1, cmd_index -1)
      }
      if (system("command -v " file_to_check " >/dev/null 2>&1")!=0) {
        buttons = buttons " class='db' >"
        instructs = "<font size=4 color=\"red\">&bull;&nbsp;</font>Items in red are not installed on your system."
      }
    } else {
        buttons = buttons ">"
    }
    buttons = buttons "</td>"
    if ( stg % num_buttons_on_row == 0 ) {
      buttons = buttons "</tr><tr>"
    }

  }

  pageoptions = "<hr><form method=\"GET\" ><table>"
  pageoptions = pageoptions "<tr>"
  pageoptions = pageoptions buttons
  pageoptions = pageoptions "</tr></table></form>"

  print pageoptions

  if (sysarg =="")
    print instructs
  else
    print results
}

function LoadCmds( theButton, theDescr, thePrecheck, theCommand, theErrorMsg, theToolTip ) {
  # theButton is the button test
  # theDescr is the section description before the command, seperate multiple by semicolon
  # thePrecheck is the command to run to check if theCommand should be run, seperate multiple by semicolon
  # theCommand is the command to run, seperate multiple by semicolon
  # theErrorMsg is the error message to display is command is not found, seperate multiple by semicolon
  # theToolTip is the the button tooltip
  num_commands++;
  commands[ num_commands, "button"]   = theButton
  commands[ num_commands, "descr"]    = theDescr
  commands[ num_commands, "precheck"] = thePrecheck
  commands[ num_commands, "command"]  = theCommand
  commands[ num_commands, "err_msg"]  = theErrorMsg
  commands[ num_commands, "tool_tip"] = theToolTip
}

function WrtCmd(dscr, chk, cmd, msg, f, out, prg, prg2) {
  if ( chk == "" || ! system( chk) ) {
    prg = substr(cmd " ", 1, index( cmd " "," ")-1)
    prg2 = substr(cmd "|", 1, index( cmd "|","|")-1)
    out = "<strong>" dscr " (from " prg2 ")</strong><br><pre>"
    #cmd = cmd " 2>&1 "
    cmd = cmd " 2>&1 | tr -cd '\11\12[:print:]' "
    #out = out "<!-- FS=" FS "-->"
    #out = out "<!-- chk=" chk "-->"
    #out = out "<!-- cmd=" cmd "-->"
    if (system("command -v " prg " >/dev/null 2>&1")==0) {
      # trim non-printable chars
      while ( ( cmd | getline f ) > 0) {
        out = out f "<br>"
      }
      close(cmd)
    } else {
      out = out dscr " not available.  The command '" prg "' was not found on your system.  You may need to install it.<br>" msg
    }
    out = out "</pre><br>"
  }
  return out
}

function runcmd(btnstr, prechkstr, cmdstr, descr, err_txt, n, i, theHTML, cmdlist, descrlist, errlist) {
  theHTML = "<fieldset style=\"margin-top:10px;\"><legend>&nbsp<strong>" btnstr "</strong>&nbsp</legend><pre>"
  n=split(cmdstr, cmdlist, ";")
  split(prechkstr, prechklist, ";")
  split(descr, descrlist, ";")
  split(err_txt, errlist, ";")
  for (i=1;i<=n;i++) {
    theHTML = theHTML WrtCmd( descrlist[i], prechklist[i], cmdlist[i], errlist[i])
  }
  theHTML = theHTML "</pre></fieldset>"
  return theHTML
}

function CGI_setup( uri, version, i) {
  delete GETARG
  delete MENU
  delete PARAM
  GETARG["Status"] = ARGV[1]
  GETARG["Method"] = ARGV[2]
  GETARG["URI"] = ARGV[3];
  i = index(ARGV[3], "?")
  if (i > 0) { # is there a "?" indicating a CGI request?
    split(substr(ARGV[3], 1, i-1), MENU, "[/:]")
    split(substr(ARGV[3], i+1), PARAM, "&")
    for (i in PARAM) {
      j = index(PARAM[i], "=")
      GETARG[substr(PARAM[i], 1, j-1)] = substr(PARAM[i], j+1)
    }
  } else { # there is no "?", no need for splitting PARAMs
    split(ARGV[3], MENU, "[/:]")
  }
}
