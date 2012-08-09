#define ADD_ON_MENU=Smart History
#define ADD_ON_URL=smarthistory
#define ADD_ON_VERSION=1.1 - added tests for directory, file, and php
#UNMENU_RELEASE $Revision$ $Date$
SMART_HISTORY_DIR="/boot/smarthistory"
SMART_HISTORY_PHP="smarthistory.php"
if [ ! -d "$SMART_HISTORY_DIR" ]
then
  echo "<font size=+2 color=red>Sorry: cannot run smarthistory.  <br><b>The $SMART_HISTORY_DIR directory does not exist.</b></font>"
  exit
fi
if [ ! -f "$SMART_HISTORY_DIR"/"$SMART_HISTORY_PHP" ]
then
  echo "<font size=+2 color=red>Sorry: cannot run smarthistory.  <br><b>The $SMART_HISTORY_DIR/$SMART_HISTORY_PHP file does not exist.</b></font>"
  exit
fi
cd "$SMART_HISTORY_DIR"
which php >/dev/null 2>&1
if [ $? = 1 ]
then
  echo "<font size=+2 color=red>Sorry: cannot run smarthistory.  <br><b>The \"php\" interperter is not installed.</b></font>"
  exit
fi
php "$SMART_HISTORY_PHP" -wake ON -output HTML -graph IMAGE -report ALL
