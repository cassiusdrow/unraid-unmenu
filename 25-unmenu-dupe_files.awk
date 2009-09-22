BEGIN {
#define ADD_ON_URL     dupe_files
#define ADD_ON_MENU    Dupe Files
#define ADD_ON_STATUS  YES
#define ADD_ON_TYPE    awk
#define ADD_ON_VERSION 1.1
#define ADD_ON_VERSION 1.2 deal with appostraphe in file name

  CGI_setup();

  theHTML = ""
  theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>Duplicate Files</strong></legend>"
  theHTML = theHTML "<table width=\"100%\" cellpadding=2 cellspacing=2><form method=\"GET\">"
  theHTML = theHTML "<tr><td valign=\"top\"><input type=\"submit\" name=\"usage\" value=\"Dupe Files\"></td>"
  theHTML = theHTML "<td valign=\"top\">Press the \"Dupe Files\" button to list the duplicate files that exist in "
  theHTML = theHTML "multiple parallel /mnt/disk* folders, but where only one can be shown in the user share."
  theHTML = theHTML " These are logged by the User-share process to /var/log/syslog, but the entries do not give enough information to"
  theHTML = theHTML " easily deal with the files."
  theHTML = theHTML "<br>To locate duplicates, this process must scan for files on all disks with similar directory paths "
  theHTML = theHTML "to those in the syslog. <br><b>This process may take a while, please be patient and wait for the browser to refresh."
  theHTML = theHTML " If disks are spun down, they may spin up as directories are scanned if their directory entries are not in memory.</b></td></tr>"
  
  if ( GETARG["usage"] == "Dupe+Files" ) {
    theHTML = theHTML "<tr><td colspan=2>"
    RS="\n"
    dupe_files=""

    dupe_files="<table cellpadding=0 cellspacing=0 width=\"100%\"><tr><td>"
    dupe_files=dupe_files "<fieldset style=\"margin-top:10px;\">"
    dupe_files=dupe_files "<legend><strong>Duplicate Files on Disk Shares</strong></legend>"
    dupe_files=dupe_files "<table width=\"100%\" cellpadding=0 cellspacing=0 border=0>"
    dupe_files=dupe_files "<tr><td align=\"center\" width=\"2%\">&nbsp;"
    dupe_files=dupe_files "</td><td align=\"left\" width=\"98%\"><b><u>File</u></b></td></td></tr>"

    # basically, if a "duplicate object" name is found in the syslog that looks like 
    # this "/mnt/disk5/Movies/x/y/z/file_name.avi" the "sed" script below (with all the backslashes)
    # applies the edit as shown below to convert the name into "/mnt/*/Movies/x/y/z/file_name.avi" 
    # and then does an "ls -lad /mnt/*/Movies/x/y/z/file_name.avi"
    # Since we are looking for parallel folders on multiple /mnt/disk(s) it will list the duplicated files
    #
    # I just kept adding backslashes until it worked... honest... Joe L.
    # or... as it says in the subway advertisements... "If U cn rd this, U can get a gud job"
    cmd="tail -10000 /var/log/syslog | grep \"duplicate object\" | sed \"s/  / /g\" | cut -d\" \" -f8- |"
    cmd = cmd "sed -e \"s/^\\\\/[^\\\\/]*\\\\/[^\\\\/]*\\\\/\\\\(.*\\\\)/ls -lad \\\\/mnt\\\\/*\\\\/'\\\\1'/\""
    cmd = cmd " | tr \"'\" \"*\"  | sort -u |  sh - "
    #print cmd "<br>"
    while (( cmd  | getline f ) > 0 ) {
        if ( f ~ "/mnt/user" ) continue
	dupe_files=dupe_files "<tr><td align=\"center\" width=\"2%\">&nbsp;"
	dupe_files=dupe_files "</td><td  style=\"font-family:courier\" align=\"left\" width=\"98%\">" f "</td></td></tr>"
    }
    close(cmd)

    dupe_files = dupe_files "</table>"
    theHTML = theHTML dupe_files "</td></tr>"
  }

  theHTML = theHTML "</form></table></fieldset>" 
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
