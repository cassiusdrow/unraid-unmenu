BEGIN {
#define ADD_ON_URL         pkg_manager
#define ADD_ON_MENU        Pkg Manager
#define ADD_ON_STATUS      NO
#define ADD_ON_TYPE        awk
#define ADD_ON_VERSION     1.0 BubbaQ
#define ADD_ON_VERSION     1.1 Initial concept by BubbaQ - extensive Modifications by Joe L.
#define ADD_ON_VERSION     1.2 Changed pattern expected to match package .conf files to not need leading number, suggested by jarodtufts
#define ADD_ON_VERSION     1.3 Added code to identify mal-formed package .conf files.
#define ADD_ON_VERSION     1.4 fixed incorrect button name when package exists on server, but different version.
#define ADD_ON_VERSION     1.5 Improved handling of download when 404 "not-found" error returned on download URL
#define ADD_ON_VERSION     1.6 Fixed initialization of version string.
#define ADD_ON_VERSION     2.0 Modified for new features of configurable/editable package-variables
#define ADD_ON_VERSION     2.1 Modified to allow more than one URL per package to support needed libraries, etc.
#define ADD_ON_VERSION     2.2 Added newline prior to auto-install command, in case user did not add newline at the end of the "go" file
#define ADD_ON_VERSION     2.2.1 Fixed bug with input variables with embedded spaces
#define ADD_ON_VERSION     2.2.2 Fixed bug with input variables with special characters
#define ADD_ON_VERSION     2.2.3 Fixed bug md5 sum of extra_packages.  Fixed display of returned html when URL not valid.
#define ADD_ON_VERSION     2.2.4 Fixed bug with version compare of package with no affiliated download.
#define ADD_ON_VERSION     2.3   Modified to select package and then only show selected package.
#UNMENU_RELEASE $Revision$ $Date$


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
          package_extra_url[package_count]    = ""
          package_extra_url_count[package_count] = 0
          package_file[package_count]   = "PACKAGE_FILE undefined"
          package_extra_file[package_count]   = "EXTRA PACKAGE_FILE undefined"
          package_extra_file_count[package_count] = 0
          package_md5[package_count]    = ""
          package_extra_md5[package_count]    = ""
          package_extra_md5_count[package_count] = 0
          package_installed[package_count]   = ""
          package_version_test[package_count]   = "echo undefined"
          package_version_string[package_count]   = ""
          package_depend[package_count] = ""
          package_dependency_count[package_count] = 0
          package_install_count[package_count] = 0
          package_installation[package_count, 0]   = "PACKAGE_INSTALLATION undefined"
          package_variable_count[package_count] = 0
          package_variable[package_count, 0]   = "PACKAGE_VARIABLE undefined"
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
      # the extra URLs to download the package
      match( line , /^(PACKAGE_EXTRA_URL)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
          package_extra_url_count[package_count]++
	  package_extra_url[package_count,package_extra_url_count[package_count]] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the name of a file to test if exists.  If it exists, package is already downloaded.
      match( line , /^(PACKAGE_FILE)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_file[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the name of extra file to test if exists.  If it exists, extra file is already downloaded.
      match( line , /^(PACKAGE_EXTRA_FILE)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
          package_extra_file_count[package_count]++
	  package_extra_file[package_count,package_extra_file_count[package_count]] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the MD5 checksum to verify the downloaded package arrived intact.
      match( line , /^(PACKAGE_MD5)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
	  package_md5[package_count] = substr(line,c[3,"start"],c[3,"length"])
      }
      delete c;
      # the MD5 checksum to verify the downloaded extra file arrived intact.
      match( line , /^(PACKAGE_EXTRA_MD5)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
          package_extra_md5_count[package_count]++
	  package_extra_md5[package_count,package_extra_md5_count[package_count]] = substr(line,c[3,"start"],c[3,"length"])
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
      # package configurable variables(one per line) This is a "two-dimensional" array
      # and may have multiple members, one per variable.  
      match( line , /^(PACKAGE_VARIABLE)([\t =]+)(.+)/, c)
      if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
          package_variable_count[package_count]++
	  package_variable[package_count, package_variable_count[package_count]] = substr(line,c[3,"start"],c[3,"length"])
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
  select_package_file=""
  edit_package_file=""
  save_edit_flag=""
  delete edit_variable;
  for (a in PARAM) {
      if ( PARAM[a] ~ "manual_install-" ) {
#theHTML = theHTML PARAM[a] "<br>" 

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
               select_package_file = the_package
               manual_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".manual_install"
               print "PACKAGE_DIRECTORY=" PACKAGE_DIRECTORY > manual_install_file
               print "SCRIPT_DIRECTORY=" ScriptDirectory > manual_install_file
               for ( pc=1; pc <= package_variable_count[i]; pc++ ) {
                  delete f;
                  match ( package_variable[i,pc] , /^([^\|]*)(\|\|)([^=]*)(=)(.*)(\|\|)(.*)/, f);
                  if ( f[1,"length"] > 0 && f[2,"length"] > 0 && f[4,"length"] > 0 ) {
                    theVar = substr(package_variable[i,pc],f[3,"start"],f[3,"length"])
                    theVal = substr(package_variable[i,pc],f[5,"start"],f[5,"length"])
                    
                    print theVar "=\"" theVal "\"" > manual_install_file
                  }
               } 
               for ( pc=1; pc <= package_install_count[i]; pc++ ) {
                  #theHTML = theHTML package_installation[i,pc] ORS
                  print package_installation[i,pc] > manual_install_file
               } 
               close(manual_install_file)
               install_output="/tmp/unmenu_manual_install.out" 
               cmd = "chmod +x '" manual_install_file "';cd '" PACKAGE_DIRECTORY "'; sh '" manual_install_file "' >" install_output " 2>&1"
               system(cmd);
               while (( getline inst_out < install_output ) > 0 ) {
                  theHTML = theHTML inst_out ORS
               }
               close(install_output)

              # while (( cmd | getline inst_out  ) > 0) {
              #    theHTML = theHTML inst_out ORS
              # }

               theHTML = theHTML "</pre>"
               auto_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".auto_install"
               if (FileExists(auto_install_file) == "yes" ) { 
                  system("cp " manual_install_file " " auto_install_file)
               }
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
               select_package_file = the_package
               auto_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".auto_install"
               print "PACKAGE_DIRECTORY=" PACKAGE_DIRECTORY > auto_install_file
               print "SCRIPT_DIRECTORY=" ScriptDirectory > auto_install_file
               for ( pc=1; pc <= package_variable_count[i]; pc++ ) {
                  delete f;
                  match ( package_variable[i,pc] , /^([^\|]*)(\|\|)([^=]*)(=)(.*)(\|\|)(.*)/, f);
                  if ( f[1,"length"] > 0 && f[2,"length"] > 0 && f[4,"length"] > 0 ) {
                    theVar = substr(package_variable[i,pc],f[3,"start"],f[3,"length"])
                    theVal = substr(package_variable[i,pc],f[5,"start"],f[5,"length"])
                    
                    print theVar "=\"" theVal "\"" > auto_install_file
                  }
               } 
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
               select_package_file = the_package
               auto_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".auto_install"
               system("rm '" auto_install_file "' 2>/dev/null" )
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
               select_package_file = the_package
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
               for ( p = 1; p <= package_extra_url_count[i]; p++ ) {
                 match( package_extra_url[i,p] , /^(http:\/\/)([^\/]*)(.*)/, c)
                 if ( c[1,"length"] > 0 && c[2,"length"] > 0 && c[3,"length"] > 0 ) {
                   theServer = substr(package_extra_url[i,p],c[2,"start"],c[2,"length"])
                   #theURL    = "/" substr(package_extra_url[i,p],c[3,"start"],c[3,"length"])
                   port   = "/80"
                   download_package(package_name[i], PACKAGE_DIRECTORY "/" package_extra_file[i,p],  theServer, port, package_extra_url[i,p] )
                 }
                 if ( FileExists( PACKAGE_DIRECTORY "/" package_extra_file[i,p] ) == "yes" ) {
                   theHTML = theHTML "<font color=\"blue\"><b>" package_extra_file[i,p] " has been downloaded</b></font><br>"
                 } else {
                   theHTML = theHTML "<font color=\"red\"><b>" package_extra_file[i,p] " not successfully downloaded</b></font><br>"
                 }
               }
               if ( allPackageFilesExist(i) != "yes" ) {
                 manual_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".manual_install"
                 system("rm '" manual_install_file "' 2>/dev/null" )
                 auto_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".auto_install"
                 system("rm '" auto_install_file "' 2>/dev/null" )
               }
               break;
            }
          }
          ORS = OLD_ORS
          break;
      }
      if ( PARAM[a] ~ "select-" ) {
          delete f;
          match ( PARAM[a], /^select-([^=]*)(=)(.*)/, f);
          if ( f[1,"length"] > 0 && f[2,"length"] > 0 && f[3,"length"] > 0 ) {
            select_package_file = substr(PARAM[a],f[1,"start"],f[1,"length"])
          }
      }
      if ( PARAM[a] ~ "edit-" ) {
          delete f;
          match ( PARAM[a], /^edit-([^=]*)(=)(.*)/, f);
          if ( f[1,"length"] > 0 && f[2,"length"] > 0 && f[3,"length"] > 0 ) {
            edit_package_file = substr(PARAM[a],f[1,"start"],f[1,"length"])
          }
      }
      if ( PARAM[a] ~ "save_edit-" ) {
          delete f;
          match ( PARAM[a], /^save_edit-([^=]*)(=)(.*)/, f);
          if ( f[1,"length"] > 0 && f[2,"length"] > 0 && f[3,"length"] > 0 ) {
            edit_package_file = substr(PARAM[a],f[1,"start"],f[1,"length"])
            select_package_file=edit_package_file
          }
          save_edit_flag="save"
      }
      if ( PARAM[a] ~ "var-" ) {
          delete f;
#theHTML = theHTML PARAM[a] "<br>"
          match ( PARAM[a], /^var-([^=]*)(=)(.*)/, f);
          if ( f[1,"length"] > 0 && f[2,"length"] > 0 ) {
             edit_package_var = substr(PARAM[a],f[1,"start"],f[1,"length"])
             edit_package_value = unencodeHex(substr(PARAM[a],f[3,"start"],f[3,"length"]))
	     edit_variable[edit_package_var] = edit_package_value
#theHTML = theHTML edit_package_var " = " edit_package_value "<br>"
          }
      }
  }
  
  if ( save_edit_flag == "save" ) {
    # need to replace the value in the package_variable array with the new value
    # match the package in the package array
    for ( i = 1; i <= package_count; i++ ) {
      if (package_file[i] == edit_package_file ) {

        # save a copy of the old .conf file, 
        old_conf=package[i - 1] strftime("-%Y-%m-%d-%H%M%S.bak")
        system("cp '" package[i - 1] "' '" old_conf "'")

        # and lastly re-write the .conf file, then remove .manual_install and .auto_install files if present.
        for (ev in edit_variable) {
          # find the matching variable in the package
          for ( vv = 1; vv <= package_variable_count[i]; vv++ ) {
            delete f;
            match ( package_variable[i,vv] , /^([^\|]*)(\|\|)([^=]+)(=)(.*)(\|\|)(.*)/, f);
            if ( f[1,"length"] > 0 && f[2,"length"] > 0 && f[4,"length"] > 0 && f[5,"length"] >= 0 ) {
               theVar = substr(package_variable[i,vv],f[1,"start"],f[1,"length"])
               theVarName = substr(package_variable[i,vv],f[3,"start"],f[3,"length"])
               theVarVal = substr(package_variable[i,vv],f[5,"start"],f[5,"length"])
               theVarDesc = substr(package_variable[i,vv],f[7,"start"],f[7,"length"])
	       if ( theVarName == ev ) {
                  # substitute the new value
                  package_variable[i,vv] = theVar "||" theVarName "=" edit_variable[ev] "||" theVarDesc
                  # stream edit the .conf file to save the new value
                  # first escape the special characters to the "sed" command
                  gsub(/[\[\]\*\&\.\^\$]/, "\\\\&" ,theVarVal);
                  cmd="sed -i \"s~||" theVarName "=" theVarVal "||~||" theVarName "=" edit_variable[ev] "||~\" " package[i - 1]
                  system(cmd)
#theHTML = theHTML cmd "<br>"
                  break;
               } 
            }
          }
        }
        manual_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".manual_install"
        system("rm '" manual_install_file "' 2>/dev/null" )
        auto_install_file = PACKAGE_DIRECTORY "/" package_file[i] ".auto_install"
        system("rm '" auto_install_file "' 2>/dev/null" )
        break;
      }
    }
    edit_package_file=""   
  }

#theHTML = theHTML edit_package_file "<br>"
  theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>Download and Install Extra Software Packages</strong></legend>"
  theHTML = theHTML "<form>"
  theHTML = theHTML "<table width=\"100%\" border=0>"
  if ( edit_package_file != "" || select_package_file != "" ) {
      theHTML = theHTML "<tr><td colspan=\"10\"><input type=submit name=\"\" value=\"View All Avaliable Packages\"><hr></td></tr>"
  }
  for ( i = 1; i <= package_count; i++ ) {
    if ( edit_package_file != "" ) {
        if ( edit_package_file != package_file[i] ) {
          continue;
        }
    } else {
        if ( select_package_file != "" ) {
            if ( select_package_file != package_file[i] ) {
              continue;
            }
        } else {
            theHTML = theHTML "<tr>"
            theHTML = theHTML "<td style=\"background-color:#DDDDDD\">"
            theHTML = theHTML "<input type=submit name=\"select-"
            theHTML = theHTML package_file[i] "\" value=\"Select " package_file[i] "\"></td>"
            theHTML = theHTML "<td width=\"80%\" style=\"background-color:#DDDDDD\">"
            theHTML = theHTML package_name[i]
            if ( allPackageFilesExist(i) == "yes" ) {
                if ( FileExists( package_installed[i] ) == "yes" ) {
                   ver_string = PackageVersionTest( package_version_test[i] )
                   if ( package_version_test[i] != "" && ver_string == package_version_string[i] ) { 
                     if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ".auto_install" ) == "yes" ) {
                       theHTML = theHTML "<br><font color=\"blue\">Currently Installed. "
                       theHTML = theHTML "Will be automatically Re-Installed upon Re-Boot.</font>"
                     } else {
                       theHTML = theHTML "<br><font color=\"blue\">Currently Installed.</font> <font color=\"brown\">Will <b>"
                       theHTML = theHTML "NOT</b> be automatically Re-Installed upon Re-Boot.</font>"
                     }
                   } else {
                     # different version found
                     theHTML = theHTML "<br><font color=\"maroon\">Installed, but version is different. "
                     theHTML = theHTML "Current version='" ver_string "' expected '" package_version_string[i] "'</font>"
                   }
                } else {
                   # not installed
                   theHTML = theHTML "<br><font color=\"brown\">Not Installed</font>"
                }
            } else {
                # not downloaded
                if ( FileExists( package_installed[i] ) == "yes" ) {
                   theHTML = theHTML "<br><font color=\"navy\">Installed, Not Downloaded</font>"
                } else {
                   theHTML = theHTML "<br><font color=\"brown\">Not Downloaded</font>"
                }
            }
            theHTML = theHTML "</td>"
            theHTML = theHTML "</tr>"
            theHTML = theHTML "<tr><td colspan=\"10\"><table border=0>"
            theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Description:</b></td>"
            theHTML = theHTML "<td valign=\"top\">" package_descr[i] "</td></tr></table></td></tr>"
	    continue;
        }
    }
    theHTML = theHTML "<tr>"
    theHTML = theHTML "<td style=\"background-color:#DDDDDD\">"
    theHTML = theHTML package_name[i]
    theHTML = theHTML "</td>"
     
    if ( edit_package_file == "" ) {
      if ( allPackageFilesExist(i) == "yes" ) {
          if ( FileExists( package_installed[i] ) == "yes" ) {
             ver_string = PackageVersionTest( package_version_test[i] )
  
             # if package is installed already and is the same version
             if ( package_version_test[i] != "" && ver_string == package_version_string[i] ) { 
  
  
               if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ".auto_install" ) == "yes" ) {
                 theHTML = theHTML "<td><font color=\"blue\">Currently Installed.<br>Will be automatically Re-Installed upon Re-Boot.</font></td>"
                 theHTML = theHTML "<td>"
                 if ( save_edit_flag == "save" ) {
                   if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ".manual_install" ) == "no" ) {
                     theHTML = theHTML "<input type=submit name=\"manual_install-"
                     theHTML = theHTML package_file[i] "\" value=\"Re-Install Now with Edited Variables\"><br>"
                   }
                 }
                 theHTML = theHTML "<input type=submit name=\"no_install-"
                 theHTML = theHTML package_file[i] "\" value=\"Disable Re-Install on Re-Boot\"></td>"
               } else {
                 theHTML = theHTML "<td><font color=\"blue\">Currently Installed.</font><br><font color=\"brown\">Will <b>"
                 theHTML = theHTML "NOT</b> be automatically Re-Installed upon Re-Boot.</font></td>"
                 theHTML = theHTML "<td>"
                 if ( save_edit_flag == "save" ) {
                   if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ".manual_install" ) == "no" ) {
                     theHTML = theHTML "<input type=submit name=\"manual_install-"
                     theHTML = theHTML package_file[i] "\" value=\"Re-Install Now with Edited Variables\"><br>"
                   }
                 } else {
                   theHTML = theHTML "<input type=submit name=\"auto_install-"
                   theHTML = theHTML package_file[i] "\" value=\"Enable Re-Install on Re-Boot\"></td>"
                 }
               }
             } else { # installed, but different version
               theHTML = theHTML "<td><font color=\"orange\">Installed, but version is different.<br>"
               theHTML = theHTML "Current version='" ver_string "' expected '" package_version_string[i] "'</font></td>"
               if ( package_url[i] == "none" ) {
                 theHTML = theHTML "<td><font color=\"purple\">Package not yet installed (no download needed)</font></td>"
                 theHTML = theHTML "<td><input type=submit name=\"manual_install-" package_file[i] "\" value=\"Install " package_file[i] "\"</td>"
                 nomd5="true"
               } else {
                 if ( allPackageFilesExist(i) == "yes" ) {
                   if (allMD5Verify( i ) == "OK" ) {
                     theHTML = theHTML "<td><input type=submit name=\"manual_install-" package_file[i] "\" value=\"Install " package_file[i] "\"</td>"
                   } else {
                     theHTML = theHTML "<td><b><font color=\"red\"> (MD5 of existing downloaded file NOT matched - download may be corrupted or download URL no longer valid.)</b></font>"
                     if ( IsHTML( PACKAGE_DIRECTORY "/" package_file[i], 30 ) == "YES" ) {
                         theHTML = theHTML ShowFile( PACKAGE_DIRECTORY "/" package_file[i], 20)
                     }
                     for ( pe = 1; pe <= package_extra_md5_count[ i ]; pe++ ) {
                       if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_extra_file[i,pe], package_extra_md5[i,pe] ) != "OK" ) {
                         if ( IsHTML( PACKAGE_DIRECTORY "/" package_extra_file[i,pe], 30 ) == "YES" ) {
                             theHTML = theHTML ShowFile( PACKAGE_DIRECTORY "/" package_extra_file[i,pe], 20)
                         }
                       }
                     }
                     theHTML = theHTML "<input type=submit name=\"download-" package_file[i] "\" value=\"Download " package_file[i] "\"</td>"
                   }
                 } 
               }
             }
          } else {
             # package is not installed yet, but is downloaded
             if ( package_url[i] == "none" ) {
               theHTML = theHTML "<td><font color=\"purple\">Package not yet installed (no download needed)</font></td>"
               nomd5="true"
             } else {
               theHTML = theHTML "<td><font color=\"purple\">Package downloaded, but not yet installed</font></td>"
             }
             if ( nomd5 == "true" || VerifyMD5( PACKAGE_DIRECTORY "/" package_file[i], package_md5[i] ) == "OK" ) {
               theHTML = theHTML "<td><input type=submit name=\"manual_install-" package_file[i] "\" value=\"Install " package_file[i] "\"</td>"
               nomd5=""
             } else {
               theHTML = theHTML "<td><b><font color=\"red\"> (MD5 of existing downloaded file NOT matched - download may be corrupted or download URL no longer valid.)</b></font>"
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
    }
    theHTML = theHTML "</tr>"
    if ( package_descr[i] == "" ) {
        package_descr[i] = "no description provided"
    }
    theHTML = theHTML "<tr><td colspan=\"10\"><table border=0>"
    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Description:</b></td>"
    theHTML = theHTML "<td valign=\"top\">" package_descr[i] "</td></tr>"
    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Package URL:</b></td>"
    theHTML = theHTML "<td valign=\"top\"><a href=\"" package_url[i] "\">" package_url[i] "</a></td></tr>"
    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Package File:</b></td>"
    theHTML = theHTML "<td valign=\"top\">" package_file[i] "</td></tr>"
    if ( package_md5[i] != "" ) {
      theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>md5 Checksum:</b></td>"
      theHTML = theHTML "<td valign=\"top\">" package_md5[i] 
      if ( FileExists( PACKAGE_DIRECTORY "/" package_file[i] ) == "yes" ) {
        if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_file[i], package_md5[i] ) == "OK" ) {
          theHTML = theHTML "<b> (matches checksum of downloaded file " package_file[i] ")</b>"
        } else {
          theHTML = theHTML "<b><font color=\"red\"> (NOT matched - download may be corrupted or download URL no longer valid.)<br>"
          if ( IsHTML( PACKAGE_DIRECTORY "/" package_file[i], 30 ) == "YES" ) {
              theHTML = theHTML ShowFile( PACKAGE_DIRECTORY "/" package_file[i], 20)
          }
          theHTML = theHTML "</b></font><br>"
        }
      } 
      theHTML = theHTML "</td></tr>"
    } else {
      theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>md5 Checksum:</b></td>"
      theHTML = theHTML "<td valign=\"top\"> md5 not specified in config file </td></tr>"
    }
    for ( p = 1; p <= package_extra_url_count[i]; p++ ) {
      theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Addl. Pkg. URL-" p ":</b></td>"
      theHTML = theHTML "<td valign=\"top\"><a href=\"" package_extra_url[i,p] "\">" package_extra_url[i,p] "</a></td></tr>"
      theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Addl. Pkg. File-" p ":</b></td>"
      theHTML = theHTML "<td valign=\"top\">" package_extra_file[i,p] "</td></tr>"
      if ( package_extra_md5[i,p] != "" ) {
        theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Addl. md5 Checksum:</b></td>"
        theHTML = theHTML "<td valign=\"top\">" package_extra_md5[i,p] 
        if ( FileExists( PACKAGE_DIRECTORY "/" package_extra_file[i,p] ) == "yes" ) {
          if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_extra_file[i,p], package_extra_md5[i,p] ) == "OK" ) {
            theHTML = theHTML "<b> (matches checksum of downloaded file " package_extra_file[i,p] ")</b>"
          } else {
            theHTML = theHTML "<b><font color=\"red\"> (NOT matched - download may be corrupted, or download URL no longer valid.)<br>"
            if ( IsHTML( PACKAGE_DIRECTORY "/" package_extra_file[i,p], 30 ) == "YES" ) {
                theHTML = theHTML ShowFile( PACKAGE_DIRECTORY "/" package_extra_file[i,p], 20)
            }
            theHTML = theHTML "</b></font><br>"
          }
        } 
        theHTML = theHTML "</td></tr>"
      } else {
        theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Addl. md5 Checksum:</b></td>"
        theHTML = theHTML "<td valign=\"top\"> md5 not specified in config file </td></tr>"
      }
    }

    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Memory&nbsp;Usage:</b></td>"
    theHTML = theHTML "<td valign=\"top\">" package_mem[i] "</td></tr>"

    theHTML = theHTML "<tr><td align=\"right\" valign=\"top\"><b>Dependencies:</b></td>"
    theHTML = theHTML "<td valign=\"top\">"
    for ( a = 1; a <= package_dependency_count[i]; a++ ) {
          theHTML = theHTML package_depend[i, a] "<br>"
    }
    theHTML = theHTML "</td></tr>"
    if ( edit_package_file != "" ) {
      config_label="Edit Configuration Variables"
      config_instructions="<font size=\"+2\" color=blue><b>Editing Configuration Variables</font>"
      config_instructions = config_instructions "<font size=\"+1\" color=blue>"
      config_instructions = config_instructions "<br>Make changes as desired in the input fields provided below," 
      config_instructions = config_instructions " then press the \"Save New Values\" button.</b></font><br>"
    } else {
      config_label="Configuration Variables"
      config_instructions=""
    }

    if ( package_variable_count[i] > 0 ) {
        theHTML = theHTML "<tr><td colspan=3>" config_instructions
        theHTML = theHTML "<fieldset style=\"margin-top:10px;\" >"
        theHTML = theHTML "<legend style=\"background-color:#DDDDDD\"><strong>" config_label "</strong></legend>"
        theHTML = theHTML "<table border=0>"
        if ( edit_package_file != "" ) {
            edit_disable=""
        } else {
            edit_disable="DISABLED"
        }
        for ( a = 1; a <= package_variable_count[i]; a++ ) {
            delete f;
#theHTML = theHTML   package_variable[i,a] "<br>"
            match ( package_variable[i,a] , /^([^\|]*)(\|\|)(.*)(\|\|)(.*)/, f);
            if ( f[1,"length"] > 0 && f[2,"length"] > 0 && f[3,"length"] > 0 ) {
               theVar = substr(package_variable[i,a],f[1,"start"],f[1,"length"])
               theVarVal = substr(package_variable[i,a],f[3,"start"],f[3,"length"])
               theVarDesc = substr(package_variable[i,a],f[5,"start"],f[5,"length"])

               theHTML = theHTML   "<tr><td align=\"right\" valign=\"middle\">"
               theHTML = theHTML   "<b>" theVar ":</b>"
               theHTML = theHTML   "</td>"
               theHTML = theHTML   "<td valign=\"middle\">"
               # get the variable name and value
               delete nv;
               match( theVarVal , /^([^\t=]+)([\t ]*)(=)([\t ]*)(.*)/, nv)
               theVN = substr(theVarVal,nv[1,"start"],nv[1,"length"])
               theVV = substr(theVarVal,nv[5,"start"],nv[5,"length"])
               theHTML = theHTML   "<input size=25 " edit_disable " name=\"var-" theVN "\" value=\"" theVV "\">"
               theHTML = theHTML   "</td>"
               theHTML = theHTML   "<td valign=\"middle\">"
               theHTML = theHTML   theVarDesc
               theHTML = theHTML   "</td></tr>"
            }
        }
        theHTML = theHTML "<tr><td align=\"center\" colspan=3>"
        if ( edit_package_file != "" ) {
          theHTML = theHTML "<input type=submit name=\"save_edit-" package_file[i] "\" value=\"Save New Values\">"
          theHTML = theHTML "<input type=submit name=\"cancel_edit-" package_file[i] "\" value=\"Cancel Edit\">"
        } else {
          theHTML = theHTML "<input type=submit name=\"edit-" package_file[i] "\" value=\"Edit Configuration Variables\">"
        }
        theHTML = theHTML "</td></tr>"
        theHTML = theHTML "</table></fieldset></td></tr>"
    }

    theHTML = theHTML "</table></td></tr>"
    theHTML = theHTML "<tr><td colspan=\"10\"><hr>"
    theHTML = theHTML "<a name=\"" package_file[i + 1] "\"></a>"
    theHTML = theHTML "</td></tr>"

  }
  if ( package_count == 0 ) {
      theHTML = theHTML "<tr><td>No Packages defined in package configuration file(s)</td></tr>"
  }
  theHTML = theHTML "</table></form>"
  theHTML = theHTML "</fieldset>"

  print theHTML
}

function allPackageFilesExist( package_index , p) {
    if ( package_url[package_index] == "none" ) {
       return "yes"
    }
    if ( FileExists( PACKAGE_DIRECTORY "/" package_file[package_index] ) != "yes" ) {
       return "no"
    }
    for ( p = 1; p <= package_extra_url_count[ package_index ]; p++ ) {
      if ( FileExists( PACKAGE_DIRECTORY "/" package_extra_file[package_index,p] ) != "yes" ) {
        return "no"
      }
    }
    return "yes"
}

function FileExists( fname ) {
  if (system("test -f " fname ) == 0 ) {
    return "yes"
  } else { 
    return "no"
  }
}

function PackageVersionTest( theTest ) {
  verString=""
  OLD_RS=RS
  RS="\n"
  theTest | getline verString 
  close(theTest);
  RS=OLD_RS
  return verString;
}

function allMD5Verify( package_index , p) {
    if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_file[package_index], package_md5[package_index] ) != "OK" ) {
      return "BAD"
    }
    for ( p = 1; p <= package_extra_md5_count[ package_index ]; p++ ) {
      if ( VerifyMD5( PACKAGE_DIRECTORY "/" package_extra_file[package_index,p], package_extra_md5[package_index,p] ) != "OK" ) {
        return "BAD"
      }
    }
    return "OK"
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
  html_flag="NO"
  linecounter=0
  while (( getline line < fpath ) > 0 && linecounter++ < numlines ) {
      if ( line ~ "<HTML>" ) {
        html_flag="YES"
        break
      }
      if ( line ~ "<html>" ) {
        html_flag="YES"
        break
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
  
  if (system("test -d " AUTO_INSTALL_DIRECTORY " 2>/dev/null")==0) {
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
    print "\n" AUTO_INSTALL_COMMAND >> theFilePath 
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
function unencodeHex( theValue ) {
    decodedValue = ""
    gsub("+"," ",theValue)
    # desl with hex encoding of strings
     for ( i = 1; i<=length(theValue); i++ ) {
        if ( substr(theValue,i,1) == "%" ) {
           chr=sprintf("%c", strtonum("0x" substr(theValue, i+1,2)))
           decodedValue = decodedValue chr
           i+=2
        } else {
           decodedValue = decodedValue substr(theValue,i,1)
        }
    }
    return decodedValue
}

