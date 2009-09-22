BEGIN {
#define ADD_ON_URL    links
#define ADD_ON_MENU   Useful Links
#define ADD_ON_STATUS YES
#define ADD_ON_TYPE   awk
#define ADD_ON_VERSION   1.1
#define ADD_ON_VERSION   1.2 Fixed increment of link counter

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

  extra_links = GetUsefulLinks(ScriptDirectory "/" ConfigFile);
  extra_links += GetUsefulLinks(ScriptDirectory "/" LocalConfigFile);

  theHTML = "<fieldset style=\"margin-top:10px;\"><legend><strong>Useful Links</strong></legend>"
  theHTML = theHTML "<table cellpadding=0 cellspacing=0>"

  # If links are defined in the unmenu.conf file, they are used INSTEAD of the ones coded here.  This allows local changes
  # without having to re-edit this plug-in.
  #
  # links should be defined in the unmenu.conf file as shown on the next line, but without the leading "#" character.
  #USEFUL_LINK = <a href="http://tower/main.htm">Standard unRAID Server Management Page</a>

  if ( extra_links > 0 ) {
      for ( a = 1; a <= extra_links; a++ ) { 
         theHTML = theHTML "<tr><td>" USEFUL_LINK[a] "</td></tr>" RS
      }
  } else {
      theHTML = theHTML "<tr><td><a href=\"http://lime-technology.com/forum/index.php\">Lime Technology Support Forum</a></td></tr>" RS
      theHTML = theHTML "<tr><td><a href=\"http://lime-technology.com/wiki/index.php?title=UnRAID_Wiki\">Lime Technology Wiki</a></td></tr>" RS
      theHTML = theHTML "<tr><td><a href=\"http://lime-technology.com/wiki/index.php?title=Best_of_the_Forums\">Best Of The Forums</a></td></tr>" RS
      theHTML = theHTML "<tr><td><a href=\"http://lime-technology.com/wiki/index.php?title=Troubleshooting\">Unraid Troubleshooting</a></td></tr>" RS
      theHTML = theHTML "<tr><td><a href=\"http://lime-technology.com/wiki/index.php?title=FAQ\">Frequently Asked Questions</a></td></tr>" RS
      theHTML = theHTML "<tr><td><a href=\"http://www.lime-technology.com\">Lime Technology Home Page</a></td></tr>" RS
  }

  theHTML = theHTML "</table></fieldset>" 
  print theHTML

}
function GetUsefulLinks(cfile) {
    RS="\n"
    additional_links=0
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^USEFUL_LINK([\t ]*)(=)([\t ]*)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && 
               c[3,"length"] > 0 && c[4, "length"] > 0 ) {
               additional_links++;
               USEFUL_LINK[additional_links] = substr(line,c[4,"start"],c[4,"length"])
          }
    }
    close(cfile);
    return additional_links
}
