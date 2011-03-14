BEGIN {
#define ADD_ON_URL     utility
#define ADD_ON_MENU
#define ADD_ON_STATUS  NO
#define ADD_ON_TYPE    awk
#ADD_ON_HTTP_HEADER=NO
#ADD_ON_OPTIONS=-f unmenu.base.lib.awk -f utility.lib.awk
#define ADD_ON_VERSION 1.0 - contributed by bjp999
#define ADD_ON_VERSION 1.5 - Part of myMain 12-1-10 release, contributed by bjp999
#define ADD_ON_VERSION 1.53 - changes for myMain 3-10-11 release, contributed by bjp999 - 5.0b6 support
#UNMENU_RELEASE $Revision$ $Date$

   # (c) Copyright bjp999, 2009-2011.  All rights reserved.
   # This program carries no warranty or guarantee of any kind.  It is used strictly at the users risk.

   CGI_setup()
   cmd  = GETARG["cmd"]
   dev  = GETARG["dev"]
   disk = GETARG["disk"]
   #print "<p> cmd='" cmd "'</p>"
   #print "<p> parm1='" parm1 "'</p>"
   #print "<p> parm2='" parm2 "'</p>"
   #print "<p> parm3='" parm3 "'</p>"

   if ( ScriptDirectory == "" ) {
       ScriptDirectory = ".";
   }
   if ( ConfigFile == "" ) {
       ConfigFile = "unmenu.conf";
   }

   # Local config file variables will never be overwritten by a distributd file.
   # It is here where local changes should be made without worry about them being
   # lost when a new unmenu.conf file is distributed.
   if ( LocalConfigFile == "" ) {
       LocalConfigFile = "unmenu_local.conf";
   }
   GetConfigValues(ScriptDirectory "/" ConfigFile);
   GetConfigValues(ScriptDirectory "/" LocalConfigFile);

   amp="AMP3RS4ND"
   nbsp=amp "nbsp;"

   vv[0, "from"] = "what"
   vv[1, "from"] = "stuff"
   vv[2, "from"] = "ImageURL"

   if(GETARG["ImageURL"] == "")
      vv[2, "to"] = "http://" MyHost "/log/images";
   else
      vv[2, "to"] = GETARG["ImageURL"]

   vv[3, "from"] = "legend"
   vv[3, "to"] = ""

   if(cmd == "smartctl") {
      if(GETARG["file"] == "")
         if(GETARG["smart"] == "")
            RunCommand(sprintf("smartctl -a -d ata /dev/%s", dev), disk);
         else
            RunCommand(sprintf("smartctl -a " GETARG["smart"] " /dev/%s", dev), disk);
      else
         RunCommand("fromdos<" GETARG["file"], GETARG["file"], "smartctl " GETARG["file"]);
   }
   else if (cmd == "hdparm") {
      RunCommand(sprintf("hdparm -I /dev/%s", dev), disk);
   }
   else if (cmd == "samba") {
      RunCommand("testparm -s", "", "Samba Configuration");
   }
   else if (cmd == "test") {
      vv[0, "to"] = "RunTest";
      vv[1, "to"] = RunTest();
   }
   else if(cmd == "spinup") {
      disk_blocks = GetRawDiskBlocks( "/dev/" dev )
      skip_blocks = 1 + int( rand() * disk_blocks );
      cmd="dd if=/dev/" dev " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
      system(cmd);
      vv[0, "to"] = "Spinup " dev;
      vv[0, "to"] = "Done"
   }
   else if(cmd == "syslog") {
      SyslogHtml(GETARG["syslog"], GETARG["style"], (1==0));
   }
   else if (cmd == "spindown") {
      cmd="/usr/sbin/hdparm -y /dev/" dev " >/dev/null 2>&1"
      system(cmd);
      vv[0, "to"] = "Spindown " dev;
      vv[1, "to"] = "Done"
   }
   else if (cmd == "syslogx") {
      syslog=GETARG["syslog"]
      if (syslog=="") {
         syslog="/var/log/syslog"
      }
      #vv[0, "to"] = "Filtered syslog (disk=\"" disk ", dev=\"" dev ")"
      FilterSyslogx(syslog,dev,disk)
   }
   else if (cmd == "syslogRobJ") {
      syslog=GETARG["syslog"]
      if (syslog=="") {
         syslog="/var/log/syslog"
      }
      #fn="/tmp/temp"
      vv[0, "to"] = "Filtered syslog (disk='" disk "' , device='" dev "')"
      FilterSyslogRobJ(syslog,dev,disk) > fn
      #close(fn);
      #vv[1, "to"] = GetSysLog(0, "/tmp/temp");
   }
   else if (cmd == "smarthistory") {
      SMART_HISTORY_DIR = CONFIG["SMART_HISTORY_DIR"] ? CONFIG["SMART_HISTORY_DIR"] : "/boot/smarthistory"
      SMART_HISTORY_CMD = CONFIG["SMART_HISTORY_CMD"] ? CONFIG["SMART_HISTORY_CMD"] : "./smarthistory -wake ON -output HTML -graph IMAGE -report ALL -devices /dev/" dev
      RunCommand("cd " SMART_HISTORY_DIR "; " SMART_HISTORY_CMD);
   }

   fn="UtilityShell.html"

   htmlLoadFile(fn, html)

   #for(i=0; i<html["count"]; i++) {
   #   perr(i "  " html[i, "type"] " --> " html[i]);
   #}

   if(OptionToLoadSyslog)
      htmlExpandGroup(html, "A");

   htmlExpandGroup(html, "H"); #include html "head" section

   ss = htmlSerialize(html, 0, vv);
   #perr(ss);
   gsub(amp, "\\&", ss);
   print ss;
}

function RunCommand(cmd, disk, output) {
    RS="\n"
    if(output == "")
       vv[0, "to"] = cmd "   (" disk ")"
    else
       vv[0, "to"] = output

    output = ""
    while (( cmd | getline f ) > 0)
      output = output f  "<br>"

    vv[1, "to"]   = output
    #perr(output);

    close(cmd)
}

function FilterSyslogRobJ(syslog, dev, disk, cmd, f)
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
   first=(1==1)
   fn="/tmp/temp"
    while (( cmd | getline f ) > 0)
      if(first)
         print f>fn
      else
         print f>>fn

    #perr(output);

    close(cmd)
    close(fn)

    t = GETARG["style"]
    if(length(t) > 1)
       t = substr(t, 2, 1)

    vv[1, "to"] = GetSysLog(0, "/tmp/temp", t+0);
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
   RunCommand(cmd, "Filtered syslog for "disk)
}

function RunTest()
{
   t="abcdefg1hij2kmmm3lmnop1hij2kmmm3asdfasdf1hij2kmmm3asdfsadf1hij2kmmm3"
   t1=t
   gsub("1.*2", "", t1)
   gsub("3", "", t1);
   return t "<br>" t1 "<br>"
}

#-------------------------------------------
# Utility function to perform debug prints.
#-------------------------------------------
#function p(printme)
#{
#   gsub("<", "\\&lt;", printme);
#   gsub(">", "\\&gt;", printme);
#   print "<p>"printme"</p>"
#}

# open and read the unmenu configuration file.  In it, look for lines with the following pattern:
#variableName = ReplacementValue

# The values found there can be used to override values of some variables in these scripts.
# the CONFIG[] array is set with the variable.

function GetConfigValues(cfile) {
    RS="\n"
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^([^# \t=]+)([\t ]*)(=)([\t ]*)(.+)/, c)
          #print c[1,"length"] " " c[2,"length"] " " c[3,"length"] " "  c[4, "length"] " " c[5, "length"] " " line
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 &&
               c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               CONFIG[substr(line,c[1,"start"],c[1,"length"])] = substr(line,c[5,"start"],c[5,"length"])
               if ( DebugMode == "yes" ) {
                   print "importing from unmenu.conf: " \
                     "CONFIG[" substr(line,c[1,"start"],c[1,"length"]) "] = " substr(line,c[5,"start"],c[5,"length"])
               }
          }
    }
    close(cfile);
}

