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
#define ADD_ON_HEAD <STYLE type='text/css'>.db {color:red;}</STYLE>
#UNMENU_RELEASE $Revision$ $Date$

  CGI_setup()
  num_commands=0;

  LoadCmds("function", "CPU Info", "", "", "CPU Info" );
  LoadCmds("exec", "Memory Info", "/usr/bin/free -l", "", "Memory Info" );
  LoadCmds("function", "Ethernet Info", "", "", "Information about your network interface");
  LoadCmds("exec", "Ps info", "/usr/bin/ps -eaf", "", "A current Process Listing");
  LoadCmds("exec", "Fuser info", "/usr/bin/fuser -mv /mnt/disk* /mnt/user/* 2>&1","You don't appear to have fuser installed.", "File systems and user-shares in use");
  LoadCmds("exec", "Uptime", "/usr/bin/uptime;/usr/bin/uname -a", "", "Up-time");
  LoadCmds("exec", "Top Processes", "/usr/bin/top -b -n1", "", "Processes using the most system resources");
  LoadCmds("exec", "Open Files", "/usr/bin/lsof", "You don't appear to have lsof installed.", "A list of open files");
  LoadCmds("exec", "Mounted File Systems", "/bin/mount", "", "A list of mounted file systems");
  LoadCmds("exec", "File System Space", "/usr/bin/df", "", "A list of file system usage statistics");
  LoadCmds("exec", "List Devices", "/usr/bin/lsdev", "You don't appear to have lsdev installed", "A listing of the devices on your server");
  LoadCmds("exec", "UPS Status", "/sbin/apcaccess status", "You don't appear to have a UPS monitoring program installed","UPS Status");
  LoadCmds("exec", "PCI Devices", "/sbin/lspci -v", 
          "PCI Utilities can be installed from the <a href=\"package_manager\">unMENU Package Manager.</a>",
          "A listing of the PCI devices on your server");
  LoadCmds("exec", "Loaded Modules", "/sbin/lsmod", "", "Loaded Kernel Modules");

  buttons = ""
  ran_command_flag = "n"
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
      if ( commands[ stg, "type"] == "exec" ) {
         #results = runcmd(tx[2], tx[1], tx[3])
         ran_command_flag = "y"
         results = runcmd( commands[ stg, "command" ], commands[ stg, "button"], commands[ stg, "err_msg"])
      }
    }

    buttons = buttons "<td ><input class=\"sysinfo_button\" type=submit name='option' value='" commands[ stg, "button"] "'"
    if ( commands[stg, "tool_tip" ] != "" ) {
       buttons = buttons " title='"  commands[stg, "tool_tip"] "'"
    }

    # If we defined an error message, we need to determine if the command exists.
    if ( commands[ stg, "err_msg" ] != "" ) {
      cmd_index = index( commands[ stg, "command" ], " ")
      if ( cmd_index == 0 ) {
        file_to_check = commands[ stg, "command" ]
      } else {
        file_to_check = substr( commands[ stg, "command" ], 1, cmd_index )
      }
      if (system("test -f " file_to_check )!=0) {
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

  if ( ran_command_flag == "n" ) {
    results = ProcessSysinfoPage(sysarg)
  }
  
  if (sysarg =="")
    print instructs
  else
    print results


}

function LoadCmds( theType, theButton, theCommand, theErrorMsg, theToolTip ) {
  num_commands++;
  commands[ num_commands, "type"]    = theType
  commands[ num_commands, "button"]  = theButton
  commands[ num_commands, "command"] = theCommand
  commands[ num_commands, "err_msg"] = theErrorMsg
  commands[ num_commands, "tool_tip"] = theToolTip
}

function GetCpuInfo(f) {
    sixtyfourbit = "<b><font color=blue>CPU is 32 Bit Capable.</font> <font color=red>It is NOT 64 Bit capable.</font></b><br><br>"
    cmd = "cat /proc/cpuinfo"
    RS="\n"
    cpuinfo = "<strong>CPU Info (from /proc/cpuinfo)</strong><br><pre>"
    while (( cmd | getline f ) > 0) {
     cpuinfo = cpuinfo f  "<br>"
     if ( f ~ / lm / ) {
         sixtyfourbit = "<b><font color=blue>CPU is 64 Bit Capable.</font><b><br><br>"
     }
    }
    cpuinfo = sixtyfourbit cpuinfo "</pre><br>"
    close(cmd)
    return cpuinfo
}

function GetSensorInfo(f) {
    cmd = "/usr/bin/sensors"
    RS="\n"
    if (system("test -f /usr/bin/sensors")==0) {
      sensorinfo = "<strong>Sensor info (from /usr/bin/sensors)</strong><br><pre>"
      while (( cmd | getline f ) > 0) {
       sensorinfo = sensorinfo f "<br>"
      }
      sensorinfo = sensorinfo "</pre><br>"
      close(cmd)
    } else {
      sensorinfo = "<strong>Sensor info (from /usr/bin/sensors)</strong><br><pre>Sensor info not available. <br>Consider installing the lm-sensors package, if your kernel supports hardware monitoring or you have the proper modules (.ko files) available.</br></pre>"
    }
    return sensorinfo
}

function GetAcpiInfo(f) {
    cmd = "/usr/local/bin/acpitool -c"
    RS="\n"
    acpiinfo = "<strong>ACPI CPU Info (from /usr/local/bin/acpitool)</strong><br><pre>"
    while (( cmd | getline f ) > 0) {
     acpiinfo = acpiinfo f "<br>"
    }
    acpiinfo = acpiinfo "</pre><br>"
    close(cmd)
    return acpiinfo
}

function ProcessSysinfoPage(sysarg) {

  # user pressed the "CPU" button
  if (sysarg == "CPU+Info" ) {
    theHTML = "<fieldset style=\"margin-top:10px;\"><legend><strong>System Info</strong></legend><pre>"
    
    if (system("test -f /usr/local/bin/acpitool")==0) theHTML = theHTML GetAcpiInfo();
    else theHTML = theHTML GetCpuInfo();

    theHTML = theHTML GetSensorInfo();
  }

  # user pressed the "Ethernet" button
  if (sysarg == "Ethernet+Info" ) {
    theHTML = "<fieldset style=\"margin-top:10px;\"><legend><strong>Ethernet info</strong></legend><pre>"
    theHTML = theHTML "<strong>NIC info (from ethtool)</strong><br><pre>"
    cmd = "ethtool eth0"
    while (( cmd | getline f ) > 0) {
     theHTML = theHTML f  "<br>"
    }
    theHTML = theHTML "<br><strong>NIC driver info (from ethtool -i)</strong><pre>"
    cmd = "ethtool -i eth0"
    while (( cmd | getline f ) > 0) {
     theHTML = theHTML f  "<br>"
    }
    theHTML = theHTML "<br><strong>Ethernet config info (from ifconfig)</strong><pre>"
    cmd = "ifconfig eth0"
    while (( cmd | getline f ) > 0) {
     theHTML = theHTML f  "<br>"
    }
  }

  theHTML = theHTML "</pre></fieldset>"
  close(cmd)
  print theHTML
}

function runcmd(cmdstr, descr, err_txt) {
  theHTML = "<fieldset style='margin-top:1px;'><legend><strong>" descr "</strong></legend><pre>"
  split(cmdstr, cmdlist, ";")
  flag = 0
  for (cmd_no in cmdlist) {
    cmd    = cmdlist[cmd_no] " 2>&1"
    proggy = substr(cmd,1,index(cmd," "))
    
    theHTML = theHTML "<strong>(from " cmdlist[cmd_no] ")</strong><pre>"
    if (system("test -f " proggy)==0) {
      while (( cmd | getline f ) > 0) {
        theHTML = theHTML f  "<br>"
      }
      close(cmd)
      flag = 1
    } else {
      theHTML = theHTML "The command '" proggy "' was not found on your system.  You may need to install it.<br>"      
    }
    if (flag == 0  && err_txt != "") 
        theHTML = theHTML err_txt

    theHTML = theHTML "<br>"

  }
  theHTML = theHTML "</fieldset>"
  return theHTML
}

function CGI_setup(   uri, version, i) {
  delete GETARG;         delete MENU;        delete PARAM
  GETARG["Status"] = ARGV[1]; GETARG["Method"] = ARGV[2]; GETARG["URI"] = ARGV[3]; 
  i = index(ARGV[3], "?")
  if (i > 0) {             # is there a "?" indicating a CGI request?
    split(substr(ARGV[3], 1, i-1), MENU, "[/:]")
    split(substr(ARGV[3], i+1), PARAM, "&")
    for (i in PARAM) {
      j = index(PARAM[i], "=")
      GETARG[substr(PARAM[i], 1, j-1)] = substr(PARAM[i], j+1)
    }
  } else {             # there is no "?", no need for splitting PARAMs
    split(ARGV[3], MENU, "[/:]")
  }
}
