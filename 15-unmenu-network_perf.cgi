#ADD_ON_MENU Network Performance
#ADD_ON_URL network_performance
#ADD_ON_VERSION .1 - Proof of concept version Joe L.
#ADD_ON_VERSION 1 - improved formatting by zoggy
#UNMENU_RELEASE $Revision$ $Date$

# refresh interval
refresh=2

# measurement type.  Can be avg, sum, or max
type=avg

# copy of style sheet definitions from bwm-ng.css
echo "<style type=\"text/css\">
body {
    font: 12pt Arial, Helvetica, sans-serif;
    text-decoration: none;
}
.bwm-ng-header {
    margin: 10px;
    font: bold 12px Arial, Helvetica, Sans-serif;
    font-weight: bold;
}
.bwm-ng-output {
    background-color: #fff;
    margin: 10px 5px 15px;
    text-align: right;
    border-spacing: 0;
    border: #cdcdcd 1px solid;
    border-width: 1px 0 0 1px;
}
.bwm-ng-output td {
    border: #cdcdcd 1px solid;
    border-width: 0 1px 1px 0;
    padding: 4px;
    vertical-align: top;
}
.bwm-ng-output tr:hover {
    background-color: #f5f5f5;
}
.bwm-ng-head {
    font: bold 14px Arial, Helvetica, Sans-serif;
    border-collapse: collapse;
    padding: 4px;
    background-color: #fbfbfb;
    background-image: -moz-linear-gradient(top, white, #efefef);
    background-image: -ms-linear-gradient(top, white, #efefef);
    background-image: -webkit-gradient(linear, 0 0, 0 100%, from(white), to(#efefef));
    background-image: -webkit-linear-gradient(top, white, #efefef);
    background-image: -o-linear-gradient(top, white, #efefef);
    background-image: linear-gradient(to bottom, white, #efefef);
    filter: progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffffff', endColorstr='#efefef', GradientType=0);
    background-repeat: repeat-x;
    -webkit-box-shadow: inset 0 1px 0 white;
    -moz-box-shadow: inset 0 1px 0 #ffffff;
    box-shadow: inset 0 1px 0 white;
    color: brown;
    text-align: center;
}
.bwm-ng-name {
    width: 75px;
    font-weight: bold;
    text-align: right;
}
.bwm-ng-in,
.bwm-ng-out {
    width: 125px;
}
.bwm-ng-output tr:nth-last-child(2) {
    font-weight: bold;
    color: darkblue;
}
.bwm-ng-total {
    width: 150px;
    font-weight: bold;
}
.bwm-ng-errors {
    color: #ff0000;
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

