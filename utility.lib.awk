#ADD_ON_VERSION 1.0 - contributed by bjp999
#UNMENU_RELEASE $Revision$ $Date$

#---------------------------------------------------------------------------
# Similar to same named function in unmenu.awk.  Handles numbers that start
# out in kilobytes.
#---------------------------------------------------------------------------
function human_readable_number( num, dpk, dpm, dpg, dpt, thousand, t, suffix, dec_places, ret_val ) {
    if(thousand == "")
       thousand = 1000;
    else
       thousand = thousand+0; #coerce to number

    suffix="K"
    dec_paces = dpk;
    if ( num >= thousand ) {
        num = num / thousand
        suffix="M"
        dec_places = dpm;
    }
    if ( num >= thousand-50 ) {
        num = (num+2) / thousand
        suffix="G"
        dec_places = dpg;
    }
    if ( num >= thousand-50 ) {
        num = (num+2) / thousand
        suffix="T"
        dec_places = dpt;
    }

    if(dec_places == 0)
       ret_val = sprintf( "%d", num)
    else {
       ret_val = sprintf( "%." dec_places "f", num)
       while(1==1) {
          t=substr(ret_val, length(ret_val));
          if((t==".") || (t=="0"))
             ret_val=substr(ret_val, 1, length(ret_val)-1)
          if(t != "0")
             break;
       }
    }
    return(ret_val suffix)
}

#-----------------------------------------------------------------------
# Similar to function above, but this one handles numbers that begin in
# single units.
#-----------------------------------------------------------------------
function human_readable_number2( num, dpk, dpm, dpg, dpt, thousand, t, suffix, dec_places, ret_val ) {
   if(thousand == "")
      thousand = 1000;
   else
      thousand = thousand+0; #coerce to number

    suffix=""
    dec_places=0
    if ( num >= thousand ) {
        num = num / thousand
        suffix="K"
        dec_places = dpk;
    }
    if ( num >= thousand ) {
        num = num / thousand
        suffix="M"
        dec_places = dpm;
    }
    if ( num >= thousand ) {
        num = num / thousand
        suffix="G"
        dec_places = dpg;
    }
    if ( num >= thousand ) {
        num = num / thousand
        suffix="T"
        dec_places = dpt;
    }

    if(dec_places == 0)
       ret_val = sprintf( "%d", num)
    else {
       ret_val = sprintf( "%." dec_places "f", num)
       while(1==1) {
          t=substr(ret_val, length(ret_val));
          if((t==".") || (t=="0"))
             ret_val=substr(ret_val, 1, length(ret_val)-1)
          if(t != "0")
             break;
       }
    }
    return(ret_val suffix)
}


#------------------------------------------------------------------
# Utility function to scale bytes/sec numbers into suitable units.
#------------------------------------------------------------------
function HumanReadablePerSec(num)
{
    if(num > 1000000)
       return(sprintf("%.1f", num/1000000) " MB/s")
    else if(num > 1000)
       return(sprintf("%d", num/1000) " KB/s")
    else
       return(sprintf("%d", num) " B/s")
}

#-------------------------------------------------
# Utility function to add commas to long numbers.
#-------------------------------------------------
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


#--------------------------------------------------------------------------------
# Utility function to convert a mm/dd/yy or mm/dd/yyyy to a raw date (yyyymmdd).
#--------------------------------------------------------------------------------
function DateToRawDate(indate, i, j, s, a)
{
   i = index(indate, s="/");
   if(i<1) {
      i = index(indate, s="-");
      if(i<1)
         return("-1");
   }
   if(split(indate, a, s) != 3)
      return(-1);

   if((a[1] < 1) || (a[1] > 12))
      return(-1);

   if((a[2] < 1) || (a[1] > 31))
      return(-1);

   if((a[3] >= 90) && (a[3] <100))
      a[3] = 1900 + a[3];
   else if(a[3] < 100)
      a[3] = 2000 + a[3];

   if((a[3] < 1990) || (a[3] > 2089))
      return(-1);

   return a[3] * 10000 + a[1] * 100 + a[2];
}


#-------------------------------------------
# Utility function to perform debug prints.
#-------------------------------------------
function p(printme)
{
   gsub("<", "\\&lt;", printme);
   gsub(">", "\\&gt;", printme);
   print "<p>"printme"</p>"
   #print "<p>"printme"</p>" | "cat 1>&2"
}

#----------------------------------------------------
# Utility function to perform debug prints to stderr.
#----------------------------------------------------
function perr(printme)
{
   print printme | "cat 1>&2"
}

#---------------------------------------------
# Utility function read HTML file into memory
#---------------------------------------------
function htmlLoadFile(fn, oa, ix, li, ch, i)
{
   #-----------------------------------------------------------------------
   # Lines should be formatted as <!--xx-->      {html...}
   #    where the xx is either ...
   #       0 - Skip
   #       1 - Include Once
   #       letter - Optional or repeatable group
   #
   # The output array (oa), will look like this ...
   #    oa[i, "type"] either 0, letter, or @
   #    oa[i]         text
   #    oa["count"]   number of items (first index) in oa
   #    oa[i, j]      Only for repeatable groups, j=repeatable group count
   #                  (this is populated in the htmlExpandGroup() function
   #    oa[repeatGroup, "count"] number of time repeat group is repeated
   #-----------------------------------------------------------------------
   if(ix+0==0)
      ix=0;

   while (( getline li < fn ) > 0 ) {
      lastch=ch;
      if(substr(li,1,4) == "<!--") {
         ch = substr(li, 5, 1)
         i = index(li, "-->")
         li = substr(li, i+3)
         if(ch == "0")
            ;
         else {
            if((lastch != "") && (lastch != ch))
               oa[lastch, "end"] = ix-1;
            oa[ch, "count"] = 0;
            oa[ix, "type"] = ch;
            oa[ix++] = li;
            #perr("load->" ix-1 " " oa[ix-1, "type"] " " li)
         }
      }
   }
   oa["count"] = ix;

   #for(i=0; i<oa["count"]; i++) {
   #   perr(i " " oa[i, "type"] " --> " oa[i]);
   #}
}

#-------------------------------------------------------------
# Utility function to process a repeatable group in HTML file
#-------------------------------------------------------------
function htmlExpandGroup(oa, groupId, inx, vv, i, found, ix, j, li) {
   found=0;
   for(i=0; i < oa["count"]; i++) {
      if(oa[i, "type"] == groupId) {
         if(found == 0) {
            ix = oa[groupId, "count"] + 0
            found = 1;
         }
         li = oa[i];
         gsub("\\$ix\\$", inx, li); # freebee
         for(j=0; vv[j, "from"] != ""; j++) {
            #perr("from=" vv[j,"from"])
            #perr("to=" vv[j,"to"])
            #perr("preline =" li)
            #perr("from=" vv[j, "from"] "    to=" vv[j, "to"]);
            #perr("before=" li);
            gsub("\\$" vv[j, "from"] "\\$", vv[j, "to"], li);
            #perr("after=" li);
            #perr("postline=" li)
         }
         oa[i, ix++] = li;
         #perr(li);
      }
      else
         if(found == 1) {
            oa[groupId, "count"] = ix;
            break;
         }
   }
}

#-------------------------------------------------------------
# Utility function to process a repeatable group in HTML file
#-------------------------------------------------------------
function htmlSerialize(oa, includeAction, vv, i, j, theHTML) {
   theHTML = "";
   loggit=0
   for(i=0; i < oa["count"]; i++) {
      if(oa[i, "type"] == "1") {
         theHTML = theHTML oa[i];
         #perr(i);
      }
      else if(oa[i, "type"] == "@") {
         if(includeAction > 0) {
            theHTML = theHTML oa[i];
            #perr(i);
         }
      }
      else {
         for(j=0; j<oa[oa[i, "type"], "count"]; j++)
            for(i2=i; i2<= oa[oa[i, "type"], "end"]; i2++) {
               theHTML = theHTML oa[i2, j];
               #perr(i2 " " j);
            }
         i = oa[oa[i, "type"], "end"];

         #perr( i "  " oa[i, "type"] " " oa[oa[i, "type"], "end"]);
         #perr("post i=" i);
         #if(loggit++ > 20)
         #   break;
      }
   }
   for(i=0; vv[i, "from"] != ""; i++)
      gsub("\\$" vv[i, "from"] "\\$", vv[i, "to"], theHTML);

   return theHTML;
}
function ltrim(s)
{
  sub("^[ \t]+", "", s);               # strip leading whitespace
  return s;
}

function rtrim(s)
{
  sub("[ \t]+$", "", s);               # strip trailing whitespace
  return s;
}

function trim(s)
{
  sub("^[ \t]+", "", s);               # strip leading whitespace
  sub("[ \t]+$", "", s);               # strip trailing whitespace
  return s;
}

function ceiling(x)
{
   return (x == int(x)) ? x : int(x)+1
}

function join(array, sep, result, i)
{
   result = array[1]

   for (i=2; array[i] != ""; i++)
      result = result sep array[i]

   return result
}

function lastchars(str,len)
{
   return substr(str, length(str) - len + 1 );
}

function HtmlRefresh(url)
{
   return "<HEAD> <meta HTTP-EQUIV=\"REFRESH\" content=\"0; url=" url "\"> </HEAD>"
}

