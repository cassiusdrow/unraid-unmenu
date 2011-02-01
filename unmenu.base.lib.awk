#ADD_ON_VERSION 1.5 - changes for myMain 12-1-10 release
#UNMENU_RELEASE $Revision$ $Date$
function GetArrayStatus(a, d) {
    RS="\n"
    array_numdisks=0
    numdisks=0
    last_parity_sync=0
    resync_percentage=""
    resync_finish=""
    resync_speed=""
    resync_pos=""
    last_parity_errs=0
    array_state="Not started"
    has_spinup="false"

    while (("/root/mdcmd status|strings" | getline a) > 0 ) {
        # number of disks in the superblock
        if ( a ~ "sbNumDisks" )      { delete d; split(a,d,"="); numdisks=d[2] }
        # number of disks in the "md" array
        if ( a ~ "mdNumProtected" )  { delete d; split(a,d,"="); array_numdisks=d[2] }
        # datetime (in seconds) of last parity sync
        if ( a ~ "sbSynced" )        { delete d; split(a,d,"="); last_parity_sync=d[2] }
        # number of errors detected in last parity sync
        if ( a ~ "sbSyncErrs" )      { delete d; split(a,d,"="); last_parity_errs=d[2] }
        # percentage of sync completed thus far
        if ( a ~ "mdResyncPrcnt" )   { delete d; split(a,d,"="); resync_percentage=d[2] }
        if ( a ~ "mdResyncFinish" )  { delete d; split(a,d,"="); resync_finish=d[2] }
        if ( a ~ "mdResyncSpeed" )   { delete d; split(a,d,"="); resync_speed=d[2] }
        if ( a ~ "mdResyncPos" )     { delete d; split(a,d,"="); resync_pos=d[2] }
        # array status
        if ( a ~ "mdState" )         { delete d; split(a,d,"="); array_state=d[2] }
        # per disk data, stored in disk_... arrays, delete "ata-" preface on disk_id.
        if ( a ~ "diskName" )        { delete d; split(a,d,"[.=]"); disk_name[d[2]]=d[3]; }
        if ( a ~ "diskId" )          { delete d; split(a,d,"[.=]"); offset = index(d[3],"-")+1;
                                                 disk_id[d[2]]=substr(d[3],offset); }
        if ( a ~ "diskSerial" )      { delete d; split(a,d,"[.=]"); disk_serial[d[2]]=d[3]; }
        if ( a ~ "diskSize" )        { delete d; split(a,d,"[.=]"); disk_size[d[2]]=d[3]; }
        if ( a ~ "rdevSize" )        { delete d; split(a,d,"[.=]"); rdisk_size[d[2]]=d[3]; }   #bjp999
        if ( a ~ "rdevSerial" )      { delete d; split(a,d,"[.=]"); rdisk_serial[d[2]]=d[3]; }
        if ( a ~ "diskModel" )       { delete d; split(a,d,"[.=]"); disk_model[d[2]]=d[3]; }
        if ( a ~ "rdevModel" )       { delete d; split(a,d,"[.=]"); rdisk_model[d[2]]=d[3]; }
        if ( a ~ "rdevStatus" )      { delete d; split(a,d,"[.=]"); disk_status[d[2]]=d[3]; }
        if ( a ~ "rdevName" )        { delete d; split(a,d,"[.=]"); disk_device[d[2]]=d[3];
                                       if ( disk_device[d[2]] != "" ) GetReadWriteStats(d[2])
                                     }
        if ( a ~ "rdevLastIO" )      { delete d; split(a,d,"[.=]"); rdisk_lastIO[d[2]]=d[3]; }
        #if ( a ~ "diskNumWrites" )   { delete d; split(a,d,"[.=]"); disk_writes[d[2]]=d[3]; }
        #if ( a ~ "diskNumReads" )    { delete d; split(a,d,"[.=]"); disk_reads[d[2]]=d[3]; }
        if ( a ~ "diskNumErrors" )   { delete d; split(a,d,"[.=]"); disk_errors[d[2]]=d[3]; }
        if ( a ~ "rdevSpinupGroup" ) { has_spinup="true"; }

    }
    close("/root/mdcmd status|strings")
}

function GetDiskData(cmd, a, d, line, s, i) {
  # read from /proc/partitions
    RS="\n"
    cmd="cat /proc/partitions | grep -v '^major' | grep -v '^$' "
    num_partitions=0
    while ((cmd | getline a) > 0 ) {
        num_partitions++
        delete d;
        split(a,d," ");
        major[num_partitions] = d[1]
        minor[num_partitions] = d[2]
        blocks[num_partitions] = d[3]
        device[num_partitions] = d[4]
        assigned[num_partitions] = ""
        mounted[num_partitions] = ""
        fs_type[num_partitions] = ""
        mount_mode[num_partitions] = ""
        model_serial[num_partitions] = ""
    }
    close(cmd)

    # Now, identify the UNRAID device... It should be available in /dev/disk/by-label
    cmd="ls -l /dev/disk/by-label | grep 'UNRAID'"
    while ((cmd | getline a) > 0 ) {
        delete d;
        split(a,d," ");
        sub("../../","",d[11])
        unraid_volume=d[11]
    }
    close(cmd);

    # match the device to the volume labeled UNRAID
    for( a = 1; a <= num_partitions; a++ ) {
        if ( device[a] == unraid_volume ) {
             assigned[a] = "UNRAID"
        }
    }

    # Now, get the model/serial numbers. They should be available in /dev/disk/id-label
    cmd="ls -l /dev/disk/by-id"
    while ((cmd | getline line) > 0 ) {
       delete d;
       split(line,d," ");
       sub("../../","",d[11])
       for( a = 1; a <= num_partitions; a++ ) {
           if ( d[11] == ( device[a] ) && model_serial[a] == "" ) {
               model_serial[a]=d[9]
               sub("-part1","", model_serial[a])
               sub("ata-","", model_serial[a])
               break;
           }
       }
    }
    close(cmd);

    # determine if partitions are mounted anywhere
    RS="\n"
    cmd = "mount"
    while ((cmd | getline line) > 0 ) {
       delete s;
       split(line,s," ");
       for( a = 1; a <= num_partitions; a++ ) {
           if ( s[1] == ( "/dev/" device[a] ) ) {
               mounted[a]=s[3]
               fs_type[a]=s[5]
               mount_mode[a]=substr(s[6],2,2)
               break;
           }
       }
    }
    close(cmd);

    # if the partition is part of the managed array, mark it as "in-array"
    # mark the full disk partition as in-array too if matched first three characters.
    for( a = 1; a <= num_partitions; a++ ) {
        for ( i =0; i<numdisks; i++ ) {
            if ( disk_device[i] == substr(device[a],1,3) || disk_name[i] == device[a] ) {
                assigned[a] = "in-array"
            }
        }
       if ( mounted[a] == "/boot" ) {
          boot_device=device[a]
       }
    }
    # mark the boot partitons as "in-array"
    for( a = 1; a <= num_partitions; a++ ) {
       if(assigned[a] != "in-array")                           #bjp999
          GetReadWriteStatsOther( a, substr(device[a],1,3) );  #bjp999

       if ( substr(boot_device,1,3) == device[a] ) {
                assigned[a] = "in-array"
       }
    }
    # Get the shares
    delete SHARES
    RS="\n"
    cmd = "smbclient -N -L localhost 2>/dev/null"
    while ((cmd | getline line) > 0 ) {
       delete s;
       split(line,s," ");
       if ( s[2] == "Disk" ) {
          SHARES[s[1]] = s[1]
       }
    }
    close(cmd);

}


function CGI_setup( uri, version, i, j, t) {        #bjp999
  delete GETARG;         delete MENU;        delete PARAM
  gsub("+", " ", ARGV[3])
  gsub("%24", "$", ARGV[3])
  gsub("%2F", "/", ARGV[3])
  gsub("%21", "!", ARGV[3])
  gsub("%2B", "+", ARGV[3])
  gsub("%5C", "\\", ARGV[3])
  gsub("%7E", "~", ARGV[3])                         #bjp999
  gsub("%23", "#", ARGV[3])                         #bjp999
  gsub("%5E", "^", ARGV[3])                         #bjp999
  gsub("%28", "(", ARGV[3])                         #bjp999
  gsub("%29", ")", ARGV[3])                         #bjp999
  gsub("%60", "`", ARGV[3])                         #bjp999
  gsub("%3D", "=", ARGV[3])                         #bjp999
  gsub("%5B", "[", ARGV[3])                         #bjp999
  gsub("%5D", "]", ARGV[3])                         #bjp999
  gsub("%7B", "{", ARGV[3])                         #bjp999
  gsub("%7D", "}", ARGV[3])                         #bjp999
  gsub("%7C", "|", ARGV[3])                         #bjp999
  gsub("%3B", ";", ARGV[3])                         #bjp999
  gsub("%27", "'", ARGV[3])                         #bjp999
  gsub("%22", "\"", ARGV[3])                        #bjp999
  gsub("%2C", ",", ARGV[3])                         #bjp999
  gsub("%3C", "<", ARGV[3])                         #bjp999
  gsub("%3E", ">", ARGV[3])                         #bjp999
  n=gsub("%A0", amp "nbsp;", ARGV[3])

  GETARG["Status"] = ARGV[1]; GETARG["Method"] = ARGV[2]; GETARG["URI"] = ARGV[3];
  i = index(ARGV[3], "?")
  if (i > 0) {             # is there a "?" indicating a CGI request?
    split(substr(ARGV[3], 1, i-1), MENU, "[/:]")
    split(substr(ARGV[3], i+1), PARAM, "[?&]")    #bjp999
    for (i in PARAM) {
      #perr(PARAM[i])
      j = index(PARAM[i], "=")
      t = substr(PARAM[i], j+1)                   #bjp999
      #perr(t)
      gsub("%3A", ":", t)                         #bjp999
      #perr(t)
      gsub("%3F", "?", t)                         #bjp999
      #gsub("%26", "\\&", t)                 #bjp999 - couldn't make & work without using substitute
      gsub("%26", "AMP3RS4ND", t)                 #bjp999
      gsub("%25", "%", t)                         #bjp999
      #perr(substr(PARAM[i], 1, j-1))        $bjp999
      GETARG[substr(PARAM[i], 1, j-1)] = t        $bjp999
    }
  } else {             # there is no "?", no need for splitting PARAMs
    split(ARGV[3], MENU, "[/:]")
  }
}


function GetRawDiskBlocks( theDisk, partition, a, s, d_size, cmd) {
   if(constant["minrawsectors"] != "")
      return(constant["minrawsectors"]);

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

function GetReadWriteStats(theDevIndex, cmd) {
  cmd="cat /sys/block/" disk_device[theDevIndex] "/stat"
  cmd | getline
  disk_reads[theDevIndex] = $1
  disk_writes[theDevIndex] = $5
  close(cmd)
}

function GetReadWriteStatsOther(theDevIndex, theDevice, cmd) { #bjp999
  cmd="cat /sys/block/" theDevice "/stat"                      #bjp999
  cmd | getline                                                #bjp999
  other_reads[theDevIndex] = $1                                #bjp999
  other_writes[theDevIndex] = $5                               #bjp999
  close(cmd)                                                   #bjp999
}                                                              #bjp999


#function GetSysLog(numlines, syslogfile, num, syslog, f, cmd) {
#    if ( ScriptDirectory == "" ) {
#        ScriptDirectory = ".";
#    }
#
#    perr("numlines='" numlines "'");
#    num_patterns = 0;
#    num = GetSyslogPatterns(ScriptDirectory "/" "syslog_match.conf");
#    num += GetSyslogPatterns(ScriptDirectory "/" "syslog_user_match.conf");
#
#    if(numlines == 0) { # all
#       cmd = "cat '" syslogfile "'"
#       syslog = "<strong>Syslog (full contents of "  syslogfile ")</strong>"
#    }
#    else {
#       nl = numlines
#       cmd = "tail -" nl " '" syslogfile "'"
#       syslog = "<strong>Syslog (last " nl " lines of " syslogfile ")</strong>"
#    }
#    perr(cmd);
#    RS = "\n"
#    offset = 0
#    linecount = removedlines = 0
#    syslog = "<strong>Syslog (last " nl " lines of " syslogfile ")</strong>"
#     if ( syslogfile == "/var/log/syslog" ) {
#         syslog = syslog "        <A href=" MyPrefix "/syslog>Click Here to Download Complete /var/log/syslog</A>"
#     } else {
#         delete d;
#         n = split(syslogfile,d,"/")
#         syslog_name=d[n]
#         syslog = syslog "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A href=" MyPrefix "/syslog?file=" syslogfile ">Click Here to Download Complete " syslog_name "</A>"
#     }
#    syslog = syslog "<br>Legend =>  <font color=red> ERRORS </font> <font color=orange> Minor Issues </font> "
#    syslog = syslog "<font color=lime> Lime Tech </font> <font color=green> unRAID engine </font> "
#    syslog = syslog "<font color=blue> System </font> <font color=teal> Drive related </font> "
#    syslog = syslog "<font color=purple> Network </font> <font color=olive> Logins </font> "
#    syslog = syslog "<font color=brown> Misc </font>"
#    syslog = syslog "<font color=navy> Other emhttp </font><hr>"
#
#    RS="\n"
#    while (( cmd | getline f ) > 0) {
#        color=""
#        for ( i = 1; i <= num; i++ ) {
#           IGNORECASE = match_case[i]
#           if ( f ~  match_pattern[i] ) {
#              color = match_color[i]
#              break;
#           }
#        }
#
#        ++linecount
#
#        # Now format line with color
#        if ( color == "" ) {
#           syslog = syslog f "<br>"
#        }
#        else if ( offset > 1 ) {
#           logger = substr(f,offset,7)
#           off = offset
#           if ( (logger == "kernel:") || (logger == "emhttp:") || (logger == "logger:") )  off += 8
#           syslog = syslog substr(f,1,off - 1) "<font color=\"" color "\">" substr(f,off) "</font><br>"
#        }
#        else {
#           syslog = syslog "<font color=\"" color "\">" f "</font><br>"
#        }
#    }
#    close(cmd)
#    #syslog = syslog "<br><font color=blue>Total lines: " linecount
#    if ( removedlines )  syslog = syslog " &nbsp;&nbsp;( " removedlines " lines not shown )"
#    syslog = syslog "</font><br>"
#    # to prevent any tags in the log from being interperted by the browser
#    gsub("<meta","&lt;meta",syslog)
#    return syslog
#}


function GetSysLog(numlines, syslogfile, style, num, syslog, f, cmd) {

    if(substr(syslogfile,1,4) != "/tmp") {
       if(numlines == 0) # all
          syslog = "<strong>Syslog (full contents of "  syslogfile ")</strong>"
       else
          syslog = "<strong>Syslog (last " nl " lines of " syslogfile ")</strong>"

       syslog = syslog "AMP3RS4NDnbsp;AMP3RS4NDnbsp;AMP3RS4NDnbsp;AMP3RS4NDnbsp;AMP3RS4NDnbsp;<A href=" MyPrefix "/syslog?file=" syslogfile ">Click Here to Download Complete " syslog_name "</A><br>"
    }

    syslog = syslog GetColorBar(style) "<hr>"

    syslog = syslog GetSysLogRows(numlines, syslogfile)

    return syslog
}

function GetSyslogPatterns(cfile) {
    RS="\n"
    FS="[ \t]*\\|\\|[ \t]*"
    prior_color=""
    prior_case=""
    group_num = 0
    while (( getline < cfile ) > 0 ) {
      if ( NF == 3 ) {
        if(substr($1,1,1) != "#") {
           # If the same case, and the same color, construct a compound pattern
           if ( prior_case == $1 && prior_color == $3 && group_num <= 10 ) {
               match_pattern[num_patterns] = match_pattern[num_patterns] "|" substr($2,2,length($2) - 2)
               group_num++
           } else {
               group_num = 0
               num_patterns++
               match_case[num_patterns] = ( $1 == "any_case" )
               match_pattern[num_patterns] = substr($2,2,length($2) - 2)
               match_color[num_patterns] = $3
           }
           prior_color=$3
           prior_case= $1
        }
      }
    }
    close(cfile);
    return num_patterns
}

function GetSyslogFieldset(nl, option, log_fname, theHTML)
{
   if(log_fname == "")
      log_fname = "/var/log/syslog"

   theHTML = "<fieldset><legend><strong>System Log (last " nl " lines)</strong>"
   theHTML = theHTML "&nbsp&nbsp;" GetColorBar(option)
   theHTML = theHTML "</legend>"
   theHTML = theHTML GetSysLogRows(nl, log_fname);
   theHTML = theHTML "</fieldset>"
   return theHTML
}

function GetColorBar(option, template)
{
   saveColorOption = option

   return "Legend ==" amp "gt; " \
          ColorizeText("white",     "red",    "Errors",        1, template) " " \
          ColorizeText("black",     "orange", "Minor Issues",  1, template) " " \
          ColorizeText("blue",      "lime",   "Lime Tech",     1, template) " " \
          ColorizeText("white",     "green",  "unRAID engine", 1, template) " " \
          ColorizeText("white",     "blue",   "System",        1, template) " " \
          ColorizeText("white",     "teal",   "Drive related", 1, template) " " \
          ColorizeText("yellow",    "purple", "Network",       1, template) " " \
          ColorizeText("lightblue", "olive",  "Logins",        1, template) " " \
          ColorizeText("white",     "brown",  "Misc",          1, template) " " \
          ColorizeText("white",     "navy",   "Other emhttp",  1, template) " " \
          ColorizeText("gray",      "gray",   "Routine",       1, template)
}

function ColorizeText(fontcolor, backcolor, text, set, s, txt)
{
   if(set == 1) {
      _savecolor = backcolor;
      FontColor[backcolor] = fontcolor;
      TypeForColor[backcolor] = text;
   }

   if((saveColorOption == 2) || (saveColorOption == 4))
      txt = " <em>(" TypeForColor[backcolor] ")</em>"

   if(saveColorOption < 3) {
      fontcolor = backcolor
      backcolor = "white"
   }
   else
      if(backcolor == "gray")
         backcolor = "white";

   if(s == "") {
      s = "<span style='background-color:" backcolor ";'><font color=" fontcolor ">" text
      if(set != 1)
         s = s txt
      s = s "</font></span>";
   }
   else {
      gsub("\\$bcolor\\$", backcolor, s)
      gsub("\\$bcoloro\\$", _savecolor, s)
      gsub("\\$fcolor\\$", fontcolor, s)
      gsub("\\$label\\$",  text,      s)
   }
   return(s);
}


function GetSysLogRows(numlines, syslogfile, filter_sw, filter, num, syslog, f, num_patterns)
{
    if ( ScriptDirectory == "" )
        ScriptDirectory = ".";

    num_patterns = 0;
    num = GetSyslogPatterns(ScriptDirectory "/" "syslog_match.conf");
    num += GetSyslogPatterns(ScriptDirectory "/" "syslog_user_match.conf");

    if(numlines == 0)
       cmd = "cat '" syslogfile "'"
    else
       cmd = "tail -" numlines " '" syslogfile "'"

    RS = "\n"
    offset = 0
    linecount = removedlines = 0

    RS="\n"
    while (( cmd | getline f ) > 0) {

        gsub("<", "AMP3RS4NDlt;", f);
        gsub(">", "AMP3RS4NDgt;", f);

        color=""
        for ( i = 1; i <= num; i++ ) {
           IGNORECASE = match_case[i]
           if ( f ~  match_pattern[i] ) {
              color = match_color[i]
              break;
           }
        }


        # Now format line with color
        if ( color == "" ) {
           #if(first=="")
           #    perr("cb_normal=" filter["cb_normal"])
           if((filter_sw == "") || (filter["normal"])) {
              syslog = syslog f "<br>"
              ++linecount
           }
        }
        else if ( offset > 1 ) {
           logger = substr(f,offset,7)
           off = offset
           if ( (logger == "kernel:") || (logger == "emhttp:") || (logger == "logger:") )  off += 8
           if((filter_sw == "") || (filter[color])) {
              syslog = syslog substr(f,1,off - 1) ColorizeText(FontColor[color], color, substr(f,off)) "<br>"
              ++linecount
           }
        }
        else {
           if((filter_sw == "") || (filter[color])) {
              syslog = syslog ColorizeText(FontColor[color], color, f) "<br>"
              ++linecount
           }
        }
    }
    if((numlines+0 == 0) || (numlines+0 > 100)) #this is number lines requested, not # lines shown
       syslog = syslog " <br> <br><span style='background color: white'><font color='blue'>Total Lines: " linecount

    close(cmd)
    return syslog
}


function SyslogHtml(syslog, style, full)
{
   if(full) {
      vv[0, "from"] = "what"
      vv[1, "from"] = "stuff"
      vv[2, "from"] = "ImageURL"
      vv[2, "to"] = "http://" MyHost "/log/images";
      vv[3, "from"] = "legend"
      vv[3, "to"] = ""
   }

   if(syslog == "")
      syslog="/var/log/syslog"

   template="<input name='cb_$bcoloro$' type='checkbox' $ch_$bcoloro$$>" \
            "<span id='l_$bcoloro$' style='cursor:hand; background-color:$bcolor$; color: $fcolor$'" \
            "onClick=\"changeBox('document.myForm.cb_$bcoloro$')\">$label$</span>"


   if(length(style) > 1)
      style = substr(style, 2, 1)


   ss = GetColorBar(style, template);

   #perr("GETARG[Action]" GETARG["Action"])
   #perr("GETARG[cb_red]" GETARG["cb_red"])
   if(GETARG["Action"] == "load+filter") {
      filt["red"   ] = (GETARG["cb_red"        ] =="on");
      filt["orange"] = (GETARG["cb_orange"     ] =="on");
      filt["lime"  ] = (GETARG["cb_lime"       ] =="on");
      filt["green" ] = (GETARG["cb_green"      ] =="on");
      filt["blue"  ] = (GETARG["cb_blue"       ] =="on");
      filt["teal"  ] = (GETARG["cb_teal"       ] =="on");
      filt["purple"] = (GETARG["cb_purple"     ] =="on");
      filt["olive" ] = (GETARG["cb_olive"      ] =="on");
      filt["brown" ] = (GETARG["cb_brown"      ] =="on");
      filt["navy"  ] = (GETARG["cb_navy"       ] =="on");
      filt["gray"  ] = (GETARG["cb_gray"       ] =="on");
      filt["normal"] = (GETARG["cb_normal"     ] =="on");
      #perr("filt[red]=" filt["red"]);
   }
   else {
      filt["red"   ] = \
      filt["orange"] = \
      filt["lime"  ] = \
      filt["green" ] = \
      filt["blue"  ] = \
      filt["teal"  ] = \
      filt["purple"] = \
      filt["olive" ] = \
      filt["brown" ] = \
      filt["navy"  ] = \
      filt["gray"  ] = \
      filt["normal"] = (1==1);
   }
   #for(i in filt)
   #   perr(i " " filt[i])

   gsub("&", amp, ss);


   maxlines = GETARG["maxlines"]
   if(maxlines == "")
      maxlines = 5000

   if(syslog == "/var/log/syslog")
      fparm=""
   else
      fparm="?file=" syslog

   vv[0, "to"] = "Display syslog " syslog nbsp "</strong>" nbsp nbsp nbsp nbsp nbsp nbsp nbsp \
                 "<A href=/syslog" fparm ">Click Here to Download Complete " syslog "</A><strong> "
   vv[3, "to"] = ss;
   vv[1, "to"]   = GetSysLogRows(maxlines, syslog, 1, filt);
   OptionToLoadSyslog = (1==1);
   vv[4, "from"] = "syslog_file"
   vv[4, "to"]   = syslog
   vv[5, "from"] = "maxlines"
   vv[5, "to"]   = maxlines
   vv[i=6, "from"] = "ch_red"   ; vv[i, "to"] = filt["red"   ] ? "checked" : "";
   vv[++i, "from"] = "ch_orange"; vv[i, "to"] = filt["orange"] ? "checked" : "";
   vv[++i, "from"] = "ch_lime"  ; vv[i, "to"] = filt["lime"  ] ? "checked" : "";
   vv[++i, "from"] = "ch_green" ; vv[i, "to"] = filt["green" ] ? "checked" : "";
   vv[++i, "from"] = "ch_blue"  ; vv[i, "to"] = filt["blue"  ] ? "checked" : "";
   vv[++i, "from"] = "ch_teal"  ; vv[i, "to"] = filt["teal"  ] ? "checked" : "";
   vv[++i, "from"] = "ch_purple"; vv[i, "to"] = filt["purple"] ? "checked" : "";
   vv[++i, "from"] = "ch_olive" ; vv[i, "to"] = filt["olive" ] ? "checked" : "";
   vv[++i, "from"] = "ch_brown" ; vv[i, "to"] = filt["brown" ] ? "checked" : "";
   vv[++i, "from"] = "ch_navy"  ; vv[i, "to"] = filt["navy"  ] ? "checked" : "";
   vv[++i, "from"] = "ch_gray"  ; vv[i, "to"] = filt["gray"  ] ? "checked" : "";
   vv[++i, "from"] = "ch_normal"; vv[i, "to"] = filt["normal"] ? "checked" : "";

   if(full) {
      fn="UtilityShell.html"

      htmlLoadFile(fn, html)

      #for(i=0; i<html["count"]; i++) {
      #   perr(i "  " html[i, "type"] " --> " html[i]);
      #}

      if(OptionToLoadSyslog)
         htmlExpandGroup(html, "A");

      ss = htmlSerialize(html, 0, vv);
      #perr(ss);
      gsub(amp, "\\&", ss);
      return(ss)
   }
   return
}


function getImageHost( theHostName, cmd, a)
{
   "uname -n" | getline  theHostName
   close("uname -n")

   # determine if we are running on a user specified port
   cmd = "ps -ef | grep emhttp | grep -v grep"
   cmd | getline emhttp
   delete a;
   match( emhttp, /(.*emhttp)([\t ]+)(-p)([ \t]*)([0-9]+)/, a );
   if ( a[1,"length"] > 0 && a[2,"length"] > 0 && a[3,"length"] > 0 && a[5,"length"] > 0 ){
      theHostName = theHostName ":" substr(emhttp, a[5,"start"],a[5,"length"])
   }
   close(cmd);

   return theHostName
}

