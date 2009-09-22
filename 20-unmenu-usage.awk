BEGIN {
#define ADD_ON_URL     usage
#define ADD_ON_MENU    Disk Usage
#define ADD_ON_STATUS  YES
#define ADD_ON_TYPE    awk
#define ADD_ON_VERSION 1.0

  CGI_setup();

  theHTML = ""
  theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>Disk Usage</strong></legend>"
  theHTML = theHTML "<table width=\"100%\"><form method=\"GET\">"
  if ( GETARG["Status"] == "STARTED" ) {
  	theHTML = theHTML "<tr><td><input type=\"submit\" name=\"usage\" value=\"Disk Usage\"></td>"
  	theHTML = theHTML "<td>Press the \"Disk Usage\" button to see the disk usage for the shared "
  	theHTML = theHTML "folders on each of the disks in the unRAID array.<br>This will take a bit of time, as "
  	theHTML = theHTML "it must scan every directory on every disk. If disks are spun down, they may spin up "
        theHTML = theHTML "if the disk directory entries are not already in memory.</td></tr>"

	if ( GETARG["usage"] == "Disk+Usage" ) {
	    theHTML = theHTML "<tr><td colspan=2>"
	    #cmd="du -s --si /mnt/user/* /mnt/disk*/* 2>/dev/null | awk ' { print $2 \"|\" $1 }' | sort"
	    cmd="du -s --si /mnt/user/* /mnt/disk*/* 2>/dev/null | awk ' { print substr($0,length($1) + 1) \"|\" $1 }' | sort"


	    RS="\n"
	    disk_usage=""
	    disk_usage="<table cellpadding=0 cellspacing=0 width=\"100%\"><tr><td>"
	    disk_usage=disk_usage "<fieldset style=\"margin-top:10px;\"><legend><strong>Shared Folder Disk Usage</strong></legend>"
	    disk_usage=disk_usage "<table width=\"100%\" cellpadding=0 cellspacing=0 border=0>"
	    disk_usage=disk_usage "<tr><td align=\"center\" width=\"10%\"><b><u>Usage</u></b>"
	    disk_usage=disk_usage "</td><td align=\"left\" width=\"90%\"><b><u>Disk Folder</u></b></td></td></tr>"
	    while (( cmd | getline f ) > 0) {
		delete u;
		split(f,u,"|");
		disk_usage=disk_usage "<tr><td align=\"center\" width=\"10%\">" u[2] 
		disk_usage=disk_usage "</td><td align=\"left\" width=\"90%\">" u[1] "</td></td></tr>"
	    }
	    close(cmd)
	    disk_usage = disk_usage "</table>"
	    theHTML = theHTML disk_usage "</td></tr>"
	}

  } else {
  	theHTML = theHTML "<tr><td>Disk usage statistics are not available when the array is not started.</td></tr>"
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
