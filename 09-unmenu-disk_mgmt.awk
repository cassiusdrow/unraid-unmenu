BEGIN {
#ADD_ON_URL=disk_management
#ADD_ON_MENU=Disk Management
#ADD_ON_STATUS=YES
#ADD_ON_TYPE=awk
#ADD_ON_OPTIONS=-f unmenu.base.lib.awk -f utility.lib.awk
#ADD_ON_VERSION 1.0 - Joe L.
#ADD_ON_VERSION 1.1 - improved ability to kill processes using disk being un-mounted. Joe L.
#ADD_ON_VERSION 1.2 - print reiserfsck commands for rebuild-tree (if needed) to screen. Joe L.
#ADD_ON_VERSION 1.3 - print more of smartctl output on long/short test requests Joe L.
#ADD_ON_VERSION 1.4 - use spinup/spindown commands now available in 4.5 unRAID Joe L.
#ADD_ON_VERSION 1.5 - added call to srand() to seed random number generator used when spinning up disks not assigned to the array.
#UNMENU_RELEASE $Revision$ $Date$

   GetConfigValues(ScriptDirectory "/" ConfigFile, "");
   GetConfigValues(ScriptDirectory "/" LocalConfigFile, "");

   # If you like geek style 1024 byte sizes, rather than marketing 1000 byte sizes, then set this to 1024
   # in the unmenu.conf file
   OneThousand = CONFIG["OneThousand"] ? CONFIG["OneThousand"] : 1000
   amp="AMP3RS4ND"

   #-----------------
   # Initializations 
   #-----------------
   CGI_setup();

   # Warning temperature ranges for hard disks are set here. Main screen disk temperature output is color coded.
   # override these default values by setting them in unmenu.conf file
   yellow_temp = CONFIG["yellow_temp"] ? CONFIG["yellow_temp"] : 40
   orange_temp = CONFIG["orange_temp"] ? CONFIG["orange_temp"] : 45
   red_temp    = CONFIG["red_temp"]    ? CONFIG["red_temp"]    : 50

   # Samba File Create and Directory Create masks (by default, the same as unRAID)
   create_mask    = CONFIG["create_mask"]    ? CONFIG["create_mask"]    : "711"
   directory_mask = CONFIG["directory_mask"] ? CONFIG["directory_mask"] :  "711"

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

   GetDiskData()
   for ( i =0; i<numdisks; i++ ) {
     GetDiskFreeSpace( disk_name[i], i);
   }
   close(cmd);
   SetUpDiskMgmtPage( "disk_management" )
   print DiskMgmtPageDoc
}

function SetUpDiskMgmtPage( theMenuVal ) {
  GetMountOptions(ScriptDirectory "/" ConfigFile);
  GetMountOptions(ScriptDirectory "/" LocalConfigFile);

  if ( GETARG["disk_device"] == "" && GETARG["hdparm"] == "HDParm Info" ) {
    DiskCommandOutput = "You must first select a disk before running hdparm on it."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["smart_stats"] == "Smart Status Report" ) {
    DiskCommandOutput = "You must first select a disk before requesting statistics."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["smart_short"] == "Short Smart Test" ) {
    DiskCommandOutput = "You must first select a disk before requesting a short SMART test."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["smart_long"] == "Long Smart Test" ) {
    DiskCommandOutput = "You must first select a disk before requesting a long SMART test."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["spin_up"] == "Spin Up" ) {
    DiskCommandOutput = "You must first select a disk before spinning it up."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["spin_down"] == "Spin Down" ) {
    DiskCommandOutput = "You must first select a disk before spinning it down."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["umount"] == "Un-Mount Drive" ) {
    DiskCommandOutput = "You must first select a disk before un-mounting it."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["fsck"] == "File System Check" ) {
    DiskCommandOutput = "You must first select a disk before checking it."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["fsck_repair"] == "F-S Repair (fix-fixable)" ) {
    DiskCommandOutput = "You must first select a disk before repairing it."
    delete GETARG;
  }
  # if not null,  split the disk_device field into its three component parts. These are in d[1], d[2], d[3]
  # d[1] = linux device (/dev/hdb, etc)
  # d[2] = model/serial
  # d[3] = md device (md1, md2, etc)
  if ( GETARG["disk_device"] != "" ) {
    delete d;
    val = GETARG["disk_device"]
    gsub("%2F","/",val)
    gsub("%7C","|",val)
    split(val,d,"|");
  }
  # user pressed the "HDParm Infobutton"
  if ( GETARG["disk_device"] != "" && GETARG["hdparm"] == "HDParm Info" ) {
    DiskCommandOutput = "<b><u><font size=\"+1\">HDParm Info for " d[1] " " d[2] "</font></u></b><br><pre>"
    cmd="hdparm -I " d[1]
    RS="\n"
    while (( cmd | getline f ) > 0)  {
        DiskCommandOutput = DiskCommandOutput f ORS
    }
    close(cmd);
    DiskCommandOutput = DiskCommandOutput "</pre>"
  }
  # user pressed the "Smart Statistics button"
  if ( GETARG["disk_device"] != "" && GETARG["smart_stats"] == "Smart Status Report" ) {
    SpinUp(d[3])
    DiskCommandOutput = "<b><u><font size=\"+1\">Statistics for " d[1] " " d[2] "</font></u></b><br><pre>"
    cmd="smartctl -a -d ata " d[1]
    DiskCommandOutput = DiskCommandOutput "<b>" cmd "</b>" ORS
    RS="\n"
    while (( cmd | getline f ) > 0)  {
        DiskCommandOutput = DiskCommandOutput f ORS
    }
    close(cmd);
    DiskCommandOutput = DiskCommandOutput "</pre>"
  }
  # user pressed the "Smart Short Test button"
  if ( GETARG["disk_device"] != "" && GETARG["smart_short"] == "Short Smart Test" ) {
    SpinUp(d[3])
    DiskCommandOutput = "Smart Short Test of " d[1] " will take from several minutes to an hour or more.<br><pre>"
    cmd="smartctl -t short -d ata " d[1] " 2>&1"
    RS="\n"
    DiskCommandOutput = DiskCommandOutput "<b>" cmd "</b>" ORS
    while (( cmd | getline f ) > 0)  {
        DiskCommandOutput = DiskCommandOutput f ORS
    }
    close(cmd);
    DiskCommandOutput = DiskCommandOutput "</pre>"
  }
  # user pressed the "Smart Long Test button"
  if ( GETARG["disk_device"] != "" && GETARG["smart_long"] == "Long Smart Test" ) {
    SpinUp(d[3])
    DiskCommandOutput = "Smart Long Test of " d[1] " could take several hours or more.<br>You must disable disk spin-down during this test, otherwise it will abort when the disk is spun down.<pre>"
    cmd="smartctl -t long -d ata " d[1] " 2>&1"
    RS="\n"
    DiskCommandOutput = DiskCommandOutput "<b>" cmd "</b>" ORS
    while (( cmd | getline f ) > 0)  {
        DiskCommandOutput = DiskCommandOutput f ORS
    }
    close(cmd);
    DiskCommandOutput = DiskCommandOutput "</pre>"
  }
  # user pressed the "Spin Down"
  if ( GETARG["disk_device"] != "" && GETARG["spin_down"] == "Spin Down" ) {
    DiskCommandOutput =  d[1] " has been spun down."
    SpinDown(d[1])
  }
  # user pressed the "Spin Up"
  if ( GETARG["disk_device"] != "" && GETARG["spin_up"] == "Spin Up" ) {
    DiskCommandOutput =  d[1] " (" d[3] ") has been spun up."
    SpinUp(d[3])
  }
  if ( GETARG["disk_device"] != "" && GETARG["umount"] == "Un-Mount Drive" ) {
    if ( d[3] ~ "md" ) {
        DiskCommandOutput = StopSamba();
        DiskCommandOutput = DiskCommandOutput " and " UnmountDisks(d[1]);
    } else {
       DiskCommandOutput = "Sorry: Only disks with file systems can be un-mounted."
    }
  }
  if ( GETARG["disk_device"] != "" && GETARG["fsck"] == "File System Check" ) {
    if ( d[3] ~ "md" ) {
        DiskCommandOutput = StopSamba() "<br>"
        DiskCommandOutput = DiskCommandOutput UnmountDisks(d[1]) "<br>"
        DiskCommandOutput = DiskCommandOutput FsckDisk(d[1],"")   "<br>"
        DiskCommandOutput = DiskCommandOutput MountDisk(d[1])   "<br>"
        DiskCommandOutput = DiskCommandOutput StartSamba()       "<br>"
    } else {
       DiskCommandOutput = "Sorry: File System Check can only be run on disks with file systems."
    }
  }
  if ( GETARG["disk_device"] != "" && GETARG["fsck_repair"] == "F-S Repair (fix-fixable)" ) {
    if ( d[3] ~ "md" ) {
        DiskCommandOutput = StopSamba() "<br>";
        DiskCommandOutput = DiskCommandOutput UnmountDisks(d[1]) "<br>"
        DiskCommandOutput = DiskCommandOutput FsckDisk(d[1],"--fix-fixable")   "<br>"
        DiskCommandOutput = DiskCommandOutput MountDisk(d[1])   "<br>"
        DiskCommandOutput = DiskCommandOutput StartSamba()       "<br>"
    } else {
       DiskCommandOutput = "Sorry: File System Repair can only be run on disks with file systems."
    }
  }
  for (i in PARAM) {
      if ( PARAM[i] ~ "hdparm-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">HDParm Info for /dev/" d[2] "</font></u></b><br><pre>"
          cmd="hdparm -I /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "smart_status-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">SMART status Info for /dev/" d[2] "</font></u></b><br><pre>"
          cmd="smartctl -a -d ata /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "smart_short-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Smart Short Test of /dev/" d[2] " will take from several minutes to an hour or more.<pre>"
          cmd="smartctl -t short -d ata /dev/" d[2] " 2>&1"
          RS="\n"
          DiskCommandOutput = DiskCommandOutput "<b>" cmd "</b><br>" ORS
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          break;
      }
      if ( PARAM[i] ~ "smart_long-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Smart Long Test of " d[2] " could take several hours or more.<pre>"
          cmd="smartctl -t long -d ata /dev/" d[2] " 2>&1"
          RS="\n"
          DiskCommandOutput = DiskCommandOutput "<b>" cmd "</b><br>" ORS
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          break;
      }
      if ( PARAM[i] ~ "spin_up-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Spin-Up " d[2] "<pre>"
          srand() # important to get random numbers 
          # calculate a random block between 1 and the max blocks on the device
          disk_blocks = GetRawDiskBlocks( "/dev/" d[2] )
          skip_blocks = 1 + int( rand() * disk_blocks );

          cmd="dd if=/dev/" d[2] " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
          #DiskCommandOutput = DiskCommandOutput "<br>" cmd
          system(cmd);
          break;
      }
      if ( PARAM[i] ~ "spin_down-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Spin-Down " d[2] "<pre>"
          cmd="/usr/sbin/hdparm -y /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          break;
      }
      if ( PARAM[i] ~ "mkreiserfs-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "mkreiserfs " d[2] "<pre>"
          cmd="mkreiserfs  -q /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          cmd="sfdisk --change-id /dev/" d[2] " 1 83 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          break;
      }
      if ( PARAM[i] ~ "unmount-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">/dev/" d[2] " has been un-mounted.</font></u></b><br><pre>"
          cmd="umount /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          mountpoint= "/mnt/disk/" d[2]
          system("rmdir " mountpoint " 2>/dev/null")
          system("rmdir /mnt/disk 2>/dev/null")
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "mount-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          if ( d[3] == "ntfs" ) { 
             # if we have ntfs-3g, use it.
             if (system("test -f /bin/ntfs-3g")==0) {
                 d[3] = "ntfs-3g" 
             } else {
                # load the old read-only driver, if it is not already loaded into memory.
                 system("lsmod | grep 'ntfs' >/dev/null 2>&1 || modprobe ntfs");
             }
          }
          if ( d[3] == "hfsplus" ) { 
             system("lsmod | grep 'hfsplus' >/dev/null 2>&1 || modprobe hfsplus");
          }
          
          system("mkdir /mnt/disk")
          mountpoint= "/mnt/disk/" d[2]
          system("mkdir " mountpoint )
          system("hdparm -S242 /dev/" substr(d[2],1,3) " >/dev/null")


          if ( d[3] in MOUNT_OPTIONS) {
             MountOptions = MOUNT_OPTIONS[d[3]]
          } else {
              if ( "other" in MOUNT_OPTIONS ) {
                 MountOptions = MOUNT_OPTIONS["other"] " -t " d[3]
              } else {
                 MountOptions = "-r -t " d[3]
              }
          }

          cmd="mount " MountOptions " /dev/" d[2] " " mountpoint " 2>&1"
          DiskCommandOutput = "<b><u><font size=\"+1\">/dev/" d[2] " mounted on " mountpoint "</font></u></b><br>"
          DiskCommandOutput = DiskCommandOutput "Using command: <b>" cmd "</b><br><pre>"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "readonly-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          mountpoint= "/mnt/disk/" d[2]
          MountOptions = "-o remount,ro"
          cmd="mount " MountOptions " " mountpoint " 2>&1"
          DiskCommandOutput = "<b><u><font size=\"+1\">/dev/" d[2] " re-mounted as read-only on " mountpoint "</font></u></b><br>"
          DiskCommandOutput = DiskCommandOutput "Using command: <b>" cmd "</b><br><pre>"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "writable-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          mountpoint= "/mnt/disk/" d[2]
          MountOptions = "-o remount,rw"
          cmd="mount " MountOptions " " mountpoint " 2>&1"
          DiskCommandOutput = "<b><u><font size=\"+1\">/dev/" d[2] " re-mounted as writable on " mountpoint "</font></u></b><br>"
          DiskCommandOutput = DiskCommandOutput "Using command: <b>" cmd "</b><br><pre>"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "unshare-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">Share of /dev/" d[2] " stopped.</font></u></b><br><pre>"
          # Name of samba config file has changed as of unRAID 4.5-beta3
          if (system("test -f /etc/samba/smb-shares.conf")==0) {
            sharefile="/etc/samba/smb-shares.conf"
          } else {
            sharefile="/etc/samba/smb.shares"
          }
          old_sharefile = sharefile "_old"
          RS="\n"
          share_exists="n"
          # check to ensure share does exist
          while (( getline line < sharefile ) > 0 ) {
              if ( line ~ "\\[" d[2] "\\]" ) {
                 share_exists="y"
              }
          }
          close(sharefile)
          OFS_OLD = OFS
          OFS = "\n"
          if ( share_exists == "y" ) {
             # Copy the smb.shares file to a temp file
             system("cp " sharefile " " old_sharefile)
             # Copy the smb.shares file back, but without the section for this shared folder
              delete_share_line="n"
              while (( getline line < old_sharefile ) > 0 ) {
                  if ( delete_share_line == "y" && line ~ "\\[.*\\]" ) {
                     delete_share_line="n"
                  }
                  if ( line ~ "\\[" d[2] "\\]" ) {
                     delete_share_line="y"
                  }
                  if ( delete_share_line == "n" ) {
                     print line > sharefile
                  }
             }
             close(sharefile)
             close(old_sharefile)
          }
          cmd="smbcontrol smbd reload-config"
          while (( cmd | getline f ) > 0) ;
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          OFS = OFS_OLD
          break;
      }
      if ( PARAM[i] ~ "share-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">Sharing /dev/" d[2] " as " d[2] "</font></u></b><br><pre>"
          # Name of samba config file has changed as of unRAID 4.5-beta3
          if (system("test -f /etc/samba/smb-shares.conf")==0) {
            sharefile="/etc/samba/smb-shares.conf"
          } else {
            sharefile="/etc/samba/smb.shares"
          }
          RS="\n"
          share_exists="n"
          # check to ensure share does not already exist
          while (( getline line < sharefile ) > 0 ) {
              if ( line ~ "\\[" d[2] "\\]" ) {
                 share_exists="y"
              }
          }
          close(sharefile)
          if ( share_exists == "n" ) {
              OFS_OLD = OFS
              OFS = "\n"
              print "[" d[2] "]" >> sharefile
              print "        path = /mnt/disk/" d[2] > sharefile
              print "        read only = No" > sharefile
              print "        force user = root" > sharefile
              print "        map archive = Yes" > sharefile
              print "        map system = Yes" > sharefile
              print "        map hidden = Yes" > sharefile
              print "        create mask = " create_mask > sharefile
              print "        directory mask = " directory_mask > sharefile
              close(sharefile)
              OFS = OFS_OLD
          }
          cmd="smbcontrol smbd reload-config"
          while (( cmd | getline f ) > 0) ;
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
  }


  DiskMgmtPageDoc = "<form method=\"GET\" >"

  DiskTmp = DiskManagement(val)

  DiskMgmtPageDoc = DiskMgmtPageDoc DiskTmp DiskCommandOutput 
  
  DiskMgmtPageDoc = DiskMgmtPageDoc "</form>"
}

function GetMountOptions(cfile) {
   RS="\n"
   while (( getline line < cfile ) > 0 ) {
      if ( line ~ "MOUNT_OPTIONS" ) {
          delete c;
          match( line , /^(MOUNT_OPTIONS)([\t ]*)([^\t =]*)([=\t ]*)(.*)/, c)
          #print c[1,"length"] " " c[2,"length"] " " c[3,"length"] " "  c[4, "length"] " " c[5, "length"] " " line
          if ( c[1,"length"] > 0 && c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               MOUNT_OPTIONS[substr(line, c[3,"start"],c[3,"length"])] = substr(line,c[5,"start"],c[5,"length"])
          }
      }
   }
   close(cfile);
}

function DiskManagement(select_value, i, outstr ) {

    outstr = ""
    outstr = outstr "<fieldset style=\"margin-top:10px;\"><legend><strong>Array Disk Management</strong></legend>"
    outstr = outstr "<table width=\"100%\" cellpadding=1 cellspacing=1 border=0>"
    outstr = outstr "<tr>"
    outstr = outstr "<td><u>Device</u>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
    outstr = outstr "<u>Model/Serial</u></td><td><u></u></td>"
    outstr = outstr "</tr>"
    outstr = outstr "<tr><td><select style=\"font-family:courier\" name=\"disk_device\"><option value=\"\"></option>"
    rebuild_tree_str=""
    unmount_drives=""
    remount_drives=""
    for ( i =0; i<numdisks; i++ ) {
        if ( disk_device[i] == "" ) { continue; }
        option_value="/dev/" disk_device[i] "|" disk_id[i] "|" disk_name[i] 
        if ( select_value == option_value ) { 
            is_selected = "selected" 
        } else { 
            is_selected = "" 
        }
        # Check for file system failure flag
        fsck_result_file= "/tmp/reiserfsck_" disk_device[i]
        while (( getline fsline < fsck_result_file ) > 0 ) {
           if ( fsline ~ "has_fix_fixable" && is_selected != "" ) {
              has_fix_fixable = "YES"
           }
           if ( fsline ~ "has_rebuild_tree" ) {
              has_rebuild_tree = "YES"
              rebuild_tree_str = rebuild_tree_str "reiserfsck --rebuild_tree /dev/" disk_name[i] "<br>"
              unmount_drives = unmount_drives "umount /dev/" disk_name[i] "<br>"
              remount_drives = remount_drives "mount /dev/" disk_name[i] " /mnt/disk" i "<br>"
           }
        }
        close(fsck_result_file)
        outstr = outstr "<option value=\"" option_value "\" " is_selected ">"
        outstr = outstr i " " "/dev/" disk_device[i] " " disk_id[i] "</option>" ORS
    }
    outstr = outstr "</select></td>"
    outstr = outstr "<td ><input type=submit name=\"hdparm\" value=\"HDParm Info\"</td>"
    outstr = outstr "<td ><input type=submit name=\"smart_stats\" value=\"Smart Status Report\"</td>"
    outstr = outstr "<td ><input type=submit name=\"smart_short\" value=\"Short Smart Test\"</td>"
    outstr = outstr "<td ><input type=submit name=\"smart_long\" value=\"Long Smart Test\"</td>"
    outstr = outstr "<td width=\"800\">&nbsp;</td>"
    outstr = outstr "</tr><tr><td>&nbsp;</td>"
    outstr = outstr "<td ><input type=submit name=\"spin_up\" value=\"Spin Up\"</td>"
    outstr = outstr "<td ><input type=submit name=\"spin_down\" value=\"Spin Down\"</td>"
    outstr = outstr "<td ><input type=submit name=\"fsck\" value=\"File System Check\"</td>"
    if ( has_fix_fixable == "YES" ) {
      outstr = outstr "<td ><input type=submit name=\"fsck_repair\" value=\"F-S Repair (fix-fixable)\"</td>"
    }
    outstr = outstr "<td width=\"800\">&nbsp;</td>"
    outstr = outstr "</tr>"
    i = numdisks + 1;
    outstr = outstr "<tr><td align=\"left\" colspan=\"99\"><ul><li>Short SMART tests take a few minutes or more to run, "
    outstr = outstr "Long SMART tests can take hours. SMART reports and tests will spin up the drive.<br>"
    outstr = outstr "Long and Short SMART test results will appear in the Smart-Status-Report once they complete.<br>You must disable disk-spin-down during a \"long\" test, otherwise, the test will abort when the disk is spun down.<br><br>"
    outstr = outstr "<li>File System Checks can take from a few minutes to 45 minutes or more in a large file system with lots of files.<br> "
    outstr = outstr "It will appear as if the browser is hung waiting for the web-server to return. "
    outstr = outstr "<b>Be patient, it eventually will.</b><br>File System Check output is also sent to the System Log<br><br>"
    if ( has_fix_fixable == "YES" ) {
      outstr = outstr "<li>The <b>F-S Repair (fix-fixable)</b> (File System Repair) button should only be "
      outstr = outstr "used if a prior <b>File-System-Check</b> reports "
      outstr = outstr "that a file-system  needs repair<br> and that a <b>reiserfsck --fix-fixable</b> is suggested."
    }
    outstr = outstr "</ul>"
    if ( has_rebuild_tree == "YES" ) {
      outstr = outstr "<fieldset>"
      outstr = outstr "<b>One or more of your disks has indicated that a reiserfsck --rebuild-tree is required to fix its file-system."
      outstr = outstr "<br>The commands shown in red below must be entered on the Linux command line.</b><br>"
      outstr = outstr "<font color=\"red\"><b>cd /root<br>samba stop<br>" 
      outstr = outstr unmount_drives rebuild_tree_str remount_drives "/usr/sbin/smbd -D<br>/usr/sbin/nmbd -D</font></b><br><br>"
      outstr = outstr "</fieldset>"
    }
    outstr = outstr "<font color=\"blue\">"
    outstr = outstr "Warning: A file system check will stop SAMBA and unmount the drive, perform the file system "
    outstr = outstr "check, then re-mount the drive and re-start SAMBA.<br>"
    outstr = outstr "<b>Neither Disk or User Shares will be visible on the LAN when SAMBA is stopped</b></font><br>"
    outstr = outstr "</td></tr></table></fieldset>"
    outstr = outstr "<fieldset style=\"margin-top:10px;\">"
    outstr = outstr "<table width=\"100%\" cellpadding=2 cellspacing=2 border=0>"

    GetDiskData()
    bootdrive = ""
    cachedrive = ""
    unassigned_drive = ""
    prev_disk = ""
    for( a = 1; a <= num_partitions; a++ ) {

       if ( substr(device[a],1,2) != "md" && assigned[a] == "" ) {
            if ( unassigned_drive == "" ) {
                unassigned_drive = "<tr><td colspan=10 align=\"left\"><b><u>Drive Partitions - Not In Protected Array</u></b></td></tr>"
                unassigned_drive = unassigned_drive "<tr>"
                unassigned_drive = unassigned_drive "<td width=\"30*\"><u>Model/Serial</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Temp</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Size</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\"><u>Device</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\"><u>Mounted</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5\"><u>File&nbsp;System<u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\"></td>"
                unassigned_drive = unassigned_drive "</tr>"
            }
            fs = GetDiskFileSystem("/dev/" device[a] );
            mp = mounted[a]
            fstype = fs_type[a]
            mm = mount_mode[a]
            GetDiskFreeSpace("/dev/" device[a] , numdisks + 3);
            if ( device[a] !~ /[0-9]/ ) {
                disk_size[ numdisks + 3] = GetRawDiskSize( "/dev/" device[a] )
            }
            if ( prev_disk != model_serial[a] ) {
              if ( prev_disk != "" ) {
                unassigned_drive = unassigned_drive "<tr><td colspan=10><hr></td></tr>"
              }
            }
            unassigned_drive = unassigned_drive "<tr>"
            if ( prev_disk != model_serial[a] ) {
              prev_disk = model_serial[a]
              unassigned_drive = unassigned_drive "<td>" model_serial[a] "</td>"
              temp= GetDiskTemperature( "/dev/" substr(device[a],1,3) );
              unassigned_drive = unassigned_drive "<td align=\"center\">" temp "</td>"
            } else {
              unassigned_drive = unassigned_drive "<td align=right>partition (" CommaFormat(blocks[a]) " blocks):</td><td>&nbsp;</td>"
            }
            unassigned_drive = unassigned_drive "<td align=\"right\">" disk_size[numdisks + 3] "</td>"
            unassigned_drive = unassigned_drive "<td>/dev/" device[a] "</td>"
            unassigned_drive = unassigned_drive "<td>" mp "</td>"
            unassigned_drive = unassigned_drive "<td>" fs "</td>"
            # If this is a partition on a drive.  
            if ( device[a] ~ /[0-9]/  || fs == "vfat" ) {
                # if there is file system on the partition
                if ( fs != "" ) {
                    # if the partition is mounted
                    if ( mp != "" ) {
                        #unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                        if (  device[a] in SHARES ) {
                            # if the partition is shared
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"unshare-"
                            unassigned_drive = unassigned_drive device[a] "\" value=\"Stop Share of /dev/" device[a] "\"</td>"
                            if ( fstype != "" && fstype != "ntfs" ) {
                               if ( mm == "ro" ) {
                                 unassigned_drive = unassigned_drive "</tr><td colspan=1>&nbsp;</td><td colspan=5 align=right>"
                                 unassigned_drive = unassigned_drive "<font color=blue>Drive is currently mounted as read-only</font></td><td ><input type=submit name=\"writable-"
                                 unassigned_drive = unassigned_drive device[a] "\" value=\"Re-Mount as Writable /dev/" device[a] "\"</td>"
                               }
                               if ( mm == "rw" ) {
                                 unassigned_drive = unassigned_drive "</tr><td colspan=1>&nbsp;</td><td colspan=5 align=right>"
                                 unassigned_drive = unassigned_drive "<font color=red><b>Drive is currently mounted as writable</b></font></td><td ><input type=submit name=\"readonly-"
                                 unassigned_drive = unassigned_drive device[a] "\" value=\"Re-Mount as Read Only /dev/" device[a] "\"</td>"
                               }
                            }
                        } else {
                            # if the partition is not yet shared
                            if ( mp != "/mnt/cache" ) {
                                unassigned_drive = unassigned_drive "<td ><input type=submit name=\"unmount-"
                                unassigned_drive = unassigned_drive device[a] "\" value=\"Un-Mount /dev/" device[a] "\"</td>"
                                unassigned_drive = unassigned_drive "<td ><input type=submit name=\"share-"
                                unassigned_drive = unassigned_drive device[a] "\" value=\"Share /dev/" device[a] "\"</td>"
                                if ( fstype != "" && fstype != "ntfs" ) {
                                   if ( mm == "ro" ) {
                                     unassigned_drive = unassigned_drive "</tr><td colspan=1>&nbsp;</td><td colspan=5 align=right>"
                                     unassigned_drive = unassigned_drive "<font color=blue>Drive is currently mounted as read-only</font></td><td ><input type=submit name=\"writable-"
                                     unassigned_drive = unassigned_drive device[a] "\" value=\"Re-Mount as Writable /dev/" device[a] "\"</td>"
                                   }
                                   if ( mm == "rw" ) {
                                     unassigned_drive = unassigned_drive "</tr><td colspan=1>&nbsp;</td><td colspan=5 align=right>"
                                     unassigned_drive = unassigned_drive "<font color=red><b>Drive is currently mounted as writable</b></font></td><td ><input type=submit name=\"readonly-"
                                     unassigned_drive = unassigned_drive device[a] "\" value=\"Re-Mount as Read Only /dev/" device[a] "\"</td>"
                                   }
                                }
                            } else {
                                unassigned_drive = unassigned_drive "<td width=\"15%\">unRAID Cache Drive</td>"
                                unassigned_drive = unassigned_drive "<td width=\"15%\"></td>"
                            }
                        }
                    } else {
                        if ( fs == "ntfs" || fs == "reiserfs" || fs == "ext2" || fs == "vfat" || fs == "ext3" || fs == "hfsplus" ) {
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"mount-"
                            unassigned_drive = unassigned_drive device[a] "-" fs "\" value=\"Mount /dev/" device[a] "\"</td>"
                            unassigned_drive = unassigned_drive "<td width=\"5*\"></td>"
                        } else {
                            unassigned_drive = unassigned_drive "<td width=\"15%\"></td>"
                            unassigned_drive = unassigned_drive "<td width=\"15%\"></td>"
                        }
                    }
                } else {
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"mkreiserfs-"
                    unassigned_drive = unassigned_drive device[a] "-" fs "\" value=\"Create reiserfs on /dev/" device[a] "\"</td>"
                    unassigned_drive = unassigned_drive "<td width=\"5*\"></td>"
                }
            # If this is the raw drive, and not a partition.  
            } else {
                # SMART features not available on USB devices
                if ( model_serial[a] ~ /^usb-/ ) {
                    unassigned_drive = unassigned_drive "<td align=\"left\" width=\"30%\" colspan=\"6\"></td>"
                    #unassigned_drive = unassigned_drive "<input type=submit name=\"hdparm-"
                    #unassigned_drive = unassigned_drive device[a] "\" value=\"HDParm (" device[a] ")\"</td>"
                } else {
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"hdparm-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"HDParm (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_status-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Smart Status (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                    unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_short-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Short Smart Test (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_long-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Long Smart Test (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                    unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"spin_up-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Spin Up (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"spin_down-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Spin Down (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                }
            }
            unassigned_drive = unassigned_drive "</tr>"
       }
    }
    outrows=""
    outrows = outrows "<td><u>Status</u></td><td><u>Device</u></td><td><u>Model/Serial</u></td>"
    outrows = outrows "<td align=\"center\" ><u>Temp</u></td><td width=\"50%\"><u>File System<u></td>"
    outstr = outstr unassigned_drive

    outstr = outstr "</table></fieldset>"
    return outstr
}
function GetDiskFileSystem(theDisk , thePartition, file_system, a, s) {
    # get the file system of the specified partition
    cmd = "vol_id " theDisk thePartition " 2>/dev/null"
#print cmd
    file_system=""
    RS="\n"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ "ID_FS_TYPE" ) {
            delete s;
            split(a,s,"=");
            file_system=s[2]
        }
    }
    close(cmd);
    return file_system
}

function GetMountPoint( theDisk , mount_point, a, s ) {
    mount_point=""
    RS="\n"
    cmd = "mount"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ theDisk ) {
            delete s;
            split(a,s," ");
            mount_point=s[3]
        }
    }
    close(cmd);
    return mount_point
}

function GetRawDiskSize( theDisk, partition, a, s) {
    d_size = ""
    cmd = "fdisk -l " theDisk " 2>/dev/null"
    RS="\n"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ theDisk ) {
            delete s;
            split(a,s," ");
            d_size=s[3] s[4]
            break;
        }
    }
    close(cmd);
    sub("B,","",d_size)
    return d_size
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
function GetDiskFreeSpace(theDisk, theArrayIndex, a) {
    RS="\n"
    theDisk = theDisk " " # append a space to the disk name so we do not mistake md10 for md1
    found_flag="n"
    
    cmd="df --block-size=" OneThousand
    while (( cmd | getline a) > 0 ) {
        #one user reported his "df" returned /dev/md/3 instead of /dev/md3.  this fixes the name
        gsub("/dev/md/","/dev/md", a)
        if ( a ~ theDisk && theArrayIndex > 0 ) {
            found_flag="y"
            delete free;
            split(a,free," ");
            disk_size[theArrayIndex]=human_readable_number(free[2])
            disk_used[theArrayIndex]=human_readable_number(free[3])
            disk_avail[theArrayIndex]=human_readable_number(free[4])
            disk_pctuse[theArrayIndex]=free[5]
            disk_mounted[theArrayIndex]=free[6]
            total_disk_size +=free[2]
            total_disk_used +=free[3]
            total_disk_avail +=free[4]
        }
    }
    if ( found_flag == "n" ) {
        disk_size[theArrayIndex]="";
        disk_used[theArrayIndex]="";
        disk_avail[theArrayIndex]="";
        disk_pctuse[theArrayIndex]="";
        disk_mounted[theArrayIndex]="";
    }
    if ( theDisk == "total " ) {
        disk_size[theArrayIndex]=human_readable_number(total_disk_size)
        disk_used[theArrayIndex]=human_readable_number(total_disk_used)
        disk_avail[theArrayIndex]=human_readable_number(total_disk_avail)
        if ( total_disk_size > 0 ) {
            total_pct_used = int( ( total_disk_used * 100 ) / total_disk_size) "%";
        }
        disk_pctuse[theArrayIndex]=total_pct_used;
        disk_mounted[theArrayIndex]="";
    }
    close(cmd)
}
function GetDiskTemperature(theDisk, the_temp, cmd, a, t, is_sleeping) {

    if ( theDisk == "/dev/" ) {
       return "";
    }
    the_temp="*"
    is_sleeping = "n"
    cmd = "hdparm -C " theDisk " 2>/dev/null" 
    while ((cmd | getline a) > 0 ) {
    if ( a ~ "standby" ) {
        is_sleeping = "y"
    }
    }
    close(cmd);
    if ( is_sleeping == "n" ) {
        cmd = "smartctl -d ata -A " theDisk "| grep -i temperature" 
        while ((cmd | getline a) > 0 ) {
            delete t;
            split(a,t," ")
            the_temp = t[10] "&deg;C"
            t[10] = t[10] + 0 # coerce to a number
            yellow_temp = yellow_temp + 0
            orange_temp = orange_temp + 0
            red_temp = red_temp + 0
            if ( t[10] >= yellow_temp && t[10] < orange_temp ) {
                the_temp = "<div style=\"background-color:yellow;\">" the_temp "</div>"
            }
            if ( t[10] >= orange_temp && t[10] < red_temp ) {
                the_temp = "<div style=\"background-color:orange;\">" the_temp "</div>"
            }
            if ( t[10] >= red_temp ) {
                the_temp = "<div style=\"background-color:red;\">" the_temp "</div>"
            }
        }
        close(cmd);
    }
    return the_temp
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
function CCGI_setup( uri, version, i, j) {
  delete GETARG;         delete MENU;        delete PARAM

  gsub("+", " ", ARGV[3])
  gsub("%24", "$", ARGV[3])
  gsub("%2F", "/", ARGV[3])
  gsub("%28", "(", ARGV[3])
  gsub("%29", ")", ARGV[3])
  gsub("%21", "!", ARGV[3])
  gsub("%2B", "+", ARGV[3])
  gsub("%5C", "\\", ARGV[3])
  n=gsub("%A0", amp "nbsp;", ARGV[3])

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
  if ( 1== 1 || DebugMode == "yes" ) { 
    for ( i in MENU ) {
        print "MENU[" i "] '" MENU[i] "'<br>"
    }
    for ( i in GETARG ) {
        print "GETARG[" i "] '" GETARG[i] "'<br>"
    }
    for ( i in PARAM ) {
        print "PARAM[" i "] '" PARAM[i] "'<br>"
    }
  }
}
function StopSamba( cmd) {
   system("killall smbd nmbd")
   return "Samba Stopped"
}
function StartSamba( cmd) {
    system("/usr/sbin/smbd -D")
    system("/usr/sbin/nmbd -D")
    return "Samba Started"
}

function  SpinUp( disk, cmd, f) {
    # Spin Up drives
    # loop through the drives spinning them up
    # by reading a single "random" block from each disk in turn.  
    srand() # important to get random numbers when unmenu is re-started.
    for ( i =0; i<numdisks; i++ ) {
#print disk_name[i] ORS
        if ( disk_name[i] == disk ) {
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

function SpinDown( disk, cmd, i, f) {
    # Spin Down the drives
    for ( i =0; i<numdisks; i++ ) {
        if ( "/dev/" disk_device[i] == disk ) {
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
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
    #    print cmd "<br>"
        delete ppp;
        while (( cmd | getline f ) > 0) {
          split(f,ppp," ")
          for (ii in ppp) {
            pids[pp++] = ppp[ii];
          }
        }
        close(cmd);
    }
    }
    cmd="fuser -cu /mnt/user 2>/dev/null"
    delete ppp;
    while (( cmd | getline f ) > 0) {
          split(f,ppp," ")
          for (ii in ppp) {
            pids[pp++] = ppp[ii];
          }
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "killing " pids[i] "<br>"
        system("kill -TERM " pids[i] )
    }
    # Second try, kill any processes still running on the disk(s) to be unmounted
    delete pids;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        delete ppp;
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
        #print cmd "<br>"
        while (( cmd | getline f ) > 0) {
          split(f,ppp," ")
          for (ii in ppp) {
            pids[pp++] = ppp[ii];
          }
        }
        close(cmd);
    }
    }
    cmd="fuser -cu /mnt/user 2>/dev/null"
    delete ppp;
    while (( cmd | getline f ) > 0) {
          split(f,ppp," ")
          for (ii in ppp) {
            pids[pp++] = ppp[ii];
          }
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "2killing " pids[i] "<br>"
        system("kill -TERM " pids[i] )
    }

    # third try, kill off any remainders with kill -9
    delete pids;
    delete ppp;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
        #print cmd
        while (( cmd | getline f ) > 0) {
          split(f,ppp," ")
          for (ii in ppp) {
            pids[pp++] = ppp[ii];
          }
        }
        close(cmd);
    }
    }
    cmd="fuser -cu /mnt/user 2>/dev/null"
    delete ppp;
    while (( cmd | getline f ) > 0) {
          split(f,ppp," ")
          for (ii in ppp) {
            pids[pp++] = ppp[ii];
          }
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "3killing " pids[i] "<br>"
        system("kill -KILL " pids[i] )
    }
    system("sleep 3");
    
    # unmount the drives
    for ( i =0; i<numdisks; i++ ) {
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        disk_unmounted[i] = disk_mounted[i]
        cmd="umount /dev/" disk_name[i]
        unmount_out = unmount_out "/dev/" disk_name[i] " Unmounted<br>"
        #print cmd
        while (( cmd | getline f ) > 0) ;
        close(cmd);
    }
   }
   return unmount_out
}

function FsckDisk(disk, fix, cmd) {
    RS="\n"
    fsck_out=""
    for ( i =0; i<numdisks; i++ ) {
    if ( "/dev/" disk_device[i] == disk || disk == "All Disks" ) {
            fsck_out="<b>Checking /dev/" disk_name[i] " (/dev/" disk_device[i] ")</b><br>"
        if ( disk_name[i] == "" ) {
            fs = ""
        } else {
            fs = GetDiskFileSystem("/dev/" disk_device[i], "1")
        }
        #print "filesystem type:" fs " for disk  /dev/" disk_device[i]
        if ( fs == "reiserfs" ) {
            if ( fix != "" ) {
                cmd="reiserfsck " fix " -q -y /dev/" disk_name[i] " 2>&1| tee -a /var/log/syslog"
            } else {
                cmd="reiserfsck -q -y /dev/" disk_name[i] " 2>&1| tee -a /var/log/syslog"
            }
            #print cmd
            fsck_result_file= "/tmp/reiserfsck_" disk_device[i]
            system("rm " fsck_result_file " >/dev/null 2>&1")
            has_fix_fixable = "NO"
            has_rebuild_tree = "NO"
            while (( cmd | getline f ) > 0) {
                if ( fix == "" ) {
                 if ( f ~ "fix-fixable" ) {
                   has_fix_fixable = "YES"
                   print "has_fix_fixable" > fsck_result_file
                 }
                 if ( f ~ "with rebuild-tree" ) {
                   print "has_rebuild_tree" > fsck_result_file
                   has_rebuild_tree = "YES"
                 }
                }
                fsck_out = fsck_out f "<br>"
            }
	    if ( has_fix_fixable == "YES" || has_rebuild_tree == "YES" ) {
               close(fsck_result_file)
            }
            close(cmd);
        } else {
            if ( fs == "" ) {
                fsck_out = fsck_out " Sorry, no file system detected on /dev/" disk_name[i] "<br>"
            } else {
                fsck_out = fsck_out " Sorry, not coded to handle " fs " on /dev/" disk_name[i] "<br>"
            }
        }
    }
   }
   return fsck_out
}

function MountDisk(disk) {
    RS="\n"
    mount_out=""
    # mount the drive
    for ( i =0; i<numdisks; i++ ) {
    if ( "/dev/" disk_device[i] == disk || disk == "All Disks" ) {
        fs = GetDiskFileSystem("/dev/" disk_device[i], "1")
        mount_out = mount_out "/dev/" disk_name[i] " mounted on " disk_unmounted[i] "<br>"
        cmd="mount -t reiserfs -o noatime,nodiratime /dev/" disk_name[i] " " disk_unmounted[i] " 2>&1"
#        print cmd
        while (( cmd | getline f ) > 0) ;
        close(cmd);
    }
   }
   return mount_out
}

function StopArray() {
    # stop the unRAID array
    cmd="/root/mdcmd stop"
    #print cmd
    while (( cmd | getline f ) > 0) ;
    close(cmd);
}
