#ADD_ON_MENU Network Performance
#ADD_ON_URL network_performance
#ADD_ON_VERSION .1 - Proof of concept version Joe L.
#UNMENU_RELEASE $Revision$ $Date$

# refresh interval
refresh=1

# measurement type.  Can be avg, sum, or max
type=avg

# copy of style sheet definitions from bwm-ng.css
echo "<style type=\"text/css\">
BODY {
    font:      10pt Arial, Helvetica, sans-serif;
    text-decoration: none;
}
.bwm-ng-output {
	padding: 3px 10px 0.5ex 10px;
	margin: 10px;
	width: 55ex;
	border-width: 1px;
	border-style: solid;
}
.bwm-ng-header {
	margin: 10px;
	font: 12pt Arial, Helvetica, sans-serif;
	font-weight: bold;
}
.bwm-ng-head {
	font-weight: bold;
        color: brown;
}
.bwm-ng-name {
    margin-left: 10px;
	width: 10ex;
    font-weight: bold;
}
.bwm-ng-in {
	width: 10ex;
}
.bwm-ng-out {
    width: 10ex;
}
.bwm-ng-total {
	width: 10ex;
    font-weight: bold;
}
.bwm-ng-errors {
    color: #FF0000;
}
.bwm-ng-dummy {
}
</style>"

bwm=`which bwm-ng`
if [ "$bwm" = "" ]
then
    echo "<hr><b><font size=+2 color=red>Sorry: required bwm-ng package does not appear to be installed.</font><br>"
    echo "You may use the \"Package Manager\" in unMENU to install bwm-ng."
    exit
fi

echo "<b>From: bwm-ng -o html -T $type -R $refresh -c 1 -H </b><br><hr>"
bwm-ng -o html -T $type -R $refresh -c 1 -H | \
    sed -e "s/Interface/Device/" -e "s/Rx/Read/" -e "s/Tx/Write/"
