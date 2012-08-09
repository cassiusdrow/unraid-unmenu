BEGIN {
#ADD_ON_URL=lsof
#ADD_ON_MENU=
#ADD_ON_STATUS=NO
#ADD_ON_PAGE_HEADING=NO
#ADD_ON_TYPE=awk
#ADD_ON_VERSION= Version: .1  - Joe L.
#UNMENU_RELEASE $Revision$ $Date$

  if ( ScriptDirectory == "" ) {
      ScriptDirectory = ".";
  }
  if ( ConfigFile == "" ) {
      ConfigFile = "unmenu.conf";
  }

  GetConfigValues(ScriptDirectory "/" ConfigFile);

  CGI_setup();

  theHTML = "<fieldset style=\"margin-top:1px;\"><legend><strong>Open Files</strong></legend><pre>"
  theHTML = theHTML "<strong>(from lsof /dev/md*)</strong><pre>"
  if (system("test -f /usr/bin/lsof")==0) {
      cmd = "lsof /dev/md*"
      while (( cmd | getline f ) > 0) {
        theHTML = theHTML f  "<br>"
      }
  } else {
    theHTML = theHTML "<strong>you don't appear to have the \"lsof\" package installed</strong>"
  }
  theHTML = theHTML "</fieldset>"
  print theHTML

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
