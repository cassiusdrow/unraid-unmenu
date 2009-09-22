BEGIN {
#define ADD_ON_URL         package_manager
#define ADD_ON_MENU        Package Manager
#define ADD_ON_STATUS      NO
#define ADD_ON_TYPE        awk
#define ADD_ON_VERSION     1.0 BubbaQ
#define ADD_ON_VERSION     1.1 Initial concept by BubbaQ - extensive Modifications by Joe L.
#define ADD_ON_VERSION     1.2 Changed pattern expected to match package .conf files to not need leading number, suggested by jarodtufts
#define ADD_ON_VERSION     1.3 Added code to identify mal-formed package .conf files.
#define ADD_ON_VERSION     1.4 fixed incorrect button name when package exists on server, but different version.
#define ADD_ON_VERSION     1.5 Improved handling of download when 404 "not-found" error returned on download URL


  if ( MyHost == "" ) {
      "uname -n" | getline MyHost
      close("uname -n")
  }
  # You can override the default port from the command line too.
  if (MyPort ==  0) MyPort = 8080

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

  PACKAGE_DIRECTORY = CONFIG["PACKAGE_DIRECTORY"] ? CONFIG["PACKAGE_DIRECTORY"] : "/boot/packages"
  AUTO_INSTALL_COMMAND = CONFIG["AUTO_INSTALL_COMMAND"] ? CONFIG["AUTO_INSTALL_COMMAND"] : ""

  # if this directory does not exist, the auto install file command will be appended to the /boot/config/go script
  # the location can be overridden from the unmenu.conf file
  AUTO_INSTALL_DIRECTORY = CONFIG["AUTO_INSTALL_DIRECTORY"] ? CONFIG["AUTO_INSTALL_DIRECTORY"] : "/boot/custom/etc/rc.d"
  AUTO_INSTALL_FILE      = CONFIG["AUTO_INSTALL_FILE"] ? CONFIG["AUTO_INSTALL_FILE"] : "S10-install_custom_packages"
  AUTO_INSTALL_TEST      = CONFIG["AUTO_INSTALL_TEST"] ? CONFIG["AUTO_INSTALL_TEST"] : "grep '^[^#]*\\.auto_install'"

  # if the package folder does not exist, create it
  CreatePackageFolder( PACKAGE_DIRECTORY )

  CGI_setup()

  RS="\n"

  cmd="cd " ScriptDirectory "; pwd"
  cmd | getline ScriptDirectory
  close(cmd)

  # open unmenu package files, 
  # look for any "*-unmenu-package*.conf" files
  # move them to the packages directory, then
  # for each file, open it to read the desired package details
  cmd="ls " ScriptDirectory "/*-unmenu-*package*.conf 2>/dev/null"

  while (( cmd | getline unmenu_package_file ) > 0) {
    system("mv " unmenu_package_file " " PACKAGE_DIRECTORY "/" );
  }
  close(cmd);

  cmd="ls " PACKAGE_DIRECTORY "/*-unmenu-*package*.conf 2>/dev/null"
  package_count=0
  ep=0
  
  while (( cmd | getline unmenu_package_file ) > 0) {
    package[ep] = unmenu_package_file;
    ep++;
  }
  close(cmd);
  # now, process each package file in turn.  Open them, scan for their parameters as described below.
  for ( i = 0; i < ep; i++ ) {
    while (( getline line < package[i] ) > 0 ) {
      # just in case the package configure file was edited in windows... get rid of the carriage return.
      gsub("\r","", line)

      delete c;
      # expect the package name first in a series of lines.
      match( line , /^(PACKAGE_NAME)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
          package_count++;
	  package_name[package_count]   = substr(line,c[3,"start"],c[3,"length"])
          package_descr[package_count]  = ""
          package_url[package_count]    = ""
          package_file[package_count]   = "PACKAGE_FILE undefined"
          package_installed[package_count]   = ""
          package_version_test[package_count]   = "echo undefined"
          package_version_string[package_count]   = ""
          package_depend[package_count] = ""
          package_dependency_count[package_count] = 0
          package_install_count[package_count] = 0
          package_installation[package_count, 0]   = "PACKAGE_INSTALLATION undefined"
          package_mem[package_count]   = ""
      }
      # expect the package description.  There may be more than one line, just concatenate
      delete c;
      match( line , /^(PACKAGE_DESCR)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_descr[package_count] = package_descr[package_count] " " substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the URL to download the package
      match( line , /^(PACKAGE_URL)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_url[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the name of a file to test if exists.  If it exists, package is already downloaded.
      match( line , /^(PACKAGE_FILE)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_file[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the MD5 checksum to verify the downloaded package arrived intact.
      match( line , /^(PACKAGE_MD5)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_md5[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the name of a file to test if package installed.  If it exists, package is installed.
      match( line , /^(PACKAGE_INSTALLED)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_installed[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the name of a command to run to verify version of package currently installed.
      match( line , /^(PACKAGE_VERSION_TEST)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_version_test[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the name of a file to test if package installed.  If it exists, package is installed.
      match( line , /^(PACKAGE_VERSION_STRING)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_version_string[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # names of package dependecies (file names that must exist, one per line) This is a "two-dimensional" array
      # and may have multiple members
      match( line , /^(PACKAGE_DEPENDENCIES)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
          package_dependency_count[package_count]++
	  package_depend[package_count, package_dependency_count[package_count]] = substr(line,c[3,"start"],c[3,"length"])
      }
      # package installation commands (one per line) This is a "two-dimensional" array
      # and may have multiple members, one per command.  
      # If not specified, this will be "installpkg package_name"
      match( line , /^(PACKAGE_INSTALLATION)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
          package_install_count[package_count]++
	  package_installation[package_count, package_install_count[package_count]] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # memory usage of package
      match( line , /^(PACKAGE_MEMORY_USAGE)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_mem[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
    }
    close(package[i]);
  }


  # Internal strftime is always local time. We can request the offset (%z) and use it to calculate GMT time.
  # Get time-zone offset (needed for GMT timestamps in HTTP headers)
  # we multiply by -1 since we need to know GMT's offset from local, not local's offset from GMT
  tz_offset = ( strftime("%z", systime()) / 100 ) * 60 * 60 * -1


  ORS = "\r\n"
  MyPrefix    = "http://" MyHost ":" MyPort

  theHTML = "" 
  for (a in PARAM) {
      if ( PARAM[a] ~ "manual_install-" ) {
          OLD_RS = RS
          OLD_ORS = ORS
          ORS = "\n"
          RS  = "\n"
          delete d;
          split(PARAM[a],d,"=")
          the_package = substr(d[1],length("manual_install-")+1,length(d[1]))
          theHTML = theHTML "<br>" 
          theHTML = theHTML "<font color=\"blue\"><b>" the_package " installation:</b></font><br><pre>"
          for ( i = 1; i <= package_count; i++ ) {
            if ( the_package == package_file[i] ) {
               manual_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".manual_install"
               print "SCRIPT_DIRECTORY=" ScriptDirectory > manual_install_file
               for ( pc=1; pc <= package_install_count[i]; pc++ ) {
                  print package_installation[i,pc] > manual_install_file
               } 
               close(manual_install_file)
               
               cmd = "chmod +x '" manual_install_file "';cd '" PACKAGE_DIRECTORY "'; sh -c '" manual_install_file "' 2>&1"
               while (( cmd | getline inst_out  ) > 0) {
                  theHTML = theHTML inst_out ORS
               }
               theHTML = theHTML "</pre>"
               if ( FileExists( package_installed[i] ) == "yes" ) {
                 theHTML = theHTML "<font color=\"blue\"><b>" the_package " is now installed:</b></font><br><pre>"
               } else {
                 theHTML = theHTML "<font color=\"blue\"><b>" the_package 
                 theHTML = theHTML " apparently did not install properly, " package_installed[i] " does not exist.</b></font><br><pre>"
               }
               break;
            }
          }
          ORS = OLD_ORS
          RS = OLD_RS
          break;
      }
      if ( PARAM[a] ~ "auto_install-" ) {
          OLD_ORS = ORS
          ORS = "\n"
          delete d;
          split(PARAM[a],d,"=")
          the_package = substr(d[1],length("auto_install-")+1,length(d[1]))
          theHTML = theHTML "<br>" 
          theHTML = theHTML "<font color=\"blue\"><b>" the_package " Will be Re-Installed each time the server is re-booted</b></font><br>"
          for ( i = 1; i <= package_count; i++ ) {
            if ( the_package == package_file[i] ) {
               auto_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".auto_install"
               print "SCRIPT_DIRECTORY=" ScriptDirectory > auto_install_file
               for ( pc=1; pc <= package_install_count[i]; pc++ ) {
                  print package_installation[i,pc] > auto_install_file
               } 
               close(auto_install_file)
               system("chmod +x '" auto_install_file "'")
               break;
            }
          }
          ORS = OLD_ORS
          install_auto_install_command()
          break;
      }
      if ( PARAM[a] ~ "no_install-" ) {
          OLD_ORS = ORS
          ORS = "\n"
          delete d;
          split(PARAM[a],d,"=")
          the_package = substr(d[1],length("no_install-")+1,length(d[1]))
          theHTML = theHTML "<br>" 
          theHTML = theHTML "<font color=\"blue\"><b>" the_package " Will be no longer be Re-Installed each time the server is re-booted</b></font><br>"
          for ( i = 1; i <= package_count; i++ ) {
            if ( the_package == package_file[i] ) {
               auto_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".auto_install"
               system("rm '" auto_install_file "'" )
               break;
            }
          }
          ORS = OLD_ORS
          break;
      }
      # If the user pressed the "download" button, process it.
      if ( PARAM[a] ~ "download-" ) {
          OLD_ORS = ORS
          ORS = "\n"
          delete d;
          split(PARAM[a],d,"=")
          the_package = substr(d[1],length("download-")+1,length(d[1]))
          theHTML = theHTML "<br>" 
          for ( i = 1; i <= package_count; i++ ) {
            if ( the_package == package_file[i] ) {
               match( package_url[i] , /^(http:\/\/)([^\/]*)(.*)/, c)
               if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
                 theServer = substr(package_url[i],c[2,"start"],c[2,"length"])
                 #theURL    = "/" substr(package_url[i],c[3,"start"],c[3,"length"])
                 port   = "/80"
                 download_package(package_name[i], PACKAGE_DIRECTORY "/" package_file[i],  theServer, port, package_url[i] )
               }
               if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ) == "yes" ) {
                 theHTML = theHTML "<font color=\"blue\"><b>" the_package " has been downloaded</b></font><br>"
               } else {
                 theHTML = theHTML "<font color=\"red\"><b>" the_package " not successfully downloaded</b></font><br>"
               }
               break;
            }
          }
          ORS = OLD_ORS
          break;
      }
  }

  theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>Download and Install Extra Software Packages</strong></legend>"
  theHTML = theHTML "<form>"
  theHTML = theHTML "<table width=\"100%\" border=0>"
  for ( i = 1; i <= package_count; i++ ) {
    theHTML = theHTML "<tr>"
    theHTML = theHTML "<td style=\"background-color:#DDDDDD\">"
    theHTML = theHTML package_name[i]
    theHTML = theHTML "</td>"
    if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ) == "yes" || package_url[i] == "none" ) {
        if ( FileExists( package_installed[i] ) == "yes" ) {
           ver_string = PackageVersionTest( package_version_test[i] )

           # if package is installed already and is the same version
           if ( package_version_test[i] != "" && ver_string == package_version_string[i] ) { 


             if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ".auto_install" ) == "yes" ) {
               theHTML = theHTML "<td><font color=\"blue\">Currently Installed.<br>Will be automatically Re-Installed upon Re-Boot.</font></td>"
               theHTML = theHTML "<td ><input type=submit name=\"no_install-"
               theHTML = theHTML package_file[i] "\" value=\"Disable Re-Install on Re-Boot\"></td>"
             } else {
               theHTML = theHTML "<td><font color=\"blue\">Currently Installed.</font><br><font color=\"brown\">Will <b>"
               theHTML = theHTML "NOT</b> be automatically Re-Installed upon Re-Boot.</font></td>"
               theHTML = theHTML "<td ><input type=submit name=\"auto_install-"
               theHTML = theHTML package_file[i] "\" value=\"Enable Re-Install on Re-Boot\"></td>"
             }
           } else { # installed, but different version
             theHTML = theHTML "<td><font color=\"orange\">Installed, but version is different.<br>"
             theHTML = theHTML "Current version='" ver_string "' expected '" package_version_string[i] "'</font></td>"
             if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ) == "yes" ) {
               if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_file[i], package_md5[i] ) == "OK" ) {
                 theHTML = theHTML "<td><input type=submit name=\"manual_install-" package_file[i] "\" value=\"Install " package_file[i] "\"</td>"
               } else {
                 theHTML = theHTML "<td><b><font color=\"red\"> (MD5 of existing downloaded file NOT matched - download may be corrupted.)</b></font>"
                 if ( IsHTML( PACKAGE_DIRECTORY "/" package_file[i], package_md5[i] ) == "YES" ) {
                     theHTML = theHTML ShowFile( PACKAGE_DIRECTORY "/" package_file[i], 20)
                 }
                 theHTML = theHTML "<input type=submit name=\"download-" package_file[i] "\" value=\"Download " package_file[i] "\"</td>"
               }
             } 
           }
        } else {
           # package is not installed yet, but is downloaded
           if ( package_url[i] == "none" ) {
             theHTML = theHTML "<td><font color=\"purple\">Package not yet installed (no download needed)</font></td>"
           } else {
             theHTML = theHTML "<td><font color=\"purple\">Package downloaded, but not yet installed</font></td>"
           }
           if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_file[i], package_md5[i] ) == "OK" ) {
             theHTML = theHTML "<td><input type=submit name=\"manual_install-" package_file[i] "\" value=\"Install " package_file[i] "\"</td>"
           } else {
             theHTML = theHTML "<td><b><font color=\"red\"> (MD5 of existing downloaded file NOT matched - download may be corrupted.)</b></font>"
             theHTML = theHTML "<input type=submit name=\"download-" package_file[i] "\" value=\"Re-Download " package_file[i] "\"</td>"
           }
        }
    } else {
       # package has not been downloaded
        if ( FileExists( package_installed[i] ) == "yes" ) {
           ver_string = PackageVersionTest( package_version_test[i] )

           # if package is installed already and is the same version
           if ( ver_string == package_version_string[i] ) { 
             theHTML = theHTML "<td><font color=\"navy\">Currently installed, but not downloaded.</font></td>"
             theHTML = theHTML "<td><input type=submit name=\"download-" package_file[i] "\" value=\"Download " package_file[i] "\"</td>"
           } else {
             theHTML = theHTML "<td><font color=\"teal\">Installed, current version='" ver_string "' but expected '" package_version_string[i] "'</font></td>"
             theHTML = theHTML "<td><input type=submit name=\"download-" package_file[i] "\" value=\"Download " package_file[i] "\"</td>"
           }
        } else {
           theHTML = theHTML "<td>&nbsp;</td>"
           theHTML = theHTML "<td><input type=submit name=\"download-" package_file[i] "\" value=\"Download " package_file[i] "\"</td>"
        }
    }
    theHTML = theHTML "</tr>"
    if ( package_descr[i] == "" ) {
        package_descr[i] = "no description provided"
    }
    theHTML = theHTML "<tr><td colspan=\"10\"><table border=0>"
    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Package File:</b></td>"
    theHTML = theHTML "<td valign=\"top\">" package_file[i] "</td></tr>"
    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Description:</b></td>"
    theHTML = theHTML "<td valign=\"top\">" package_descr[i] "</td></tr>"
    if ( package_md5[i] != "" ) {
      theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>md5 Checksum:</b></td>"
      theHTML = theHTML "<td valign=\"top\">" package_md5[i] 
      if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ) == "yes" ) {
        if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_file[i], package_md5[i] ) == "OK" ) {
          theHTML = theHTML "<b> (matches checksum of downloaded file)</b>"
        } else {
          theHTML = theHTML "<b><font color=\"red\"> (NOT matched - download may be corrupted.)</b></font>"
          if ( IsHTML( PACKAGE_DIRECTORY "/" package_file[i], package_md5[i] ) == "YES" ) {
              theHTML = theHTML ShowFile( PACKAGE_DIRECTORY "/" package_file[i], 20)
          }
        }
      } 
      theHTML = theHTML "</td></tr>"
    } else {
      theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>md5 Checksum:</b></td>"
      theHTML = theHTML "<td valign=\"top\"> md5 not specified in config file </td></tr>"
    }
    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Memory&nbsp;Usage:</b></td>"
    theHTML = theHTML "<td valign=\"top\">" package_mem[i] "</td></tr>"
    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Dependencies:</b></td>"
    theHTML = theHTML "<td valign=\"top\">"
    for ( a = 1; a <= package_dependency_count[i]; a++ ) {
          theHTML = theHTML package_depend[i, a] "<br>"
    }
    theHTML = theHTML "</td>"
    theHTML = theHTML "</tr>"
    theHTML = theHTML "</table></td></tr>"
    theHTML = theHTML "<tr><td colspan=\"10\"><hr></td></tr>"

  }
  if ( package_count == 0 ) {
      theHTML = theHTML "<tr><td>No Packages defined in package configuration file(s)</td></tr>"
  }
  theHTML = theHTML "</table></form>"
  theHTML = theHTML "</fieldset>"

  print theHTML
}

function FileExists( fname ) {
  if (system("test -f " fname ) == 0 ) {
    return "yes"
  } else { 
    return "no"
  }
}

function PackageVersionTest( theTest ) {
  OLD_RS=RS
  RS="\n"
  theTest | getline verString 
  close(theTest);
  RS=OLD_RS
  return verString;
}

function VerifyMD5( fpath , md5 , cmd) {
  OLD_RS=RS
  RS="\n"
  cmd = "md5sum " fpath
  cmd | getline
  if ( md5 == $1 ) {
    md5result="OK"
  } else {
    md5result="BAD"
  }
  close(cmd);
  RS=OLD_RS
  return md5result;
}

function IsHTML( fpath , numlines,  line, linecounter) {
  OLD_RS=RS
  RS="\n"
  html_flag=""
  linecounter=0
  while (( getline line < fpath ) > 0 && linecounter++ < numlines ) {
      if ( line ~ "<html>" ) {
        html_flag="YES"
      }
  }
  close(fpath);
  RS=OLD_RS
  return html_flag;
}

function ShowFile( fpath , numlines,  line, file_contents, linecounter) {
  OLD_RS=RS
  RS="\n"
  file_contents=""
  linecounter=0
  while (( getline line < fpath ) > 0 && linecounter++ < numlines ) {
    file_contents = file_contents line
  }
  close(fpath);
  RS=OLD_RS
  return file_contents;
}

function install_auto_install_command() {

  # check if the rc.d directoy exists
  # if not, we will append to /boot/config/go
  
  if (system("test -d " AUTO_INSTALL_DIRECTORY )==0) {
    theFilePath = AUTO_INSTALL_DIRECTORY "/" AUTO_INSTALL_FILE    
  } else {
    theFilePath = "/boot/config/go"    
  }
  gsub("%PACKAGE_DIRECTORY%", PACKAGE_DIRECTORY, AUTO_INSTALL_COMMAND)
  # if the auto_install line is not appended, add one to the file
  theTest = AUTO_INSTALL_TEST " " theFilePath " >/dev/null 2>&1"
  if ( system( theTest ) != 0 ) {
    OLD_ORS=ORS
    ORS="\n"
    print AUTO_INSTALL_COMMAND >> theFilePath 
    close(theFilePath);
    ORS=OLD_ORS
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

# open and read the unmenu configuration file.  In it, look for lines with the following pattern:
#variableName = ReplacementValue

# The values found there can be used to override values of some variables in these scripts.
# the CONFIG[] array is set with the variable.

function GetConfigValues(cfile) {
    RS="\n"
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^([^# \t=]+)([\t ]*)(=)([\t ]*)(.+)/, c)
          #print c[1,"length"] " " c[2,"length"] " " c[3,"length"] " "  c[4, "length"] " " c[5, "length"] " " line
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && 
               c[3,"length"] > 0 && c[4, "length"] > 0 && c[5, "length"] > 0 ) {
               CONFIG[substr(line,c[1,"start"],c[1,"length"])] = substr(line,c[5,"start"],c[5,"length"])
               if ( DebugMode == "yes" ) { 
                   print "importing from unmenu.conf: " \
                     "CONFIG[" substr(line,c[1,"start"],c[1,"length"]) "] = " substr(line,c[5,"start"],c[5,"length"])
               }
          }
    }
    close(cfile);
}

# if the packages folder does not exist, create it.
function CreatePackageFolder( pdir ) {

  path="/"
  x = split( pdir, package_path, "/")
  for ( i = 2; i <= x; i++ ) {
     path = path package_path[i] "/"
     system ("[ ! -d " path " ] && mkdir " path );
  }
}

function download_package(title, filename, server, port, url) {

    my_socket = "/inet/tcp/0/" server port

    request = "GET " url  " HTTP/1.1\r\nHost: " server "\r\nAccept: */*\r\nConnection: close\r\n\r\n"

    outHTML = ""

    # check for redirects, up to 5 levels
    loop_count = 0 
    do {
        outHTML = outHTML get_headers(my_socket, request, HEADERS)
        if ("Location" in HEADERS) { 
            close(my_socket)
            parse_location(HEADERS["Location"], params)
            my_socket = params["my_socket"]
            if (my_socket == "") {
                outHTML = outHTML "Downloading of package '" title "' failed:  "
                outHTML = outHTML "Headers corrupted or not available."
                outHTML = outHTML " Are you sure your unRAID server can connect to the Internet?"
                return outHTML
            }
#            request  = "GET " params["request"] " HTTP/1.1\r\nHost: " params["Host"] "\r\n\r\n"
            request =  "GET " params["request"] " HTTP/1.1\r\nHost: " params["Host"] "\r\nAccept: */*\r\nConnection: close\r\n\r\n"
        }
        loop_count++
    } while (("Location" in HEADERS) && loop_count < 5)

    if (loop_count == 5) {
        outHTML = "Downloading of package '" title "' failed, due to a redirect loop."
        return outHTML
    } else {
      outHTML = outHTML "Headers retrieved...<br>"
    }
    
    outHTML = outHTML "Saving package to file '" filename "' (size: " HEADERS["Content-Length"] ")... please be patient...<br>"
    
    save_file(my_socket, filename)

    close(my_socket)

    outHTML = outHTML "Successfully downloaded package'" title "'."
    return outHTML
}

function get_headers(the_socket, request,    HEADERS) {

    out = ""

    print request |& the_socket

    # get the http status response
    if (the_socket |& getline > 0) {
        HEADERS["_status"] = $2
#print HEADERS["_status"] > "/dev/stderr"
    }
    else {
        out = "Download failed:  Headers not available.  Are you sure your unRAID server can connect to the Internet?"
        return out
    }

    RS_save=RS
    RS="\r\n"
    while ((the_socket |& getline) > 0) {
#print $0 > "/dev/stderr"
        if (match($0, /([^:]+): (.+)/, matches)) {
            HEADERS[matches[1]] = matches[2]
            out = out " :" matches[1] " => " matches[2] "<br>"
        } else { 
          break 
        }
    }
    RS=RS_save
#print out > "/dev/stderr"
    return out
}

function save_file(the_socket, filename) {
    RS_save  = RS
    ORS_save = ORS
    ORS = ""
    RS = ".{1,512}"

    while ((the_socket |& getline) > 0) {
        print RT > filename
    }
    close(filename)

    RS  = RS_save
    ORS = ORS_save
}
