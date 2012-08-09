BEGIN {
#ADD_ON_URL=array_management
#ADD_ON_MENU=Array Management
#ADD_ON_STATUS=YES
#ADD_ON_TYPE=awk
#ADD_ON_OPTIONS=-f unmenu.base.lib.awk -f utility.lib.awk
#ADD_ON_VERSION 1.1 - Joe L.
#ADD_ON_VERSION 1.2 - modified spin-up/spin down to use commands available as of 4.5 unRAID  - Joe L.
#ADD_ON_VERSION 1.2.1 - modified spin-up/spin down to use commands available as of 4.5 unRAID  - Joe L.
#ADD_ON_VERSION 1.2.3 - fixed "Stop" button - Joe L.
#ADD_ON_VERSION 1.2.4 - fixed path to md.c to detect NOCORRECT mode
#UNMENU_RELEASE $Revision$ $Date$

   GetConfigValues(ScriptDirectory "/" ConfigFile, "");
   GetConfigValues(ScriptDirectory "/" LocalConfigFile, "");

   amp="AMP3RS4ND"

   #-----------------
   # Initializations 
   #-----------------
   CGI_setup();

   GetArrayStatus();

   if ( has_spinup == "" ) {
     has_spinup="false"
     while (("/root/mdcmd status|strings" | getline a) > 0 ) {
       if ( a ~ "rdevSpinupGroup" ) { 
           has_spinup="true"; 
           break;
       }
     }
     close("/root/mdcmd status|strings")
   }

   SetUpArrayMgmtPage()
   print ArrayMgmtPageDoc
}

function SetUpArrayMgmtPage() {
  # user pressed the "cancel parity check button"
  if ( array_state == "STARTED" && GETARG["nocheck_parity"] == "Cancel Parity Check" ) {
    cmd="/root/mdcmd nocheck"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
    delete GETARG;
    # wait a tiny bit for unRAID to STOP the parity check so we can report on it in the status box
    system("sleep 5");
    ReloadPage();
  }
  # user pressed the "parity verify button"
  if ( array_state == "STARTED" && GETARG["verify_parity"] == "Verify Parity but do NOT Correct it." ) {
    cmd="/root/mdcmd check NOCORRECT"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
    delete GETARG;
    # wait a tiny bit for unRAID to start the parity check so we can report on it in the status box
    system("sleep 5");
    ReloadPage();
  }
  # user pressed the "parity check button"
  if ( array_state == "STARTED" && GETARG["check_parity"] == "Check and Correct Parity" ) {
    cmd="/root/mdcmd check"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
    delete GETARG;
    # wait a tiny bit for unRAID to start the parity check so we can report on it in the status box
    system("sleep 5");
    ReloadPage();
  }
  # user pressed the "stop samba button"
  if ( array_state == "STARTED" && GETARG["stop_samba"] == "Stop Samba" ) {
    StopSamba()
    delete GETARG;
  }
  # user pressed the "start samba button"
  if ( array_state == "STARTED" && GETARG["start_samba"] == "Start Samba" ) {
    StartSamba()
    delete GETARG;
  }
  # user pressed the "Spin Up Drives button"
  if ( array_state == "STARTED" && GETARG["spin_up"] == "Spin Up Drives" ) {
    SpinUp("All Disks")
    delete GETARG;
  }
  # user pressed the "Spin Down Drives button"
  if ( array_state == "STARTED" && GETARG["spin_down"] == "Spin Down Drives" ) {
    SpinDown("All Disks")
    delete GETARG;
  }
  # user pressed the "reload samba button"
  if ( array_state == "STARTED" && GETARG["reload_samba"] == "Reload Samba Config" ) {
    cmd="smbcontrol smbd reload-config"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
    delete GETARG;
  }
  # user pressed the "Stop server button", need to stop samba, unmount drives, then stop array.
  if ( array_state == "STARTED" && GETARG["stop_array"] == "Stop Array" ) {
    SpinUp("All Disks")
    system("sync")
    StopSamba();
    system("killall shfs");
    x=UnmountDisks("All Disks");
#    print x

    StopArray();
    system("mv /etc/samba/smb-shares.conf /etc/samba/smb-shares.old_conf >/dev/null 2>&1");
    StartSamba();
    ReloadPage();
    delete GETARG;
  }

  #GetArrayStatus()
  samba_active=IsSambaStarted();
  has_nocorrect=HasParity_NOCORRECT();

  ArrayMgmtPageDoc = ""
  ArrayMgmtPageDoc = ArrayMgmtPageDoc "<form method=\"GET\" ><table width=\"100%\">"
    
  # show appropriate buttons based on current status.
  if ( array_state == "STARTED" ) {
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td>&nbsp;</td><td>&nbsp;</td></tr>" \
    "<tr><td width=\"10%\"><input type=submit name=\"stop_array\" value=\"Stop Array\"</td><td align=\"left\">\
    Stop the unRAID array.  Note: you must use the Lime-Technology supplied unRAID management web-page to Start the array.</td></tr>" \
        "<tr><td><hr></td><td><hr></td></tr>"
    if ( resync_finish != "" && resync_finish != "0" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"nocheck_parity\" value=\"Cancel Parity Check\"</td><td align=\"left\">\
        Cancel the Parity Check of the unRAID array</td></tr><tr><td><hr></td><td><hr></td></tr>"
    } else {
        pc_ok = ParityCheckPossible( array_state ) 
        if ( pc_ok != "" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><button type=\"button\" disabled=\"disabled\">Parity Check</button></td><td align=\"left\">\
        Parity check not possible with missing or disabled disks.</td></tr><tr><td><hr></td><td><hr></td></tr>"
        } else {
        if ( has_nocorrect == "yes" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "<tr><td valign=\"top\" width=\"10%\"><input type=submit name=\"verify_parity\" "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "value=\"Verify Parity but do NOT Correct it.\"</td> "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "<td valign=\"top\" align=\"left\"> "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "Initiate a Parity Verify of the unRAID array but do not correct it if an error is found.  "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "This is a new ability added to unRAID as of 4.5beta3."
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "<br><br>In some circumstances, we suspect a specific data disk to be wrong, and parity to be right.  "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "Other times, we suspect disks are fine,"
        ArrayMgmtPageDoc = ArrayMgmtPageDoc " but memory or motherboard errors cause parity calculations to compute inconsistently"
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "<br><br>This verify allows you to investigate these issues before possibly overwriting correct parity "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "with incorrectly computed values.   "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc " This is the best choice to use when you suspect memory, cabling, or "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "motherboard issues are calusing random data errors when parity is calculated."
        ArrayMgmtPageDoc = ArrayMgmtPageDoc " <br><br>As of the 4.5.3 version of unRAID, when this <b>Verify Parity</b> is run, "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "there is no indication of the specific disk addresses with the "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "errors written to the syslog. This is expected to change in some future release. "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "At that point in the future, by looking at the errors in the syslog, "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "we will know exactly which bytes in parity need updating.<br><br>"
        ArrayMgmtPageDoc = ArrayMgmtPageDoc " As of 4.5.3 version of unRAID, all you will see is the parity error count reported by the web-interface"
        ArrayMgmtPageDoc = ArrayMgmtPageDoc " increasing as errors are detected. Also, "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "the Lime-Technology management interface still says parity check when this is run, and not verify... "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "<br><br>If an error is detected it will NOT be corrected.  If an actual error, any subsequent Verify "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc " should find the same parity descrepency again and again until corrected."
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "</td></tr><tr><td><hr></td><td><hr></td></tr>"
        }

        ArrayMgmtPageDoc = ArrayMgmtPageDoc "<tr><td valign=\"top\" width=\"10%\"><input type=submit name=\"check_parity\" "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "value=\"Check and Correct Parity\"</td><td valign=\"top\" align=\"left\">"
        ArrayMgmtPageDoc = ArrayMgmtPageDoc " Initiate a Parity Check of the unRAID array, "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "if the parity drive seems to be incorrect, update it.  "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "<br>This process assumes your data is correct and parity is not "
        ArrayMgmtPageDoc = ArrayMgmtPageDoc "whenever an error is detected.</td></tr><tr><td><hr></td><td><hr></td></tr>"
	}
    }
    if ( has_spinup == false ) { 
        read_random="by reading a random block of data from each disk in turn" 
    } else { 
        read_random="" 
    }
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
    "<tr><td width=\"10%\"><input type=submit name=\"spin_up\" value=\"Spin Up Drives\"</td><td align=\"left\">\
    Spin Up All Disk Drives " read_random "</td></tr><tr><td><hr></td><td><hr></td></tr>"
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
    "<tr><td width=\"10%\"><input type=submit name=\"spin_down\" value=\"Spin Down Drives\"</td><td align=\"left\">\
    Spin Down All Disk Drives</td></tr><tr><td><hr></td><td><hr></td></tr>"
    if ( samba_active == "yes" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"stop_samba\" value=\"Stop Samba\"</td><td align=\"left\">\
        Stop Samba Shares</td></tr><tr><td><hr></td><td><hr></td></tr>"
    } else {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"start_samba\" value=\"Start Samba\"</td><td align=\"left\">\
        Start Samba Shares</td></tr><tr><td><hr></td><td><hr></td></tr>"
    }
    if ( samba_active == "yes" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"reload_samba\" value=\"Reload Samba Config\"</td><td align=\"left\">\
        Reload Samba Share Configuration File</td></tr><tr><td><hr></td><td><hr></td></tr>"
    }
  } else if ( array_state == "STOPPED" ) {
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
    "<tr><td width=\"10%\"><input type=button name=\"start_array\" value=\"Start Array\" \
    onclick=\"alert('Sorry: not implimented, use the unRAID supplied management web-page to restart the array');\">\
    </td><td align=\"left\"><b>Unfortunately, it is not possible to start the unRAID array in the unMENU interface. \
     Please use the \"Start\" button on the Lime-Technology supplied  management web-page to restart the array.</td></tr>"
  }
  ArrayMgmtPageDoc = ArrayMgmtPageDoc \
  "</table>" \
  "</form>"
}

function StopSamba( cmd) {
   system("/etc/rc.d/rc.samba stop | logger");
   system("/etc/rc.d/rc.nfsd stop | logger");
   return "Samba Stopped"
}
function StartSamba( cmd) {
   system("/etc/rc.d/rc.samba start | logger");
   system("/etc/rc.d/rc.nfsd start | logger");
   return "Samba Started"
}

function  SpinUp( disk, cmd, f) {
    # Spin Up drives
    # loop through the drives spinning them up by using the spinup command if available or
    # by reading a single "random" block from each /dev/md* device in turn if not.  
    srand() # important to get random numbers when unmenu is re-started.
    for ( i =0; i<numdisks; i++ ) {
#print disk_name[i] ORS
        if ( disk_name[i] == disk || disk == "All Disks" ) {
            if ( has_spinup == "true" ) {
               cmd="/root/mdcmd spinup " i " >/dev/null 2>&1"
            } else {
               # calculate a random block between 1 and the max blocks on the device
               skip_blocks = 1 + int( rand() * disk_size[i] );

               #cmd="dd if=/dev/" disk_device[i] " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
               cmd="dd if=/dev/" disk_name[i] " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
            }
            #print cmd ORS
            system(cmd);
        }
    }
}

function ParityCheckPossible( array_status, ret_val, i, f ) {
    ret_val = ""
    if ( array_status != "STARTED" ) {
	ret_val="Array not started, parity check not possible."
    }
    for ( i =0; i<numdisks; i++ ) {
	if ( disk_status[i] == "DISK_DSBL" || disk_status[i] == "DISK_NP" ) {
           ret_val="One or more disks are disabled or not present, parity check not possible."
	}
    }
    return ret_val
}

function SpinDown( disk, cmd, i, f) {
    # Spin Down the drives
    for ( i =0; i<numdisks; i++ ) {
        if ( "/dev/" disk_device[i] == disk || disk == "All Disks" ) {
            if ( has_spinup == "true" ) {
               cmd="/root/mdcmd spindown " i
            } else {
               cmd="/usr/sbin/hdparm -y /dev/" disk_device[i]
            }
          #    print cmd
            while (( cmd | getline f ) > 0) ;
            close(cmd);
        }
   }
}

function UnmountDisks( disk ,cmd) {
    # kill any processes running on the disk(s) to be unmounted
    unmount_out=""
    delete pids;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
      if ( disk_name[i] != "" ) {
      cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
      while (( cmd | getline f ) > 0) {
          pids[pp++] = f
      }
      close(cmd);
      }
    }
    for ( i=0; i<pp;i++ ) {
        cmd="kill -TERM " pids[i]
        unmount_out = unmount_out cmd "<br>"
        system(cmd)
    }
    delete pids;
    pp=0

    # check for any loop devices holding mounted file systems open to disks
    # un-mount them
    cmd="mount | grep \"loop=/dev/loop[0-9])\"" 

    while (( cmd | getline f ) > 0) {
          delete c;
          unmount_out = unmount_out "Mounted=" f "<br>"

          match( f , /^(.+)( on \/)(.+)( type .*loop=\/dev\/loop[0-9]\))$/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 && c[4,"length"] > 0 ) {
              ucmd = substr(f,c[3,"start"],c[3,"length"])
              ucmd = "umount '/" ucmd "'"
              unmount_out = unmount_out ucmd "<br>"
              system(ucmd)
          }
    }
    

    cmd="fuser -cu /mnt/user /dev/loop* 2>/dev/null"
    while (( cmd | getline f ) > 0) {
        pids[pp++] = f
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "killing " pids[i]
        #system("kill  -0 pids[i] && kill -TERM " pids[i] )
        cmd="kill -TERM " pids[i]
        unmount_out = unmount_out cmd "<br>"
        system(cmd)
    }

    # Second try, kill any processes still running on the disk(s) to be unmounted
    delete pids;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
        #print cmd
        while (( cmd | getline f ) > 0) {
            pids[pp++] = f
        }
        close(cmd);
    }
    cmd="fuser -cu /mnt/user /dev/loop* 2>/dev/null"
    while (( cmd | getline f ) > 0) {
        pids[pp++] = f
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "killing " pids[i]
        #system("kill  -0 pids[i] && kill -TERM " pids[i] )
        cmd="kill -TERM " pids[i]
        unmount_out = unmount_out cmd "<br>"
        system(cmd)
    }

    # third try, kill off any remainders with kill -9
    delete pids;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
        #print cmd
        while (( cmd | getline f ) > 0) {
            pids[pp++] = f
        }
        close(cmd);
    }
    cmd="fuser -cu /mnt/user 2>/dev/null"
    while (( cmd | getline f ) > 0) {
        pids[pp++] = f
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "killing " pids[i]
        #system("kill  -0 pids[i] && kill -KILL " pids[i] )
        cmd="kill -KILL " pids[i]
        unmount_out = unmount_out cmd "<br>"
        system(cmd)
    }

    
    # unmount the drives
    system("umount /mnt/user;rmdir /mnt/user");
    for ( i =0; i<numdisks; i++ ) {
      if ( disk_name[i] != "" ) {
        disk_unmounted[i] = mounted[i]
        cmd="umount /dev/" disk_name[i]
        unmount_out = unmount_out "/dev/" disk_name[i] " Unmounted<br>"
        system(cmd);
        cmd="rmdir /mnt/disk" i
        unmount_out = unmount_out "<br>" cmd
        system(cmd);
     }
   }
   return unmount_out
}

function GetConfigValues(cfile, preface) {
    RS="\n"
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^([^# \t=]+)([\t ]*)(=)([\t ]*)(.+)/, c)
          #print c[1,"length"] " " c[2,"length"] " " c[3,"length"] " "  c[4, "length"] " " c[5, "length"] " " line
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && 
               c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               CONFIG[ preface substr(line,c[1,"start"],c[1,"length"])] = substr(line,c[5,"start"],c[5,"length"])
               if ( DebugMode == "yes" ) { 
                   print "importing from " cfile ": " \
                     "CONFIG[" preface substr(line,c[1,"start"],c[1,"length"]) "] = " substr(line,c[5,"start"],c[5,"length"])
               }
          }
    }
    close(cfile);
}

function IsSambaStarted( cmd) {
    samba_online="no"
    cmd="ps -ef | grep /usr/sbin/smbd | grep -v grep"
    while (( cmd | getline f ) > 0)  {
    if ( f ~ "smbd" ) {
        samba_online="yes"
    }
    }
    close(cmd);
    return samba_online
}

function HasParity_NOCORRECT() {
    has_parity_nocorrect="no"
    cmd="grep NOCORRECT /usr/src/linux*/drivers/md/md.c"
    while (( cmd | getline f ) > 0)  {
      if ( f ~ "NOCORRECT" ) {
        has_parity_nocorrect="yes"
      }
    }
    close(cmd);
    return has_parity_nocorrect
}


function StopArray() {
    # stop the unRAID array
    cmd="/root/mdcmd stop"
    system(cmd);

}

function ReloadPage() {
    js = ""
    js = "<script language=\"JavaScript\">\n"
    js = js "<!--\n"
    js = js "var sURL = unescape(window.location.pathname);\n"
    js = js "var p = sURL.indexOf('?');\n"
    js = js "sURL = sURL.substring(p);\n"
    js = js "\n"
    js = js "setTimeout( \"refresh()\", 2*1000 );\n"
    js = js "\n"
    js = js "function refresh()\n"
    js = js "{\n"
    js = js "    window.location.href = sURL;\n"
    js = js "}\n"
    js = js "//-->\n"
    js = js "</script>\n"
    js = js "\n"
    js = js "<script language=\"JavaScript1.1\">\n"
    js = js "<!--\n"
    js = js " function refresh()\n"
    js = js "{\n"
    js = js "    window.location.replace( sURL );\n"
    js = js "}\n"
    js = js "//-->\n"
    js = js "</script>\n"
    print js
}
