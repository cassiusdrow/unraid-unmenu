BEGIN {
#ADD_ON_URL=system_log
#ADD_ON_MENU=Syslog
#ADD_ON_STATUS=YES
#ADD_ON_TYPE=awk
#ADD_ON_OPTIONS=-f drivedb.lib.awk -f unmenu.base.lib.awk -f utility.lib.awk
#ADD_ON_VERSION= Version: .4b - contributed by RobJ
#ADD_ON_VERSION= Version: .5a - modified by RobJ
#ADD_ON_VERSION= Version: .5a1 - modified by RobJ
#ADD_ON_VERSION= Version: .4c - modified by Joe L.
#ADD_ON_VERSION= Version: .6  - modified by RobJ
#ADD_ON_VERSION= Version: .6a - modified by Joe L.
#ADD_ON_VERSION= Version: .7  - modified by RobJ
#ADD_ON_VERSION= Version: .8  - modified by Joe L. to use a pattern file.
#ADD_ON_VERSION= Version: .9  - modified by Joe L. to escape special charaters
#ADD_ON_VERSION= Version: 1.0  - modified by bjp999, Use common routines to generate enhanced syslog viewer
#UNMENU_RELEASE $Revision$ $Date$

   #-----------------
   # Initializations
   #-----------------
   CGI_setup();

   CONFIG_FILE      = "myMain_local.conf"

   amp="AMP3RS4ND"

   nbsp = amp "nbsp;"

   LoadConfigFile("myMain.conf", configDefault, (1==1))
   LoadConfigFile(CONFIG_FILE, configLocal, (1==1))

   print SyslogHtml(GETARG["syslog"], constant["SyslogStyle"], (1==1));

}
