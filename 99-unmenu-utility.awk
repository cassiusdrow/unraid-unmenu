BEGIN {
#define ADD_ON_URL     utility
#define ADD_ON_MENU
#define ADD_ON_STATUS  NO
#define ADD_ON_TYPE    awk
#define ADD_ON_VERSION 1.0 - contributed by bjp999

  CGI_setup()
  cmd  = GETARG["cmd"]
  dev  = GETARG["dev"]
  disk = GETARG["disk"]
  #print "<p> cmd='" cmd "'</p>"
  #print "<p> parm1='" parm1 "'</p>"
  #print "<p> parm2='" parm2 "'</p>"
  #print "<p> parm3='" parm3 "'</p>"

  if(cmd == "smartctl") { 
     if(GETARG["file"] == "")
        print RunCommand(sprintf("smartctl -a -d ata /dev/%s", dev), disk);
     else
        print RunCommand("fromdos<" GETARG["file"], GETARG["file"], "smartctl " GETARG["file"]);
  }
  else if (cmd == "hdparm") {
     print RunCommand(sprintf("hdparm -I /dev/%s", dev), disk);
  }
  else if (cmd == "test") {
     RunTest();
  }
  else if(cmd == "spinup") { 
     disk_blocks = GetRawDiskBlocks( "/dev/" dev )
     skip_blocks = 1 + int( rand() * disk_blocks );
     cmd="dd if=/dev/" dev " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
     system(cmd);
     print "<p>Done</p>"
  }
  else if (cmd == "spindown") {
     cmd="/usr/sbin/hdparm -y /dev/" dev " >/dev/null 2>&1"
     system(cmd);
     print "<p>Done</p>"
  }
  else if (cmd == "syslogx") {
     syslog=GETARG["syslog"]
     if (syslog=="") {
        syslog="/var/log/syslog"
     }
     FilterSyslogx(syslog,dev,disk)
     print "<p>Done</p>"
  }
  else if (cmd == "syslogRobJ") {
     syslog=GETARG["syslog"]
     if (syslog=="") {
        syslog="/var/log/syslog"
     }
     FilterSyslogRobJ(syslog,dev,disk)
     print "<p>Done</p>"
  }
  else if (cmd == "smarthistory") {
     cmd = "cd /boot/smarthistory; ./smarthistory -wake ON -output HTML -graph IMAGE -report ALL -devices /dev/" dev;
     print "<p> </p><strong>" cmd "   (" disk ")</strong><br><br>"

     while (( cmd | getline f ) > 0) {
        print f
     }

     close(cmd);
  }

  #print RunCommand(cmdarg, parm1arg);
}

function RunCommand(cmd, disk, output) {
    RS="\n"
    if(output == "")
       output = "<p> </p><strong>" cmd "   (" disk ")</strong><br><pre>"
    else
       output = "<p> </p><strong>" output "</strong><br><pre>"


    while (( cmd | getline f ) > 0) {
     output = output f  "<br>"
    }
    output = output "</pre><br>"
    close(cmd)
    return output
}

function FilterSyslogRobJ(syslog, dev, disk)
{
   if ( substr(dev,1,2) == "hd" ) {   # IDE devices
      if ( disk == "parity" )
         cmd = "|md0: [^p]"
      else
         cmd = "|md" substr(disk, 5) "[^0-9]"
   }
   else {   # SATA or other SCSI devices
      #Step 1 - Find the ata#s
      cmd = "cat " syslog "|grep '\\[" dev "\\]'"
      #p(cmd)
      cmd|getline f
      close(cmd)
      split(f,d);
      t=d[7];
      delete d;
      split(t, d, ":")
      atanum=d[1]
      atanum2=d[3]
      #p(dev ", " disk ", " atanum ", " atanum2);
      if ( disk == "flash" )
         cmd = "|scsi" atanum " :|scsi " atanum ":0:" atanum2 ":0"
      else if ( disk == "parity" )
         cmd = "|scsi" atanum " :|scsi " atanum ":0:" atanum2 ":0| ata" atanum ":| ata" atanum ".0" atanum2 ":|md0: [^p]"
      else
         cmd = "|scsi" atanum " :|scsi " atanum ":0:" atanum2 ":0| ata" atanum ":| ata" atanum ".0" atanum2 ":|" disk "[^0-9]| md" substr(disk, 5) ":"
   }
   cmd = "cat " syslog "|egrep \"(" dev cmd ")\""
   #p(cmd)
   print RunCommand(cmd, "Filtered syslog for " disk (substr(disk,1,4) != "disk" ? " drive" : "") )
}

function FilterSyslogx(syslog, dev, disk)
{
   #Step 1 - Find the ata#
   cmd = "cat " syslog "|grep '\\[" dev "\\]'"
   #p(cmd)
   cmd|getline f
   close(cmd)
   split(f,d);
   t=d[7];
   delete d;
   split(t, d, ":")
   atanum=d[1]
   #p(dev ", " disk ", " atanum);
   cmd = "cat " syslog "|egrep \"(" dev "|" disk "[^0-9]|md" substr(disk, 5) "[^0-9]|ata[ ]*" atanum "[^0-9])\"";
   #p(cmd)
   print RunCommand(cmd, "Filtered syslog for "disk)
}

function CGI_setup( uri, version, i) {
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


function GetRawDiskBlocks( theDisk, partition, a, s) {
    d_size = ""
    cmd = "fdisk -l " theDisk
    RS="\n"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ theDisk ) {
            delete s;
            split(a,s," ");
            d_size=s[5]
            break;
        }
    }
    close(cmd);
    return ( d_size / 1024 )
}

function RunTest()
{
   t="abcdefg1hij2kmmm3lmnop1hij2kmmm3asdfasdf1hij2kmmm3asdfsadf1hij2kmmm3"
   t1=t
   gsub("1.*2", "", t1)
   gsub("3", "", t1);
   p(t)
   p(t1)
}

#-------------------------------------------
# Utility function to perform debug prints. 
#-------------------------------------------
function p(printme)
{
   gsub("<", "\\&lt;", printme);
   gsub(">", "\\&gt;", printme);
   print "<p>"printme"</p>"
}

