BEGIN {
#ADD_ON_URL=system_log
#ADD_ON_MENU=Syslog
#ADD_ON_STATUS=YES
#ADD_ON_TYPE=awk
#ADD_ON_VERSION= Version: .4b - contributed by RobJ
#ADD_ON_VERSION= Version: .5a - modified by RobJ
#ADD_ON_VERSION= Version: .5a1 - modified by RobJ
#ADD_ON_VERSION= Version: .4c - modified by Joe L.
#ADD_ON_VERSION= Version: .6  - modified by RobJ
#ADD_ON_VERSION= Version: .6a - modified by Joe L.
#ADD_ON_VERSION= Version: .7  - modified by RobJ
#ADD_ON_VERSION= Version: .8  - modified by Joe L. to use a pattern file.
#ADD_ON_VERSION= Version: .9  - modified by Joe L. to escape special charaters
#UNMENU_RELEASE $Revision$ $Date$

  if ( ScriptDirectory == "" ) {
      ScriptDirectory = ".";
  }
  if ( ConfigFile == "" ) {
      ConfigFile = "unmenu.conf";
  }

  GetConfigValues(ScriptDirectory "/" ConfigFile);

  num_patterns = 0;
  num = GetSyslogPatterns(ScriptDirectory "/" "syslog_match.conf");
  num += GetSyslogPatterns(ScriptDirectory "/" "syslog_user_match.conf");

  #####################################################################################
  # You may redefine the number of lines you wish displayed in the unmenu.conf file
  # Please do not change the values here, as they will only need to be re-edited
  # if a new version of the syslog viewer is released.
  #####################################################################################
  # number of lines when invoked via the file browser
  file_browser_syslog_lines = CONFIG["file_browser_syslog_lines"] ? CONFIG["file_browser_syslog_lines"] : 10000

  # number of lines shown when invoked via main menu
  syslog_summary_lines = CONFIG["syslog_summary_lines"] ? CONFIG["syslog_summary_lines"] : 3000

  CGI_setup();

  if ( GETARG["file"] != "" ) {
      log_fname = GETARG["file"]
      nl = file_browser_syslog_lines
      decodedFile = ""
      # deal with hex encoding of strings
      for ( i = 1; i<=length(log_fname); i++ ) {
          if ( substr(log_fname,i,1) == "%" ) {
             ch=sprintf("%c", strtonum("0x" substr(log_fname, i+1,2)))
             decodedFile = decodedFile ch
             i+=2
          } else {
             decodedFile = decodedFile substr(log_fname,i,1)
          }
      }
      # deal with single quotes... end first quoted string, escape quote, start second string
      gsub("'","'\\''",decodedFile)
      log_fname = decodedFile
  } else {
      log_fname = "/var/log/syslog"
      nl = syslog_summary_lines
  }

  theHTML = "<fieldset style=\"margin-top:10px;\"><legend><strong>System Log</strong></legend>"
  theHTML = theHTML GetSysLog(nl, log_fname, num);
  theHTML = theHTML "</fieldset>"
  print theHTML

}


function GetSysLog(numlines, syslogfile, num, syslog, f) {

    nl = numlines
    cmd = "tail -" nl " '" syslogfile "'"
    RS = "\n"
    offset = 0
    linecount = removedlines = 0
    syslog = "<strong>Syslog (last " nl " lines of " syslogfile ")</strong>"
    if ( syslogfile == "/var/log/syslog" ) {
        syslog = syslog "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A href=" MyPrefix "/syslog>Click Here to Download Complete /var/log/syslog</A>"
    } else {
        delete d;
        n = split(syslogfile,d,"/")
        syslog_name=d[n]
        syslog = syslog "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A href=" MyPrefix "/syslog?file=" syslogfile ">Click Here to Download Complete " syslog_name "</A>"
    }
    syslog = syslog "<br>Legend =>  <font color=red> ERRORS </font> <font color=orange> Minor Issues </font> "
    syslog = syslog "<font color=lime> Lime Tech </font> <font color=green> unRAID engine </font> "
    syslog = syslog "<font color=blue> System </font> <font color=teal> Drive related </font> "
    syslog = syslog "<font color=purple> Network </font> <font color=olive> Logins </font> "
    syslog = syslog "<font color=brown> Misc </font>"
    syslog = syslog "<font color=navy> Other emhttp </font><hr>"

    RS="\n"
    while (( cmd | getline f ) > 0) {

        color=""
        for ( i = 1; i <= num; i++ ) {
           IGNORECASE = match_case[i]
           if ( f ~  match_pattern[i] ) {
              color = match_color[i]
              break;
           } 
        }

        ++linecount

        # Now format line with color
        if ( color == "" ) {
           syslog = syslog f "<br>"
        }
        else if ( offset > 1 ) {
           logger = substr(f,offset,7)
           off = offset
           if ( (logger == "kernel:") || (logger == "emhttp:") || (logger == "logger:") )  off += 8
           syslog = syslog substr(f,1,off - 1) "<font color=\"" color "\">" substr(f,off) "</font><br>"
        }
        else {
           syslog = syslog "<font color=\"" color "\">" f "</font><br>"
        }
    }
    close(cmd)
    syslog = syslog "<br><font color=blue>Total lines: " linecount
    if ( removedlines )  syslog = syslog " &nbsp;&nbsp;( " removedlines " lines not shown )"
    syslog = syslog "</font><br>"
    # to prevent any tags in the log from being interperted by the browser
    gsub("<meta","&lt;meta",syslog)
    return syslog
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


# open and read the unmenu configuration file.  In it, look for lines with the following pattern:
#variableName = ReplacementValue

# The values found there can be used to override values of some variables in these scripts.
# the CONFIG[] array is set with the variable.

function GetConfigValues(cfile) {
    RS="\n"
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^([^# \t=]+)([\t ]*)(=)([\t ]*)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 &&
               c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               CONFIG[substr(line,c[1,"start"],c[1,"length"])] = substr(line,c[5,"start"],c[5,"length"])
          }
    }
    close(cfile);
}

function OldGetSyslogPatterns(cfile) {
    RS="\n"
    FS="[ \t]*\\|\\|[ \t]*"
    while (( getline < cfile ) > 0 ) {
      if ( NF == 3 ) {
        num_patterns++
        match_case[num_patterns] = ( $1 == "any_case" )
        match_pattern[num_patterns] = substr($2,2,length($2) - 2)
        match_color[num_patterns] = $3
      }
    }
    close(cfile);
    return num_patterns
}

function GetSyslogPatterns(cfile) {
    RS="\n"
    FS="[ \t]*\\|\\|[ \t]*"
    prior_color=""
    prior_case=""
    group_num = 0
    while (( getline < cfile ) > 0 ) {
      if ( NF == 3 ) {
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
    close(cfile);
    return num_patterns
}
