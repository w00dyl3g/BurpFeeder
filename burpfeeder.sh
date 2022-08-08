#!/bin/bash

############################################################
### VARS
# color
Color_Off='\033[0m'       # Text Reset
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
#param
SCRIPT=$0
URLS_FILE=$1
BURP_PROXY="http://127.0.0.1:8080"
BURP_PROXY_IP="127.0.0.1"
BURP_PROXY_PORT="8080"
BURP_PROXY_TYPE="http"
JUICY_EXT="asp\|\.aspx\|\.php\|\.php3\|\.php4\|\.php5\|\.txt\|\.shtm\|\.shtml\|\.phtm\|\.phtml\|\.jhtml\|\.pl\|\.jsp\|\.cfm\|\.cfml\|\.py\|\.rb\|\.cfg\|\.zip\|\.pdf\|\.gz\|\.tar\|\.tar\.gz\|\.tgz\|\.doc\|\.docx\|\.xls\|\.xlsx\|\.conf"


##############################################################
### FUNCTIONS

function banner {
    echo " _                       __               _           "
    echo "| |__  _   _ _ __ _ __  / _| ___  ___  __| | ___ _ __ "
    echo "| '_ \| | | | '__| '_ \| |_ / _ \/ _ \/ _\` |/ _ \ '__|"
    echo "| |_) | |_| | |  | |_) |  _|  __/  __/ (_| |  __/ |   "
    echo "|_.__/ \__,_|_|  | .__/|_|  \___|\___|\__,_|\___|_|  "
    echo "            ──▒▒▒▒▒────▄████▄─────"
    echo "            ─▒─▄▒─▄▒──███▄█▀──────"
    echo "            ─▒▒▒▒▒▒▒─▐████──█──█──"
    echo "            ─▒▒▒▒▒▒▒──█████▄──────"
    echo "            ─▒─▒─▒─▒───▀████▀─────"
    echo "                   v0.1"
    echo "               by w00dyl3g"
    echo ""
}

function echo_color {
    echo -e "$1$2$Color_Off"
}

function arg_parser {
    #CHECK ARGS
    echo_color $Yellow "[INFO] - Parsing arguments"
    if [ $# -ne 1 ]
    then
        echo_color $Red "[ERROR] - Missing arguments"
        echo_color $White "[USAGE] - ./burpfeeder.sh urls_file.txt"
        exit 1
    elif [ $1 = "-h" ] || [ $1 = "--help" ] || [ $1 = "help" ]
    then
        echo_color $White "[USAGE] - ./burpfeeder.sh urls_file.txt"
        exit 2
    fi
    #CHECK URLS FILE
    if [ -f $URLS_FILE ]
    then
        echo_color $Green "[SUCCESS] - File Exists: $URLS_FILE"
    else
        echo_color $Red "[ERROR] - File NOT Exists: $URLS_FILE"
        exit 3
    fi

}

function init {
    echo_color $Yellow "[INFO] - Cleaning old reports"
    rm -rf burpfeeder.old
    mv burpfeeder burpfeeder.old
    mkdir -p burpfeeder/eyewitness
    mkdir -p burpfeeder/gobuster
    echo_color $Green "[SUCCESS] - Initialization Completed"
}

function identify {
    #TECH DETECT
    echo_color $Yellow "[INFO] - Detecting Technologies used"
    $(which httpx) -http-proxy $BURP_PROXY -l $URLS_FILE -sc -td -title -server -probe -t 1 -output burpfeeder/httpx.log 1>/dev/null 2>/dev/null
    echo_color $Green "[SUCCESS] - Detection Completed:"
    echo_color $Cyan "\t$(pwd)/burpfeeder/httpx.log"
    awk '$0="\t\t"$0' burpfeeder/httpx.log
}

function spidering {
    #SPIDERING
    echo_color $Yellow "[INFO] - Start spidering websites"
    $(which gospider) -p $BURP_PROXY -S $URLS_FILE --sitemap --robots --js -t 1 -a --output burpfeeder/gospider 1>/dev/null 2>/dev/null
    for file in $(ls -1 burpfeeder/gospider)
    do
        #CLEANING RESULTS
        mv burpfeeder/gospider/$file{,.tmp}
        cat burpfeeder/gospider/$file.tmp | rev | cut -d" " -f1 | rev | sort -u | grep http > burpfeeder/gospider/$file
        rm burpfeeder/gospider/$file.tmp
        #FEEDING BURP
        for url in $(cat burpfeeder/gospider/$file):
        do
            $(which curl) -x $BURP_PROXY $url 1>/dev/null 2>/dev/null
            #sleep 0.15 #avoid waf with throttling
        done
        #INTERESTING FILES
        cat burpfeeder/gospider/$file | cut -d"?" -f1 | grep $JUICY_EXT > burpfeeder/gospider/$file.juicy
        #echo_color $Yellow "[INFO] - Interesting Files:"
        #for url in $(cat burpfeeder/gospider/$file.juicy):
        #do
        #    echo_color $White "\t$url"
        #done
    done
    echo_color $Green "[SUCCESS] - Spidering Completed"
    echo_color $Yellow "[INFO] - Juicy files found:"
    for file in $(ls -1 burpfeeder/gospider/*.juicy)
    do
        echo_color $Cyan "\t$(pwd)/$file"
        awk '$0="\t\t"$0' $file
    done 

}

function recording {
    # TODO: Check if Eyewitness is installed
    echo_color $Yellow "[INFO] - Start recording juicy pages"
    for file in $(ls -1 burpfeeder/gospider/*.juicy)
    do
        output_file="$(echo $file|rev|cut -d'/' -f'1'|rev|cut -d'.' -f'1')"
        #echo $file $output_file
        echo n | /opt/tools/EyeWitness-20220803.1/Python/EyeWitness.py -f $file -d burpfeeder/eyewitness/$output_file --proxy-ip $BURP_PROXY_IP --proxy-port $BURP_PROXY_PORT --proxy-type $BURP_PROXY_TYPE 1>/dev/null 2>/dev/null
    done
    echo_color $Green "[SUCCESS] - Recording Completed"
    echo_color $Yellow "[INFO] - Screenshot files here:"
    for file in $(ls -1 burpfeeder/eyewitness/*/report.html)
    do
        echo_color $Cyan "\t$(pwd)/$file"
    done
}

function wafwoof {
    echo_color $Yellow "[INFO] - Detecting WAF used"
    urls="$(cat $URLS_FILE| tr '\n' ' ')"
    wafw00f -a -p $BURP_PROXY -o burpfeeder/waf.log $urls 1>/dev/null 2>/dev/null
    echo_color $Green "[SUCCESS] - Detection Completed:"
    echo_color $Cyan "\t$(pwd)/burpfeeder/waf.log"
    awk '$0="\t\t"$0' burpfeeder/waf.log
}

function backupfinder {
    echo_color $Yellow "[INFO] - Start finding backup pages from juicy pages"
    for file in $(ls -1 burpfeeder/gospider/*.juicy)
    do
        output_file=$(echo "${file/gospider/gobuster}" | cut -d"." -f1)
        rm $output_file.juicy 2>/dev/null
        for line in $(cat $file)
        do
            url=$(echo $line | rev | cut -d "/" -f2- | rev)
            echo $line | rev | cut -d"/" -f1 | rev > $output_file.wordlist
            $(which gobuster) dir --proxy $BURP_PROXY -d -u $url -w $output_file.wordlist --exclude-length 0 -o $output_file 1>/dev/null 2>/dev/null
            awk '{ print "'"$url"'" $1;}' $output_file >> $output_file.juicy
        done
    done
    echo_color $Green "[SUCCESS] - Detection Completed:"
    echo_color $Cyan "\tBackup files may be found here:"
    for file in $(ls -1 burpfeeder/gospider/*.juicy)
    do
        diff_file=$(echo "${file/gospider/gobuster}")
        diff $file $diff_file 2>/dev/null
        if [ $? -ne 0 ]
        then
            echo -E "\t\t$diff_file"
        fi
    done    
}

function looting {
    echo_color $Yellow "[INFO] - Start looting for juicy pages"
    #TBC
}

function leave {
    echo_color $Purple "[EXIT] Go to the Burp dashboard and analyze the results :)"
}

#####################################################
### CODE

banner
init
arg_parser $#
identify
wafwoof
spidering
recording
backupfinder
leave

#########################################################
### TO DO
# add httploot
