BEGIN {
#define ADD_ON_URL         share_iso
#define ADD_ON_MENU        Share ISO
#define ADD_ON_STATUS      NO
#define ADD_ON_TYPE        awk
#define ADD_ON_VERSION     1.1  

  if ( MyHost == "" ) {
      "uname -n" | getline MyHost
      close("uname -n")
  }
  # You can override the default port from the command line too.
  if (MyPort ==  0) MyPort = 8080

  af=1
  fn=0

  # Internal strftime is always local time. We can request the offset (%z) and use it to calculate GMT time.
  # Get time-zone offset (needed for GMT timestamps in HTTP headers)
  # we multiply by -1 since we need to know GMT's offset from local, not local's offset from GMT
  tz_offset = ( strftime("%z", systime()) / 100 ) * 60 * 60 * -1

  CGI_setup();

  ORS = "\r\n"

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

  MyPrefix    = "http://" MyHost ":" MyPort

  idx=1
  top_menu=ARGV[4]
  n = split(top_menu,m,"|")
  for ( i = 1; i < n; i = i + 2) {
     url[idx] = m[i]
     menu[idx]  = m[i+1] 
     idx++
  }
  theMenu  = "<font size=\"-1\">"
  for ( a = 1; a<idx; a++ ) {
    top_menu = top_menu url[a] "|" menu[a] "|"
    if ( url[a] == "file_browser" ) {
        theMenu = theMenu " <nobr>" menu[a] "</nobr> " 
    } else {
        theMenu = theMenu " <nobr><A HREF=" MyPrefix "/" url[a] ">" menu[a] "</A></nobr> "
    }
    theMenu = theMenu "|"
  }
  theMenu=theMenu "</font>"

  #####################################################################################
  # We only respond to two types of requests.  
  # Those for directory listings, and those for files to be shared/un-shared
  # The directory listings and files are limited to those below the folders defined here
  #####################################################################################
  # Edit the list as locally in unmenu.conf as required.
  # DO NOT edit the file here.. as it will be overwritten if a new version of
  # the file browser is released.
  #####################################################################################
  GetAllowedFolders(ScriptDirectory "/" ConfigFile);
  GetAllowedFolders(ScriptDirectory "/" LocalConfigFile);

  # if the unmenu.conf file has a set of allowed folders, use them
  if ( fn > 0 ) {
     for ( a = 1; a <= fn; a++ ) {
        ALLOWED_FOLDER[af++] = allowed[a]
     }
  } else {
      # if it does not have any allowed folders defined, use the following default list
      ALLOWED_FOLDER[af++] = "/mnt/user/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk1/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk2/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk3/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk4/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk5/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk6/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk7/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk8/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk9/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk10/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk11/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk12/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk13/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk14/" 
      ALLOWED_FOLDER[af++] = "/mnt/disk15/" 
  }

  num_mounts=GetLoopMountedISO()
  
  if ( GETARG["unshare_iso"] != "" ) {
        theFile = GETARG["unshare_iso"]
        decodedFile = ""
        # desl with hex encoding of strings
        for ( i = 1; i<=length(theFile); i++ ) {
            if ( substr(theFile,i,1) == "%" ) {
               c=sprintf("%c", strtonum("0x" substr(theFile, i+1,2)))
               decodedFile = decodedFile c 
               i+=2
            } else {
               decodedFile = decodedFile substr(theFile,i,1)
            }
        }
        # deal with single quotes... end first quoted string, escape quote, start second string
        gsub("'","'\\''",decodedFile)
        theFile = decodedFile 
        OLD_RS = RS
        OLD_ORS = ORS
        ORS = "\r\n"

        response = ""
	base_name = getBaseName( theFile );
	#mount_name = substr( base_name, 1, length(base_name) - 4 )

	share_name = substr( base_name, 1, length(base_name) - 4 )
	mount_name = share_name
	gsub("\\\\'","",mount_name)
	gsub("'","",mount_name)

	# un-mount the file
	system("umount '" theFile "'" );
        num_mounts=GetLoopMountedISO()
        # Name of samba config file has changed as of unRAID 4.5-beta3
        if (system("test -f /etc/samba/smb-shares.conf")==0) {
          sharefile="/etc/samba/smb-shares.conf"
        } else {
          sharefile="/etc/samba/smb.shares"
        }
        old_sharefile = sharefile "_old"
        RS="\n"
        share_exists="n"
        # check to ensure share does exist
        while (( getline line < sharefile ) > 0 ) {
            if ( line ~ "\\[" mount_name "\\]" ) {
               share_exists="y"
            }
        }
        close(sharefile)
        ORS_OLD = ORS
        ORS = "\n"
        if ( share_exists == "y" ) {
           # Copy the smb.shares file to a temp file
           system("cp " sharefile " " old_sharefile)
           # Copy the smb.shares file back, but without the section for this shared folder
            delete_share_line="n"
            while (( getline line < old_sharefile ) > 0 ) {
              if ( delete_share_line == "y" && line ~ "\\[.*\\]" ) {
                 delete_share_line="n"
              }
              if ( line ~ "\\[" mount_name "\\]" ) {
                 delete_share_line="y"
              }
              if ( delete_share_line == "n" ) {
                 print line > sharefile
              }
           }
           close(sharefile)
           close(old_sharefile)
        }
        ORS = ORS_OLD
        cmd="smbcontrol smbd reload-config"
        while (( cmd | getline reload ) > 0) ;
        close(cmd);
  }

  if ( GETARG["share_iso"] != "" ) {
        theFile = GETARG["share_iso"]
        decodedFile = ""
        # desl with hex encoding of strings
        for ( i = 1; i<=length(theFile); i++ ) {
            if ( substr(theFile,i,1) == "%" ) {
               c=sprintf("%c", strtonum("0x" substr(theFile, i+1,2)))
               decodedFile = decodedFile c 
               i+=2
            } else {
               decodedFile = decodedFile substr(theFile,i,1)
            }
        }
        gsub("'","'\\''",decodedFile)
        theFile = decodedFile 
        #OLD_RS = RS
        #OLD_ORS = ORS
        #ORS = "\r\n"

        response = ""
	base_name = getBaseName( theFile );
	share_name = substr( base_name, 1, length(base_name) - 4 )
	mount_name = share_name
	gsub("\\\\'","",mount_name)
	gsub("''","",mount_name)

	
	# create the mount point
	system("mkdir -p '/var/tmp/mnt/" mount_name "'" );
	# mount using the loop device
	mcmd="mount -tiso9660 -o ro,loop '" theFile "' '/var/tmp/mnt/" mount_name "'"
	system(mcmd)
#	print mcmd "<br>"

        num_mounts=GetLoopMountedISO()
	# If successful, create a user-share, if not, display error

	if ( isLoopMounted( base_name )  == "n" ) {
		if ( num_mounts == 8 ) {
		   print "<hr><font color=red>Unable to mount " mount_name ".  Max number ISO Shares already exist.</font><br>"
         	} else {
		   print "<hr><font color=red>Unable to mount " mount_name ".</font><br>"
		}
	} else {
	# create the user share
	# Name of samba config file has changed as of unRAID 4.5-beta3
        if (system("test -f /etc/samba/smb-shares.conf")==0) {
          sharefile="/etc/samba/smb-shares.conf"
        } else {
          sharefile="/etc/samba/smb.shares"
        }
	RS="\n"
        share_exists="n"
        # check to ensure share does not already exist
        while (( getline line < sharefile ) > 0 ) {
          if ( line ~ "\\[" mount_name "\\]" ) {
               share_exists="y"     
          }
        }
            close(sharefile)
            if ( share_exists == "n" ) {
                  ORS_OLD = ORS
                  ORS = "\n"
                  print "[" mount_name "]" >> sharefile
                  print "        path = /var/tmp/mnt/" mount_name > sharefile
                  print "        read only = No" > sharefile
                  print "        force user = root" > sharefile
                  print "        map archive = Yes" > sharefile
                  print "        map system = Yes" > sharefile
                  print "        map hidden = Yes" > sharefile
                  close(sharefile)
                  ORS = ORS_OLD
            }
            # share it on the lan
            cmd="smbcontrol smbd reload-config"
            while (( cmd | getline reload ) > 0) ;
            close(cmd);
        }
	
     }

        OLD_RS = RS
        OLD_ORS = ORS
        ORS = "\r\n"


        theDir = GETARG["dir"]

        # the user is requesting a directory listing...
	# if the user did not specify a folder, or a file, present them with a list of potential "top-level" folders.
	# if they did specify a folder, use it.

        OLD_FS=FS
        FS=""
        out_html=""
        if ( theDir == "" ) {
              for ( a = 1; a < af ; a++ ) {
                  # this validates that the folders in the ALLOWED_FOLDER exist. 
                  # (in case the ALLOWED_FOLDER list is not edited or run on a system with fewer drives 
                  # than max permitted)
                  cmd = "ls -dl " ALLOWED_FOLDER[a] " 2>/dev/null "
                  while (( cmd | getline ) > 0 ) {
                     # we match on the first 8 whitespace delimited fields, and then use RLENGTH 
                     # to substring $0 to get the 9th onward.
                     # unfortunatly, the "ls" command is not fixed column width so we must resort to this.
                     match( $0, /[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]*/ )
                     theDir=substr($0,RLENGTH + 2,length($0))
                     gsub(/ /,"+",theDir)
                     out_html=out_html "<tr><td>&bull;&nbsp;<a href=\"http://" MyHost 
                     out_html=out_html ":" MyPort "/share_iso?dir=" theDir "\">" theDir "</a></td></tr>\r\n" 
                  }
                  close(cmd)
              }
              theDir = ""
          } else {
              theDirectory = theDir
              decodedDir = ""
              # deal with hex encoding of strings
              for ( i = 1; i<=length(theDirectory); i++ ) {
                if ( substr(theDirectory,i,1) == "%" ) {
                   c=sprintf("%c", strtonum("0x" substr(theDirectory, i+1,2)))
                   decodedDir = decodedDir c 
                   i+=2
                } else {
                   decodedDir = decodedDir substr(theDirectory,i,1)
                }
              }
              # deal with single quotes... end first quoted string, escape quote, start second string
              gsub("'","'\\''",decodedDir)
              # resolve the absolute path
              cmd="cd '''" decodedDir "''' 2>/dev/null && pwd || echo invalid-directory " 
              cmd | getline decodedDir
              close(cmd)
              theDir = decodedDir "/" 
              # user supplied a directory, make sure it is a subfolder of one allowed.
              allowed_folder="NO"
              for ( a = 1; a < af ; a++ ) {
                 if ( substr(theDir, 1, length(ALLOWED_FOLDER[a])) == ALLOWED_FOLDER[a] ) {
                    allowed_folder="YES"
                    break;
                 }
             }
             if ( allowed_folder == "YES" ) {
             # make sure folder exists.
             cmd = "ls -ald '" theDir "' 2>/dev/null "
             while (( cmd | getline ) > 0 ) {
                match( $0, /[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]*/ )
                theDir=substr($0,RLENGTH + 2,length($0))
                pdir = getParentDirectory( theDir )
                out_html = out_html "<tr><td ><b>File Name</b></td>"
                out_html = out_html     "<td align=\"right\"><b>Mode</b></td>"
                out_html = out_html     "<td align=\"right\"><b>Size</b></td>"
                out_html = out_html     "<td align=\"right\" ><b>Created</b></td><td>&nbsp;&nbsp;</td></tr>"
                out_html = out_html "<tr><td colspan=\"99\" align=\"left\">&bull;&nbsp;<a href=\"http://" MyHost
                out_html=out_html ":" MyPort "/share_iso?dir=" pdir "\"> .. (Parent Directory)</a></td></tr>\r\n" 
                out_html = out_html getDirectoryListing( theDir )
            }
            close(cmd)
        } else {
            out_html=out_html "<tr><td >Sorry: Access to " theDir " is not permitted.</td></tr>\r\n" 
        }
    }
    FS=OLD_FS

    theHTML = "<HTML><TITLE>Share ISO Browser</TITLE><HEAD>"
    theHTML = theHTML "</HEAD>"
    theHTML = theHTML "<BODY>"
    theHTML = theHTML "<STYLE type=\"text/css\">"
    theHTML = theHTML " td.d { font-family:courier;padding: 0px 5px 0px 5px;background-color:#e0e0e0; }" 
    theHTML = theHTML " td.l { font-family:courier;padding: 0px 5px 0px 5px;background-color:#ffffff; }" 
    theHTML = theHTML "</STYLE>"
    theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>Shared ISO files</strong></legend>"
    theHTML = theHTML "<table width=\"100%\" cellpadding=0 cellspacing=0>"
    theHTML = theHTML PrintLoopMounted()
    theHTML = theHTML "</table></fieldset>"
    theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>Share ISO Browser</strong></legend>"
    theHTML = theHTML "<table width=\"100%\" cellpadding=0 cellspacing=0>"
    if ( theDir == "" ) {
      theHTML = theHTML "<tr><td colspan=\"10\" align=\"left\">Choose from one of the top-level folders listed below:</td></tr>"
    } else {
      theHTML = theHTML "<tr><td colspan=\"10\" align=\"left\">Directory: " theDir "</td></tr>"
    }
    theHTML = theHTML "</table></fieldset>"
    theHTML = theHTML "<form><table cellspacing=0 border=1>"
    theHTML = theHTML out_html

    theHTML = theHTML "</table></form>"
    theHTML = theHTML "</BODY></HTML>" 

    response = ""
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

function getBaseName( file_name , fn, c) {
   delete fn;
   c = split(file_name, fn, "/")
   return fn[c];
}


# for a given path, return the parent folder.  If we are at the top of the list of allowed folders, return "" instead
function getParentDirectory( theDir , i, a, allowed_folder) {
    if ( substr(theDir, length(theDir),1) == "/" ) { 
	theDir = substr(theDir, 1,length(theDir) -1) 
    }
    for ( i = length(theDir) ; i > 0; i-- ) {
        if ( substr(theDir,i,1) == "/" ) {
           theParent = substr(theDir,1,i)
           break
        }
    }
    allowed_folder="NO"
    for ( a = 1; a < af ; a++ ) {
      if ( substr(theParent, 1, length(ALLOWED_FOLDER[a])) == ALLOWED_FOLDER[a] ) {
         allowed_folder="YES"
         break;
      }
    }
    if ( allowed_folder == "NO" ) theParent = ""
    return theParent
}

function getDirectoryListing( theDir , out_html, cmd) {
  out_html=""
  theDirectory = theDir

  # deal with embedded single quotes
  gsub("'","'\\''",theDirectory)
  cmd="ls -al --group-directories-first '" theDirectory "'" 

  tdclass=""
  while (( cmd | getline ) > 0 ) {
     # we match on the first 8 whitespace delimited fields, and then use RLENGTH to substring $0 to get the 9th onward
     # unfortunatly, the "ls" command is not fixed column width so we must resort to this.
     delete d;
     split($0, d, " ")
     match( $0, /[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]*/ )
     theFile=substr($0,RLENGTH + 2,length($0))
     if ( theFile == "." || theFile == ".." ) continue;
     gsub("'","%27",theDir)
#     gsub(" ","%20",theDir)
     theFileName = theFile
     if ( theFileName == "" ) { continue; }
     gsub(/ /,"%20",theFile)
     gsub("?","%3F",theFile)
     gsub("&","%26",theFile)
     gsub("'","%27",theFile)
     gsub(/\(/,"%28",theFile)
     gsub(/\)/,"%29",theFile)

     if ( substr(d[1],1,1) == "d" ) {
	theType="dir"
        theSlash="/"
     } else {
	theType="file"
        theSlash=""
     }

     # alternate color stripes
     if ( tdclass == "l" ) { tdclass="d" } else { tdclass = "l" }

     the_url = "share_iso"

     #  don't list non-ISO files
     if ( theType == "file" ) {
        if ( ! match( tolower(theFile) ,/.*\.iso$/) ) {
          continue;
	}
     }
     if ( theType == "dir" ) {
       out_html=out_html "<tr><td  class=\"" tdclass "\" >&bull;&nbsp;<a href=\"http://" MyHost 
       out_html=out_html ":" MyPort "/" the_url "?" theType "=" theDir theFile theSlash "\"><nobr>"
       out_html=out_html theFileName theSlash "</nobr></a></td>" 
     } else {
       out_html=out_html "<tr><td  class=\"" tdclass "\" >&bull;&nbsp;<nobr>"
       out_html=out_html theFileName theSlash "</nobr></td>" 
     }

     # file mode
     out_html=out_html "<td  class=\"" tdclass "\" >" d[1] "</td>" 
     # file size
     out_html=out_html "<td  class=\"" tdclass "\" align=\"right\">" d[5] "</td>" 
     # file date
     gsub(" ","\\&nbsp;",d[7])
     out_html=out_html "<td align=\"right\"  class=\"" tdclass "\">" d[6] " " d[7] " " d[8] "</td>"
#     if (theFile ~ ".ISO" || theFile ~ ".iso" ) { 
     if ( match( tolower(theFile) ,/.*\.iso$/) ) { 
       gsub(/ /,"%20",theDir)
       if ( isLoopMounted( theFile ) == "y" ) {
         out_html=out_html "<td><a href=\"http://" MyHost ":" MyPort "/share_iso?dir=" theDir "&unshare_iso=" theDir theFile theSlash "\">UnShare ISO</a></td>"
       } else {
         out_html=out_html "<td><a href=\"http://" MyHost ":" MyPort "/share_iso?dir=" theDir "&share_iso=" theDir theFile theSlash "\">Share ISO</a></td>"
       }
     } else {
       out_html=out_html "<td>&nbsp;</td>"
     }
     out_html=out_html "</tr>\r\n" 
  }
  close(cmd)
  return out_html
}

# open and read the unmenu configuration file.  In it, look for lines with the following pattern:
#variableName = ReplacementValue

# The values found there can be used to override values of some variables in these scripts.
# the CONFIG[] array is set with the variable.

function GetAllowedFolders(cfile) {
    RS="\n"
    while (( getline line < cfile ) > 0 ) {
          delete f;
          match( line , /^(ALLOWED_FOLDER)([\t ]*)(=)([\t ]*)(.+)/, f)
          if ( f[1,"length"] > 0 && f[2,"length"] > 0 && 
               f[3,"length"] > 0 && f[4, "length"] > 0 && f[5, "length"] > 0 ) {
               allowed[++fn] = substr(line,f[5,"start"],f[5,"length"])
          }
    }
    close(cfile);
}

function PrintLoopMounted ( out_str) {
	out_str=""
	for (a in loop_iso ) {
                if (loop_iso[a] ~ ".ISO$" || loop_iso[a] ~ ".iso$" || loop_iso[a] ~ "*$" ) { 
                    bn=getBaseName( loop_iso[a])
                    bn_len=length(bn)
                    dir_name=substr(loop_iso[a], 1, length(loop_iso[a]) - bn_len)
                    out_str = out_str loop_iso[a] " <a href=\"http://" MyHost ":" MyPort "/share_iso?dir=" dir_name "&unshare_iso=" loop_iso[a] "\">UnShare ISO</a><br>"
		    #out_str = out_str loop_iso[a] "<br>"
		}
	}
	if ( out_str == "" ) out_str = "No ISO files shared currently."
	return out_str
}

function isLoopMounted( theFile ,fn,fnl) {

	gsub("%27","'",theFile)
	gsub("'","",theFile)
# 	print "testing: " theFile "<br>"
	is_looped="n"
	for (a in loop_iso ) {
                fn=getBaseName(loop_iso[a])
                fnl=length(fn)
                if ( substr(fn,fnl , 1) == "*") {
                   fn=substr(fn,1,fnl - 1)
                }
# 		print " -- " fn "<br>"
		if ( theFile ~ fn ) {
	           is_looped="y"
#  	           print " -- LOOPED " loop_iso[a] "<br>"
                   break;
	        }
	}
        return is_looped
}
function OldGetLoopMountedISO ( cmd,lfile) {
    RS="\n"
    i=1
    cmd="losetup -a"
    delete loop_iso;
    delete f;
    while (( cmd | getline lfile ) > 0) {
        match(lfile, /^(\/dev\/loop[0-9]+:.*)( \()(.+)(\))$/, f)
	loop_iso[i]=f[3]
	gsub("'","",loop_iso[i])
	i++
    }
    close(cmd)
    return i - 1
}
function GetLoopMountedISO ( cmd,lfile) {
    RS="\n"
    i=1
    cmd="mount | grep \"loop=/dev/loop\""
    delete loop_iso;
    delete f;
    while (( cmd | getline lfile ) > 0) {
        match(lfile, /^(.*)( on \/var\/tmp\/mnt.*)$/, f)
	loop_iso[i]=f[1]
	gsub("'","",loop_iso[i])
	i++
    }
    close(cmd)
    return i - 1
}
