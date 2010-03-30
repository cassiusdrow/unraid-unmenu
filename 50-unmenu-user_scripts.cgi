#ADD_ON_MENU User Scripts
#ADD_ON_URL user_scripts
#ADD_ON_VERSION .1 - Proof of concept version
#ADD_ON_VERSION .2 - Added unmenu_local.conf file
#ADD_ON_VERSION .3 - Fixed to allow single quotes in button labels
#ADD_ON_VERSION .4 - Added conditional tests to allow for dynamic button labels.
#UNMENU_RELEASE $Revision$ $Date$

function ReloadPage() {
    echo "<script language=\"JavaScript\">"
    echo "<!--"
    echo "var sURL = unescape(window.location.pathname);"
    echo "var p = sURL.indexOf('?');"
    echo "sURL = sURL.substring(p);"
    echo ""
    echo "setTimeout( \"refresh()\", $1*1000 );"
    echo ""
    echo "function refresh()"
    echo "{"
    echo "    window.location.href = sURL;"
    echo "}"
    echo "//-->"
    echo "</script>"
    echo ""
    echo "<script language=\"JavaScript1.1\">"
    echo "<!--"
    echo " function refresh()"
    echo "{"
    echo "    window.location.replace( sURL );"
    echo "}"
    echo "//-->"
    echo "</script>"
}

if [ "$ScriptDirectory" = "" ]
then
      ScriptDirectory="." 
fi
if [ "$ConfigFile" = "" ]
then
      ConfigFile="unmenu.conf"
fi

# Local config file variables will never be overwritten by a distributd file.
# It is here where local changes should be made without worry about them being
# lost when a new unmenu.conf file is distributed.
if [ "$LocalConfigFile" = "" ]
then
      LocalConfigFile="unmenu_local.conf"
fi

# user scripts are normally in the $ScriptDirectory, but this directory can be
# overridden by a value in the ConfigFile.
UserScriptDir=`grep "^UserScriptDirectory" "$ScriptDirectory/$ConfigFile" 2>/dev/null | sed "s/=/ /" | cut -d" " -f2-`
if [ "$UserScriptDir" = "" ]
then
    UserScriptDir="$ScriptDirectory"
fi

LocUserScriptDir=`grep "^UserScriptDirectory" "$ScriptDirectory/$LocalConfigFile" 2>/dev/null | sed "s/=/ /" | cut -d" " -f2-`
if [ "$LocUserScriptDir" != "" ]
then
    UserScriptDir=$LocUserScriptDir
fi

#echo "Importing user-scripts from ${UserScriptDir}/" >&2
c=0
scripts=`ls "$UserScriptDir"/[0-9]*unmenu_user_script* 2>/dev/null`
for a in $scripts
do
    [ ! -x "$a" ] && continue;
    let c=c+1
    script[$c]="$a"
    label[$c]=`grep "^#define USER_SCRIPT_LABEL" "$a" | cut -d" " -f3-`
    descr[$c]=`grep "^#define USER_SCRIPT_DESCR" "$a" | cut -d" " -f3-`
    conditional_test[$c]=`grep "^#define USER_SCRIPT_TEST" "$a" | cut -d" " -f3-`
    reload_page[$c]=`grep "^#define USER_SCRIPT_RELOAD" "$a" | cut -d" " -f3-`
    #echo "imported ${label[$c]} from ${script[$c]} ${descr[$c]}<br>"
done

# Now for some HTML, draw the buttons
echo "<hr><form method=GET><table>"
i=1
while test $i -le $c
do
    if [ "${conditional_test[$i]}" != "" ]
    then
       new_label=`sh -c "${conditional_test[$i]}" 2>&1`
    #   echo "${label[$i]} = x${new_label}x" "<br>"
       label[$i]="$new_label"
    fi
    if [ "${label[$i]}" != "" -a "${label[$i]}" != " " -a "${descr[$i]}" != "" ]
    then
        echo "<tr><td><input type=submit value=\"${label[$i]}\" name=\"command\"></td><td>${descr[$i]}</td></tr>"
    fi
    let i=i+1
done
echo "</table></form><hr>"

# now, determine if the user pressed a button submitting a form
# this simple parse of $3 looks for only one parameter.
# It will be the label on the button pushed.
cgi_params=${3#*\?}
command=${3#*\=}
command=`echo "$command" | tr "+" " " | sed "s/%27/'/g"|sed "s/%2F/\//g"`

if [ "$command" != "" ]
then
    i=1
    while test $i -le $c
    do
#    echo "matching x${command}x against y${label[$i]}y <br>"
        if [ "$command" = "${label[$i]}" ]
        then
            # here we execute the script and capture its output to be sent to the browser
            ${script[$i]} 2>&1
            if [ "${reload_page[$i]}" != "" ]
            then
               ReloadPage ${reload_page[$i]}
            fi
            break;
        fi
        let i=i+1
    done
fi

