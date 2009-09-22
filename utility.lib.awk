#ADD_ON_VERSION 1.0 - contributed by bjp999

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

