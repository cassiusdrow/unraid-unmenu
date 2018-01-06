BEGIN {
#ADD_ON_URL=myConfig
#ADD_ON_MENU=
#ADD_ON_STATUS=YES
#ADD_ON_TYPE=awk
#ADD_ON_HTTP_TAGS=NO
#ADD_ON_PAGE_HEADING=NO
#ADD_ON_HTTP_HEADER=YES
#ADD_ON_OPTIONS=-f drivedb.lib.awk -f unmenu.base.lib.awk -f utility.lib.awk
#ADD_ON_REFRESH = 0
#ADD_ON_CONFIG=norefresh.conf
#define ADD_ON_VERSION 1.0 - Part of myMain 12-1-10 release, contributed by bjp999
#define ADD_ON_VERSION 1.1 - change order of attributes
#UNMENU_RELEASE $Revision$ $Date$

   # Copyright bjp999, 2010.  This program carries no guarantee of any kind.

   #-----------------
   # Initializations
   #-----------------
   CGI_setup();

   amp="AMP3RS4ND"

   CONFIG_FILE      = "myMain_local.conf"
   #CONFIG_FILE      = "myMain_local.bjp"
   CONFIG_FILE_BACK = "myMain_local.bak"

   nbsp = amp "nbsp;"

   activesort = GETARG["sort"]
   activeview = GETARG["view"]
   curseq     = GETARG["seq"]
   mode       = GETARG["mode"]

   LoadConfigFile("myMain.conf", configDefault, (1==1))
   LoadConfigFile(CONFIG_FILE, configLocal, (1==1))

   #perr("Mode=" mode);
   if(mode == "main")
      MainConfig();
   else if (mode == "drive")
      DriveConfig();
   else if (mode == "view")
      ViewConfig();

   if(constant["ImageHost"] != "")
      host = constant["ImageHost"]
   else
      host = getImageHost();

   gsub("%ImageURL%", "http://" host "/log/images", theHTML);
   #gsub("%MyHost%", MyHost, theHTML);
   gsub(amp, "\\&", theHTML);
   print theHTML;
}

#----------------------------------------
# "Main" Configuration (global settings)
#----------------------------------------
function MainConfig(fn, vv)
{
   #perr("Action==> " GETARG["Action"]);
   fn="myMainConfigMain.html"

   #perr("Action==> " GETARG["Action"]);

   if(GETARG["Action"] == "Save") {
      #perr("Saving");
      MainConfigSave();
      UnloadConfigFile();
      delete configDefault;
      delete configLocal;
      LoadConfigFile("myMain.conf", configDefault, (1==1))
      LoadConfigFile(CONFIG_FILE, configLocal, (1==1))
   }
   else
      message=""

   #vv[vv["count"]=0, "from"] = "defsmartignorelist"; vv[vv["count"], "to"] = constant["SmartIgnoreList"];

   vv[vv["count"]=0, "from"] = "defidlen";           vv[vv["count"], "to"] = configDefault["idlen"];
   vv[++vv["count"], "from"] = "defmyserverwidth";   vv[vv["count"], "to"] = configDefault["myserverwidth"];
   vv[++vv["count"], "from"] = "defmyslotswidth";    vv[vv["count"], "to"] = configDefault["myslotswidth"];
   vv[++vv["count"], "from"] = "defsysloglines";     vv[vv["count"], "to"] = configDefault["sysloglines"];
   vv[++vv["count"], "from"] = "defsyslogstyle";     vv[vv["count"], "to"] = configDefault["syslogstyle"];
   vv[++vv["count"], "from"] = "defimagehost";       vv[vv["count"], "to"] = configDefault["imagehost"];
   #vv[++vv["count"], "from"] = "defsmartignorelist"; vv[vv["count"], "to"] = configDefault["smartignorelist"];

   vv[++vv["count"], "from"] = "refreshinterval";     vv[vv["count"], "to"] = configLocal["refreshinterval"];
   vv[++vv["count"], "from"] = "mymaincheck";         vv[vv["count"], "to"] = configLocal["mymaincheck"];
   vv[++vv["count"], "from"] = "idlen";               vv[vv["count"], "to"] = configLocal["idlen"];
   vv[++vv["count"], "from"] = "myserverwidth";       vv[vv["count"], "to"] = configLocal["myserverwidth"];
   vv[++vv["count"], "from"] = "myslotswidth";        vv[vv["count"], "to"] = configLocal["myslotswidth"];
   vv[++vv["count"], "from"] = "sysloglines";         vv[vv["count"], "to"] = configLocal["sysloglines"];
   vv[++vv["count"], "from"] = "syslogstyle";         vv[vv["count"], "to"] = configLocal["syslogstyle"];
   vv[++vv["count"], "from"] = "imagehost";           vv[vv["count"], "to"] = configLocal["imagehost"];
   #vv[++vv["count"], "from"] = "smartignorelist";     vv[vv["count"], "to"] = configLocal["smartignorelist"];

   #perr("config[refreshinterval, line]  = " config["refreshinterval", "line"])
   #perr("config[refreshinterval, value] = " config["refreshinterval"])
   #perr("config[mymaincheck, line]      = " config["mymaincheck", "line"])
   #perr("config[mymaincheck]            = " config["mymaincheck"])
   #perr("config[idlen, line]            = " config["idlen", "line"])
   #perr("config[idlen]                  = " config["idlen"])
   #perr("config[myserverwidth, line]    = " config["myserverwidth", "line"])
   #perr("config[myserverwidth]          = " config["myserverwidth"])
   #perr("config[myslotswidth, line]     = " config["myslotswidth", "line"])
   #perr("config[myslotswidth]           = " config["myslotswidth"])
   #perr("config[sysloglines, line]      = " config["sysloglines", "line"])
   #perr("config[sysloglines]            = " config["sysloglines"])
   #perr("config[syslogstyle, line]      = " config["syslogstyle", "line"])
   #perr("config[syslogstyle]            = " config["syslogstyle"])
   #perr("config[smartignorelist, line]  = " config["smartignorelist", "line"])
   #perr("config[smartignorelist]        = " config["smartignorelist"])
   #perr("config[imagehost]              = " config["imagehost"])

   vv[++vv["count"], "from"] = "message";
   vv[vv["count"],   "to"]   = message;

   htmlLoadFile(fn, html)

   #for(i=0; i<html["count"]; i++) {
   #   perr(i "  " html[i, "type"] " --> " html[i]);
   #}
   theHTML = htmlSerialize(html, 0, vv);
}

#-----------------------------
# Save "Main" config settings
#-----------------------------
function MainConfigSave(fn1, fn2, cmd, i, ar, temp)
{
   # Delete the old backup config file (it may not exist, so suppress any error)
   cmd = "rm " CONFIG_FILE_BACK " >/dev/null 2>&1";
   system(cmd);
   #perr("rm command==>" cmd);

   # Rename the current config file to backup
   cmd = "mv " CONFIG_FILE " " CONFIG_FILE_BACK;
   system(cmd);
   #perr("mv command==>" cmd);

   # Write new rows to new config file
   fn1 = CONFIG_FILE_BACK;
   fn2 = CONFIG_FILE;
   #cmd = "rm " fn2;
   #system(cmd);
   #perr("rm command==>" cmd);

   if(GETARG["mymaincheck"] == "on") {
      temp = "ADD_ON_URL =";
      print temp >>fn2
   }

   ar[1] = "refreshinterval";
   ar[2] = "idlen";
   ar[3] = "myserverwidth";
   ar[4] = "myslotswidth";
   ar[5] = "sysloglines";
   ar[6] = "syslogstyle";
   ar[7] = "imagehost";
   #ar[6] = "smartignorelist";

   for(i=1; i<=7; i++) {
      #perr(ar[i] "=" GETARG[ar[i]]);
      if(trim(GETARG[ar[i]]) != "") {
         if((temp=configLocal[ar[i], "line"]) == "")
            if((temp=configDefault[ar[i], "line"]) == "") {
               perr("Template row for ar[i] not found");
               continue;
            }
         sub("b@j@p@9@9@9", trim(GETARG[ar[i]]), temp);
         gsub(amp, "\\&", temp);
         #perr("New==>" temp)
         print temp >>fn2
      }
   }

   # Read current config file, writing new rows to new config file, skipping configured lines
   nextSkipLine = configLocal[l_ix=0, "linenum"];
   currline=0;
   while (( getline li < fn1 ) > 0 ) {
      curline++;
      if(curline == nextSkipLine) {
         nextSkipLine = configLocal[++l_ix, "linenum"];
         continue;
      }
      print li >>fn2
   }
   # close new config file
   close(fn1);
   close(fn2);

   if(GETARG["mymaincheck"] == "on")
      GETARG["mymaincheck"] = "checked";

   #perr("refreshinterval=" configLocal["refreshinterval"] " / " GETARG["refreshinterval"])
   #perr("mymaincheck    =" configLocal["mymaincheck"]     " / " GETARG["mymaincheck"])

   if((configLocal["refreshinterval"] != GETARG["refreshinterval"]) ||
      (configLocal["mymaincheck"]     != GETARG["mymaincheck"])) {

      message = "Saving main configuration.  Wait approximately 30 seconds for unmenu to reload.";

      cmd="nohup sh -c 'sleep 10;kill -USR1 `cat /var/run/unmenu.pid` '>/dev/null 2>&1 &"
      system(cmd);
   }

   cmd="rm /tmp/mymain_seq.txt >/dev/null 2>&1";
   system(cmd);
}


#--------------------------------------------------------------------------
# View configurations (change columns, sort order, and settings for views)
#--------------------------------------------------------------------------
function ViewConfig(token_ix, i, c2, c3, vv)
{
   #perr("Action==> " GETARG["Action"]);

   action = GETARG["Action"];

   if((action == "default") && (GETARG["mode"] == "view")) {
      ViewConfigSave( GETARG["viewname"], "", "" )
      UnloadConfigFile();
      delete configDefault;
      delete configLocal;
      LoadConfigFile("myMain.conf", configDefault, (1==1))
      LoadConfigFile(CONFIG_FILE, configLocal, (1==1))
      action = "";
   }

   if(action != "") {
      viewcols = GETARG["viewcols"];
      gsub("+", " ", viewcols);
      viewname = GETARG["viewname"];
      picktoken = GETARG["picktoken"];
      #perr("cbTotal==>" GETARG["cbTotal"])

      view[viewname, "totalrow"]  = (GETARG["cbTotal"]    == "on") ? "1" : "0";
      view[viewname, "perfdata"]  = (GETARG["cbPerf"]     == "on") ? "1" : "0";
      view[viewname, "smartdata"] = (GETARG["cbSmart"]    == "on") ? "1" : "0";
      view[viewname, "tempdata"]  = (GETARG["cbTemp"]     == "on") ? "1" : "0";
      view[viewname, "greenbar"]  = (GETARG["cbGreenbar"] == "on") ? "1" : "0";
      view[viewname, "plain"]     = (GETARG["cbVanilla"]  == "on") ? "1" : "0";

      #--------------------
      # Parse sort options
      #--------------------
      sortopt = GETARG["sortopt"]
      gsub("-", "", sortopt)
      split(sortopt, sortcol, "+");

      sortopt = ((GETARG["cbSort1Asc"] == "on") ? "" : "-") sortcol[1]
      if (sortcol[2] != "")
         sortopt = sortopt "+" ((GETARG["cbSort2Asc"] == "on") ? "" : "-") sortcol[2]

      delete sortcol;

      #perr("sortopt=" sortopt)

      if(substr(action, 1, 1) == "F")
         fnum = substr(action, 2)+0
      else if(substr(action, 1, 1) == "P")
         pnum = substr(action, 2)+0
      else if(substr(action, 1, 1) == "S")
         snum = substr(action, 2)+0
      else if(action == "LAST")
         pnum = 9999;
   }
   else {
      viewcols = view[GETARG["view"]];
      viewname = GETARG["view"];
      sortopt = constant[viewname "sort"]
      if(sortopt == "")
         sortopt = "num";
   }

   #--------------------
   # Parse sort options
   #--------------------
   split(sortopt, sortcol, "+");

   if(substr(sortcol[1], 1, 1) == "-") {
      sort1Asc = (1==0);
      sort1Field = substr(sortcol[1], 2);
   }
   else {
      sort1Asc = (1==1);
      sort1Field = sortcol[1];
   }

   if(sortcol[2] == "") {
      sort2Asc = (1==1);
      sort2Field = "";
   }
   else if(substr(sortcol[2], 1, 1) == "-") {
      sort2Asc = (1==0);
      sort2Field = substr(sortcol[2], 2);
   }
   else {
      sort2Asc = (1==1);
      sort2Field = sortcol[2];
   }

   viewcol["count"] = split(viewcols, viewcol, " ")

   fn="myMainConfigView.html"

   #perr("Action==> " action);
   if(fnum > 0) {
      #perr("fnum=" fnum ", field=" viewcol[fnum] ", newfield=" picktoken)
      if(picktoken != "") {
         if(picktoken == "DELETE") {
            for(i=fnum; i<=viewcol["count"]; i++) {
               viewcol[i] = viewcol[i+1];
            }
            viewcol["count"]--;
         }
         else {
            viewcol[fnum] = picktoken;
         }
         viewcols = join(viewcol, " ");
      }
   }
   else if(pnum > 0) {
      if(picktoken != "DELETE") {
         if(pnum == 9999)
            pnum = viewcol["count"]+1

         for(i=viewcol["count"]; i >= pnum; i--) {
            viewcol[i+1] = viewcol[i];
         }
         viewcol[pnum] = picktoken;

         viewcol["count"]++;

         viewcols = join(viewcol, " ");
      }
   }
   else if(snum > 0) {
      if(picktoken == "DELETE") {
         if(snum == "1") {
            sort1Field = sort2Field;
            sort1Asc   = sort2Asc;
         }
         sort2Field = "";
         sort2Asc   = (1==1);
      }
      else {
         if(snum == "1")
            sort1Field = picktoken;
         else if(snum == "2")
            sort2Field = picktoken;
      }
   }


   #----------------
   # Load HTML file
   #----------------
   htmlLoadFile(fn, html)

   #--------------------------------
   # Expand sectin "A" in HTML file
   #--------------------------------
   for(i=1; i<=viewcol["count"]; i++) {
      delete vv;
      vv[token_ix=0, "from"] = "FIELD";  vv[token_ix, "to"] = viewcol[i];
      htmlExpandGroup(html, "A", i, vv);
   }

   rowcount = ceiling((columndoc["count"]+1) / 3);

   c2 = rowcount-1;
   c3 = 2*rowcount-1;

   #perr("rowcount=" rowcount ", total=" columndoc["count"])

   #---------------------------------
   # Expand section "B" in HTML File
   #---------------------------------
   for(i=0; i<rowcount; i++) {
      delete vv;
      if(i==0) {
         vv[token_ix=0, "from"] = "TA";  vv[token_ix, "to"] = "DELETE";
         vv[++token_ix, "from"] = "DA";  vv[token_ix, "to"] = "Remove column from view";
         vv[++token_ix, "from"] = "bcolorA";  vv[token_ix, "to"] = "white";
      }
      else {
        vv[token_ix=0, "from"] = "TA";  vv[token_ix, "to"] = columndoc[i-1, 0];
        vv[++token_ix, "from"] = "DA";  vv[token_ix, "to"] = columndoc[i-1, 1];
        if(index(" " viewcols " ", " " columndoc[i-1, 0] " ") > 0) {
           vv[++token_ix, "from"] = "bcolorA";  vv[token_ix, "to"] = "yellow";
        }
        else {
           vv[++token_ix, "from"] = "bcolorA";  vv[token_ix, "to"] = "white";
        }
      }
      vv[++token_ix, "from"] = "TB";  vv[token_ix, "to"] = columndoc[c2+i, 0];
      vv[++token_ix, "from"] = "DB";  vv[token_ix, "to"] = columndoc[c2+i, 1];
      if(index(" " viewcols " ", " " columndoc[c2+i, 0] " ") > 0) {
         vv[++token_ix, "from"] = "bcolorB";  vv[token_ix, "to"] = "yellow";
      }
      else {
         vv[++token_ix, "from"] = "bcolorB";  vv[token_ix, "to"] = "white";
      }
      if(columndoc[c3+i, 0] != "") {
         vv[++token_ix, "from"] = "BUTTON";  vv[token_ix, "to"] = "<input name=\"picktoken\" type=\"radio\" value=\"$TC$\">"
         vv[++token_ix, "from"] = "TC";  vv[token_ix, "to"] = columndoc[c3+i, 0];
         vv[++token_ix, "from"] = "DC";  vv[token_ix, "to"] = columndoc[c3+i, 1];
         if(index(" " viewcols " ", " " columndoc[c3+i, 0] " ") > 0) {
            vv[++token_ix, "from"] = "bcolorC";  vv[token_ix, "to"] = "yellow";
         }
         else {
            vv[++token_ix, "from"] = "bcolorC";  vv[token_ix, "to"] = "white";
         }
      }
      else {
         vv[++token_ix, "from"] = "BUTTON";  vv[token_ix, "to"] = amp "nbsp;";
         vv[++token_ix, "from"] = "TC";  vv[token_ix, "to"] = amp "nbsp;";
         vv[++token_ix, "from"] = "DC";  vv[token_ix, "to"] = amp "nbsp;";
         vv[++token_ix, "from"] = "bcolorC";  vv[token_ix, "to"] = "white";
      }

      htmlExpandGroup(html, "B", i, vv);
   }
   delete vv;

   #--------------------------------------
   # Set up the global token replacements
   #--------------------------------------
   vv[token_ix=0, "from"] = "viewname";        vv[token_ix, "to"] = viewname;
   vv[++token_ix, "from"] = "viewcols";        vv[token_ix, "to"] = viewcols;
   vv[++token_ix, "from"] = "totalchecked";    vv[token_ix, "to"] = (view[viewname, "totalrow"]  == "1") ? "checked" : "";
   vv[++token_ix, "from"] = "perfchecked";     vv[token_ix, "to"] = (view[viewname, "perfdata"]  == "1") ? "checked" : "";
   vv[++token_ix, "from"] = "smartchecked";    vv[token_ix, "to"] = (view[viewname, "smartdata"] == "1") ? "checked" : "";
   vv[++token_ix, "from"] = "tempchecked";     vv[token_ix, "to"] = (view[viewname, "tempdata"]  == "1") ? "checked" : "";
   vv[++token_ix, "from"] = "greenbarchecked"; vv[token_ix, "to"] = (view[viewname, "greenbar"]  == "1") ? "checked" : "";
   vv[++token_ix, "from"] = "vanillachecked";  vv[token_ix, "to"] = (view[viewname, "plain"]     == "1") ? "checked" : "";

   vv[++token_ix, "from"] = "sort1";           vv[token_ix, "to"] = sort1Field;
   vv[++token_ix, "from"] = "sort1checked";    vv[token_ix, "to"] = (sort1Asc) ? "checked" : "";
   vv[++token_ix, "from"] = "sort2";           vv[token_ix, "to"] = sort2Field;
   vv[++token_ix, "from"] = "sort2checked";    vv[token_ix, "to"] = (sort2Asc) ? "checked" : "";

   #-----------------------
   # Create options string
   #-----------------------
   viewopt = view[viewname, "plain"] \
             view[viewname, "greenbar"] \
             "00" \
             view[viewname, "tempdata"] \
             view[viewname, "smartdata"] \
             view[viewname, "perfdata"] \
             view[viewname, "totalrow"]

   #--------------------
   # Create sort string
   #--------------------
   sortopt = ((sort1Asc) ? "" : "-") sort1Field
   if(sort2Field != "")
      sortopt = sortopt "+" (((sort2Asc) ? "" : "-") sort2Field)

   vv[++token_ix, "from"] = "viewopt";       vv[token_ix, "to"] = viewopt;
   vv[++token_ix, "from"] = "sortopt";       vv[token_ix, "to"] = sortopt;

   vv[++token_ix, "from"] = "what"; vv[token_ix, "to"] = "\"" toupper(substr(viewname,1,1)) substr(viewname,2) "\" View Configuration";


   if(GETARG["Action"] == "save") {
      viewline = "SetView("viewname", "viewopt", \"" GETARG["viewcols"] "\")";
      sortline = "SetConstant(" viewname "sort, \"" sortopt "\")"
      #perr("viewline==> " viewline);
      #perr("sortline==> " sortline);
      ViewConfigSave( viewname, viewline, sortline )
   }

   theHTML = htmlSerialize(html, 0, vv);
}


#--------------------
# Save view settings
#--------------------
function ViewConfigSave(viewname, viewline, sortline, fn1, fn2, cmd, i, ar, temp, currline, li, skipline1, skipline2)
{
   #----------------------------------------------------------------------
   # Delete the old backup config file (it may not exist, so suppress any
   # error)
   #----------------------------------------------------------------------
   cmd = "rm " CONFIG_FILE_BACK " >/dev/null 2>&1";
   system(cmd);
   #perr("rm command==>" cmd);

   #------------------------------------------
   # Rename the current config file to backup
   #------------------------------------------
   cmd = "mv " CONFIG_FILE " " CONFIG_FILE_BACK;
   system(cmd);
   #perr("mv command==>" cmd);

   fn1 = CONFIG_FILE_BACK;
   fn2 = CONFIG_FILE;

   #-----------------------------------
   # Write new rows to new config file
   #-----------------------------------
   if(viewline != "")
      print viewline >>fn2;
   if(sortline != "")
      print sortline >>fn2;

   #-------------------------------------------------------------------------
   # Read current config file, writing new rows to new config file, skipping
   # configured lines
   #-------------------------------------------------------------------------
   skipline1 = configLocal["view", viewname, "linenum"]
   skipline2 = configLocal["constant", viewname "sort", "linenum"]
   #perr(skipline1 " " skipline2)
   currline=0;
   while (( getline li < fn1 ) > 0 ) {
      curline++;
      if((curline == skipline1) || (curline == skipline2)) {
         #perr("Skipped line ==> " li);
         continue;
      }
      print li >>fn2
   }

   #--------------------
   # Close config files
   #--------------------
   close(fn1);
   close(fn2);
}


#--------------------------------------------------
# Drive configurations (drive specific attributes)
#--------------------------------------------------
function DriveConfig(id,i,found, x, y)
{
   values["myserial"] = GETARG["serial"];
   if(values["myserial"] == "")
      values["myserial"] = GETARG["myserial"];
   if(values["myserial"] == "") {
      if(GETARG["id"] != "") {
         for(i=0; i<configvalue["count"]; i++) {
            if(substr(configvalue[i,0], length(configvalue[i,0]) - length(GETARG["id"]) + 1) == GETARG["id"])
               if(tolower(configvalue[i,1]) == "myserial") {
                  values["myserial"] = configvalue[i,2]; # Best case we find the myserial setting
                  break;
               }
               else
                  if(length(configvalue[i,0]) > length(GETARG["id"]))
                  values["myserial"] = configvalue[i,0]; # Second best, we find a longer serial number on the setting
                                                         #   (provide compatibility with prior myMain versions)
                                                         #   but keep looking
         }
      }
   }

   #perr("Serial=" values["myserial"])

   #-------------------------------------------------------------------------
   # Regardless of user's IdLen, we always store with 4 digit serial numbers
   # - VERY unlikely to have dups!
   #-------------------------------------------------------------------------
   values["id4" ] = substr(values["myserial"], length(values["myserial"])-(4-1))
   values["autoid" ]  = substr(values["myserial"], length(values["myserial"])-(constant["IdLen"]-1))

   #names_sub_list = "myserial,autoid,manu,mysize,location,mount,slot,share,interface,modelname,cache,speed,borndate,borndate_raw,store,purchdate,purchdate_raw,invoice,cost,warranty,usage,notes";
   names_sub_list = "myserial,autoid,manu,modelname,mysize,location,mount,slot,share,interface,cache,speed,borndate,borndate_raw,store,purchdate,purchdate_raw,invoice,cost,warranty,usage,notes"
   
   names_out_list = names_sub_list
   #gsub("serial,", "", names_out_list)
   gsub("autoid,", "", names_out_list)

   names_sub["count"]  = split(names_sub_list, names_sub, ",")
   names_out["count"]  = split(names_out_list, names_out, ",")

   #-------------------------------------------------------
   # Find all existing config values for drive in question
   #-------------------------------------------------------
   j=0; config_ix=0; drive_found=0; otherdisk["count"] = 0;
   y=length(values["myserial"]);
   for(i=0; i<configvalue["count"]; i++) {
      x = length(configvalue[i, 0]);

      len = (x>6) ? 6 : x;

      if(len < 2) #ignore if less than 2 characters (0 or 1)
         continue;

      if(y < len)
         len=y;

      if((values["myserial"] != "") && (substr(configvalue[i, 0], x-len+1) == substr(values["myserial"], y-len+1))) {
         DriveConfigValue[j, 0] = configvalue[i,0];   # Serial Number / ID
         DriveConfigValue[j, 1] = configvalue[i,1];   # Attribute Name
         DriveConfigValue[j, 2] = configvalue[i,2];   # Attribute Value
         DriveConfigValue[j++, 3] = configvalue[i,3]; # Line number
         drive_found=1;
      }
      else {
         if((configvalue[i, 1] == "location") || (configvalue[i, 1] == "mount")) {
            drive2[substr(configvalue[i, 0], x-constant["IdLen"]+1), configvalue[i, 1]] = configvalue[i,2];
            if(configvalue[i, 1] == "mount") {
               if((substr(configvalue[i,2], 1, 4) == "disk") && (length(configvalue[i,2]) == 5))
                  drive2[substr(configvalue[i, 0], x-constant["IdLen"]+1), "mount2"] = substr(configvalue[i,2], 1, 4) "0" substr(configvalue[i,2], 5, 1);
               else
                  drive2[substr(configvalue[i, 0], x-constant["IdLen"]+1), "mount2"] = configvalue[i,2];
               #perr("drive2[" substr(configvalue[i, 0], x-constant["IdLen"]+1) ", \"mount2\"] = " drive2[substr(configvalue[i, 0], x-constant["IdLen"]+1), "mount2"]);
            }
         }

         #perr("id=" id);
         found=0;

         for(config_ix=0; otherdisk[config_ix] != ""; config_ix++)
            if(otherdisk[config_ix] == substr(configvalue[i, 0], x-constant["IdLen"]+1)) {
               found=1;
               break;
            }
         if(found == 0)
            otherdisk[otherdisk["count"]++] = substr(configvalue[i, 0], x-constant["IdLen"]+1)
      }
   }
   DriveConfigValue["count"] = j;

   #for(i=0; i<DriveConfigValue["count"]; i++)
   #   p("1=" DriveConfigValue[i, 1] "  2=" DriveConfigValue[i, 2] "  3=" DriveConfigValue[i, 3]);

   #for(i=0; i<otherdisk["count"]; i++)
   #   p("otherdisk" i "=" otherdisk[i]);


   #perr("Action=" GETARG["Action"])

   #-----------------------------------------------------------------------------------------------------
   # User requested to make the changes.  This will read through the local config file, remove all lines
   # related to the drive and insert the new attributes based on the myConfig screen.
   #-----------------------------------------------------------------------------------------------------
   if(GETARG["Action"]=="Save") {
      DriveConfigSaveOrDelete("save");
      theHTML = HtmlRefresh("myConfig?mode=drive&serial=" values["myserial"])
   }

   else if(GETARG["Action"]=="Delete") {
      DriveConfigSaveOrDelete("delete");
      theHTML = HtmlRefresh("myConfig?mode=drive")
   }

   else if(GETARG["Action"]=="Load")
      theHTML = HtmlRefresh("myConfig?mode=drive&serial=" GETARG["newid"])

   else if(GETARG["Action"]=="LoadSerial")
      theHTML = HtmlRefresh("myConfig?mode=drive&serial=" GETARG["newid"])

   else {
      extraAttr["count"] = 0;
      foundextra = 0;
      for(i=0; i<DriveConfigValue["count"]; i++) {
         name = DriveConfigValue[i, 1];
         if(index(names_sub_list, name) > 0) {
            values[name] = DriveConfigValue[i,2];
            #perr("name=" name ", value=" values[name]);
         }
         else {
            extraAttr[extraAttr["count"], "name"]  = DriveConfigValue[i,1];
            if(DriveConfigValue[i,1] == GETARG["newattr"] "_ok") {
               extraAttr[extraAttr["count"], "value"] = GETARG["newvalue"]
               foundextra = 1;
            }
            else
               extraAttr[extraAttr["count"], "value"] = DriveConfigValue[i,2];

            extraAttr["count"]++;
         }
      }

      if(foundextra == 0)
         if(GETARG["newattr"] != "") {
            extraAttr[extraAttr["count"], "name"]  = GETARG["newattr"] "_ok";
            extraAttr[extraAttr["count"], "value"] = GETARG["newvalue"]
            extraAttr["count"]++;
         }

      fn="myMainConfigDrive.html"

      htmlLoadFile(fn, html)

      #for(i=0; i<html["count"]; i++) {
      #   perr(i "  " html[i, "type"] " --> " html[i]);
      #}

      for(i=0; i<extraAttr["count"]; i++) {
         delete vv;
         vv[config_ix=0, "from"] = "attrname";        vv[config_ix, "to"] = extraAttr[i, "name"];
         vv[++config_ix, "from"] = "attrvalue";       vv[config_ix, "to"] = extraAttr[i, "value"];

         htmlExpandGroup(html, "A", i, vv);
      }

      for(i=0; i<6; i++)
         htmlExpandGroup(html, "B", i);

      delete vv;
      config_ix=0;

      SortOtherDisks(otherdisk["count"]);
      for(j=0; otherdisk[j] != ""; j++) {
         i = sortarray[j];
         x = trim(drive2[otherdisk[i],"location"] " " drive2[otherdisk[i],"mount"]);
         if(length(x) > 0)
            x = amp"nbsp;" x ;

         vv[config_ix, "from"] = "otherid" i;     vv[config_ix, "to"] = otherdisk[i];
         vv[++config_ix, "from"] = "otherinfo" i;  vv[config_ix, "to"] = x
         htmlExpandGroup(html, "C", i, vv);
      }

      #---------------------------------------------------
      # Override "my" values with values passed by unmenu
      #---------------------------------------------------
      if((GETARG["disk_size"] != "") && (values["mysize"] == "")) {
         values["mysize"] = GETARG["disk_size"];
         if(values["location"] == "")
            values["location"] = "unRaid"
      }

      if((GETARG["disk"] != "") && (values["mount"] == ""))
         values["mount"] = GETARG["disk"];

      if(values["manu"] == "")
         values["manu"] = GETARG["manu"];

      delete vv;
      for(i=1; names_sub[i] != ""; i++) {
         vv[i-1, "from"] = names_sub[i];
         vv[i-1, "to"]   = values[names_sub[i]];
      }
      vv[i-1, "from"] = "what"; vv[i-1, "to"] = "Disk \"" values["autoid"] "\" Configuration";
      #perr("serial=" values["myserial"]);
      if(values["myserial"] == "") {
         vv[i, "from"] = "disabled"; vv[i, "to"] = "disabled=\"disabled\"";
      }
      else {
         vv[i, "from"] = "disabled"; vv[i, "to"] = "";
      }


      theHTML = htmlSerialize(html, 0, vv);

      #for(i=0; i<configvalue["count"]; i++) {
      #   p(i ":  0=" configvalue[i, 0] "  1="configvalue[i, 1] "  2=" configvalue[i, 2] "  3=" configvalue[i, 3])
      #}
   }
}

#-----------------------
# Save drive attributes
#-----------------------
function DriveConfigSaveOrDelete(mode, fn1, fn2, li, ix_fn1, ix_tgv, rc, name, value, dumpedPayload, id)
{

   id = values["id4"] # can change to "id6" if you have duplicate last 4 chars of serial number (extrememly unlikely)

   # Delete the old backup config file (it may not exist, so suppress any error)
   cmd = "rm " CONFIG_FILE_BACK " >/dev/null 2>&1";
   system(cmd);
   #perr("rm command==>" cmd);

   # Rename the current config file to backup
   cmd = "mv " CONFIG_FILE " " CONFIG_FILE_BACK;
   system(cmd);
   #perr("mv command==>" cmd);

   # Write new rows to new config file
   fn1 = CONFIG_FILE_BACK;
   fn2 = CONFIG_FILE;

   if(mode == "delete")
      dumpedPayload = 1;
   else
      dumpedPayload = 0;

   #fn1 = CONFIG_FILE;
   #fn2 = "/tmp/temp.conf";
   #system("unlink " fn2 " 2>/dev/null");

   ix_fn1 = 0;
   ix_tgv = 0;

   for(;;) {
      rc = (getline li < fn1);
      ix_fn1++;

      #--------------------------------------------------------------------------------------------------------
      # Put the attributes in place of old attributes.  If we've hit the end of the file, put them at the end.
      #--------------------------------------------------------------------------------------------------------
      if((ix_fn1 == DriveConfigValue[ix_tgv, 3]) || ((rc < 1) && (dumpedPayload == 0))) {
         ix_tgv++;
         if(dumpedPayload == 0) {

            GETARG["borndate_raw"]  = DateToRawDate(GETARG["borndate"]);
            GETARG["purchdate_raw"] = DateToRawDate(GETARG["purchdate"]);

            for(i=1; names_out[i] != ""; i++) {
               value=cleanValue(GETARG[names_out[i]]);
               if(value!="")
                  print "SetDriveValue(" id ", " names_out[i] ", \"" value "\")" >>fn2
            }

            for(i=0; i<10; i++) {
               #perr("adhoc" i "_name");
               name=cleanName(trim(GETARG["adhoc" i "_name"]));
               value=cleanValue(GETARG["adhoc" i "_value"]);
               #perr("name=" name);
               if((name != "") && (value != ""))
                  print "SetDriveValue(" id ", "name ", \"" value "\")" >>fn2
            }

            for(i=0; i<6; i++) {
               #perr("new" i "_name");
               name=cleanName(GETARG["new" i "_name"]);
               value=cleanValue(GETARG["new" i "_value"]);
               #perr("name=" name);
               if((name != "") && (value != ""))
                  print "SetDriveValue(" id ", "name ", \"" value "\")" >>fn2
            }
            dumpedPayload = 1;

            if(rc < 1) {
               print "" >>fn2  # if we put at the end of the file, put in an extra line
               break;
            }
         }
      }
      else {
         if(rc < 1)
            break;
         else
            print li >>fn2
      }
   }
   close(fn1);
   close(fn2);
   #system("mv -f " fn2 " " fn1);
}

function cleanName(s)
{
   gsub("[ \\t\\n\\r~!@#$%^&*()+={}\\[\\]|\\\\:;\"',./<>?]", "", s);   # remove all sorts of special characters
   return(s);
}

function cleanValue(s)
{
   gsub("\\\"", "'", s); # change double quotes to single quotes
   gsub("[\\n\\r&]", "", s);  # remove & and cr/lf (that probably can't get into the field anyway)
   gsub("[ \\t]+", " ", s);   # collapse muliple spaces or tabs to a single space
   return(s);
}

function SortOtherDisks(sortcount, i, j, k)
{
   for(i=0; i<sortcount; i++)
      sortarray[i] = i;

   for(j=0; j<sortcount-1; j++)
      for(i=0; i<sortcount-j-1; i++)
         if(( drive2[sortarray[i], "location" ]  >  drive2[ sortarray[i+1], "location" ] )       ||
            (( drive2[ otherdisk[sortarray[i]], "location" ] == drive2[ otherdisk[sortarray[i+1]], "location" ] ) &&
             ( drive2[ otherdisk[sortarray[i]], "mount2" ]    >  drive2[ otherdisk[sortarray[i+1]], "mount2" ] ))          ||
            (( drive2[ otherdisk[sortarray[i]], "location" ] == drive2[ otherdisk[sortarray[i+1]], "location" ] ) &&
             ( drive2[ otherdisk[sortarray[i]], "mount2" ]    == drive2[ otherdisk[sortarray[i+1]], "mount2" ] )    &&
             ( otherdisk[sortarray[i]] > otherdisk[ sortarray[i+1] ] ))) {
            k=sortarray[i]
            sortarray[i] = sortarray[i+1]
            sortarray[i+1] = k
         }
}
