BEGIN {
#define ADD_ON_URL    config_view_edit
#define ADD_ON_MENU   Config View/Edit
#define ADD_ON_STATUS YES
#define ADD_ON_TYPE   awk
#define ADD_ON_VERSION   .1 Original version.  Joe L.
#define ADD_ON_VERSION   .2 Updated with ideas borrowed from go-script-manager plug-in to keep backup versions of files.
#define ADD_ON_VERSION   .2.1 Fixed error out of "ls" when directory does not exist.  Joe L.
#UNMENU_RELEASE $Revision$ $Date$

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

  FILE_BACKUP_DIRECTORY = CONFIG["FILE_BACKUP_DIRECTORY"] ? CONFIG["FILE_BACKUP_DIRECTORY"] : "/boot/backup_files"

  # read in a possible list of files that may be edited.
  # the GetEditableFiles function populates an "EDITABLE_FILE[]" array 
  # and returns the number of array entries.
  editable_files = 0

  # add "go" to the list of files that are editable.
  editable_files = Add_Specific_Editable_File(editable_files, "/boot/config/go")

  # If the user defines specific files in the unmenu config files, add them to the EDITABLE_FILES array
  editable_files =  GetConfigEditableFiles(editable_files, ScriptDirectory "/" ConfigFile);
  editable_files =  GetConfigEditableFiles(editable_files, ScriptDirectory "/" LocalConfigFile);

  # now, scan some directories for "possible" editable files.
  editable_files = GetEditableFiles(editable_files, "/boot/config", "*.cfg" )
  editable_files = GetEditableFiles(editable_files, "/boot/config", "*.conf" )
  editable_files = GetEditableFiles(editable_files, "/boot", "*.cfg" )
  editable_files = GetEditableFiles(editable_files, ScriptDirectory, "*.conf" )
  editable_files = GetEditableFiles(editable_files, CONFIG["PACKAGE_DIRECTORY"], "*.conf" )
  editable_files = GetEditableFiles(editable_files, CONFIG["PACKAGE_DIRECTORY"], "*.manual_install" )
  editable_files = GetEditableFiles(editable_files, CONFIG["PACKAGE_DIRECTORY"], "*.auto_install" )
  editable_files = GetEditableFiles(editable_files, CONFIG["AUTO_INSTALL_DIRECTORY"], "* 2>/dev/null | grep -v '*.zip'" )
  editable_files = GetEditableFiles(editable_files, "/boot", "*.sh" )
  editable_files = GetEditableFiles(editable_files, "/boot/custom/bin", "*.sh" )

  # populate the GETARG[] array based on passed in arguments (form fields and env variables)
  CGI_setup();

  # POST field contents are "hex" encoded by the browser.  We need to un-hex encode them.
  if ( GETARG["editable_file"] != "" ) {
    theFile = GETARG["editable_file"]
    theFile = unencodeHex(theFile)
  } else {
    theFile = ""
  }
  if ( GETARG["view_backup"] != "" || GETARG["revert_backup"] != "" ) {
    theBackupFile = GETARG["backup_file"]
    theBackupFile = unencodeHex(theBackupFile)
  } else {
    theBackupFile = ""
  }

  theHTML = "<form name=\"f\" method=\"POST\" >"
  #theHTML = theHTML ARGV[3] "<br>" # for initial debugging

  # If no file is currently being edited, present the user with a list that could be edited.
  if ( GETARG["editfile"] == "" ) {

    theHTML = theHTML "<table width=\"100%\" border=\"0\"><tr><td width=\"20%\"><b>Select a Config/System File to view: </b></td><td>"
    # present the user with a list of editable files
    theHTML = theHTML "<select onchange=\"submit();\" name=\"editable_file\"><option value=\"\">Select a file</option>"

    # loop creating the "<OPTIONS>" for the SELECT list.  If one matched the current file
    # being viewed, mark it selected so it will be shown in the SELECT field.
    for ( i =1; i<=editable_files; i++ ) {
      if ( EDITABLE_FILE[i] == "" ) { continue; }
      option_value = EDITABLE_FILE[i]
      if ( theFile == option_value ) { 
         is_selected = "selected" 
      } else { 
          is_selected = "" 
      }
      theHTML = theHTML "<option value=\"" option_value "\" " is_selected ">"
      theHTML = theHTML option_value "</option>" ORS
    }
    theHTML = theHTML "</select></td><td>"
    theHTML = theHTML "<br><b><font color=\"blue\">Note: When editing, it is possible for you to"
    theHTML = theHTML " introduce syntax errors.<br>"
    theHTML = theHTML "As a precaution, prior to saving a changed version of a file, this plug-in "
    theHTML = theHTML "makes a copy of the file being edited with a suffix of YYYY-MM-DD-HHMI.bak"
    theHTML = theHTML "</font></b>"
    theHTML = theHTML "</td></tr></table>"
  } else {
    theHTML = theHTML "<table width=\"100%\" border=\"0\"><tr><td width=\"20%\"><font size=\"+1\" color=\"red\"><b>Editing :" theFile "</b></font></td></tr></table>"
    # a file is being edited, put its name in a hidden field so when we "Save" it we know
    # where to write it.
    theHTML = theHTML "<input type=\"hidden\" name=\"editable_file\" value=\"" theFile "\">"
    file_name_valid="n"
    for ( i =1; i<=editable_files; i++ ) {
      if ( EDITABLE_FILE[i] == "" ) { continue; }
      if ( theFile == EDITABLE_FILE[i] ) {
        file_name_valid="y"
        break;
      }
    }
    if ( file_name_valid == "n" ) {
      theFile = ""
    }
  }
  if ( theFile != "" ) {
    file_basename = getBaseName( theFile )
    # if the user pressed the "Save File button, save a copy of the original file, then
    # save the edited file
    if ( GETARG["savefile"] != "" ) {
      # save a copy of the original file in the backup-directory
      CreateFolder( FILE_BACKUP_DIRECTORY )
      backup_file_name = file_basename strftime("-%Y-%m-%d-%H%M.bak")
      system ( "cp -b " theFile " " FILE_BACKUP_DIRECTORY "/" backup_file_name )

      tORS = ORS
      ORS=""
      if ( GETARG["end_of_line_type"] == "UNIX" ) {
        gsub("%0D%0A","%0A",GETARG["file"])
      }
      # Save a new file with the contents that were just edited
      print unencodeHex(GETARG["file"]) > theFile
      close(theFile)
      ORS = tORS
      theHTML = theHTML "<fieldset style=\"margin-top:10px;\">"
      theHTML = theHTML "<b><font size=\"+1\" color=\"blue\" >Saved: " theFile "</font></b><br>"
      theHTML = theHTML "A backup copy of the original was saved as <b><font color=\"blue\">" backup_file_name "<br>"
      theHTML = theHTML "</b></font> in the <b><font color=\"blue\">" FILE_BACKUP_DIRECTORY " </font></b>directory.</fieldset>"
    }
    if ( GETARG["revert_backup"] != "" ) {
      # save a copy of the current original file in the backup-directory
      backup_file_name = file_basename strftime("-%Y-%m-%d-%H%M.bak")
      system ( "cp -b " theFile " " FILE_BACKUP_DIRECTORY "/" backup_file_name )
      theHTML = theHTML "cp " theBackupFile " " theFile "<br>"
      system ( "cp " theBackupFile " " theFile )

      theHTML = theHTML "<fieldset style=\"margin-top:10px;\">"
      theHTML = theHTML "<b><font size=\"+1\" color=\"blue\" >Saved: " theFile "</font></b><br>"
      theHTML = theHTML "A backup copy of the current original was saved as <b><font color=\"blue\">" backup_file_name "<br>"
      theHTML = theHTML "</b></font> in the <b><font color=\"blue\">" FILE_BACKUP_DIRECTORY " </font></b>directory."
      theHTML = theHTML "<br>The backup copy " theBackupFile " was then copied back to " theFile "</fieldset>"
    }
    if ( GETARG["editfile"] == "" ) {
      num_backup_copies = GetBackupCopyList( file_basename , FILE_BACKUP_DIRECTORY ) 
      if ( num_backup_copies > 0 ) {
        theHTML = theHTML "<table width=\"100%\" border=\"0\"><tr><td width=\"25%\"><b>" 
        if ( num_backup_copies == 1 ) {
          theHTML = theHTML num_backup_copies " backup copy of this file exists: </b></td><td>"
        } else {
          theHTML = theHTML num_backup_copies " backup copies of this file exist: </b></td><td>"
        }
        # present the user with a list of backup files
        theHTML = theHTML "<select name=\"backup_file\">"
    
        # loop creating the "<OPTIONS>" for the SELECT list.  If one matched the current file
        # being viewed, mark it selected so it will be shown in the SELECT field.
        for ( i = num_backup_copies; i > 0; i-- ) {
          option_value = BACKUP_COPIES[i]
          if ( theBackupFile == option_value ) { 
             is_selected = "selected" 
          } else { 
              is_selected = "" 
          }
          theHTML = theHTML "<option value=\"" option_value "\" " is_selected ">"
          theHTML = theHTML option_value "</option>" ORS
        }
        theHTML = theHTML "</select></td><td width=\"70%\" align=\"left\"><input type=\"submit\" name=\"view_backup\" value=\"View Backup Copy\"</td></table>"
      }
    }

    fileViewed = GETARG["view_backup"] != "" ? theBackupFile : theFile
    theHTML = theHTML "<fieldset style=\"margin-top:10px;\"><legend><strong>Viewing: " fileViewed "</strong></legend>"
    if ( GETARG["editfile"] != "" ) {
      # the GetFile function also sets the number of lines variable numLines
      file_contents = GetFile(theFile, "edit");
      if ( numCR > ( numLines / 4 )) {
        # MS-DOS CR/LF
        theHTML = theHTML "<input type=\"hidden\" value=\"MS-DOS\" name=\"end_of_line_type\">"
      } else {
        # Unix LF
        theHTML = theHTML "<input type=\"hidden\" value=\"UNIX\" name=\"end_of_line_type\">"
      }
      numLines+=2
      theHTML = theHTML "<textarea style=\"color:blue;background-color:lightyellow\" rows=\"" numLines "\" cols=\"120\" name=\"file\">"
      theHTML = theHTML file_contents
      theHTML = theHTML "</textarea>"
      theHTML = theHTML "<hr><table width=\"100%\"><tr><td align=\"center\" border=0>"
      theHTML = theHTML "<Input type=submit name=savefile value='Save File'><b> " theFile "</b>"
      theHTML = theHTML "<Input type=submit name=canceledit value='Cancel File Edit'>"
    } else {
      if ( GETARG["view_backup"] != "" ) {
        theHTML = theHTML theBackupFile "<br>"
        theHTML = theHTML "<pre>" GetFile(theBackupFile, "view") "</pre>";
        differences = GetFileDiff(theFile, theBackupFile) 
        theHTML = theHTML "<hr><pre>"  differences
        theHTML = theHTML "</pre><table width=\"100%\"><tr><td align=\"center\" border=0>"
        theHTML = theHTML "<Input type=submit name=vf value='View Current: " file_basename "'>&nbsp;&nbsp;"
        if ( differences ~ /<b>Differences Exist:/ ) {
          theHTML = theHTML "<Input type=submit name=revert_backup value='Revert to : " getBaseName(theBackupFile) "'>"
        }
      } else {
      # view the file
        theHTML = theHTML "<pre>" GetFile(theFile, "view") "</pre>";
        theHTML = theHTML "<hr><table width=\"100%\"><tr><td align=\"center\" border=0>"
        theHTML = theHTML "<Input type=submit name=editfile value='Edit'><b> " theFile "</b>"
      }
    }
    theHTML = theHTML "</td></tr></table>"
    theHTML = theHTML "</fieldset>"
  } else {
    theHTML = theHTML "<hr>This plug-in allows viewing and editing of selected system and configuration files."
    theHTML = theHTML "<ul><li>When viewing a file, you may edit it by pressing the \"Edit File\" button below it.</li>"
    theHTML = theHTML "<li>When a file is edited, and subsequently saved, a backup copy of the original is made.</li> "
    theHTML = theHTML "<li>If you press \"Cancel File Edit\" when editing a file, no change to the original is made.</li> "
    theHTML = theHTML "<li>Backup copies may be viewed, with the differences between the older copy and the current displayed in \"diff\" format.</li> "
    theHTML = theHTML "<li>Backup copies may not be edited.</li> "
    theHTML = theHTML "<li>You may \"Revert\" to a backup version by pressing the button present at the bottom of the \"diff\" listing.</li></ul>"
    theHTML = theHTML "You may define additional locally editable files in the unmenu.conf or unmenu_local.conf"
    theHTML = theHTML " file as follows:<br><b>EDITABLE_FILE = full_path_to_your_local_file</b><br>"
    theHTML = theHTML "(Multiple EDITABLE_FILE entries are allowed)"
  }

  # awk limitation for POST, need extra unused field as last field on form".
  theHTML = theHTML "<input type=\"hidden\" value=\"\" name=\"dummy\">"
  theHTML = theHTML "</form>"
  print theHTML

}

function GetFile( theFileName, viewEdit,   ret ) {
    RS="\n"
    ret = ""
    numLines = 0
    numCR = 0
    eol = RS
    while (( getline line < theFileName ) > 0 ) {
      if ( line ~ /[\r]$/ ) numCR++
      if ( viewEdit == "view" ) {
        gsub("&","\\&amp;",line)
        gsub("<","\\&lt;",line)
        gsub(">","\\&gt;",line)
      }
      ret = ret line eol
      numLines++;
    }
    close(theFileName)
    return ret
}

function Add_Specific_Editable_File(idx , cfile) {
  idx++
  EDITABLE_FILE[idx] = cfile
  return idx
}

function GetConfigEditableFiles(idx, cfile) {
    RS="\n"
    additional_files=idx
    while (( getline line < cfile ) > 0 ) {
          delete c;
          match( line , /^EDITABLE_FILE([\t ]*)(=)([\t ]*)(.+)/, c)
          if ( c[1,"length"] > 0 && c[2,"length"] > 0 && 
               c[3,"length"] > 0 && c[4, "length"] > 0 ) {
               additional_files++;
               EDITABLE_FILE[additional_files] = substr(line,c[4,"start"],c[4,"length"])
          }
    }
    close(cfile);
    return additional_files
}

function GetEditableFiles(idx, cdir, cfile   ,cmd) {
    RS="\n"
    additional_files=idx
    cmd = "ls --file-type " cdir "/" cfile " 2>/dev/null" 
#print cmd >/dev/stderr
    while (( cmd | getline line ) > 0 ) {
       additional_files++;
       EDITABLE_FILE[additional_files] = line
    }

    close(cmd);
    return additional_files
}
function GetFileDiff(cf, bf,   ret, line){
    RS="\n"
    cmd = "diff " cf " " bf " 2>&1"
    ret = ""
    while (( cmd | getline line ) > 0 ) {
      gsub("&","\\&amp;",line)
      gsub("<","\\&lt;",line)
      gsub(">","\\&gt;",line)
      ret = ret line RS
    }
    close(cmd)
    if ( ret == "" ) {
      ret = "<b>No differences</b> exist between " cf " <br>and " bf
    } else {
      ret = "<b>Differences Exist:<br><font color=\"red\">< = " cf "<br>> = " bf "</font></b><br>" ret
    }
    return ret
}

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

function CGI_setup(   uri,  i) {
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

function getBaseName( file_name , fn, c) {
   delete fn;
   c = split(file_name, fn, "/")
   return fn[c];
}

# if the file backup folder does not exist, create it.
function CreateFolder( pdir ) {

  path="/"
  x = split( pdir, dir_path, "/")
  for ( i = 2; i <= x; i++ ) {
     path = path dir_path[i] "/"
     system ("[ ! -d " path " ] && mkdir " path );
  }
}

function GetBackupCopyList(fn, fd,  line) {
    RS="\n"
    delete BACKUP_COPIES
    backup_copies=0
    cmd = "ls --file-type " fd "/" fn "-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.bak 2>/dev/null" 
#print cmd >/dev/stderr
    while (( cmd | getline line ) > 0 ) {
       backup_copies++;
       BACKUP_COPIES[backup_copies] = line
    }
    close(cmd);
    return backup_copies
} 
