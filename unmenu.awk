#UNMENU_RELEASE $Revision$ $Date$
BEGIN {
  # Copyright Joe L. 2008.
  #
  # This web-server is not guaranteed to be able to do anything, 
  # but it does not have a "Restore" button, therefore, it is an improvement to many.
  # It does offer a lot of features not available in the stock unRAID web-server and
  # since it supports plug-in modules, can be extended to just about any need. 
  #
  # invoke as:
  #     awk -W re-interval -f unmenu.awk
  # or to use a port other than 8080
  #     awk -v MyPort=90 -W re-interval -f unmenu.awk
  #
  # point browser to http://tower:8080
  #
  theRevision=""
  while (( getline line < "unmenu.awk" ) > 0 ) {
      # Expect a string describing the release of the plug-in
      if ( substr(line,1,15) == "#UNMENU_RELEASE" ) {
          theRevision = substr(line,17, 16)
          gsub("\\$","",theRevision)
          break;
      }
  }
  close("unmenu.awk")
  
  version = "Version 1.3 " theRevision " Joe L.... with modifications as suggested by bjp999 and many others"
  
  # Plug-in scripts are expected to reside in the same directory where this program is invoked if the following
  # variable is not changed.  If you wish to speciify a different directory for the plug-in scripts, you
  # can change this accordingly.
  ScriptDirectory=""

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

  GetConfigValues(ScriptDirectory "/" ConfigFile, "");
  GetConfigValues(ScriptDirectory "/" LocalConfigFile, "");


  #####################################################################################
  # Some site specific variables are defined below here.  
  # You may change them as you desire in the unmenu_local.conf file.
  # PLEASE DO NOT CHANGE THEM IN THIS FILE.  If you do, they will get overwrittten
  # when a new version of unmenu.awk is released.
  #####################################################################################

  # Main page "auto" refresh interval in seconds is set here. Other pages are NOT auto refreshed. 
  # If you wish a different refresh interval, set the corresponding value in unmenu.conf
  # Note, auto refresh occurs ONLY when array state = STARTED
  REFRESH_INTERVAL = CONFIG["REFRESH_INTERVAL"] ? CONFIG["REFRESH_INTERVAL"] : 60

  # If you like geek style 1024 byte sizes, rather than marketing 1000 byte sizes, then set this to 1024
  # in the unmenu.conf file
  OneThousand = CONFIG["OneThousand"] ? CONFIG["OneThousand"] : 1000

  # Warning temperature ranges for hard disks are set here. Main screen disk temperature output is color coded.
  # override these default values by setting them in unmenu.conf file
  yellow_temp = CONFIG["yellow_temp"] ? CONFIG["yellow_temp"] : 40
  orange_temp = CONFIG["orange_temp"] ? CONFIG["orange_temp"] : 45
  red_temp    = CONFIG["red_temp"]    ? CONFIG["red_temp"]    : 50

  # Samba File Create and Directory Create masks (by default, the same as unRAID)
  create_mask    = CONFIG["create_mask"]    ? CONFIG["create_mask"]    : "711"
  directory_mask = CONFIG["directory_mask"] ? CONFIG["directory_mask"] :  "711"

  # If not otherwise defined in the unmenu.conf file, show 6 syslog lines on the main page
  # If set to 0, show no lines.
  syslog_main_lines = CONFIG["syslog_main_lines"] ? CONFIG["syslog_main_lines"] : 6

  # If desired, set iframes with used defined content at bottom of main page.
  main_page_user_content = CONFIG["main_page_user_content"] ? CONFIG["main_page_user_content"] : ""

  # You can override the host name from the command line so all references willl be 
  # by IP adddress rather than by Server Name
  # like this:  awk -v MyHost=192.168.2.100 -W re-interval -f unmenu.awk
  # the server name can also be set in the unmenu.conf file as MyHost = Hostname.
  if ( MyHost == "" ) {
    MyHost = CONFIG["MyHost"] ? CONFIG["MyHost"] : getHost()
  } 

  # You can override the default port (8080) from the command line too. 
  # (use an additional -v variableName=replacementValue for each variable to be set)
  # like this:  awk -v MyHost=192.168.2.100 -v MyPort=90 -W re-interval -f unmenu.awk
  # the port can also be set in the unmenu.conf file as MyPort = NN.
  if (MyPort ==  0) {
    MyPort = CONFIG["MyPort"] ? CONFIG["MyPort"] : 8080
  }

  if ( DebugPlugInCommand == "" ) { 
      DebugPlugInCommand = "no"; 
  }
  if ( DebugMode == "" ) { 
      DebugMode = "no"; 
  }
  DebugMode = CONFIG["DebugMode"] ? CONFIG["DebugMode"] : DebugMode
  DebugMode = tolower(DebugMode)
  #####################################################################################
  # End of site specific variables.  
  #
  # You will not need to make any changes below this point in the file unless
  # you have a desire to tinker with the built in pages. 
  # (and you really don't need to make any above here in most cases)
  #
  # If you make improvements, please share them.  It you find a bug, let me know and
  # I'll fix it in my version too. If you write a really neat plug-in, share it too. 
  # Hopefully, the comments in the code will make your task easier.
  #
  # Joe L.
  #####################################################################################

  HttpService = "/inet/tcp/" MyPort "/0/0"
  MyPrefix    = "http://" MyHost ":" MyPort
  Status      = 200             # this means OK
  Reason      = "OK"
  SambaStatus=""

  # Internal strftime is always local time. We can request the offset (%z) and use it to calculate GMT time.
  # Get time-zone offset (needed for GMT timestamps in HTTP headers)
  # we multiply by -1 since we need to know GMT's offset from local, not local's offset from GMT
  tz_offset = ( strftime("%z", systime()) / 100 ) * 60 * 60 * -1

  # open unmenu "plug-in" script directory, 
  # look for any "NN-unmenu-*.awk" scripts and any "NN-unmenu-*.cgi" scripts.
  # for each script, open it to read the desired menu entry for the top menu
  # also, read the "url" it will appear to be to the end-user
  # and get the flag that will determine if the standard top-of-screen status box should not be used
  # later, if the "url" is matched, it will be invoked and the output, expected in html, 
  # will be sent to the user's browser.
  # When a plug-in is invoked, the array status, METHOD, and querrystring parameters are passed 
  cmd="ls " ScriptDirectory "/[0-9]*-unmenu-*.awk " ScriptDirectory "/[0-9]*-unmenu-*.cgi 2>/dev/null"
  add_on_count=0
  while (( cmd | getline add_on_awk_script ) > 0) {
    add_on[add_on_count] = add_on_awk_script;
    add_on_status[add_on_count]="YES"  # default is to have top status box.
    add_on_http_header[add_on_count]="YES"  # default is to have HTTP header included
    add_on_top_heading[add_on_count]="YES"  # default is to have top of page heading included
    add_on_html_tags[add_on_count]="YES"    # default is to supply <HTML><HEAD>...</HEAD><BODY>...</BODY></HTML>
    add_on_version[add_on_count]="(ADD_ON_VERSION not specified in plug-in, default version assigned) 0.1" 
    add_on_release[add_on_count] = ""
    add_on_head_count[add_on_count] = 0
    add_on_count++;
  }
  close(cmd);
  # now, process each script in turn.  Open them, scan for their url, menu label, type, 
  # and other parameters as described below.
  # Only ADD_ON_URL, ADD_ON_MENU and ADD_ON_TYPE are required to exist in the plug-in.
  for ( i = 0; i < add_on_count; i++ ) {
    while (( getline line < add_on[i] ) > 0 ) {
      # Expect a string describing the release of the plug-in
      if ( substr(line,1,15) == "#UNMENU_RELEASE" ) {
          add_on_release[i] = substr(line,17, 16)
          gsub("\\$","",add_on_release[i])
      }
      if ( line ~ "ADD_ON_" ) {
          delete c;
          # expect the URL to be used on the top menu
          match( line , /^(#ADD_ON_URL|#define\WADD_ON_URL)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_url[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          # expect the Label to be used on the top menu, if no label, the plug-in can only be
          # be invoked by specifing the URL
          match( line , /^(#ADD_ON_MENU|#define\WADD_ON_MENU)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_menu[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          # expect YES or NO... default=YES,  NO = do not include top status box
          delete c;
          match( line , /^(#ADD_ON_STATUS|#define\WADD_ON_STATUS)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_status[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          # expect "awk" or "??? (anything other than awk is invoked as executible command)"
          delete c;
          match( line , /^(#ADD_ON_TYPE|#define\WADD_ON_TYPE)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_type[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          # expect YES or NO... YES = include <HTML><HEAD><TITLE></TITLE></HEAD><BODY> ... </BODY></HTML> 
          # NO = let plug in supply
          delete c;
          match( line , /^(#ADD_ON_HTML_TAGS|#define\WADD_ON_HTML_TAGS)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_html_tags[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          # expect YES or NO... YES = include top of page heading, NO = do not show heading
          delete c;
          match( line , /^(#ADD_ON_PAGE_HEADING|#define\WADD_ON_PAGE_HEADING)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_top_heading[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          # expect YES or NO... default=YES include HTTP header, 
          # NO = plug-in will supply HTTP header lines and ALL subsequent content on page
          delete c;
          match( line , /^(#ADD_ON_HTTP_HEADER|#define\WADD_ON_HTTP_HEADER)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_http_header[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          # Expect the name of an configuration for for this add-on.
          # in it, we will look for specific definitions... at this time AUTO_REFRESH
          delete c;
          match( line , /^(#ADD_ON_CONFIG|#define\WADD_ON_CONFIG)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_config[i] = substr(line,c[3,"start"],c[3,"length"])
              if ( DebugMode == "yes" ) { 
                  print "defined plug-in config:" add_on_config[i] 
              }
          }
          # Expect the name of a local configuration for for this add-on.
          # in it, we will look for specific definitions... at this time AUTO_REFRESH
          delete c;
          match( line , /^(#ADD_ON_LOCAL_CONFIG|#define\WADD_ON_LOCAL_CONFIG)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_local_config[i] = substr(line,c[3,"start"],c[3,"length"])
              if ( DebugMode == "yes" ) { 
                  print "defined plug-in local config:" add_on_local_config[i] 
              }
          }
          # Expect a string describing the version of the plug-in
          delete c;
          match( line , /^(#ADD_ON_VERSION|#define\WADD_ON_VERSION)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_version[i] = substr(line,c[3,"start"],c[3,"length"])
          }
          delete c;
          # special lines to be included in <head> </head> of plug-in
          # multiple lines are allowed
          match( line , /^(#ADD_ON_HEAD|#define\WADD_ON_HEAD)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_head_count[i]++
              add_on_head[i, add_on_head_count[i]] = substr(line,c[3,"start"],c[3,"length"])
          }
          # Expect a string describing additional options to supply for a plug-in
          delete c;
          match( line , /^(#ADD_ON_OPTIONS|#define\WADD_ON_OPTIONS)([\t =]+)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
              add_on_options[i] = substr(line,c[3,"start"],c[3,"length"])
          }
      }
    }
    close(add_on[i]);
  }
  for ( i = 0; i < add_on_count; i++ ) {
    if ( add_on_config[i] != "" ) {
      GetConfigValues(ScriptDirectory "/" add_on_config[i], "pi-" i );
      if ( DebugMode == "yes" ) { 
          print "importing plug-in config values:" add_on_config[i] 
      }
    }
    if ( add_on_local_config[i] != "" ) {
      GetConfigValues(ScriptDirectory "/" add_on_local_config[i], "pi-" i );
      if ( DebugMode == "yes" ) { 
          print "importing local plug-in config values:" add_on_local_config[i] 
      }
    }
  }
  # for debugging, print the plug-in scripts found and imported.
  if ( DebugMode == "yes" ) { 
     for ( i = 0; i < add_on_count; i++ ) {
       print "importing:" add_on_url[i] " as \"" add_on_menu[i] "\" from " add_on[i]
     } 
  }

  Footer      = "</BODY></HTML>"
  
  while ("3.14159" != "PI") {
      if ( DebugMode == "yes" ) { 
         print "opening port to listen for requests"
      }

      # We block here waiting for a new request from the browser
      HttpService |& getline                 # wait for new client request

      if ( DebugMode == "yes" ) { 
         print strftime(), $0                        # do some logging
      }

      arg1=$1
      arg2=$2

      CGI_setup($1, $2, $3)                  # read request parameters
      if ((GETARG["Method"] == "GET") || (GETARG["Method"] == "POST")) { 

         #Thanks to  bjp999 we can now also handle POST as well as GET requests.
         # one tiny limitation, the last character of the last field on the form
         # cannot be read from the input TCP/IP stream without the server blocking
         # waiting for more input.  So, include a "unused" hidden field as the LAST field
         # on a form and expect to lose the last character of its value.
         if(GETARG["Method"] == "POST") {
            tRS=RS
            RS="\r\n"

            while(1) {
               HttpService |& getline li   # process POST for new client request
               if(li=="")
                  break;
               delete d;
               split(li,d,":")
               if(d[1] == "Content-Length")
                  len=d[2]+0;
            }
            # if we were to read the entire form, we would block waiting for more from the browser.
            # we must read one character less than available, so we will not block and can send a
            # response back to the client's browser.
            RS = ".{" len-1 "}"
            HttpService |& getline li 
            form_field_string = arg2 "?" RT
            #perr("form_field_string='" form_field_string "'")

            RS=tRS
         } else {
            form_field_string=arg2
         }

          built_in_matched="n"
          plug_in_matched="n"
          special_matched="n"

          # see if we match any of the plug-in modules
            for ( i = 0; i < add_on_count; i++ ) {
               if ( MENU[2] == add_on_url[i] ) {
                  plug_in_matched="y"   # we'll handle the request with a plug-in.
                  GetArrayStatus()

                  # newer modules will be able to tell the difference between their initial GET 
                  # and a subsequent POST of their form as the METHOD is passed as arg1..

                  plugin_options = add_on_options[i] != "" ? add_on_options[i] : ""
                  # set up the command to invoke the add-on
                  if ( add_on_type[i] == "awk" ) {
                      cmd="gawk -v ConfigFile=" ConfigFile " -v MyHost=" MyHost " -v ScriptDirectory=" ScriptDirectory 
                      if ( LocalConfigFile != "" ) {
                          cmd = cmd " -v LocalConfigFile=" LocalConfigFile
                      }
                      cmd = cmd " -v MyPort=" MyPort " -W re-interval " plugin_options " -f " add_on[i] " " array_state " " arg1 " '" form_field_string "' '" top_menu "'"
                  } else { # this is a "cgi" script.  It should be execuitable. It can be shell, etc.
                      cmd= "ConfigFile='" ConfigFile "' MyHost='" MyHost "' MyPort='" MyPort "' "
                      if ( LocalConfigFile != "" ) {
                          cmd = cmd "LocalConfigFile='" LocalConfigFile "' "
                      }
                      cmd = cmd "ScriptDirectory='" ScriptDirectory "' " add_on[i] " " plugin_options " " array_state " " arg1 " '" form_field_string "' '" top_menu "'"
                  }
                  #perr("arg1='" arg1 "'")
                  #perr("arg2='" arg2 "'")
                  #perr(cmd)

                  # If we will display the <HTML><TITLE></TITLE><HEAD></HEAD><BODY> tags, set it up
                  Header=""
                  if ( add_on_html_tags[i]=="YES" ) {
                      Header = GetPageHEAD(i);
                  }

                  # If we will display the top_of_page heading menu, set it up
                  PageMenu=""
                  if ( add_on_top_heading[i]== "YES" ) {
                      PageMenu = SetUpTopMenu(MENU[2]);
                  }

                  # If we will display the array status, set it up.
                  ArrayStatusDoc=""
                  if ( add_on_status[i] == "YES" ) {
                      ArrayStatusDoc = ArrayStateHTML();
                  }

                  OLD_RS = RS
                  OLD_ORS = ORS
                  ORS = "\r\n"

                  first_chunk="y"
                  # For this Regular Expression to work we need the -W re-interval option on the command line
                  RS = ".{1,128}" # read 128 bytes at a time from the plug-in, this should allow us to handle binary data
                                  # Originally we tried a much larger size "chunk", it slowed the plug-in pages down dramatically

                  response=""
                  if ( DebugPlugInCommand != "no" ) {
                    DebugPlugInCommand="<br>" cmd "<br>"
                  }
                  while (( cmd | getline html ) > 0 ) {
                      if ( add_on_http_header[i] == "YES" ) {
                          if ( first_chunk == "y" ) {
                              first_chunk = "n"
                              if( array_state == "STARTED") {
                                plug_in_refresh_interval = CONFIG["pi-" i "ADD_ON_REFRESH"] ? CONFIG["pi-" i "ADD_ON_REFRESH"] : 0
                              } else {
                                plug_in_refresh_interval = 0
                              }
                              # We supply a HTTP header before the first chunk
                              # note, we handle everything here as text/html.
                              http_headers = GetHTTP_Header("text/html", plug_in_refresh_interval, add_on_url[i] ) 
                              response = http_headers ORS
                              if ( add_on_html_tags[i]=="YES" ) {
                                  doc_length = sprintf("%x", length(Header));
                                  response = response doc_length ORS Header ORS
                              }
                              if ( PageMenu != "" ) {
                                  doc_length = sprintf("%x", length(PageMenu));
                                  response = response doc_length ORS PageMenu ORS
                              }
                              if ( ArrayStatusDoc != "" ) {
                                  doc_length = sprintf("%x", length(ArrayStatusDoc));
                                  response = response doc_length ORS ArrayStatusDoc ORS
                              }
                              if ( DebugPlugInCommand != "no" ) {
                                  doc_length = sprintf("%x", length(DebugPlugInCommand));
                                  response = response doc_length ORS DebugPlugInCommand ORS
                              }
                          }
                          doc_length = sprintf("%x", length(RT));
                          response = response doc_length ORS RT ORS
                      } else { 
                          # if add_on_http_header = "NO", EVERYTHING IS DONE IN THE PLUG-IN. 
                          # All we do here is read it in and then send to the waiting browser. 
                          # In other words, the plug-in supplies the HTTP header and text.
                          #  
                          # Note: this code concatenates the 128 byte chunks of the output and 
                          # will use all of memory if you attempt to send an object from the plug-in 
                          # that uses more memory than can be allocated. 
                          # (using more memory than available would crash the server as it kills processes
                          # as it attempts to free memory for reallocation)
                          # I tried incrementally sending the output to HttpServe in "chunks", but the 
                          # IE browser closes the connection after sending it a few chunks and then we fail. 
                          # Apparently, it establishes a new connection and the old connection has 
                          # nobody listening.  (Firefox works as expected, but most use IE)
                          
                          response = response RT
                      }
                  }
                  if ( add_on_html_tags[i]=="YES" && add_on_http_header[i] == "YES" ) {
                      doc_length = sprintf("%x", length(Footer));
                      response = response doc_length ORS Footer ORS
                  }
                  if ( add_on_http_header[i] == "YES" ) {
                      # Send the final zero length "chunk"
                      response = response "0" ORS 
                  }
                  print response |& HttpService
                  close(cmd)
                  RS = OLD_RS
                  ORS = OLD_ORS

                  if ( DebugMode == "yes" ) { 
                      # debugging lines to output entire page to a file.
                      print response >"http_out"
                      close("http_out")
                  }

                  break;
             }
        }

        # To add a new "built-in page" to this "web-server" add a new set of entries here and
        # in the SetUpTopMenu() function located just below here
        #
        # or, you can write a "plug-in" paqe in its own file in the ScriptDirectory and make
        # no changes here at all. This is the easiest solution, as almost anything can be done
        # in a plug-in. 
        #
        # The only pages that are better put in this main script are those that need to access 
        # a lot of the globally available data arrays collected on main status page
    
        # if not handled by a plug-in-script, use a built-in
        if ( plug_in_matched != "y" ) {

          if ( DebugMode == "yes" ) { 
             print "Plug-in not matched " MENU[2]
          }

          # special requests (syslog download) handled here
          if (MENU[2] == "syslog") {

              # If a syslog file was named as a request parameter, use it instead of /var/log/syslog
              if ( GETARG["file"] != "" ) {
                  log_fname = GETARG["file"]
                  delete d;
                  n = split(log_fname,d,"/")
                  attachment_name=d[n]
              } else {
                  log_fname = "/var/log/syslog"
                  attachment_name=strftime("syslog-%Y-%m-%d.txt")
              }

               print "HTTP/1.0", Status, Reason                      |& HttpService
               print "Connection: Close"                             |& HttpService
               print "Pragma: no-cache"                              |& HttpService
               print "Content-disposition: attachment;filename=" attachment_name |& HttpService
               print "Content-type: application/octet-stream" ORS        |& HttpService
               RS = "\n"          # log file lines are terminated this way
               while (( getline line < log_fname ) > 0 ) {
                   if ( line !~ /emhttp:.*registered to:/ ) {
                       print line                       |& HttpService
                   } else {
                       print substr(line,1,index(line,"red to:")+7) "(name withheld)"  |& HttpService
                   }
               }

               #close(HttpService)                     # End the upload of this file
      
              close (log_fname)
              RS="\r\n"
              MENU[2] = "";
              special_matched="y"
        
            }

            # If no specific page is requested, show the home status page
            if (MENU[2] == "" ) {
              built_in_matched="y"
              SetUpHomePage()
              PageMenu = SetUpTopMenu("")
              Document = PageMenu PageDoc
            }

            if (MENU[2] == "array_management") {
              built_in_matched="y"
              SetUpArrayMgmtPage()
              PageMenu = SetUpTopMenu(MENU[2]);
              Document = PageMenu ArrayMgmtPageDoc
            }

            if (MENU[2] == "disk_management" || MENU[2] == "disk_repair") {
              built_in_matched="y"
              SetUpDiskMgmtPage( MENU[2] )
              PageMenu = SetUpTopMenu("disk_management");
              Document = PageMenu DiskMgmtPageDoc
            }

            # This built-in "syslog" page is not used if the syslog plug-in is put into place. 
            # The built-in command does not do color coding of syslog lines. The plug-in does.
            # I left this here mostly to show that a built-in can be replced with a plug-in easily
            # with no changes to this code at all.  
            # Just write and/or install a plug-in with the same "url" as the built-in
            if (MENU[2] == "system_log") {
              built_in_matched="y"
              SetUpSyslogPage()
              PageMenu = SetUpTopMenu(MENU[2]);
              Document = PageMenu SyslogPageDoc
            }

            if (MENU[2] == "about") {
              built_in_matched="y"
              GetArrayStatus();
              PageMenu = SetUpTopMenu(MENU[2]);
              ArrayStatusDoc = ArrayStateHTML();
              Document = "<pre><b>unmenu.awk: " version "</b><br><br><u>Plug-in-modules</u>" ORS
              for ( i = 0; i < add_on_count; i++ ) {
                  delete d;
                  n = split(add_on[i],d,"/")
                  Document = Document d[n] ": " add_on_version[i] " - " add_on_release[i] ORS
              }
              Document = PageMenu ArrayStatusDoc Document
            }

            if (MENU[2] == "help") {
              built_in_matched="y"
              GetArrayStatus();
              PageMenu = SetUpTopMenu(MENU[2]);
              ArrayStatusDoc = ArrayStateHTML();
              Document = "<br>Help is available at:<ul>"
              Document = Document "<li><a href=\"http://lime-technology.com/wiki/index.php?title=Troubleshooting\">"
              Document = Document "Troubleshooting</a></li>"
              Document = Document "<li><a href=\"http://lime-technology.com/wiki/index.php?title=FAQ\">"
              Document = Document "Frequently Asked Questions</a></li>"
              Document = Document "<li><a href=\"http://lime-technology.com/wiki/index.php?title=Best_of_the_Forums\">"
              Document = Document "Best Of The Forums</a></li>"
              Document = Document "<li><a href=\"http://lime-technology.com/wiki/index.php?title=Unofficial_Documentation\">"
              Document = Document "User Contributed Documentation</a></li>"
              Document = Document "<li><a href=\"http://lime-technology.com/forum\">"
              Document = Document "Lime-Technology Support Forum</a></li>"
              Document = Document "</ul>"
              Document = PageMenu ArrayStatusDoc Document
            }

            if ( built_in_matched != "y" && special_matched != "y" ) { 
              if ( DebugMode == "yes" ) { 
                 print "special/built-in page not matched '" MENU[2] "'"
              }
              Document = "<HR><H1>404 Page Not Found</H1>We were unable to find the requested page '" MENU[2] "'<HR>"
              Document = Document "<a href=\"/\">Click here to return to the unMENU main page</a>"
            }
    
            
            if ( special_matched == "n" ) { 
              # now add the HTTP header and send the page to the browser.
              RS = ORS    = "\r\n"          # header lines are terminated this way
              Header = GetPageHEAD(-1);
              WebPage = Header Document Footer
      
              # If on the main page and the array id started, let it auto-refresh.
              if (MENU[2] == "" && array_state == "STARTED") {
                  refresh_interval = REFRESH_INTERVAL
              } else {
                  refresh_interval = 0
              }
              http_headers = GetHTTP_Header("text/html", refresh_interval, "/" ) 
              doc_length = sprintf("%x", length(WebPage));
              print http_headers ORS doc_length ORS WebPage ORS "0" ORS |& HttpService

              # debugging lines to output entire page to a file.
              #print http_headers ORS doc_length ORS WebPage ORS "0" ORS >"http_out"
              #close("http_out")
            }
        }
    } else if (GETARG["Method"] == "HEAD")    {
            http_headers = GetHTTP_Header("text/html", 0, "/" ) 
            print http_headers ORS |& HttpService
    } else if (GETARG["Method"] != "") { print "bad method -" GETARG["Method"] "-"
    }

    if ( DebugMode == "yes" ) { 
       print "closing port listening for requests"
    }
    close(HttpService)  # stop talking to this request from the web client
  }
}

function getHost( theHostName) {
    "uname -n" | getline  theHostName
    close("uname -n")
    return theHostName
}

function GetHTTP_Header( type, refresh, header, url) {
    header =        "HTTP/1.1 200 OK" "\r\n"
    header = header "Connection: Close" "\r\n"
    header = header "Pragma: no-cache" "\r\n"
    header = header "Cache-Control: private, max-age=0" "\r\n"
    header = header strftime("Date: %a, %d %b %Y %H:%M:%S GMT", (systime() + (tz_offset))) "\r\n"
#    print strftime("Date: %a, %d %b %Y %H:%M:%S GMT", (systime() + (tz_offset))) 
    header = header "Expires: -1\r\n"
    header = header "Content-Type: " type "\r\n"
    header = header "Transfer-Encoding: chunked" "\r\n"
    if ( refresh > 0 ) {
        header = header "Refresh: " refresh "; URL=" url "\r\n"
    }
    return header
}

function CGI_setup(   method, uri, version, i) {
  delete GETARG;         delete MENU;        delete PARAM
  GETARG["Method"] = $1; GETARG["URI"] = $2; GETARG["Version"] = $3
  i = index($2, "?")
  if (i > 0) {             # is there a "?" indicating a CGI request?
    split(substr($2, 1, i-1), MENU, "[/:]")
    split(substr($2, i+1), PARAM, "&")
    for (i in PARAM) {
      j = index(PARAM[i], "=")
      GETARG[substr(PARAM[i], 1, j-1)] = substr(PARAM[i], j+1)
    }
  } else {             # there is no "?", no need for splitting PARAMs
    split($2, MENU, "[/:]")
  }
  if ( DebugMode == "yes" ) { 
    for ( i in MENU ) {
        print "MENU[" i "] '" MENU[i] "'"
    }
    for ( i in GETARG ) {
        print "GETARG[" i "] '" GETARG[i] "'"
    }
    for ( i in PARAM ) {
        print "PARAM[" i "] '" PARAM[i] "'"
    }
  }
}

# We pass in the one URL we do NOT want included as a link, but only as a label.
# The other possible pages are made into links. The entire top of form is a three column table.
# To add a new built-in web-page, the two arrays below need to have an additional member defined 
# and the set of "if ( MENU[2] == ...)" statements above appended
# most pages can be external as a plug-in, so unless you need access to global data here, 
# make your addition a plug-in module. They automatically add their menu entries when processed.

function SetUpTopMenu(urlName, theMenu, i, menu_flag) {

  if ( urlName == "/" ) urlName = "";
  delete menu; delete url;

  # the possible web links and affilated URLs are defined here in two arrays.
  # note: do not name a "url" entry "syslog" as that is handled in the upload code and
  # does not appear in the top menu.
  idx=1
  menu[idx]="Main";       url[idx]="";            idx++;
  menu[idx]="Array Mgmt"; url[idx]="array_management";  idx++;
  menu[idx]="Disk Mgmt";  url[idx]="disk_management";     idx++;
  menu[idx]="";           url[idx]="disk_repair";     idx++;
  menu[idx]="Syslog";     url[idx]="system_log";      idx++;

  # merge and/or append the plug-in modules. 
  # (if the URL exists, it is merged, replacing the original, otherwise, it is appended to the menu items)
  for ( i = 0; i < add_on_count; i++ ) {
    add_on_index = MenuIndex(add_on_url[i], idx);
    menu[add_on_index] = add_on_menu[i];
    url[add_on_index] = add_on_url[i];
    if ( add_on_index == idx ) {
        idx++;
    }
  } 

  # these two menu entries always are on the end of the list
  menu[idx]="About";     url[idx]="about";      idx++;
  menu[idx]="Help";      url[idx]="help";      idx++;

  # build the HTML for the top menu
  top_menu=""  # passed to plug-ins, in case they need it.
  theMenu  = "<table cellspacing=0 cellpadding=0 border=0 width=\"100%\"><tr><td width=\"40%\"><font size=\"-1\">"
  for ( a = 1; a<idx; a++ ) {
    if ( url[a]  != "syslog" && menu[a] != "" ) {
        top_menu = top_menu url[a] "|" menu[a] "|"
        if ( url[a] == urlName ) {
            theMenu = theMenu " <nobr>" menu[a] "</nobr> " 
        } else {
            theMenu = theMenu " <nobr><A HREF=" MyPrefix "/" url[a] ">" menu[a] "</A></nobr> "
        }
        theMenu = theMenu "|"
    }
  }
  # just in case the user embedded a single quote in a menu label. 
  gsub("'","'\\''",top_menu)

  "date" | getline DateTime
  close("date")

  theMenu = substr(theMenu,1, length(theMenu)-1); 
  theMenu = theMenu "</font></td><td align=center width=\"20%\"><font size=\"4\"><b>" MyHost 
  theMenu = theMenu " unRAID Server</b></font></td>\
    <td align=\"right\" width=\"40%\">" DateTime "</td></tr>\
    </table>\
    " ORS ORS
  return theMenu
}

# If a menu item already exists with the same "url", return its index to use to replace it with the plug-in entry, 
# otherwise, return an index to add a new entry on the end of the array
function MenuIndex(theurl, mindex, found_url, a) {
    found_url=0
    for ( a = 1; a< mindex; a++) {
        if ( url[a] == theurl ) {
            found_url=a
            break;
        }
    }
    if ( found_url > 0 ) {
        return found_url
    } else {
        return mindex
    }
}

function GetPageHEAD(add_on_num, theHEAD, i) {

  theHEAD = "<HTML><title>" MyHost " unRAID Server</title><HEAD>\
    <STYLE type=\"text/css\">\
    td.t {\
    border-top: 1px solid black;\
    }\
    </STYLE>"
  if ( add_on_num >= 0 ) {
    for ( i =1; i<= add_on_head_count[add_on_num]; i++ ) {
      theHEAD = theHEAD add_on_head[add_on_num, i]
    }
  }
  theHEAD = theHEAD "</HEAD><BODY onload=\"self.scrollTo(0,0)\">"
  return theHEAD;
}

function ArrayStateHTML(theHTML, parity_status, i) {
  if ( array_state != "STARTED" ) {
     state_font="<font color=\"red\">"
     array_status_text="<font color=\"red\"><b>unRAID ARRAY is STOPPED </b></font>"
  } else {
     state_font="<font color=\"black\">"
     array_status_text=""
  }
  # return a fieldset for the Array Status for the top of page.
  samba_active=IsSambaStarted();
  if ( samba_active == "no" ) {
    SambaStatus = "; <font color=\"red\"><b> SAMBA is STOPPED, Shared drives will not be visible on the LAN.</b></font>"
  } else {
    SambaStatus  = ""
  }

  arraydisks=0
  parity_valid=""
  rebuilding_disk=""
  for ( i =0; i<numdisks; i++ ) {
    if ( disk_status[i] == "DISK_NP" && disk_device[i] == "" ) {
        continue;
    }
    arraydisks++;
    if ( disk_name[i] == "" && disk_device[i] != "" ) {
        if ( disk_status[i] ~ "DISK_OK" ) {
            parity_valid="Parity is Valid:"
        } else {
              parity_valid="<font color=\"red\">PARITY NOT VALID: " disk_status[i] "</font>"
        }
    }
    if ( disk_status[i] == "DISK_INVALID" && disk_device[i] != "") {
      rebuilding_disk = i;
    }
  }

  if ( parity_valid=="") {
    parity_valid="Parity disk not configured."
  }

  if ( resync_finish != "" && resync_finish != "0" ) {
     if(rebuilding_disk != "") {
        oper = rebuilding_disk == "0" ? "Rebuilding Parity" :  "Rebuilding disk" rebuilding_disk;
     } else {
        oper="Parity Check in progress";
     }


     parity_status= state_font array_state "; " arraydisks " disks in array." SambaStatus "<br><br><font color=\"red\"><b> "  oper "</font>" 

     if(rebuilding_disk == "")
        rebuilding_disk = 0   #retrieve total size and compute % complete based on parity disk size

     if ( disk_size[rebuilding_disk] > 0 ) {
       pct_complete = sprintf("%.1f", resync_pos/disk_size[rebuilding_disk]*100);
     } else {
       pct_complete = 0;
     }

     theHTML = "<fieldset style=\"margin-top:8px;\"><legend><strong>Array Status</strong></legend>"
     theHTML = theHTML "<table border=\"0\" width=\"100%\">"
     theHTML = theHTML "	<tr>"
     theHTML = theHTML "		<td width=\"35%\" valign=\"top\">" parity_status "</td>"
     theHTML = theHTML "		<td width=\"25%\" align=\"left\">"
     theHTML = theHTML "	        <table width=\"100%\" border=\"0\"><tr>"
     theHTML = theHTML "		<td width=37*>Total&nbsp;Size</td>"
     theHTML = theHTML "		<td align=right ><b>" CommaFormat(disk_size[rebuilding_disk]) "</b></td>"
     theHTML = theHTML "		<td width=20*; align=\"left\"><b>&nbsp;KB</b></td>"		
     theHTML = theHTML "	        </tr>"	
     theHTML = theHTML "	        <tr>"
     theHTML = theHTML "		<td>Current</td>"
     theHTML = theHTML "		<td align=\"right\"><b>" CommaFormat(resync_pos) "</b></td>"
     theHTML = theHTML "		<td align=\"left\"><b>&nbsp;(" pct_complete "%)</b></td>"		
     theHTML = theHTML "	        </tr>"
     theHTML = theHTML "	        <tr>"
     theHTML = theHTML "		<td>Speed</td>"
     theHTML = theHTML "		<td align=\"right\"><b>" CommaFormat(resync_speed) "</b></td>"
     theHTML = theHTML "		<td align=\"left\"><b>&nbsp;KB/sec</b></td>"		
     theHTML = theHTML "	        </tr>"
     theHTML = theHTML "	        <tr>"
     theHTML = theHTML "		<td>Finish</td>"
     theHTML = theHTML "		<td align=\"right\"><b>" resync_finish "</b></td>"
     theHTML = theHTML "		<td align=\"left\"><b>&nbsp;minutes</b></td>"		
     theHTML = theHTML "	        </tr>"
     if(rebuilding_disk == 0) { # only show sync errors here if fixing parity.
       theHTML = theHTML "	        <tr>"
       theHTML = theHTML "		<td>Sync&nbsp;Errors</td>"
       theHTML = theHTML "		<td align=\"right\"><b>" CommaFormat(last_parity_errs) "</b></td>"
       theHTML = theHTML "		<td align=\"left\"><b>&nbsp;(corrected)</b></td>"		
       theHTML = theHTML "	        </tr>"
     }
     theHTML = theHTML "		</table>"
     theHTML = theHTML "		</td><td width=50%>&nbsp;</td>"
     theHTML = theHTML "	</tr>"
     theHTML = theHTML "</table></fieldset>"

  } else {

     secsSinceLastParity = strftime("%s") - strftime("%s", last_parity_sync);
     daysSinceLastParity = secsSinceLastParity/(60*60*24) + 0.5;

     if(secsSinceLastParity < (60*60*24))
        ParityCheckMsg = "&lt; 1 day ago";
     else if(daysSinceLastParity < 2)
        ParityCheckMsg = "1 day ago";
     else if(daysSinceLastParity <= 30)
        ParityCheckMsg = sprintf("%d", daysSinceLastParity) " days ago"
     else if(secsSinceLastParity < (60*60*24*61))
        ParityCheckMsg = "<b>" sprintf("%d", daysSinceLastParity) "</b> days ago"
     else if(secsSinceLastParity < (60*60*24*90))  
        ParityCheckMsg = "<font style=\"background-color:yellow\"><b>&nbsp;" sprintf("%d", daysSinceLastParity) "&nbsp;</b></font>&nbsp;days ago"
     else
        ParityCheckMsg = "<font style=\"background-color:red;color:white\"><b>&nbsp;" sprintf("%d", daysSinceLastParity) "&nbsp;</b></font>&nbsp;days ago"

     if(last_parity_errs == 0)
        SyncErrorMsg = "with no sync errors."
     else if(last_parity_errs < 20) 
        SyncErrorMsg = ".&nbsp;&nbsp;&nbsp;Parity updated <b> " last_parity_errs " </b>times to address sync errors."
     else if(last_parity_errs < 100)
        SyncErrorMsg = ".&nbsp;&nbsp;&nbsp;Parity updated&nbsp;<font style=\"background-color:yellow\"><b>&nbsp;" last_parity_errs " </b></font>&nbsp;times to address sync errors."
     else
        SyncErrorMsg = ".&nbsp;&nbsp;&nbsp;Parity updated&nbsp;<font style=\"background-color:red;color:white\"><b>&nbsp;" last_parity_errs " </b></font>&nbsp;times to address sync errors."

    if ( parity_valid!="" && parity_valid!="Parity disk not configured." ) {
      parity_status= "; " parity_valid 
      if ( parity_valid=="Parity is Valid:" ) {
          parity_status = parity_status ".&nbsp;&nbsp;&nbsp;Last parity check&nbsp;" ParityCheckMsg " " SyncErrorMsg "&nbsp;&nbsp;&nbsp;";
      }
    } else {
      parity_status= "; <b>Array is not protected by a parity disk: " parity_valid "</b>" 
    }
     
    #parity_status= "; " parity_valid " Last parity check: " strftime("%a %b %d %H:%M:%S %Z %Y",last_parity_sync) " \
    # finding " last_parity_errs " errors. ";

     theHTML = "<fieldset style=\"margin-top:10px;\"><legend><strong>Array Status</strong></legend>\
     " state_font array_state "</font>, " array_status_text arraydisks " disks in array.&nbsp;&nbsp;&nbsp" parity_status  SambaStatus "</fieldset>" 
  }

  return theHTML;
}

function SetUpHomePage() {
  GetArrayStatus();
  GetDiskData()

  PageDoc = ArrayStateHTML();
  PageDoc = PageDoc DiskStatusHTML();
  PageDoc = PageDoc GetOtherDisks();
  if ( syslog_main_lines > 0 ) {
      PageDoc = PageDoc GetSyslogTail(syslog_main_lines);
  }
  if ( main_page_user_content ) {
      gsub("%MyHost%",MyHost,main_page_user_content)
      gsub("%MyPort%",MyPort,main_page_user_content)
      
      PageDoc = PageDoc "<iframe width=\"100%\" "  main_page_user_content "\">"
      PageDoc = PageDoc "Sorry: your browser does not seem to support inline frames"
      PageDoc = PageDoc "</iframe>"
  }
}

function SetUpArrayMgmtPage() {
  # user pressed the "cancel parity check button"
  if ( array_state == "STARTED" && GETARG["nocheck_parity"] == "Cancel+Parity+Check" ) {
    cmd="/root/mdcmd nocheck"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
    delete GETARG;
  }
  # user pressed the "parity check button"
  if ( array_state == "STARTED" && GETARG["check_parity"] == "Check+Parity" ) {
    cmd="/root/mdcmd check"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
    delete GETARG;
    # wait a tiny bit for unRAID to start the parity check so we can report on it in the status box
    system("sleep 5");
  }
  # user pressed the "stop samba button"
  if ( array_state == "STARTED" && GETARG["stop_samba"] == "Stop+Samba" ) {
    StopSamba()
    delete GETARG;
  }
  # user pressed the "start samba button"
  if ( array_state == "STARTED" && GETARG["start_samba"] == "Start+Samba" ) {
    StartSamba()
    delete GETARG;
  }
  # user pressed the "Spin Up Drives button"
  if ( array_state == "STARTED" && GETARG["spin_up"] == "Spin+Up+Drives" ) {
    SpinUp("All Disks")
    delete GETARG;
  }
  # user pressed the "Spin Down Drives button"
  if ( array_state == "STARTED" && GETARG["spin_down"] == "Spin+Down+Drives" ) {
    SpinDown("All Disks")
    delete GETARG;
  }
  # user pressed the "reload samba button"
  if ( array_state == "STARTED" && GETARG["reload_samba"] == "Reload+Samba+Config" ) {
    cmd="smbcontrol smbd reload-config"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
    delete GETARG;
  }
  # user pressed the "Stop server button", need to stop samba, unmount drives, then stop array.
  if ( array_state == "STARTED" && GETARG["stop_array"] == "Stop+Array" ) {
    StopSamba();
    UnmountDisks("All Disks");
    StopArray();
    delete GETARG;
  }

  GetArrayStatus()
  samba_active=IsSambaStarted();
  ArrayMgmtPageDoc = ArrayStateHTML();
  ArrayMgmtPageDoc = ArrayMgmtPageDoc "<form method=\"GET\" ><table width=\"100%\">"
    
  # show appropriate buttons based on current status.
  if ( array_state == "STARTED" ) {
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td>&nbsp;</td><td>&nbsp;</td></tr>" \
    "<tr><td width=\"10%\"><input type=submit name=\"stop_array\" value=\"Stop Array\"</td><td align=\"left\">\
    Stop the unRAID array.  Note: you must use the real unRAID management page to Start the array.</td></tr>" \
        "<tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    if ( resync_finish != "" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"nocheck_parity\" value=\"Cancel Parity Check\"</td><td align=\"left\">\
        Cancel the Parity Check of the unRAID array</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    } else {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"check_parity\" value=\"Check Parity\"</td><td align=\"left\">\
        Initiate a Parity Check of the unRAID array</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    }
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
    "<tr><td width=\"10%\"><input type=submit name=\"spin_up\" value=\"Spin Up Drives\"</td><td align=\"left\">\
    Spin Up All Disk Drives by reading a random block of data from each disk in turn.</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
    "<tr><td width=\"10%\"><input type=submit name=\"spin_down\" value=\"Spin Down Drives\"</td><td align=\"left\">\
    Spin Down All Disk Drives</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    if ( samba_active == "yes" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"stop_samba\" value=\"Stop Samba\"</td><td align=\"left\">\
        Stop Samba Shares</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    } else {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"start_samba\" value=\"Start Samba\"</td><td align=\"left\">\
        Start Samba Shares</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    }
    if ( samba_active == "yes" ) {
        ArrayMgmtPageDoc = ArrayMgmtPageDoc \
        "<tr><td width=\"10%\"><input type=submit name=\"reload_samba\" value=\"Reload Samba Config\"</td><td align=\"left\">\
        Reload Samba Share Configuration File</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr>"
    }
  } else if ( array_state == "STOPPED" ) {
    ArrayMgmtPageDoc = ArrayMgmtPageDoc \
    "<tr><td width=\"10%\"><input type=button name=\"start_array\" value=\"Start Array\" \
    onclick=\"alert('Sorry: not implimented, use the real management page to restart the array');\">\
    </td><td align=\"left\"><b>Unfortunately, it is not possible to start the unRAID array in this interface. \
     Please use the Lime-Technology supplied  management page to restart the array.</td></tr>"
  }
  ArrayMgmtPageDoc = ArrayMgmtPageDoc \
  "</table>" \
  "</form>"
}

function StopSamba( cmd) {
   system("killall smbd nmbd")
   return "Samba Stopped"
}
function StartSamba( cmd) {
    system("/usr/sbin/smbd -D")
    system("/usr/sbin/nmbd -D")
    return "Samba Started"
}

function SpinUp( disk, cmd, f) {
    # Spin Up drives
    # loop through the drives spinning them up
    # by reading a single "random" block from each disk in turn.  
    srand() # important to get random numbers when unmenu is re-started.
    for ( i =0; i<numdisks; i++ ) {
        if ( "/dev/" disk_device[i] == disk || disk == "All Disks" ) {
            # calculate a random block between 1 and the max blocks on the device
            skip_blocks = 1 + int( rand() * disk_size[i] );

            cmd="dd if=/dev/" disk_device[i] " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
        #    print cmd
            system(cmd);
        }
    }
}

function SpinDown( disk, cmd, i, f) {
    # Spin Down the drives
    for ( i =0; i<numdisks; i++ ) {
        if ( "/dev/" disk_device[i] == disk || disk == "All Disks" ) {
            cmd="/usr/sbin/hdparm -y /dev/" disk_device[i]
        #    print cmd
            while (( cmd | getline f ) > 0) ;
            close(cmd);
        }
   }
}

function UnmountDisks( disk ,cmd) {
    # kill any processes running on the disk(s) to be unmounted
    unmount_out=""
    delete pids;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
        #print cmd
        while (( cmd | getline f ) > 0) {
            pids[pp++] = f
        }
        close(cmd);
    }
    }
    cmd="fuser -cu /mnt/user 2>/dev/null"
    while (( cmd | getline f ) > 0) {
        pids[pp++] = f
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "killing " pids[i]
        system("kill  -0 pids[i] && kill -TERM " pids[i] )
    }
    # Second try, kill any processes still running on the disk(s) to be unmounted
    delete pids;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
        #print cmd
        while (( cmd | getline f ) > 0) {
            pids[pp++] = f
        }
        close(cmd);
    }
    }
    cmd="fuser -cu /mnt/user 2>/dev/null"
    while (( cmd | getline f ) > 0) {
        pids[pp++] = f
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "killing " pids[i]
        system("kill  -0 pids[i] && kill -TERM " pids[i] )
    }

    # third try, kill off any remainders with kill -9
    delete pids;
    pp=0
    for ( i =0; i<numdisks; i++ ) {
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        cmd="fuser -cu /dev/" disk_name[i] " 2>/dev/null"
        #print cmd
        while (( cmd | getline f ) > 0) {
            pids[pp++] = f
        }
        close(cmd);
    }
    }
    cmd="fuser -cu /mnt/user 2>/dev/null"
    while (( cmd | getline f ) > 0) {
        pids[pp++] = f
    }
    close(cmd);
    for ( i=0; i<pp;i++ ) {
        #print "killing " pids[i]
        system("kill  -0 pids[i] && kill -KILL " pids[i] )
    }
    
    # unmount the drives
    for ( i =0; i<numdisks; i++ ) {
    if ( disk_mounted[i] != "" && ( "/dev/" disk_device[i] == disk || disk == "All Disks" )) {
        disk_unmounted[i] = disk_mounted[i]
        cmd="umount /dev/" disk_name[i]
        unmount_out = unmount_out "/dev/" disk_name[i] " Unmounted<br>"
        #print cmd
        while (( cmd | getline f ) > 0) ;
        close(cmd);
    }
   }
   return unmount_out
}

function FsckDisk(disk, fix, cmd) {
    RS="\n"
    fsck_out=""
    for ( i =0; i<numdisks; i++ ) {
    if ( "/dev/" disk_device[i] == disk || disk == "All Disks" ) {
            fsck_out="<b>Checking /dev/" disk_name[i] " (/dev/" disk_device[i] ")</b><br>"
        if ( disk_name[i] == "" ) {
            fs = ""
        } else {
            fs = GetDiskFileSystem("/dev/" disk_device[i], "1")
        }
        #print "filesystem type:" fs " for disk  /dev/" disk_device[i]
        if ( fs == "reiserfs" ) {
            if ( fix != "" ) {
                cmd="reiserfsck " fix " -q -y /dev/" disk_name[i] " 2>&1| tee -a /var/log/syslog"
            } else {
                cmd="reiserfsck -q -y /dev/" disk_name[i] " 2>&1| tee -a /var/log/syslog"
            }
            #print cmd
            while (( cmd | getline f ) > 0) {
                fsck_out = fsck_out f "<br>"
            }
            close(cmd);
        } else {
            if ( fs == "" ) {
                fsck_out = fsck_out " Sorry, no file system detected on /dev/" disk_name[i] "<br>"
            } else {
                fsck_out = fsck_out " Sorry, not coded to handle " fs " on /dev/" disk_name[i] "<br>"
            }
        }
    }
   }
   return fsck_out
}

function MountDisk(disk) {
    RS="\n"
    mount_out=""
    # mount the drive
    for ( i =0; i<numdisks; i++ ) {
    if ( "/dev/" disk_device[i] == disk || disk == "All Disks" ) {
        fs = GetDiskFileSystem("/dev/" disk_device[i], "1")
        mount_out = mount_out "/dev/" disk_name[i] " mounted on " disk_unmounted[i] "<br>"
        cmd="mount -t reiserfs -o noatime,nodiratime /dev/" disk_name[i] " " disk_unmounted[i] " 2>&1"
#        print cmd
        while (( cmd | getline f ) > 0) ;
        close(cmd);
    }
   }
   return mount_out
}

function StopArray() {
    # stop the unRAID array
    cmd="/root/mdcmd stop"
    #print cmd
    while (( cmd | getline f ) > 0) ;
    close(cmd);
}

function SetUpSyslogPage(syslog) {
  GetArrayStatus()

  SyslogPageDoc = ArrayStateHTML();
  if ( GETARG["file"] != "" ) {
      log_fname = GETARG["file"]
      nl = 10000
  } else {
      log_fname = "/var/log/syslog"
      nl = 1000
  }

  # Set the number of syslog lines you wish returned here.
  syslog = GetSysLog(nl, log_fname);
    
  SyslogPageDoc = SyslogPageDoc  syslog
}

function SetUpDiskMgmtPage( theMenuVal ) {
  GetMountOptions(ScriptDirectory "/" ConfigFile);
  GetMountOptions(ScriptDirectory "/" LocalConfigFile);

  if ( GETARG["disk_device"] == "" && GETARG["hdparm"] == "HDParm+Info" ) {
    DiskCommandOutput = "You must first select a disk before running hdparm on it."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["smart_stats"] == "Smart+Statistics" ) {
    DiskCommandOutput = "You must first select a disk before requesting statistics."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["smart_short"] == "Short+Smart+Test" ) {
    DiskCommandOutput = "You must first select a disk before requesting a short SMART test."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["smart_long"] == "Long+Smart+Test" ) {
    DiskCommandOutput = "You must first select a disk before requesting a long SMART test."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["spin_up"] == "Spin+Up" ) {
    DiskCommandOutput = "You must first select a disk before spinning it up."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["spin_down"] == "Spin+Down" ) {
    DiskCommandOutput = "You must first select a disk before spinning it down."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["umount"] == "Un-Mount+Drive" ) {
    DiskCommandOutput = "You must first select a disk before un-mounting it."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["fsck"] == "File+System+Check" ) {
    DiskCommandOutput = "You must first select a disk before checking it."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["fsck_repair"] == "File+System+Repair+(fix-fixable)" ) {
    DiskCommandOutput = "You must first select a disk before repairing it."
    delete GETARG;
  }
  if ( GETARG["disk_device"] == "" && GETARG["fsck_rebuild_tree"] == "File+System+Repair+(rebuild-tree)" ) {
    DiskCommandOutput = "You must first select a disk before repairing it."
    delete GETARG;
  }
  # if not null,  split the disk_device field into its three component parts. These are in d[1], d[2], d[3]
  # d[1] = linux device (/dev/hdb, etc)
  # d[2] = model/serial
  # d[3] = md device (md1, md2, etc)
  if ( GETARG["disk_device"] != "" ) {
    delete d;
    val = GETARG["disk_device"]
    gsub("%2F","/",val)
    gsub("%7C","|",val)
    split(val,d,"|");
  }
  # user pressed the "HDParm Infobutton"
  if ( GETARG["disk_device"] != "" && GETARG["hdparm"] == "HDParm+Info" ) {
    DiskCommandOutput = "<b><u><font size=\"+1\">HDParm Info for " d[1] " " d[2] "</font></u></b><br><pre>"
    #smartctl -a -d ata /dev/$disk_device    
    cmd="hdparm -I " d[1]
    RS="\n"
    while (( cmd | getline f ) > 0)  {
        DiskCommandOutput = DiskCommandOutput f ORS
    }
    close(cmd);
    DiskCommandOutput = DiskCommandOutput "</pre>"
  }
  # user pressed the "Smart Statistics button"
  if ( GETARG["disk_device"] != "" && GETARG["smart_stats"] == "Smart+Statistics" ) {
    DiskCommandOutput = "<b><u><font size=\"+1\">Statistics for " d[1] " " d[2] "</font></u></b><br><pre>"
    #smartctl -a -d ata /dev/$disk_device    
    cmd="smartctl -a -d ata " d[1]
    RS="\n"
    while (( cmd | getline f ) > 0)  {
        DiskCommandOutput = DiskCommandOutput f ORS
    }
    close(cmd);
    DiskCommandOutput = DiskCommandOutput "</pre>"
  }
  # user pressed the "Smart Short Test button"
  if ( GETARG["disk_device"] != "" && GETARG["smart_short"] == "Short+Smart+Test" ) {
    DiskCommandOutput = "Smart Short Test of " d[1] " will take from several minutes to an hour or more."
    #smartctl -t short /dev/$disk_device    
    cmd="smartctl -d ata -t short " d[1]
    RS="\n"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
  }
  # user pressed the "Smart Long Test button"
  if ( GETARG["disk_device"] != "" && GETARG["smart_long"] == "Long+Smart+Test" ) {
    DiskCommandOutput = "Smart Long Test of " d[1] " could take several hours or more."
    #smartctl -t long /dev/$disk_device    
    cmd="smartctl -d ata -t long " d[1]
    RS="\n"
    while (( cmd | getline f ) > 0) ;
    close(cmd);
  }
  # user pressed the "Spin Down"
  if ( GETARG["disk_device"] != "" && GETARG["spin_down"] == "Spin+Down" ) {
    DiskCommandOutput =  d[1] " has been spun down."
    SpinDown(d[1])
  }
  # user pressed the "Spin Up"
  if ( GETARG["disk_device"] != "" && GETARG["spin_up"] == "Spin+Up" ) {
    DiskCommandOutput =  d[1] " has been spun up."
    SpinUp(d[1])
  }
  if ( GETARG["disk_device"] != "" && GETARG["umount"] == "Un-Mount+Drive" ) {
    if ( d[3] ~ "md" ) {
        DiskCommandOutput = StopSamba();
        DiskCommandOutput = DiskCommandOutput " and " UnmountDisks(d[1]);
    } else {
       DiskCommandOutput = "Sorry: Only disks with file systems can be un-mounted."
    }
  }
  if ( GETARG["disk_device"] != "" && GETARG["fsck"] == "File+System+Check" ) {
    if ( d[3] ~ "md" ) {
        DiskCommandOutput = StopSamba() "<br>"
        DiskCommandOutput = DiskCommandOutput UnmountDisks(d[1]) "<br>"
        DiskCommandOutput = DiskCommandOutput FsckDisk(d[1],"")   "<br>"
        DiskCommandOutput = DiskCommandOutput MountDisk(d[1])   "<br>"
        DiskCommandOutput = DiskCommandOutput StartSamba()       "<br>"
    } else {
       DiskCommandOutput = "Sorry: File System Check can only be run on disks with file systems."
    }
  }
  if ( GETARG["disk_device"] != "" && GETARG["fsck_repair"] == "File+System+Repair+(fix-fixable)" ) {
    if ( d[3] ~ "md" ) {
        DiskCommandOutput = StopSamba() "<br>";
        DiskCommandOutput = DiskCommandOutput UnmountDisks(d[1]) "<br>"
        DiskCommandOutput = DiskCommandOutput FsckDisk(d[1],"--fix-fixable")   "<br>"
        DiskCommandOutput = DiskCommandOutput MountDisk(d[1])   "<br>"
        DiskCommandOutput = DiskCommandOutput StartSamba()       "<br>"
    } else {
       DiskCommandOutput = "Sorry: File System Repair can only be run on disks with file systems."
    }
  }
  if ( GETARG["disk_device"] != "" && GETARG["fsck_rebuild_tree"] == "File+System+Repair+(rebuild-tree)" ) {
    if ( d[3] ~ "md" ) {
        DiskCommandOutput = StopSamba() "<br>";
        DiskCommandOutput = DiskCommandOutput UnmountDisks(d[1]) "<br>"
        DiskCommandOutput = DiskCommandOutput FsckDisk(d[1],"--rebuild-tree")   "<br>"
        DiskCommandOutput = DiskCommandOutput MountDisk(d[1])   "<br>"
        DiskCommandOutput = DiskCommandOutput StartSamba()       "<br>"
    } else {
       DiskCommandOutput = "Sorry: File System Repair can only be run on disks with file systems."
    }
  }
  for (i in PARAM) {
      if ( PARAM[i] ~ "hdparm-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">HDParm Info for /dev/" d[2] "</font></u></b><br><pre>"
          cmd="hdparm -I /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "smart_status-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">SMART status Info for /dev/" d[2] "</font></u></b><br><pre>"
          cmd="smartctl -a -d ata /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "smart_short-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Smart Short Test of /dev/" d[2] " will take from several minutes to an hour or more.<pre>"
          cmd="smartctl -d ata -t short /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          break;
      }
      if ( PARAM[i] ~ "smart_long-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Smart Long Test of " d[2] " could take several hours or more.<pre>"
          cmd="smartctl -d ata -t long /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          break;
      }
      if ( PARAM[i] ~ "spin_up-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Spin-Up " d[2] "<pre>"
          # calculate a random block between 1 and the max blocks on the device
          disk_blocks = GetRawDiskBlocks( "/dev/" d[2] )
          skip_blocks = 1 + int( rand() * disk_blocks );

          cmd="dd if=/dev/" d[2] " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
          system(cmd);
          break;
      }
      if ( PARAM[i] ~ "spin_down-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "Spin-Down " d[2] "<pre>"
          cmd="/usr/sbin/hdparm -y /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          break;
      }
      if ( PARAM[i] ~ "unmount-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">/dev/" d[2] " has been un-mounted.</font></u></b><br><pre>"
          cmd="umount /dev/" d[2] " 2>&1"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          mountpoint= "/mnt/disk/" d[2]
          system("rmdir " mountpoint " 2>/dev/null")
          system("rmdir /mnt/disk 2>/dev/null")
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "mount-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          if ( d[3] == "ntfs" ) { 
             # if we have ntfs-3g, use it.
             if (system("test -f /bin/ntfs-3g")==0) {
                 d[3] = "ntfs-3g" 
             } else {
                # load the old read-only driver, if it is not already loaded into memory.
                 system("lsmod | grep 'ntfs' >/dev/null 2>&1 || modprobe ntfs");
             }
          }
          system("mkdir /mnt/disk")
          mountpoint= "/mnt/disk/" d[2]
          system("mkdir " mountpoint )
          system("hdparm -S242 /dev/" substr(d[2],1,3) " >/dev/null")


          if ( d[3] in MOUNT_OPTIONS) {
             MountOptions = MOUNT_OPTIONS[d[3]]
          } else {
              if ( "other" in MOUNT_OPTIONS ) {
                 MountOptions = MOUNT_OPTIONS["other"] " -t " d[3]
              } else {
                 MountOptions = "-r -t " d[3]
              }
          }

          cmd="mount " MountOptions " /dev/" d[2] " " mountpoint " 2>&1"
          DiskCommandOutput = "<b><u><font size=\"+1\">/dev/" d[2] " mounted on " mountpoint "</font></u></b><br>"
          DiskCommandOutput = DiskCommandOutput "Using command: <b>" cmd "</b><br><pre>"
          RS="\n"
          while (( cmd | getline f ) > 0)  {
              DiskCommandOutput = DiskCommandOutput f ORS
          }
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
      if ( PARAM[i] ~ "unshare-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">Share of /dev/" d[2] " stopped.</font></u></b><br><pre>"
          sharefile="/etc/samba/smb.shares"
          RS="\n"
          share_exists="n"
          # check to ensure share does exist
          while (( getline line < sharefile ) > 0 ) {
              if ( line ~ "\\[" d[2] "\\]" ) {
                 share_exists="y"
              }
          }
          close(sharefile)
          OFS_OLD = OFS
          OFS = "\n"
          if ( share_exists == "y" ) {
             # Copy the smb.shares file to a temp file
             system("cp /etc/samba/smb.shares /etc/samba/smb.shares_old")
             # Copy the smb.shares file back, but without the section for this shared folder
              delete_share_line="n"
              while (( getline line < "/etc/samba/smb.shares_old" ) > 0 ) {
                  if ( delete_share_line == "y" && line ~ "\\[.*\\]" ) {
                     delete_share_line="n"
                  }
                  if ( line ~ "\\[" d[2] "\\]" ) {
                     delete_share_line="y"
                  }
                  if ( delete_share_line == "n" ) {
                     print line > sharefile
                  }
             }
             close(sharefile)
             close("/etc/samba/smb.shares_old")
          }
          cmd="smbcontrol smbd reload-config"
          while (( cmd | getline f ) > 0) ;
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          OFS = OFS_OLD
          break;
      }
      if ( PARAM[i] ~ "share-" ) {
          delete d
          split(PARAM[i],d,"[=-]")
          DiskCommandOutput = "<b><u><font size=\"+1\">Sharing /dev/" d[2] " as " d[2] "</font></u></b><br><pre>"
          sharefile="/etc/samba/smb.shares"
          RS="\n"
          share_exists="n"
          # check to ensure share does not already exist
          while (( getline line < sharefile ) > 0 ) {
              if ( line ~ "\\[" d[2] "\\]" ) {
                 share_exists="y"
              }
          }
          close(sharefile)
          if ( share_exists == "n" ) {
              OFS_OLD = OFS
              OFS = "\n"
              print "[" d[2] "]" >> sharefile
              print "        path = /mnt/disk/" d[2] > sharefile
              print "        read only = No" > sharefile
              print "        force user = root" > sharefile
              print "        map archive = Yes" > sharefile
              print "        map system = Yes" > sharefile
              print "        map hidden = Yes" > sharefile
              print "        create mask = " create_mask > sharefile
              print "        directory mask = " directory_mask > sharefile
              close(sharefile)
              OFS = OFS_OLD
          }
          cmd="smbcontrol smbd reload-config"
          while (( cmd | getline f ) > 0) ;
          close(cmd);
          DiskCommandOutput = DiskCommandOutput "</pre>"
          break;
      }
  }


  GetArrayStatus()
  DiskMgmtPageDoc = ArrayStateHTML();
  DiskMgmtPageDoc = DiskMgmtPageDoc "<form method=\"GET\" >"

  if ( MENU[2] == "disk_management" ) {
    DiskTmp = DiskManagement(val)
  }
  if ( MENU[2] == "disk_repair" ) {
    DiskTmp = DiskRepair(val)
  }
  DiskMgmtPageDoc = DiskMgmtPageDoc DiskTmp DiskCommandOutput 
  
  DiskMgmtPageDoc = DiskMgmtPageDoc \
  "</form>"
}

function GetSysLog(numlines, logname, syslog, f) {
    nl=numlines
    cmd = "tail -" nl " " logname
    RS="\n"
    syslog = "<strong>Syslog (last " nl " lines of " logname ") </strong>"
    syslog = syslog "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A href=" MyPrefix "/syslog>Click Here to Download Complete /var/log/syslog</A><hr>"
    while (( cmd | getline f ) > 0) {
        syslog = syslog f "<br>"
    }
    close(cmd)
    return syslog
}

function GetSyslogTail(numlines, syslog, f) {
    nl=numlines
    cmd = "tail -" nl " /var/log/syslog"
    RS="\n"
    syslog=""
    syslog=syslog "<fieldset style=\"margin-top:10px;\"><legend><strong>Syslog (last " nl " lines)</strong></legend>"
    syslog=syslog "<table cellpadding=0 cellspacing=0 width=\"100%\"><tr><td>"
    while (( cmd | getline f ) > 0) {
        syslog = syslog f "<br>"
    }
    close(cmd)
    syslog = syslog "</td></tr></table></fieldset>"
    return syslog
}

function GetArrayStatus(a) {
    RS="\n"
    array_numdisks=0
    numdisks=0
    last_parity_sync=0
    resync_percentage=""
    resync_finish=""
    resync_speed=""
    resync_pos=""
    last_parity_errs=0
    array_state="Not started"
    while (("/root/mdcmd status|strings" | getline a) > 0 ) {
        # number of disks in the superblock
        if ( a ~ "sbNumDisks" )      { delete d; split(a,d,"="); numdisks=d[2] }
        # number of disks in the "md" array
        if ( a ~ "mdNumProtected" )  { delete d; split(a,d,"="); array_numdisks=d[2] }
        # datetime (in seconds) of last parity sync
        if ( a ~ "sbSynced" )        { delete d; split(a,d,"="); last_parity_sync=d[2] }
        # number of errors detected in last parity sync
        if ( a ~ "sbSyncErrs" )      { delete d; split(a,d,"="); last_parity_errs=d[2] }
        # percentage of sync completed thus far
        if ( a ~ "mdResyncPrcnt" )   { delete d; split(a,d,"="); resync_percentage=d[2] }
        if ( a ~ "mdResyncFinish" )  { delete d; split(a,d,"="); resync_finish=d[2] }
        if ( a ~ "mdResyncSpeed" )   { delete d; split(a,d,"="); resync_speed=d[2] }
        if ( a ~ "mdResyncPos" )     { delete d; split(a,d,"="); resync_pos=d[2] }
        # array status
        if ( a ~ "mdState" )         { delete d; split(a,d,"="); array_state=d[2] }
        # per disk data, stored in disk_... arrays, delete "ata-" preface on disk_id.
        if ( a ~ "diskName" )        { delete d; split(a,d,"[.=]"); disk_name[d[2]]=d[3]; }
        if ( a ~ "diskId" )          { delete d; split(a,d,"[.=]"); offset = index(d[3],"-")+1; 
                                                 disk_id[d[2]]=substr(d[3],offset); }
        if ( a ~ "diskSerial" )      { delete d; split(a,d,"[.=]"); disk_serial[d[2]]=d[3]; }
        if ( a ~ "diskSize" )        { delete d; split(a,d,"[.=]"); disk_size[d[2]]=d[3]; }
        if ( a ~ "rdevSerial" )      { delete d; split(a,d,"[.=]"); rdisk_serial[d[2]]=d[3]; }
        if ( a ~ "diskModel" )       { delete d; split(a,d,"[.=]"); disk_model[d[2]]=d[3]; }
        if ( a ~ "rdevModel" )       { delete d; split(a,d,"[.=]"); rdisk_model[d[2]]=d[3]; }
        if ( a ~ "rdevStatus" )      { delete d; split(a,d,"[.=]"); disk_status[d[2]]=d[3]; }
        if ( a ~ "rdevName" )        { delete d; split(a,d,"[.=]"); disk_device[d[2]]=d[3]; 
                                       if ( disk_device[d[2]] != "" ) GetReadWriteStats(d[2])
                                     }
        if ( a ~ "diskNumWrites" )   { delete d; split(a,d,"[.=]"); disk_writes[d[2]]=d[3]; }
        if ( a ~ "diskNumReads" )    { delete d; split(a,d,"[.=]"); disk_reads[d[2]]=d[3]; }
        if ( a ~ "diskNumErrors" )   { delete d; split(a,d,"[.=]"); disk_errors[d[2]]=d[3]; }
        if ( a ~ "rdevLastIO" )   { delete d; split(a,d,"[.=]"); disk_lastIO[d[2]]=d[3]; }
    }
    close("/root/mdcmd status|strings")
}

function GetDiskData() {
  # read from /proc/partitions
    RS="\n"
    cmd="cat /proc/partitions | grep -v '^major' | grep -v '^$' "
    num_partitions=0
    while ((cmd | getline a) > 0 ) {
        num_partitions++
        delete d;
        split(a,d," ");    
        major[num_partitions] = d[1]
        minor[num_partitions] = d[2]
        blocks[num_partitions] = d[3]
        device[num_partitions] = d[4]
        assigned[num_partitions] = ""
        mounted[num_partitions] = ""
        model_serial[num_partitions] = ""
    }
    close(cmd)

    # Now, identify the UNRAID device... It should be available in /dev/disk/by-label
    cmd="ls -l /dev/disk/by-label | grep 'UNRAID'"
    while ((cmd | getline a) > 0 ) {
        delete d;
        split(a,d," ");    
        sub("../../","",d[11])
        unraid_volume=d[11]
    }
    close(cmd);

    # match the device to the volume labeled UNRAID
    for( a = 1; a <= num_partitions; a++ ) {
        if ( device[a] == unraid_volume ) {
             assigned[a] = "UNRAID"
        }     
    }

    # Now, get the model/serial numbers. They should be available in /dev/disk/id-label
    cmd="ls -l /dev/disk/by-id"
    while ((cmd | getline line) > 0 ) {
       delete d;
       split(line,d," ");    
       sub("../../","",d[11])
       for( a = 1; a <= num_partitions; a++ ) {
           if ( d[11] == ( device[a] ) ) {
               model_serial[a]=d[9]
               sub("-part1","", model_serial[a])
               sub("ata-","", model_serial[a])
               break;
           }
       }
    }
    close(cmd);

    # determine if partitions are mounted anywhere
    RS="\n"
    cmd = "mount"
    while ((cmd | getline line) > 0 ) {
       delete s;
       split(line,s," ");
       for( a = 1; a <= num_partitions; a++ ) {
           if ( s[1] == ( "/dev/" device[a] ) ) {
               mounted[a]=s[3]
               break;
           }
       }
    }
    close(cmd);

    # if the partition is part of the managed array, mark it as "in-array"
    # mark the full disk partition as in-array too if matched first three characters.
    for( a = 1; a <= num_partitions; a++ ) {
        for ( i =0; i<numdisks; i++ ) {
            if ( disk_device[i] == substr(device[a],1,3) || disk_name[i] == device[a] ) {
                assigned[a] = "in-array"
            }
        }
       if ( mounted[a] == "/boot" ) {
          boot_device=device[a]
       }
    }
    # mark the boot partitons as "in-array"
    for( a = 1; a <= num_partitions; a++ ) {
       if ( substr(boot_device,1,3) == device[a] ) {
                assigned[a] = "in-array"
       }
    }
    # Get the shares
    delete SHARES
    RS="\n"
    cmd = "smbclient -N -L localhost 2>/dev/null"
    while ((cmd | getline line) > 0 ) {
       delete s;
       split(line,s," ");
       if ( s[2] == "Disk" ) {
          SHARES[s[1]] = s[1]
       }
    }
    close(cmd);

}

function GetOtherDisks(outstr) {

    bootdrive = ""
    cachedrive = ""
    unassigned_drive = ""
    for( a = 1; a <= num_partitions; a++ ) {
       if ( mounted[a] == "/mnt/cache" ) {
            cachedrive = cachedrive "<tr><td colspan=10 align=\"left\"><b><u>Cache Drive</u></b></td></tr>"
            cachedrive = cachedrive "<tr><td width=\"5*\"><u>Device</u></td><td width=\"30*\"><u>Model/Serial</u></td>"
            cachedrive = cachedrive "<td width=\"5*\"><u>Mounted</u></td>"
            cachedrive = cachedrive "<td><u>File&nbsp;System<u></td>"
            cachedrive = cachedrive "<td width=\"5*\" align=\"right\"><u>Temp</u></td>"
            cachedrive = cachedrive "<td width=\"5*\" align=\"right\"><u>Size</u></td>"
            cachedrive = cachedrive "<td width=\"5*\" align=\"right\"><u>Used</u></td>"
            cachedrive = cachedrive "<td width=\"5*\" align=\"right\"><u><nobr>%Used</nobr></u></td>"
            cachedrive = cachedrive "<td width=\"5*\" align=\"right\"><u>Free</u></td></tr>"
            fs = GetDiskFileSystem("/dev/" device[a] );
            mp = mounted[a]
            GetDiskFreeSpace("/dev/" device[a] , numdisks + 3);
            cachedrive = cachedrive "<tr><td>/dev/" device[a] "</td><td>" model_serial[a] "</td><td>" mp "</td>"
            temp= GetDiskTemperature( "/dev/" substr(device[a],1,3) );
            cachedrive = cachedrive "<td>" fs "</td><td>" temp "</td>"
            cachedrive = cachedrive "<td align=\"right\">" disk_size[numdisks + 3] "</td>"
            cachedrive = cachedrive "<td align=\"right\">" disk_used[numdisks + 3] 
            cachedrive = cachedrive "</td><td align=\"right\">" disk_pctuse[numdisks + 3] "</td>"
            cachedrive = cachedrive "<td align=\"right\">" disk_avail[numdisks + 3]"</td>"
            cachedrive = cachedrive "</tr>"
       }
       if ( mounted[a] == "/boot" ) {
            bootdrive = bootdrive "<tr><td colspan=10 align=\"left\"><b><u>UNRAID Drive</u></b></td></tr>"
            bootdrive = bootdrive "<tr><td width=\"5*\"><u>Device</u></td><td width=\"30*\"><u>Model/Serial</u></td>"
            bootdrive = bootdrive "<td width=\"5*\"><u>Mounted</u></td>"
            bootdrive = bootdrive "<td><u>File&nbsp;System<u></td><td></td>"
            bootdrive = bootdrive "<td width=\"5*\" align=\"right\"><u>Size</u></td>"
            bootdrive = bootdrive "<td width=\"5*\" align=\"right\"><u>Used</u></td>"
            bootdrive = bootdrive "<td width=\"5*\" align=\"right\"><u><nobr>%Used</nobr></u></td>"
            bootdrive = bootdrive "<td width=\"5*\" align=\"right\"><u>Free</u></td></tr>"
            fs = GetDiskFileSystem("/dev/" device[a] );
            mp = "/boot"
            GetDiskFreeSpace("/dev/" device[a], numdisks + 2);
            bootdrive = bootdrive "<tr><td>/dev/" device[a] "</td><td>" model_serial[a] "</td><td>" mp "</td>"
            bootdrive = bootdrive "<td>" fs "</td><td></td>"
            bootdrive = bootdrive "<td align=\"right\">" disk_size[numdisks + 2] "</td>"
            bootdrive = bootdrive "<td align=\"right\">" disk_used[numdisks + 2] 
            bootdrive = bootdrive "</td><td align=\"right\">" disk_pctuse[numdisks + 2] "</td>"
            bootdrive = bootdrive "<td align=\"right\">" disk_avail[numdisks + 2]"</td>"
            bootdrive = bootdrive "</tr>"
       }

       if ( substr(device[a],1,2) != "md" && assigned[a] == "" && mounted[a] != "/mnt/cache" ) {
            if ( unassigned_drive == "" ) {
                unassigned_drive = "<tr><td colspan=10 align=\"left\"><b><u>Drive Partitions - Not In Protected Array</u></b></td></tr>"
                unassigned_drive = unassigned_drive "<tr><td width=\"5*\"><u>Device</u></td><td width=\"30*\"><u>Model/Serial</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\"><u>Mounted</u></td>"
                unassigned_drive = unassigned_drive "<td><u>File&nbsp;System<u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Temp</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Size</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Used</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u><nobr>%Used</nobr></u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Free</u></td></tr>"
            }
            fs = GetDiskFileSystem("/dev/" device[a] );
            mp = mounted[a]
            GetDiskFreeSpace("/dev/" device[a] , numdisks + 3);
            if ( device[a] !~ /[0-9]/ ) disk_size[ numdisks + 3] = GetRawDiskSize( "/dev/" device[a] )
            unassigned_drive = unassigned_drive "<tr><td>/dev/" device[a] "</td><td>" model_serial[a] "</td><td>" mp "</td>"
            temp= GetDiskTemperature( "/dev/" substr(device[a],1,3) );
            unassigned_drive = unassigned_drive "<td>" fs "</td><td>" temp "</td>"
            unassigned_drive = unassigned_drive "<td align=\"right\">" disk_size[numdisks + 3] "</td>"
            unassigned_drive = unassigned_drive "<td align=\"right\">" disk_used[numdisks + 3] 
            unassigned_drive = unassigned_drive "</td><td align=\"right\">" disk_pctuse[numdisks + 3] "</td>"
            unassigned_drive = unassigned_drive "<td align=\"right\">" disk_avail[numdisks + 3]"</td>"
            unassigned_drive = unassigned_drive "</tr>"
       }
    }

    outstr = ""
    outstr = outstr "<fieldset style=\"margin-top:5px;\">"
    outstr = outstr "<table width=\"100%\" cellpadding=2 cellspacing=4 border=0>"
    outstr = outstr bootdrive
    if ( cachedrive != "" ) {
        outstr = outstr cachedrive
    }
    if ( unassigned_drive != "" ) {
        outstr = outstr unassigned_drive
    }

    outstr = outstr "</table></fieldset>"
    return outstr
}

function DiskRepair(select_value, i, outstr) {

    outstr = ""
    outstr = outstr "<fieldset style=\"margin-top:10px;\">"
    outstr = outstr "<table width=\"100%\" cellpadding=2 cellspacing=2 border=0>"
    GetDiskData()
    bootdrive = ""
    cachedrive = ""
    unassigned_drive = ""
    unassigned_drive = "<tr><td colspan=10 align=\"left\"><b><u>Drive Partitions - Not In Protected Array</u></b></td></tr>"
    unassigned_drive = unassigned_drive "<tr>"
    unassigned_drive = unassigned_drive "<td width=\"30*\"><u>Model/Serial</u></td>"
    unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Temp</u></td>"
    unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Size</u></td>"
    unassigned_drive = unassigned_drive "<td width=\"5*\"><u>Device</u></td>"
    unassigned_drive = unassigned_drive "<td width=\"5*\"><u>Mounted</u></td>"
    unassigned_drive = unassigned_drive "<td width=\"5\"><u>File&nbsp;System<u></td>"
    unassigned_drive = unassigned_drive "<td width=\"5*\"></td>"
    unassigned_drive = unassigned_drive "</tr>"

    for( a = 1; a <= num_partitions; a++ ) {

            fs = GetDiskFileSystem("/dev/" device[a] );
            mp = mounted[a]
            GetDiskFreeSpace("/dev/" device[a] , numdisks + 3);
            if ( device[a] !~ /[0-9]/ ) {
                disk_size[ numdisks + 3] = GetRawDiskSize( "/dev/" device[a] )
            }
            unassigned_drive = unassigned_drive "<tr>"
            unassigned_drive = unassigned_drive "<td>" model_serial[a] "</td>"
            temp= GetDiskTemperature( "/dev/" substr(device[a],1,3) );
            unassigned_drive = unassigned_drive "<td align=\"center\">" temp "</td>"
            unassigned_drive = unassigned_drive "<td align=\"right\">" disk_size[numdisks + 3] "</td>"
            unassigned_drive = unassigned_drive "<td>/dev/" device[a] "</td>"
            unassigned_drive = unassigned_drive "<td>" mp "</td>"
            unassigned_drive = unassigned_drive "<td>" fs "</td>"
            # If this is a partition on a drive.  
            if ( device[a] ~ /[0-9]/ ) {
                # if there is file system on the partition
                if ( fs != "" ) {
                    # if the partition is mounted
                    if ( mp != "" ) {
                        #unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                        if (  device[a] in SHARES ) {
                            # if the partition is shared
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"unshare-"
                            unassigned_drive = unassigned_drive device[a] "\" value=\"Stop Share of /dev/" device[a] "\"</td>"
                        } else {
                            # if the partition is not yet shared
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"unmount-"
                            unassigned_drive = unassigned_drive device[a] "\" value=\"Un-Mount /dev/" device[a] "\"</td>"
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"share-"
                            unassigned_drive = unassigned_drive device[a] "\" value=\"Share /dev/" device[a] "\"</td>"
                        }
                    } else {
                        if ( fs == "ntfs" || fs == "reiserfs" || fs == "ext2" || fs == "vfat" ) {
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"mount-"
                            unassigned_drive = unassigned_drive device[a] "-" fs "\" value=\"Mount /dev/" device[a] "\"</td>"
                            unassigned_drive = unassigned_drive "<td width=\"5*\"></td>"
                        } else {
                            unassigned_drive = unassigned_drive "<td width=\"15%\"></td>"
                            unassigned_drive = unassigned_drive "<td width=\"15%\"></td>"
                        }
                    }
                }
            # If this is the raw drive, and not a partition.  
            } else {
                # SMART features not available on USB devices
                if ( model_serial[a] ~ /^usb-/ ) {
                    unassigned_drive = unassigned_drive "<td align=\"left\" width=\"30%\" colspan=\"6\"></td>"
                    #unassigned_drive = unassigned_drive "<input type=submit name=\"hdparm-"
                    #unassigned_drive = unassigned_drive device[a] "\" value=\"HDParm (" device[a] ")\"</td>"
                } else {
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"hdparm-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"HDParm (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_status-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Smart Status (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                    unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_short-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Short Smart Test (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_long-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Long Smart Test (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                    unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"spin_up-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Spin Up (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"spin_down-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Spin Down (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                }
            }
            unassigned_drive = unassigned_drive "</tr>"
    }
    outrows=""
    outrows = outrows "<td><u>Status</u></td><td><u>Device</u></td><td><u>Model/Serial</u></td>"
    outrows = outrows "<td align=\"center\" ><u>Temp</u></td><td width=\"50%\"><u>File System<u></td>"
    outstr = outstr unassigned_drive

    outstr = outstr "</table></fieldset>"
    return outstr
}

function DiskManagement(select_value, i, outstr ) {

    outstr = ""
    outstr = outstr "<fieldset style=\"margin-top:10px;\"><legend><strong>Array Disk Management</strong></legend>"
    outstr = outstr "<table width=\"100%\" cellpadding=1 cellspacing=1 border=0>"
    outstr = outstr "<tr>"
    outstr = outstr "<td><u>Device</u>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
    outstr = outstr "<u>Model/Serial</u></td><td><u></u></td>"
    outstr = outstr "</tr>"
    outstr = outstr "<tr><td><select style=\"font-family:courier\" name=\"disk_device\"><option value=\"\"></option>"
    for ( i =0; i<numdisks; i++ ) {
        if ( disk_device[i] == "" ) { continue; }
        option_value="/dev/" disk_device[i] "|" disk_id[i] "|" disk_name[i] 
        if ( select_value == option_value ) { 
            is_selected = "selected" 
        } else { 
            is_selected = "" 
        }
        outstr = outstr "<option value=\"" option_value "\" " is_selected ">"
        outstr = outstr "/dev/" disk_device[i] " " disk_id[i] "</option>" ORS
    }
    outstr = outstr "</select></td>"
    outstr = outstr "<td ><input type=submit name=\"hdparm\" value=\"HDParm Info\"</td>"
    outstr = outstr "<td ><input type=submit name=\"smart_stats\" value=\"Smart Statistics\"</td>"
    outstr = outstr "<td ><input type=submit name=\"smart_short\" value=\"Short Smart Test\"</td>"
    outstr = outstr "<td ><input type=submit name=\"smart_long\" value=\"Long Smart Test\"</td>"
    outstr = outstr "<td width=\"800\">&nbsp;</td>"
    outstr = outstr "</tr><tr><td>&nbsp;</td>"
    outstr = outstr "<td ><input type=submit name=\"spin_up\" value=\"Spin Up\"</td>"
    outstr = outstr "<td ><input type=submit name=\"spin_down\" value=\"Spin Down\"</td>"
    outstr = outstr "<td ><input type=submit name=\"fsck\" value=\"File System Check\"</td>"
    #outstr = outstr "<td ><input type=submit name=\"umount\" value=\"Un-Mount Drive\"</td>"
    #outstr = outstr "<td ><input type=submit name=\"fsck_repair\" value=\"File System Repair\"</td>"
    outstr = outstr "<td width=\"800\">&nbsp;</td>"
    outstr = outstr "</tr>"
    i = numdisks + 1;
    outstr = outstr "<tr><td align=\"left\" colspan=\"99\"><ul><li>Short SMART tests take a few minutes or more to run, "
    outstr = outstr "Long SMART tests can take hours. SMART reports and tests will spin up the drive."
    outstr = outstr "<li>File System Checks can take from a few minutes to 30 minutes or more in a large file system with lots of files.<br> "
    outstr = outstr "It will appear as if the browser is hung waiting for the web-server to return. "
    outstr = outstr "<b>Be patient, it eventually will.</b><br>File System Check output is also sent to the System Log</ul>"
    outstr = outstr "<font color=\"blue\">"
    outstr = outstr "Warning: A file system check will stop SAMBA and unmount the drive, perform the file system "
    outstr = outstr "check, then re-mount the drive and re-start SAMBA.<br>"
    outstr = outstr "<b>Neither Disk or User Shares will be visible on the LAN when SAMBA is stopped</b></font></td></tr>"
    outstr = outstr "</table></fieldset>"
    outstr = outstr "<fieldset style=\"margin-top:10px;\">"
    outstr = outstr "<table width=\"100%\" cellpadding=2 cellspacing=2 border=0>"

    GetDiskData()
    bootdrive = ""
    cachedrive = ""
    unassigned_drive = ""
    for( a = 1; a <= num_partitions; a++ ) {

       if ( substr(device[a],1,2) != "md" && assigned[a] == "" ) {
            if ( unassigned_drive == "" ) {
                unassigned_drive = "<tr><td colspan=10 align=\"left\"><b><u>Drive Partitions - Not In Protected Array</u></b></td></tr>"
                unassigned_drive = unassigned_drive "<tr>"
                unassigned_drive = unassigned_drive "<td width=\"30*\"><u>Model/Serial</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Temp</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\" align=\"right\"><u>Size</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\"><u>Device</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\"><u>Mounted</u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5\"><u>File&nbsp;System<u></td>"
                unassigned_drive = unassigned_drive "<td width=\"5*\"></td>"
                unassigned_drive = unassigned_drive "</tr>"
            }
            fs = GetDiskFileSystem("/dev/" device[a] );
            mp = mounted[a]
            GetDiskFreeSpace("/dev/" device[a] , numdisks + 3);
            if ( device[a] !~ /[0-9]/ ) {
                disk_size[ numdisks + 3] = GetRawDiskSize( "/dev/" device[a] )
            }
            unassigned_drive = unassigned_drive "<tr>"
            unassigned_drive = unassigned_drive "<td>" model_serial[a] "</td>"
            temp= GetDiskTemperature( "/dev/" substr(device[a],1,3) );
            unassigned_drive = unassigned_drive "<td align=\"center\">" temp "</td>"
            unassigned_drive = unassigned_drive "<td align=\"right\">" disk_size[numdisks + 3] "</td>"
            unassigned_drive = unassigned_drive "<td>/dev/" device[a] "</td>"
            unassigned_drive = unassigned_drive "<td>" mp "</td>"
            unassigned_drive = unassigned_drive "<td>" fs "</td>"
            # If this is a partition on a drive.  
            if ( device[a] ~ /[0-9]/  || fs == "vfat" ) {
                # if there is file system on the partition
                if ( fs != "" ) {
                    # if the partition is mounted
                    if ( mp != "" ) {
                        #unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                        if (  device[a] in SHARES ) {
                            # if the partition is shared
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"unshare-"
                            unassigned_drive = unassigned_drive device[a] "\" value=\"Stop Share of /dev/" device[a] "\"</td>"
                        } else {
                            # if the partition is not yet shared
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"unmount-"
                            unassigned_drive = unassigned_drive device[a] "\" value=\"Un-Mount /dev/" device[a] "\"</td>"
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"share-"
                            unassigned_drive = unassigned_drive device[a] "\" value=\"Share /dev/" device[a] "\"</td>"
                        }
                    } else {
                        if ( fs == "ntfs" || fs == "reiserfs" || fs == "ext2" || fs == "vfat" ) {
                            unassigned_drive = unassigned_drive "<td ><input type=submit name=\"mount-"
                            unassigned_drive = unassigned_drive device[a] "-" fs "\" value=\"Mount /dev/" device[a] "\"</td>"
                            unassigned_drive = unassigned_drive "<td width=\"5*\"></td>"
                        } else {
                            unassigned_drive = unassigned_drive "<td width=\"15%\"></td>"
                            unassigned_drive = unassigned_drive "<td width=\"15%\"></td>"
                        }
                    }
                }
            # If this is the raw drive, and not a partition.  
            } else {
                # SMART features not available on USB devices
                if ( model_serial[a] ~ /^usb-/ ) {
                    unassigned_drive = unassigned_drive "<td align=\"left\" width=\"30%\" colspan=\"6\"></td>"
                    #unassigned_drive = unassigned_drive "<input type=submit name=\"hdparm-"
                    #unassigned_drive = unassigned_drive device[a] "\" value=\"HDParm (" device[a] ")\"</td>"
                } else {
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"hdparm-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"HDParm (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_status-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Smart Status (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                    unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_short-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Short Smart Test (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"smart_long-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Long Smart Test (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                    unassigned_drive = unassigned_drive "<tr><td colspan=\"6\"></td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"spin_up-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Spin Up (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "<td ><input type=submit name=\"spin_down-"
                    unassigned_drive = unassigned_drive device[a] "\" value=\"Spin Down (" device[a] ")\"</td>"
                    unassigned_drive = unassigned_drive "</tr>"
                }
            }
            unassigned_drive = unassigned_drive "</tr>"
       }
    }
    outrows=""
    outrows = outrows "<td><u>Status</u></td><td><u>Device</u></td><td><u>Model/Serial</u></td>"
    outrows = outrows "<td align=\"center\" ><u>Temp</u></td><td width=\"50%\"><u>File System<u></td>"
    outstr = outstr unassigned_drive

    outstr = outstr "</table></fieldset>"
    return outstr
}

function DiskStatusHTML(i,outstr) {
    total_disk_size = 0
    total_disk_used = 0
    total_disk_avail = 0
    outstr ="<fieldset style=\"margin-top:10px;\"><legend><strong>Array Disk Status</strong></legend>"
    outstr = outstr "<table width=\"100%\" cellpadding=0 cellspacing=0 border=0>"
    outstr = outstr "<tr>"
    outstr = outstr "<td><u>Status</u></td><td><u>Disk</u></td><td><u>Mounted</u></td>"
    outstr = outstr "<td><u>Device</u></td><td><u>Model/Serial</u></td><td align=\"right\"><u>Temp</u></td>"
    outstr = outstr "<td align=\"right\"><u>Reads</u></td><td align=\"right\"><u>Writes</u></td><td align=\"right\"><u>Errors</u></td>"

    outstr = outstr "<td align=\"right\"><u>Size</u></td><td align=\"right\"><u>Used</u></td><td align=\"right\"><u>%Used</u></td>"
    outstr = outstr "<td align=\"right\"><u>Free</u></td>"
    outstr = outstr "</tr>"
    for ( i =0; i<numdisks; i++ ) {
        if ( disk_status[i] == "DISK_NP" && disk_device[i] == "" ) {
            continue;
        }
        if ( disk_name[i] == "" ) {
            if ( disk_status[i] == "DISK_NEW" ) {
                disk_name[i] = "new disk";
            } else {
                disk_name[i] = "parity";
            }
        } else {
            disk_name[i] = "/dev/" disk_name[i];
        }
        if ( disk_status[i] == "DISK_OK" ) {
            disk_status[i] = "<font color=\"green\">OK</font>";
        } else if ( disk_status[i] == "DISK_DSBL_NEW" ) {
            disk_status[i] = "<font color=\"blue\">New Disk</font>";
        } else {
            if ( disk_name[i] == "parity" && disk_status[i] == "DISK_DSBL_NP" ) {
              disk_id[i] = "parity disk not present (" disk_status[i] ")"
              disk_status[i] = "--"
            } else {
              disk_status[i] = "<font color=\"red\"><b>" disk_status[i] "</b></font>"
            }
        }
        GetDiskFreeSpace(disk_name[i], i);
        temp= GetDiskTemperature("/dev/" disk_device[i]);
        outstr = outstr "<tr>"
        outstr = outstr "<td>" disk_status[i] "</td><td>" disk_name[i] "</td><td>" disk_mounted[i] "</td>"
        dev = disk_device[i] ? "/dev/" : ""
        outstr = outstr "<td>" dev disk_device[i] "</td><td>" disk_id[i] 
        if ( disk_status[i] ~ "DISK_WRONG" ) {
            outstr = outstr " <-- was old disk in this slot<br>&nbsp;&nbsp;&nbsp;" rdisk_model[i] "_" rdisk_serial[i] " <-- current disk in this slot"
        }
        outstr = outstr "</td>"

        outstr = outstr "<td align=\"right\">" temp "</td>"
        outstr = outstr "<td align=\"right\">" disk_reads[i] "</td><td align=\"right\">" 
        outstr = outstr disk_writes[i] "</td><td align=\"right\">" disk_errors[i] "</td>"

        outstr = outstr "<td align=\"right\">" disk_size[i] "</td><td align=\"right\">" disk_used[i] 
        outstr = outstr "</td><td align=\"right\">" disk_pctuse[i] "</td>"
        outstr = outstr "<td align=\"right\">" disk_avail[i] "</td>"
        outstr = outstr "</tr>"
    }
    i = numdisks + 1;
    GetDiskFreeSpace( "total", i );
    outstr = outstr "<tr>"
    outstr = outstr "<td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td>"
    outstr = outstr "<td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td>"
    outstr = outstr "<td>&nbsp;</td><td>&nbsp;</td><td align=\"right\" class=\"t\">Total:</td>"
    outstr = outstr "<td align=\"right\" class=\"t\">" disk_size[i] "</td><td align=\"right\" class=\"t\">" disk_used[i] 
    outstr = outstr "</td><td align=\"right\" class=\"t\">" disk_pctuse[i] "</td>"
    outstr = outstr "<td align=\"right\" class=\"t\">" disk_avail[i] "</b></td>"
    outstr = outstr "</tr>"
    outstr = outstr "</table></fieldset>"
    return outstr
}

function GetReadWriteStats(theDevIndex,  cmd) {
  cmd="cat /sys/block/" disk_device[theDevIndex] "/stat 2>/dev/null"
  cmd | getline
  disk_reads[theDevIndex] = $1
  disk_writes[theDevIndex] = $5
  close(cmd)
}

function GetDiskFileSystem(theDisk , thePartition, file_system, a, s) {
    # get the file system of the specified partition
    cmd = "vol_id " theDisk thePartition " 2>/dev/null"
#print cmd
    file_system=""
    RS="\n"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ "ID_FS_TYPE" ) {
            delete s;
            split(a,s,"=");
            file_system=s[2]
        }
    }
    close(cmd);
    return file_system
}

function GetMountPoint( theDisk , mount_point, a, s ) {
    mount_point=""
    RS="\n"
    cmd = "mount"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ theDisk ) {
            delete s;
            split(a,s," ");
            mount_point=s[3]
        }
    }
    close(cmd);
    return mount_point
}

function GetRawDiskBlocks( theDisk, partition, a, s) {
    d_size = ""
    cmd = "fdisk -l " theDisk " 2>/dev/null"
    RS="\n"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ theDisk ) {
            delete s;
            split(a,s," ");
            d_size=s[5]
            break;
        }
    }
    close(cmd);
    return ( d_size / 1024 )
}

function GetRawDiskSize( theDisk, partition, a, s) {
    d_size = ""
    cmd = "fdisk -l " theDisk " 2>/dev/null"
    RS="\n"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ theDisk ) {
            delete s;
            split(a,s," ");
            d_size=s[3] s[4]
            break;
        }
    }
    close(cmd);
    sub("B,","",d_size)
    return d_size
}

function IsSambaStarted( cmd) {
    samba_online="no"
    cmd="ps -ef | grep /usr/sbin/smbd | grep -v grep"
    while (( cmd | getline f ) > 0)  {
    if ( f ~ "smbd" ) {
        samba_online="yes"
    }
    }
    close(cmd);
    return samba_online
}

function GetDiskTemperature(theDisk, the_temp, cmd, a, t, is_sleeping, i) {

    if ( theDisk == "/dev/" ) {
       return "";
    }

    is_sleeping = ""
    # We might be able to determine spinning status by the output of the the mdcmd status.
    # If we can, no need for the hdparm -C command
    theDiskDevice=substr(theDisk,6,length(theDisk))
    for ( i =0; i<numdisks; i++ ) {
        if ( disk_device[i] == "" ) { continue; }
        if ( disk_device[i] == theDiskDevice ) {
           if ( disk_lastIO[i] == "0" ) {
              is_sleeping = "y"
           } else {
              is_sleeping = "n"
           }
           break;
        }
    }
    
    if ( is_sleeping == "" ) {
       is_sleeping = "n"
       cmd = "hdparm -C " theDisk " 2>/dev/null" 
       while ((cmd | getline a) > 0 ) {
          if ( a ~ "standby" ) {
              is_sleeping = "y"
          }
       }
       close(cmd);
    }

    the_temp="*"
    if ( is_sleeping == "n" ) {
        cmd = "smartctl -d ata -A " theDisk "| grep -i temperature" 
        while ((cmd | getline a) > 0 ) {
            delete t;
            split(a,t," ")
            the_temp = t[10] "&deg;C"
            t[10] = t[10] + 0 # coerce to a number
            yellow_temp = yellow_temp + 0
            orange_temp = orange_temp + 0
            red_temp = red_temp + 0
            if ( t[10] >= yellow_temp && t[10] < orange_temp ) {
                the_temp = "<div style=\"background-color:yellow;\">" the_temp "</div>"
            }
            if ( t[10] >= orange_temp && t[10] < red_temp ) {
                the_temp = "<div style=\"background-color:orange;\">" the_temp "</div>"
            }
            if ( t[10] >= red_temp ) {
                the_temp = "<div style=\"background-color:red;\">" the_temp "</div>"
            }
        }
        close(cmd);
    }
    return extra the_temp
}

function GetDiskFreeSpace(theDisk, theArrayIndex, a) {
    RS="\n"
    theDisk = theDisk " " # append a space to the disk name so we do not mistake md10 for md1
    found_flag="n"
    
    cmd="df --block-size=" OneThousand

    while (( cmd | getline a) > 0 ) {
        #one user reported his "df" returned /dev/md/3 instead of /dev/md3.  this fixes the name
        gsub("/dev/md/","/dev/md", a)
        if ( a ~ theDisk ) {
            found_flag="y"
            delete free;
            split(a,free," ");
            disk_size[theArrayIndex]=human_readable_number(free[2])
            disk_used[theArrayIndex]=human_readable_number(free[3])
            disk_avail[theArrayIndex]=human_readable_number(free[4])
            disk_pctuse[theArrayIndex]=free[5]
            disk_mounted[theArrayIndex]=free[6]
            total_disk_size +=free[2]
            total_disk_used +=free[3]
            total_disk_avail +=free[4]
        }
    }
    if ( found_flag == "n" ) {
        disk_size[theArrayIndex]="";
        disk_used[theArrayIndex]="";
        disk_avail[theArrayIndex]="";
        disk_pctuse[theArrayIndex]="";
        disk_mounted[theArrayIndex]="";
    }
    if ( theDisk == "total " ) {
        disk_size[theArrayIndex]=human_readable_number(total_disk_size)
        disk_used[theArrayIndex]=human_readable_number(total_disk_used)
        disk_avail[theArrayIndex]=human_readable_number(total_disk_avail)
        if ( total_disk_size > 0 ) {
            total_pct_used = int( ( total_disk_used * 100 ) / total_disk_size) "%";
        }
        disk_pctuse[theArrayIndex]=total_pct_used;
        disk_mounted[theArrayIndex]="";
    }
    close(cmd)
}

function human_readable_number( num ) {
    OneThousand = OneThousand + 0 #coerce to number
    suffix="K"
    if ( num > OneThousand ) {
        num = num / OneThousand
        suffix="M"
    }
    if ( num > OneThousand ) {
        num = num / OneThousand
        suffix="G"
    }
    if ( num > OneThousand ) {
        num = num / OneThousand
        suffix="T"
    }
    ret_val = sprintf( "%.2f%s", num, suffix)
    return ret_val
}

# open and read the unmenu configuration file.  In it, look for lines with the following pattern:
#variableName = ReplacementValue

# The values found there can be used to override values of some variables in these scripts.
# the CONFIG[] array is set with the variable.

function GetConfigValues(cfile, preface) {
    RS="\n"
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^([^# \t=]+)([\t ]*)(=)([\t ]*)(.+)/, c)
          #print c[1,"length"] " " c[2,"length"] " " c[3,"length"] " "  c[4, "length"] " " c[5, "length"] " " line
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && 
               c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               CONFIG[ preface substr(line,c[1,"start"],c[1,"length"])] = substr(line,c[5,"start"],c[5,"length"])
               if ( DebugMode == "yes" ) { 
                   print "importing from " cfile ": " \
                     "CONFIG[" preface substr(line,c[1,"start"],c[1,"length"]) "] = " substr(line,c[5,"start"],c[5,"length"])
               }
          }
    }
    close(cfile);
}

# Get the per-filesystem mount options.
# they are expected as follows (without the leading "#")
# The option for "other" is used for fs-types not specifically defined.
#MOUNT_OPTIONS reiserfs = -r -o noatime,nodiratime -t reiserfs
#MOUNT_OPTIONS ntfs     = -r -o umask=111,dmask=000 -t ntfs-3g
#MOUNT_OPTIONS vfat     = -r
#MOUNT_OPTIONS other    = -r

function GetMountOptions(cfile) {
   RS="\n"
   while (( getline line < cfile ) > 0 ) {
      if ( line ~ "MOUNT_OPTIONS" ) {
          delete c;
          match( line , /^(MOUNT_OPTIONS)([\t ]*)([^\t =]*)([=\t ]*)(.*)/, c)
          #print c[1,"length"] " " c[2,"length"] " " c[3,"length"] " "  c[4, "length"] " " c[5, "length"] " " line
          if ( c[1,"length"] > 0 && c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               MOUNT_OPTIONS[substr(line, c[3,"start"],c[3,"length"])] = substr(line,c[5,"start"],c[5,"length"])
          }
      }
   }
   close(cfile);
}

function CommaFormat(num, out)
{
   while(length(num) > 3) {
      out = "," substr(num, length(num)-2) out
      num = substr(num, 1, length(num)-3)
   }

   if(length(num) > 0)
      return(num out);
   else
      return(substr(out,1));
}

function perr(printme)
{
  if ( DebugMode == "yes" ) { 
   print printme >/dev/stderr
  }
}
