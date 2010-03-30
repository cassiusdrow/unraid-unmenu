BEGIN {
#define ADD_ON_URL    unraid_main
#define ADD_ON_MENU   unRAID Main
#define ADD_ON_STATUS NO
#define ADD_ON_TYPE   awk
#define ADD_ON_VERSION   1.1 Joe L. -- Added parse of "ps" to check for non-standard emhttp port.
#UNMENU_RELEASE $Revision$ $Date$

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

  MyHost = CONFIG["unRAIDHost"] ? CONFIG["unRAIDHost"] : getHost()

  theHTML = "<br><iframe width=100% height=\"1200\" src=\"http://" MyHost "/main.htm\">"
  theHTML = theHTML "Sorry: your browser does not seem to support inline frames"
  theHTML = theHTML "</iframe>"

  print theHTML
}

function GetConfigValues(cfile) {
    RS="\n"
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^([^# \t=]+)([\t ]*)(=)([\t ]*)(.+)/, c)
          #print c[1,"length"] " " c[2,"length"] " " c[3,"length"] " "  c[4, "length"] " " c[5, "length"] " " line
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && 
               c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               CONFIG[substr(line,c[1,"start"],c[1,"length"])] = substr(line,c[5,"start"],c[5,"length"])
          }
    }
    close(cfile);
}

function getHost( theHostName) {
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
