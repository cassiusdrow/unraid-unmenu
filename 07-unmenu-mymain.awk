BEGIN {
#ADD_ON_URL=myMain
#ADD_ON_MENU=myMain
#ADD_ON_STATUS=YES
#ADD_ON_TYPE=awk
#ADD_ON_OPTIONS=-f drivedb.lib.awk -f unmenu.base.lib.awk -f utility.lib.awk
#ADD_ON_CONFIG=myMain.conf
#ADD_ON_LOCAL_CONFIG=myMain_local.conf
#ADD_ON_VERSION 1.45 - contributed by bjp999
#ADD_ON_VERSION 1.46 - added spindown spinup commands to use new scheme used by unRAID

   #-----------------
   # Initializations 
   #-----------------
   CGI_setup();

   #-----------------
   # Get sort option 
   #-----------------
   if((activesort=GETARG["sort"]) == "")
      activesort = "num";

   #------------------------
   # Get active view option 
   #------------------------
   if((activeview=GETARG["view"]) == "")
      activeview = "default";

   #------------------
   # Get trace option 
   #------------------
   if (GETARG["trace"] == "1") {
      perr("Trace on")
      tracestart = strftime("%s") + 0;
      trace=(1==1);
   }
   else
      trace=(1==0)

   #-------------------------------------------------------------------------
   # This awk program uses a lot of gsub() and gensub() calls.  These 
   # functions have special processing for the & character.  As a result, I 
   # change the values to this special constant for internal processing, and 
   # then back to an & before outputting the HTML. 
   #-------------------------------------------------------------------------
   amp="AMP3RS4ND"
   gbdelimbase = "`"
   gbdelim1=gbdelimbase "1"
   gbdelim2=gbdelimbase "2"
   gbdelim3=gbdelimbase "3"

   #------------------------------
   # Load the configuration files 
   #------------------------------
   LoadConfigFile(ScriptDirectory"/myMain.conf")
   LoadConfigFile(ScriptDirectory"/myMain_local.conf")
   #LoadConfigFile(ScriptDirectory"/myMain_local.bjp")

   #-------------------------------------
   # Colors used for special conditions. 
   #-------------------------------------
   FullColorHtml   =  ";" constant["FullColorHtml"]      
   EmptyColorHtml  =  ";" constant["EmptyColorHtml"]     
   TotalColorHtml  =  ";" constant["TotalColorHtml"]     
   HeaderColorHtml =  ";" constant["HeaderColorHtml"]   

   #--------------------------------
   # Make it easy to use color html
   #--------------------------------

   #-------------------------------------------------------------------------
   # Because I don't know (and can't know) while building the HTML what the 
   # sort order of the rows is going to be, I embed both the greenbar and 
   # the non-greenbar color codes into the output HTML.  Then, during the 
   # final HTML prep, I search and replace to remove the unneeded code as 
   # follows: 
   #    {delim1}{normalHtml}{delim2}{gbhtml}{delim3}
   #    if normal, gsub("{delim1}.*{delim2}", "", HTML) 
   #               gsub("{delim3}", "", HTML)
   #    if gb,     gsub("{delim2}.*{delim3}", "", HTML)
   #               gsub("{delim1}, "", HTML)
   #-------------------------------------------------------------------------

   if(view[activeview, "greenbar"] == "1") {
      ColorHtml["yellow"]   = ";" gbdelim1 constant["YellowHtml"]        gbdelim2 constant["YellowGBHtml"]         gbdelim3;
      ColorHtml["orange"]   = ";" gbdelim1 constant["OrangeHtml"]        gbdelim2 constant["OrangeGBHtml"]         gbdelim3;
      ColorHtml["red"]      = ";" gbdelim1 constant["RedHtml"]           gbdelim2 constant["RedGBHtml"]            gbdelim3;
      ColorHtml["blue"]     = ";" gbdelim1 constant["BlueHtml"]          gbdelim2 constant["BlueGBHtml"]           gbdelim3;
      ColorHtml["override"] = ";" gbdelim1 constant["ColorOverrideHtml"] gbdelim2 constant["ColorOverrideGBHtml"]  gbdelim3;
      ColorHtml["default"]  = ";" gbdelim1 constant["DefaultColorHtml"]  gbdelim2 constant["DefaultColorGBHtml"]   gbdelim3;
   } else {
      ColorHtml["yellow"]   = ";" constant["YellowHtml"];
      ColorHtml["orange"]   = ";" constant["OrangeHtml"];
      ColorHtml["red"]      = ";" constant["RedHtml"];           
      ColorHtml["blue"]     = ";" constant["BlueHtml"];           
      ColorHtml["override"] = ";" constant["ColorOverrideHtml"];
      ColorHtml["default"]  = ";" constant["DefaultColorHtml"];
   }

   #-----------------------
   # Read from config file 
   #-----------------------
   OneThousand = 1000 + 0; #User should not change in this version 
   yellow_temp = constant["YellowTemp"];
   orange_temp = constant["OrangeTemp"];
   red_temp    = constant["RedTemp"];
   blue_temp   = constant["BlueTemp"];
   bullet      = constant["BulletHtml"]

   #-------------------------------------------------------------
   # Process spinup and other commands before loading the page. 
   #-------------------------------------------------------------
   cmd = GETARG["cmd"];
   srand(); #@@@ very important, otherwise spinup always reads the same sector and therefore does not work!
   if(cmd == "spin") {
      spinindparm = GETARG["spinind"];
      if (spinindparm == "0")  #spin it up
         cmd = "spinup";
      else                     #spin it down
         cmd = "spindown";
   }

   #-------------------------------------------
   # Spinup / spindown logic courtesy of JoeL. 
   #-------------------------------------------
   if(cmd != "") {
      devparm  = GETARG["dev"];
      diskparm = GETARG["disk"];
      #p(cmd)

      if(cmd == "spindown") {
         if ( diskparm == "parity" ) {
           cmd="/root/mdcmd spindown 0 >/dev/null 2>&1"
           system(cmd);
         }
         if (substr(diskparm,1,4) == "disk" ) {
           cmd="/root/mdcmd spindown " substr(diskparm,5,length(diskparm)) " >/dev/null 2>&1"
           system(cmd);
         }
         cmd="/usr/sbin/hdparm -y /dev/" devparm " >/dev/null 2>&1"
         system(cmd);
         print "<p><b>Spindown disk " diskparm "</p><p> </p>"
      }
      else if (cmd == "spinup") {
         disk_blocks = GetRawDiskBlocks( "/dev/" devparm )
         disk_blocks = disk_blocks - 128
         #p(disk_blocks)
         skip_blocks = 1 + int( rand() * disk_blocks );
         if ( diskparm == "parity" ) {
           cmd="/root/mdcmd spinup 0 >/dev/null 2>&1"
           system(cmd);
         }
         if (substr(diskparm,1,4) == "disk" ) {
           cmd="/root/mdcmd spinup " substr(diskparm,5,length(diskparm)) " >/dev/null 2>&1"
           system(cmd);
         }
        
         cmd="dd if=/dev/" devparm " of=/dev/null count=1 bs=1k skip=" skip_blocks " >/dev/null 2>&1"
         system(cmd);
         print "<p><b>Spinup disk " diskparm "</p><p> </p>"
      }
      else if(cmd == "spindownall") {
         #GetDeviceArray();
         GetUnraidDeviceArray();
         for(i=0; i<deviceunraid["count"]; i++) {
            cmd="/root/mdcmd spindown " i " >/dev/null 2>&1"
            system(cmd);
            cmd="nohup /usr/sbin/hdparm -y /dev/" deviceunraid[i] " >/dev/null 2>&1 &"
            #perr("cmd-" i " = " cmd)
            system(cmd);
         }
         #system("sleep 5");
         print "<p><b>Spindown All unRAID Array Disks</p><p> </p>"
      }
      else if (cmd == "spinupall")
         spinup = "all";         #do it a little later, after we've loaded the drive array
      else if (cmd == "spinupsmart")
         spinup = "smart";       #do it a little later, after we've loaded the drive array
      else if (cmd == "smartbase")
         spinup = "smartbase";   #do it a little later, after we've loaded the drive array
      else if (cmd == "highlight") {
         highlightdev=devparm
         highlightcolor=GETARG["color"]
      }
      else
         print "<p><b>Unknown cmd '" cmd "'</b></p><p> </p>";
   }

   #---------------------------------------
   # Load the drivedb[] associative array. 
   #---------------------------------------

   #----------------------------------------------------------------------------------------------------
   # This program works by creating an array called drivedb[] and stuffing everything I know about each 
   # drive into it.  This creates a sandbox for configuring a tabular presentation of data however you 
   # want.
   #
   # The drivedb[] array contains a number of different types of elements: 
   #
   # drivedb[index, attribute] = value - The most common - this defines an attribute of an array.  
   #                    All attributes of a single drive are kept under the same index. 
   #                    example.  drivedb[0, "device"] = "sda";
   #
   # drivedb["total", attribute] = value - The total row acts like any other drive row.  Some 
   #                    values have totals, some don't.  awk makes any unassigned value = "", a very 
   #                    handly thing for this program. 
   #
   # drivedb[serial] = index - If you know the serial number of a disk, you can find its index in the 
   #                    array using this handy shortut 
   #
   # drivedb[md] = index - Similar for "md" numbers.  If you want the index of "md11", this will return 
   #                    its index for you. 
   #
   # drivedb[device] = index - Similar for device ids (e.g., "sda" or "hdb").  It does NOT include the 
   #                    "/dev/". 
   #
   # drivedb[index|"total", attribute "extra"] - used to add some (or override) "td style" settings  
   #                    for aspecific cell (works for numbered rows and "total" rows. 
   #
   # drivedb[index|"total", "rowextra"] - allows you to add some (or override) "td style" settings on 
   #                    EVERY cell on a row. 
   #
   # drivedb["count"] - Total number of rows in the array 
   #
   # drivedb["uncount"] - Total number of unRAID disks (including parity) in the drivedb[] array 
   #
   # The order of the drivedb rows IS important.  The first rows loaded are the array rows (parity - 
   # diskxx), in order.  After that is the non-array disks (cache, flash, other). 
   #----------------------------------------------------------------------------------------------------

   #--------------------------------
   # Create column order array (co) 
   #--------------------------------
   co["count"] = split(view[activeview], co); #column order array

   #--------------------------------------------
   # Load all the rows into the drive database 
   #------------------------------------------*/
   if (trace) perr("Calling LoadDriveDb " strftime("%s") - tracestart " secs")
   drivedb["uncount"] = LoadDriveDb();

   #----------------------------------------------------------------------
   # Although the config values are loaded at the top of the program, the 
   # SetDriveValue lines are not actually performed until this point. 
   #----------------------------------------------------------------------
   if (trace) perr("Calling ApplyConfigValues " strftime("%s") - tracestart " secs")
   ApplyConfigValues()

   #------------------------------------
   # Determine which drives are spun up.
   #------------------------------------
   if (trace) perr("Calling GetDiskSpinState " strftime("%s") - tracestart " secs")
   GetDiskSpinState();

   #---------------------------------------------------------------------
   # Spin up the arry either becuase user requested it, or because we're 
   # about to gather the smart data, and spinning up all the drives in 
   # advance will make it go quicker. 
   #---------------------------------------------------------------------
   if(spinup == "all") {
      if (trace) perr("Calling SpinUpAll " strftime("%s") - tracestart " secs")
      SpinUpAll()
   }

   #-------------------------------------------
   # Spin up all drives required to run SMART.
   #-------------------------------------------
   if((spinup == "smart") || (spinup == "smartbase")) {
      if (trace) perr("Calling SpinUpSmart " strftime("%s") - tracestart " secs")
      SpinUpSmart()
   }

   #--------------------------------
   # Collect baseline SMART reports
   #--------------------------------
   #if(spinup == "smartbase") {
   #   if (trace) perr("Calling CollectSmartHistory " strftime("%s") - tracestart " secs")
   #   CollectSmartHistory()
   #}

   #------------------------------
   # Get the used and free space. 
   #------------------------------
   if (trace) perr("Calling LoadDiskSpaceInfo " strftime("%s") - tracestart " secs")
   LoadDiskSpaceInfo(OneThousand);

   #-------------------------------------------------------
   # Set some other fields after all other values are set. 
   #-------------------------------------------------------
   if (trace) perr("Calling LoadOtherInfo " strftime("%s") - tracestart " secs")
   LoadOtherInfo();

   #--------------------------------------------------------
   # Based on active view options, gather performance data. 
   #--------------------------------------------------------
   if(view[activeview, "perfdata"] == "1") {
      if (trace) perr("Calling GetPerformanceData " strftime("%s") - tracestart " secs")
      GetPerformanceData(constant["NetworkHtml"], constant["NetworkHtml"]);
   }

   #----------------------------------------------------
   # Based on active view options, gather smartctl data 
   #----------------------------------------------------
   if(view[activeview, "smartdata"] > 0) {   # 1.4
      if (trace) perr("Calling GetSmartData " strftime("%s") - tracestart " secs")
      GetSmartData();
   }

   #-----------------------------------
   # Get drive temps and spinup status 
   #-----------------------------------
   if (trace) perr("Calling GetDiskTemps " strftime("%s") - tracestart " secs")
   GetDiskTemps(view[activeview, "smartdata"])

   #--------------------------------------------------------
   # Sort the drivedb.  If the total row is going to be 
   # displayed, only sort the array part.  Otherwise, sort
   # all the rows.
   #--------------------------------------------------------
   if (trace) perr("Calling CreateSortArray " strftime("%s") - tracestart " secs")
   if(view[activeview, "totalrow"] == "1")
      CreateSortArray(activesort, drivedb["uncount"]);
   else
      CreateSortArray(activesort, drivedb["count"]);

   #-----------------------------------------------------
   # Set some variables that drive the style of the GUI. 
   #-----------------------------------------------------
   if (trace) perr("Calling HTMLSetUp " strftime("%s") - tracestart " secs")
   HTMLSetUp();


   theHTML = "<fieldset style=\"margin-top:1px;\"><legend><strong>Server Disk Summary</strong></legend>"

   #-------------------------------
   # Create the HTML output page. 
   #-------------------------------

   #---------- Pre-Table Section ----------

   tl=""
   tr=""
   if(view[activeview, "plain"] == "1")
      tr = tr "<b>Select View:</b> "
   else
      tr = tr "<b><font face=\"Verdana\"><small>Select View:</b> "
   for(i=1; i<=view["count"]; i++) {
      srt=constant[view[i] "sort"];
      if(srt == "")
         srt = "num"
      if(view[i] == activeview)
         tr = tr "[" toupper(substr(view[i],1,1)) substr(view[i],2) "] "
      else
         tr = tr "<a href=\"" myMainLink("view=" view[i] amp "sort=" srt) "\">" toupper(substr(view[i],1,1)) substr(view[i],2) "</a> "
   }

   if(view[activeview, "plain"] == "1")
      tr = tr ""
   else
      tr = tr "</small></font>"

   if(view[activeview, "plain"] == "1")
      tl = tl "<b><big>" toupper(substr(activeview,1,1)) substr(activeview,2) " View</big></b>"
   else
      tl = tl "<nobr><b><font face=\"Verdana\" size=\"4\">" toupper(substr(activeview,1,1)) substr(activeview,2) " View</font></b>"

   tl = tl "  (<a href=\"" myMainLink() "\">Refresh</a>"

   #if(view[activeview, "smartdata"] == "1")
   #   tlextra = ", <a href=\"" myMainLink("cmd=spinupsmart") "\">RefreshAll</a>, <a href=\"" myMainLink("cmd=smartbase") "\">Baseline</a>)"
   #else
   #   tlextra = ")"
   if(view[activeview, "smartdata"] == "1")
      tlextra = ", <a href=\"" myMainLink("cmd=spinupsmart") "\">RefreshAll</a>)"
   else
      tlextra = ")"

   tm = "";

   theHTML = theHTML "<table border=\"0\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\">"
   theHTML = theHTML "	<tr>"
   theHTML = theHTML "		<td>" tl tlextra "</td>"
   theHTML = theHTML "		<td><p align=\"center\">" tm "</td>"
   theHTML = theHTML "		<td><p align=\"right\">" tr "</td>"
   theHTML = theHTML "	</tr>"
   theHTML = theHTML "</table>"

   theHTML = theHTML TableTop(co);

   #---------- Table Section ----------

   #-------------------------------------------------------------------------
   # Loop through the array rows - notice we're using the sortarray to force  
   # rows to load in the right order. 
   #-------------------------------------------------------------------------
   suppressedSoFar=0;
   for(i=0; i<drivedb["sortcount"]; i++) {
      if(drivedb[i, "suppress"] == 1) {
         suppressedSoFar++;
         continue;
      }
      if (trace) perr("Calling NewRow-" drivedb[i, "disk"] " " strftime("%s") - tracestart " secs")
      theHTML=theHTML NewRow(co, sortarray[i]);
   }

   if(view[activeview, "totalrow"] == "1") {
      #------------------------
      # Create the "Total" row 
      #------------------------
      if (trace) perr("Calling NewRow-total " strftime("%s") - tracestart " secs")
      theHTML=theHTML NewRow(co, "total");

      #----------------------------------
      # Loop through the non-array rows. 
      #----------------------------------
      for(i=drivedb["uncount"]; i<drivedb["count"]; i++) {
         if (trace) perr("Calling NewRow-" drivedb["disk"] " " strftime("%s") - tracestart " secs")
         theHTML=theHTML NewRow(co, i);
      }
   }

   #---------- Post-Table Section ----------

   theHTML = theHTML TableBot();

   gsub(amp, "\\&", theHTML);

   theHTML = theHTML "</fieldset>"

   if(constant["extrafs" activeview "1"] != "")
      vw=activeview;
   else
      vw=""

   for(i=1; ; i++) {  
      fsextra=constant["extrafs" vw i]
      if(fsextra == "")
         break;

      delete d;
      d[1] = substr(fsextra, 1, index(fsextra, "=")-1)
      d[2] = substr(fsextra, index(fsextra, "=")+1);
      #p("d[1]="d[1] ", d[2]="d[2])
      if(d[1] == "url") {
         # If desired, set iframes with used defined content at bottom of main page.

         if((height=constant["extrafs" vw i "height"]) == "") 
            height=500;
         if((scroll=constant["extrafs" vw i "scroll"]) == "") 
            scroll="no";

         main_page_user_content = "height=" height " frameborder=0 marginwidth=0 scrolling=\"" scroll "\" src=\"" d[2]
         #p(main_page_user_content)
         if ( main_page_user_content ) {
            gsub("%MyHost%",MyHost,main_page_user_content)
            gsub("%MyPort%",MyPort,main_page_user_content)
            theHTML = theHTML "<br><iframe width=\"100%\" " main_page_user_content "\">"
            #p(main_page_user_content)
            theHTML = theHTML "Sorry: your browser does not seem to support inline frames"
            theHTML = theHTML "</iframe>"
            theHTML = theHTML "<script>"
            theHTML = theHTML "setTimeout(\"self.scrollTo(0,0)\",1000);"
            theHTML = theHTML "</script>"
         }
      }
      else if(d[1] == "linkset") {
         theHTML = theHTML "<br><fieldset style=\"margin-top:1px;\"><legend><strong>Hyperlinks</strong></legend>"
         theHTML = theHTML GetHyperlinkTableHtml(d[2])
         theHTML = theHTML "</fieldset>"
      }
   }

   print theHTML
   if (trace) perr("Done!" drivedb["disk"])
}

#---------------------------------------------------------------------------
# This function creates an index array used for sorting the items in the 
# drivedb.  If the sort option is prefixed by a "-", it means do a reverse 
# sort.  Columns are sortable by clicking on the column heads. 
#---------------------------------------------------------------------------
function CreateSortArray(sortcol, sortcount, i, j)
{
   drivedb["sortcount"] = sortcount

   sortcols["count"] = split(sortcol, sortcols, "+")

   #p("Sortcol1=" sortcols[1] "/" sortcol)
   #p("Sortcol2=" sortcols[2])

   for(i=0; i<sortcount; i++) 
      sortarray[i] = i;

   #for(i=0; i<nl; i++)
   #   print "<p>sortarray[" i "] = " sortarray[i] "</p>"

   if(sortcols[1] != "") {
      if(sortcols[1] ~ "^-") {
         revsort=1
         sortcols[1] = substr(sortcols[1], 2)
         sortcol = substr(sortcol, 2)
         for(j=0; j<sortcount-1; j++)
            for(i=0; i<sortcount-j-1; i++) 
               if(( drivedb[ sortarray[i], sortcols[1] ]  <  drivedb[ sortarray[i+1], sortcols[1] ] )       || 
                  (( drivedb[ sortarray[i], sortcols[1] ] == drivedb[ sortarray[i+1], sortcols[1] ] ) &&
                   ( drivedb[ sortarray[i], sortcols[2] ] <  drivedb[ sortarray[i+1], sortcols[2] ] ))) {
                  k=sortarray[i]
                  sortarray[i] = sortarray[i+1]
                  sortarray[i+1] = k
               } 
      }
      else {
         revsort=0
         for(j=0; j<sortcount-1; j++)
            for(i=0; i<sortcount-j-1; i++) 
               if(( drivedb[ sortarray[i], sortcols[1] ]  >  drivedb[ sortarray[i+1], sortcols[1] ] )       || 
                  (( drivedb[ sortarray[i], sortcols[1] ] == drivedb[ sortarray[i+1], sortcols[1] ] ) &&
                   ( drivedb[ sortarray[i], sortcols[2] ] >  drivedb[ sortarray[i+1], sortcols[2] ] ))) {
                  k=sortarray[i]
                  sortarray[i] = sortarray[i+1]
                  sortarray[i+1] = k
               }
      }

      #-------------------------------------------------------------------
      # Determine which column we are sorting by (used to place indicator 
      # showing sort column).
      #-------------------------------------------------------------------
      for(i=1; i<= co["count"]; i++) { 
         seq = vtr[ co[i] ];
         if(sortcol == sc[seq]) {
            ch[seq, "sortind"] = constant[(revsort==1) ? "SortDescHtml" : "SortAscHtml"]
            #perr("sort on column " seq " " vt[seq] " " ch[seq, "sortind"])
            break;
         }
      }
   }

   #for(i=0; i<nl; i++)
   #   print "<p>sortarray[" i "] = " sortarray[i] "</p>"
}

#-------------------------------------------------
# Set some constants that drive the GUI display. 
#-----------------------------------------------*/
function HTMLSetUp()
{
   #-------------------
   # HTML setup stuff 
   #-------------------
   if(view[activeview, "plain"] == "0") {
      tdcom=     "font-size: 10.0pt; font-family: Verdana, sans-serif; text-align: center; color: black; font-style: normal; text-decoration: none; vertical-align: center; white-space: wrap; font-weight: 400; height: 15.0pt;" 
      tdborder=  "border-left: .5pt solid windowtext; border-right: .5pt solid windowtext; border-top: medium none; border-bottom: .5pt solid windowtext; padding-left: 4px; padding-right: 4px; padding-top: 1px"
      tdhcom=    "font-size: 10.0pt; font-weight: 700; font-family: Verdana, sans-serif; text-align: center; color: black; font-style: normal; text-decoration: none; vertical-align: center; white-space: nowrap height: 15.0pt;" 
      tdhborder= "border-left: .5pt solid windowtext; border-right: .5pt solid windowtext; border-top: .5pt solid windowtext; border-bottom: .5pt solid windowtext; padding-left: 1px; padding-right: 1px; padding-top: 1px"
   }
   else {
      tdcom="vertical-align: center;"     
      tdborder=""  
      tdhcom="text-align: center; vertical-align:center;"    
      tdhborder="" 
   }

   styleHeader =  "style='" tdhcom  tdhborder ";" HeaderColorHtml      #"'" 
                                      
   styleLinePre   = "style='" tdcom "text-align:"
   styleLinePost  = tdborder
}


#---------------------------------------------------------------------
# This function sets up the HTML table, including the column headings.
#---------------------------------------------------------------------
function TableTop(co, theHTML, item) {
   theHTML="<table border='0' cellpadding='0' cellspacing='0' style='border-collapse:collapse' width=\"100%\" word-wrap>"

   theHTML=theHTML "	<tr height='20' style='height:15.0pt'>"
   first="height='20'"

   #--------------------------------------------------------
   # Loop through the columns, picking up the heading text 
   #--------------------------------------------------------
   for(i=1; i <= co["count"]; i++) {

      #-------------------------------------------------------------------
      # Use the reverse token lookup to validate and identify the column 
      # index, otherwise output a message. 
      #-------------------------------------------------------------------
      seq = vtr[ co[i] ];
      if(seq == "")
         print "<p>Unknown column name " co[i] "</p>";
      else {

         #--------------------------------------------------------------------
         # Lookup the corresponding sort column.  If we're already sorted on 
         # the column, prefix with a "-" so a reverse sort will be done on a 
         # subsequent click. If the sort column has the special value of 
         # "!", it is not a sortable column. 
         #--------------------------------------------------------------------
         sortcol=sc[seq];
         if(sortcol == activesort)
            sortcol = "-" sortcol;

         #-----------------------------------------------------------------
         # With vanilla style, use the alignment of the column data on the 
         # column header as well.  (Others will use a centered column 
         # header). 
         #-----------------------------------------------------------------
         if(view[activeview, "plain"] == "1")
            vanillastyle = ";text-align=" ca[seq]
         else
            vanillastyle = ""
         #p("vanillastyle="  vanillastyle);

         if(sortcol == "!")
            theHTML=theHTML "<td " first styleHeader vanillastyle "'>" ch[seq] "</td>";
         else
            #-------------------------------------------------------------
            # Create a hyperlink back to reload THIS page passing the sort 
            # column via the querystring. 
            #-------------------------------------------------------------
            theHTML=theHTML "<td " first styleHeader vanillastyle "'><a href=\"" myMainLink("sort=" sortcol) "\">" ch[seq] "</a>" ch[seq, "sortind"] "</td>";
      }

      first="";
   }
  
  theHTML=theHTML "</tr>"

  return theHTML;
}

#--------------------------------------------------------------------------
# This function is used to add a new row to the HTML output table.  It is 
# called for ALL rows (array rows, total row, and non-array rows) 
#--------------------------------------------------------------------------
function NewRow(co, ix, newRow, j, seq, t) {
   first="height='20'";
   newRow="<tr height='20' style='height:15.0pt'>"

   #---------------------------
   # Loop through the columns 
   #---------------------------
   for(j=1; j <= co["count"]; j++) {

      #-------------------------------------------------------------------
      # Use the reverse token lookup to validate and identify the column 
      # index, otherwise output a message. 
      #-------------------------------------------------------------------
      seq = vtr[ co[j] ];
      #print "<p>" co[j] " seq is " seq ", align=" ca[seq] "</p>"
      if(seq == "") {
         print "<p>Unknown column name " co[j] "</p>"
      }
      else {
         #-------------------------------------------------------------------
         # A lot happening on this row.  Refer to docs for the drivedb. This 
         # will insert the column extras and the row extras if they 
         # exist.  Note that the row extras may override column extras.  
         # This line does NOT put in the column values, just the tokens.  
         #-------------------------------------------------------------------
         t =  ColorHtml["default"] ";"  drivedb[ix, co[j] "extra"] ";" drivedb[ix, "rowextra"] 
         #p(ix " Before: "t)
         if(view[activeview, "greenbar"] == "1")
            if((i-suppressedSoFar)%2 != 0) {
               gsub(gbdelim1 "[^" gbdelimbase "]*" gbdelim2, "", t) 
               gsub(gbdelim3, "", t)
               if(index(drivedb[ix, co[j]], gbdelimbase) > 0) {
                  #p("Before value[" ix "," j "] = " drivedb[ix, co[j]])  
                  gsub(gbdelim1 "[^" gbdelimbase "]*" gbdelim2, "", drivedb[ix, co[j]]) 
                  gsub(gbdelim3, "", drivedb[ix, co[j]])
                  #p("Before value[" ix "," j "] = " drivedb[ix, co[j]])  
               }
            }
            else {
               #gsub(gbdelim2 ".*" gbdelim3, "", t)
               gsub(gbdelim2 "[^" gbdelimbase "]*" gbdelim3, "", t) 
               gsub(gbdelim1, "", t);
               if(index(drivedb[ix, co[j]], gbdelimbase) > 0) {
                  #p("Before value[" ix "," j "] = " drivedb[ix, co[j]])  
                  gsub(gbdelim2 "[^" gbdelimbase "]*" gbdelim3, "", drivedb[ix, co[j]]) 
                  gsub(gbdelim1, "", drivedb[ix, co[j]])
                  #p("Before value[" ix "," j "] = " drivedb[ix, co[j]])  
               }
            }
         #p(ix " After:" t)

         #newRow=newRow "<td " first "%lpre" ca[seq] ";%lpost;" g drivedb[ix, co[j] "extra"] ";" drivedb[ix, "rowextra"] "'>%" co[j]"</td>";
         newRow=newRow "<td " first "%lpre" ca[seq] ";%lpost;" t "'>%" co[j]"</td>";
         #print "<p>" newRow "</p>"
      }
      first="";
   }
   newRow=newRow "</tr>"

   #-----------------------------------------------------------------------
   # Columns behave differently on the total line vs a disk line.  On the 
   # total line, the pseudocolumn names get the word "total" appended. 
   #-----------------------------------------------------------------------
   j=""
   if(ix == "total")
      j = "total"

   #----------------------------------------------------------------------
   # Process the pseudocolumns first.  They may refer to normal columns. 
   #----------------------------------------------------------------------
   for(item=1; item <= vt["count"]; item++) {
      if(vt[item] ~ "^_")
         gsub("%" vt[item], pseudocol[vt[item] j], newRow);
   }

   #----------------------------------
   # Process the data columns second. 
   #----------------------------------
   for(item=1; item <= vt["count"]; item++) {
      if(vt[item] !~ "^_")
         gsub("%" vt[item], drivedb[ix, vt[item]], newRow);
   }

   #-----------------------------
   # Handle special conditionals
   #-----------------------------
   gsub("<!--#IF BLANK\\([^\\)][^\\)]*\\)-->[^!]*!--#FI-->", "<!--GONE-->", newRow);
   gsub("<!--#IF NOBLANK\\(\\)-->[^!]*!--#FI-->", "<!--GONE-->", newRow);

   #-------------------------------------------------------------------------
   # Do these last because they'd make the strings much longer for the other 
   # gsubs() 
   #-------------------------------------------------------------------------
   gsub("%lpre", styleLinePre, newRow);
   gsub("%lpost", styleLinePost, newRow);

   return newRow
}


#-----------------------------------------------------------------------
# This function closes the table.  Handly seems worth its own function. 
#-----------------------------------------------------------------------
function TableBot(theHTML) {
   theHTML=theHTML "</table>"
   return theHTML
}

#-----------------------------------------------------------------------
# Load the configuration file.  See myMain.conf for more info about the 
# contents of this file. 
#-----------------------------------------------------------------------
function LoadConfigFile(fn, li, ix, l)
{
   RS="\n"
   if(vt["count"] == "") {
      vt["count"] = 0
      view["count"] = 0
      configvalue["count"]= 0
   }
   while (( getline li < fn ) > 0 ) {
      if(substr(li,1,1) == "#")
         continue;

      if(length(li) < 10)
         continue;

      gsub("\\&", amp, li);

      ParseConfigFunction(li)

      #LoadToken(token, sortcolumn, colalign, colheader)
      if(funcname == "loadtoken") {
         #Check to see if this is overwriting an existing token
         if((ix=vtr[arg[0]]) == "")
            ix = vtr[arg[0]] = ++vt["count"];   #load reverse token lookup array also
         else
            perr("INFO:  Dup token " arg[0])

         vt[ix] = arg[0];
         sc[ix] = arg[1];
         ca[ix] = arg[2];
         ch[ix] = arg[3];
      }

      #LoadPseudoCol(pseudocol, value)

      else if (funcname == "loadpseudocol") {
         l = arg[1];
         gsub("MYMAINDD",   myMainLink("") amp "dev=%dev" amp "disk=%disk", l); 
         gsub("MYMAIN",     myMainLink(""), l);
         gsub("UTILITYDD",  "utility?dev=%dev" amp "disk=%disk", l);
         gsub("UTILITY",    "utility?j=x",  l); 
         pseudocol[arg[0]] = l
         #p("pseudocol[" arg[0] "] = '" l "'")
      }

      #Although dups are possible here, it won't matter because the latter one will overwrite the newer one as they are applied

      #SetDriveValue(index, attribute, value) (index can be a serial number, md# (e.g., md1), or device (i.e., sda)
      else if (funcname == "setdrivevalue") {
         configvalue[configvalue["count"], 0]   = arg[0];  
         configvalue[configvalue["count"], 1]   = arg[1];  
         configvalue[configvalue["count"]++, 2] = arg[2];  
      }

      #SetView(name, options, collist)
      # option                -------1 - total row
      # option                ------1- - gather performance data
      # option                -----1-- - gather smart data
      # option                ----1--- - gather temperature data
      # option                ---1----
      # option                --1-----
      # option                -1------ - Green bar
      # option                1------- - Drop grid formatting / special fonts
      else if (funcname == "setview") {
         if(view[arg[0]] == "")
            view[++view["count"]]  = arg[0];

         view[arg[0]]              = arg[2];
         view[arg[0], "totalrow"]  = substr(arg[1], 8, 1);
         view[arg[0], "perfdata"]  = substr(arg[1], 7, 1);
         view[arg[0], "smartdata"] = substr(arg[1], 6, 1);
         view[arg[0], "tempdata"]  = substr(arg[1], 5, 1);
         view[arg[0], "greenbar"]  = substr(arg[1], 2, 1);
         view[arg[0], "plain"]     = substr(arg[1], 1, 1);
      }

      else if(funcname == "setconstant")
         constant[arg[0]]              = arg[1];

      #p("'" li "'")
      #p("'" funcname "'")
      #for(i=0; i < arg["count"]; i++) {
      #   p("arg[" i "] = '" arg[i] "'")
      #}
   }
}

#--------------------------------------------------------------------------
# Apply values from the config file (stored in the "configvalue" array) to 
# the drivedb array. 
#--------------------------------------------------------------------------
function ApplyConfigValues() {
   for(i=0; i<configvalue["count"]; i++) {
      j = drivedb[configvalue[i, 0]]
      if(j == "")
         perr("WARNING: SetDriveValue(" configvalue[i, 0] ", " configvalue[i, 1] ", " configvalue[i, 2] ") - No drive found"); 
      else 
         drivedb[j, configvalue[i, 1]] = configvalue[i, 2];
   }
}

#---------------------------------------------------------------------------
# The function parses a configuration function into a function and an array 
# of arguments. 
#---------------------------------------------------------------------------
function ParseConfigFunction(li, i, regex)
{
  gsub("^[ \t]+", "", li);               # strip leading whitespace
  i = index(li, "(")                     # find open paren
  funcname = tolower(substr(li, 1, i-1)) # function name
  li=substr(li,i+1, length(li) - i)      # li now is the arguments section '(' is removed, but ')' is in place
  delete arg

  #-------------------------------------------------------------------
  # Tricky regular expression, handles simple args | quoted args with 
  # embedded \" strings. Note this skips leading whitespace. 
  #-------------------------------------------------------------------
  regex = "([^\\,\\) \\t]+|\\\"([^\\\"]|\\\\.)+\\\")[ \t]*[\\,\\)]"

  for(i=0; ; i++) {

     match(li, regex) #peel off next arg

     if(RSTART == 0)
        break;

     # retrieve the arg, strip off of the ',' or ')' off the end, then strip trailing spaces
     arg[i] = gensub("[ \\t]+$", "", 1, substr(li,RSTART,RLENGTH-1)) 

     # special handling of quoted strings
     if(substr(arg[i],1,1) == "\"") {
        arg[i] = substr(arg[i],2,length(arg[i])-2); #strip the quotes
        gsub("\\\\\\\\", "^#;@", arg[i]);   # change double backslash to obscure text
        gsub("\\\\", "", arg[i]);           # remove other backslashes (leaves the escaped character in place)
        gsub("\\^\\#\\;\\@", "\\", arg[i])  # change the obscure text to a single backslash
     }

     if(substr(li, RSTART+RLENGTH-1, 1) == ")")
        break; #end of function

     li = substr(li,RSTART+RLENGTH)
  }
  arg["count"] = i+1;
}

#-------------------------------------------
# Function to help create myMain hyperlink. 
#-------------------------------------------
function myMainLink(extrastuff, sep, link)
{
   sep="?"
   link=MENU[2]
   if(index(extrastuff, "sort=") == 0) {
      link=link sep "sort=" activesort 
      sep=amp
   }
   if(index(extrastuff, "view=") == 0) {
      link=link sep "view=" activeview 
      sep=amp
   }
   if(extrastuff != "")
      link = link sep extrastuff
   #p("link=" link)
   return(link)
}

function GetHyperlinkTableHtml(linkset, i, j, hltable)
{
   hltable=""
   hltable=hltable
   hltable=hltable "<table border=\"0\" width=\"100%\">"

   for(i=0; i<constant[linkset "rows"]+0; i++) {
      hltable=hltable "	<tr>"
      for(j=0; j<5; j++) {
         hltable=hltable "<td width=20%><a href=\"" constant[linkset "link-" i "-" j] "\" target=\"_blank\">" constant[linkset "name-" i "-" j] "</a></td>"
      }
      hltable=hltable "	</tr>"
   }
   hltable=hltable "</table>"

   return(hltable);
}

