BEGIN {
# we will supply our own HTTP headers and top-of-form title, etc, all the main process needs to do is send it onward to the browser.
#define ADD_ON_HTTP_HEADER NO
#define ADD_ON_URL         file_browser
#define ADD_ON_MENU        File Browser
#define ADD_ON_STATUS      NO
#define ADD_ON_TYPE        awk
#define ADD_ON_VERSION     1.0 
#define ADD_ON_VERSION     1.1 changes by RobJ 
#define ADD_ON_VERSION     1.1.1 added /mnt/disk access - by Joe L.
#define ADD_ON_VERSION     1.1.2 improved directory path validation - by Joe L.
#define ADD_ON_VERSION     1.1.3 added unmenu_local.conf file - by Joe L.
#define ADD_ON_VERSION     1.1.4 fixed handling of directory names with embedded spaces. Joe L.
#UNMENU_RELEASE $Revision$ $Date$

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
  # Those for directory listings, and those for files to be sent to the browser.
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

  # 10 Meg is max size to upload by default.  (Do not want to use all the memory and crash kernel. Keep well below 100Meg)
  MAX_UPLOAD_FILE_SIZE = CONFIG["MAX_UPLOAD_FILE_SIZE"] ? CONFIG["MAX_UPLOAD_FILE_SIZE"] : 10000000
  MAX_UPLOAD_FILE_SIZE = MAX_UPLOAD_FILE_SIZE + 0 # coerce to number

  if ( GETARG["file"] != "" ) {
        theFile = GETARG["file"]
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
        content_type =  getContentType( base_name )
	http_headers=GetHTTP_Header( content_type , base_name)

        response = http_headers ORS

        cmd="cat '" theDirectory "/" theFile "'"
        # For this Regular Expression to work we need the -W re-interval option on the command line
        RS = ".{1,128}" # read 128 bytes at a time, this should allow us to handle binary data
        while (( cmd | getline theContent ) > 0 ) {
           doc_length = sprintf("%x", length(RT));
           response = response doc_length ORS RT ORS
        }
        # Send the final zero length "chunk"
        response = response "0"
        print response

        RS = OLD_RS
        ORS = OLD_ORS
  } else { 
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
                     out_html=out_html ":" MyPort "/file_browser?dir=" theDir "\">" theDir "</a></td></tr>\r\n" 
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
                 out_html = out_html     "<td align=\"right\" ><b>Created</b></td></tr>"
                 out_html = out_html "<tr><td colspan=\"99\" align=\"left\">&bull;&nbsp;<a href=\"http://" MyHost
                 out_html=out_html ":" MyPort "/file_browser?dir=" pdir "\"> .. (Parent Directory)</a></td></tr>\r\n" 
                 out_html = out_html getDirectoryListing( theDir )
              }
              close(cmd)
              } else {
                     out_html=out_html "<tr><td >Sorry: Access to " theDir " is not permitted.</td></tr>\r\n" 
              }
          }
          FS=OLD_FS

          theHTML = "<HTML><TITLE>File Browser</TITLE><HEAD><script type=\"text/javascript\">"
          theHTML = theHTML "function tb(){ alert('Sorry: too big to open via unmenu awk based web-server'); return false; }</script></HEAD>"
          theHTML = theHTML "<BODY>"
          theHTML = theHTML "<STYLE type=\"text/css\">"
          theHTML = theHTML " td.d { font-family:courier;padding: 0px 5px 0px 5px;background-color:#e0e0e0; }" 
          theHTML = theHTML " td.l { font-family:courier;padding: 0px 5px 0px 5px;background-color:#ffffff; }" 
          theHTML = theHTML "</STYLE>"
	  theHTML = theHTML "<table width=\"100%\" cellpadding=0 cellspacing=0 border=0>"
          theHTML = theHTML "<tr><td align=\"left\" width=\"40%\">"
	  #theHTML = theHTML "<a href=\"http://" MyHost ":" MyPort "/\">Main</a>" 
          theHTML = theHTML theMenu
	  theHTML = theHTML "</td><td width=\"15%\"><font size=\"3\"><b>" 
	  theHTML = theHTML MyHost " unRAID Server</b></font></td><td width=\"35%\" align=\"right\">"
          theHTML = theHTML strftime() "</td></tr></table>"
	  theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>File Browser</strong></legend>"
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
	  http_headers=GetHTTP_Header( "text/html", "" )
          response = http_headers ORS

          doc_length = sprintf("%x", length(theHTML));
          response = response doc_length ORS theHTML ORS

          response = response "0"
          print response

  }

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

function GetHTTP_Header( type, file_name, header) {
    header =        "HTTP/1.1 200 OK" "\r\n"
    header = header "Connection: Close" "\r\n"
    header = header "Pragma: no-cache" "\r\n"
    header = header "Cache-Control: private, max-age=0" "\r\n"
    header = header strftime("Date: %a, %d %b %Y %H:%M:%S GMT", (systime() + (tz_offset))) "\r\n"
    header = header "Expires: -1\r\n"
    if ( type == "application/octet-stream" ) {
       header = header "Content-disposition: attachment;filename=" file_name  "\r\n"
    } 
    header = header "Content-Type: " type "\r\n"
    header = header "Transfer-Encoding: chunked" "\r\n"
    return header
}

function getContentType( file_name, exten, x, idx) {
  #########################################################
  # Set up some content type definitions based on
  # file extensions normally used.
  #########################################################
  EXT["html"]   = "text/html";
  EXT["htm"]    = "text/html";
  EXT["jpg"]    = "image/jpeg";
  EXT["jpeg"]   = "image/jpeg";
  EXT["zip"]    = "image/zip";
  EXT["gz"]     = "image/gz";
  EXT["tar"]    = "image/tar";
  EXT["gif"]    = "image/gif";
  EXT["txt"]    = "text/plain";

   # return the file "type" based on the extension of the file
   # Use split to find the file extension
   idx = split(file_name, exten, ".")
   x = tolower(exten[idx])

   if ( EXT[x] != "" ) {
       # using the associative array, return the content type.
       return EXT[x];
   } else {
       # we don't know how to deal with it, so let the user's browser figure it out as an upload.
       return "application/octet-stream"
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

     # If the file is over MAX Allowed size, do not attempt to send it to the browser, give a warning instead.
     if ( d[5] > MAX_UPLOAD_FILE_SIZE && substr(d[1],1,1) != "d" ) {
        out_html=out_html "<tr><td class=\"" tdclass "\" >&bull;&nbsp;<a href=\"#\" onclick=\"javascript:tb(); return false;\"<nobr>"
        out_html=out_html theFileName theSlash "</nobr></a></td>" 
     } else {
        # Special handling of *syslog*.txt files, open via the syslog viewer
        if ( theType == "file" && match( tolower(theFile) ,/.*syslog.*\.txt/) ) {
            the_url = "system_log"
        } else {
            the_url = "file_browser"
        }
        out_html=out_html "<tr><td  class=\"" tdclass "\" >&bull;&nbsp;<a href=\"http://" MyHost 
        out_html=out_html ":" MyPort "/" the_url "?" theType "=" theDir theFile theSlash "\"><nobr>"
        out_html=out_html theFileName theSlash "</nobr></a></td>" 
     }
     # file mode
     out_html=out_html "<td  class=\"" tdclass "\" >" d[1] "</td>" 
     # file size
     out_html=out_html "<td  class=\"" tdclass "\" align=\"right\">" d[5] "</td>" 
     # file date
     gsub(" ","\\&nbsp;",d[7])
     out_html=out_html "<td align=\"right\"  class=\"" tdclass "\">" d[6] " " d[7] " " d[8] "</td>"
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
          delete f;
          match( line , /^(MAX_UPLOAD_FILE_SIZE)([\t ]*)(=)([\t ]*)(.+)/, f)
          if ( f[1,"length"] > 0 && f[2,"length"] > 0 && 
               f[3,"length"] > 0 && f[4, "length"] > 0 && f[5, "length"] > 0 ) {
               CONFIG["MAX_UPLOAD_FILE_SIZE"] = substr(line,f[5,"start"],f[5,"length"])
          }
    }
    close(cfile);
}
