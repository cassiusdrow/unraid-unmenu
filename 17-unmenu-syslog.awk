BEGIN {
#ADD_ON_URL=sys_log_tail
#ADD_ON_MENU=
#ADD_ON_STATUS=NO
#ADD_ON_PAGE_HEADING=NO
#ADD_ON_TYPE=awk
#ADD_ON_VERSION= Version: .8  - modified by Joe L. to use a pattern file.
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

  CGI_setup();

  # number of lines shown when invoked via main menu
  nl = GETARG["nl"] ? GETARG["nl"] : 10

  log_fname = "/var/log/syslog"

  theHTML = "<fieldset><legend><strong>System Log (last " nl " lines)</strong>"
  theHTML = theHTML "&nbsp&nbsp;Legend => <font color=red> Errors </font> <font color=orange> Minor Issues </font> "
  theHTML = theHTML "<font color=lime> Lime Tech </font> <font color=green> unRAID engine </font> "
  theHTML = theHTML "<font color=blue> System </font> <font color=teal> Drive related </font> "
  theHTML = theHTML "<font color=purple> Network </font> <font color=olive> Logins </font> "
  theHTML = theHTML "<font color=brown> Misc </font>"
  theHTML = theHTML "<font color=navy> Other emhttp </font>"
  theHTML = theHTML "</legend>"
  theHTML = theHTML GetSysLog(nl, log_fname, num);
  theHTML = theHTML "</fieldset>"
  print theHTML

}


function GetSysLog(numlines, syslogfile, num, syslog, f) {

    cmd = "tail -" nl " '" syslogfile "'"
    RS = "\n"
    offset = 0
    linecount = removedlines = 0

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
