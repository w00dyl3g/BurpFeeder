#!/bin/sh

############################################################
### VARS

VERSION="v0.2"

NEEDED_SOFTWARE="httpx gobuster wafw00f gospider git curl"

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
JUICY_EXT="asp\|\.aspx\|\.php\|\.php3\|\.php4\|\.php5\|\.txt\|\.shtm\|\.shtml\|\.phtm\|\.phtml\|\.jhtml\|\.pl\|\.jsp\|\.cfm\|\.cfml\|\.py\|\.rb\|\.cfg\|\.zip\|\.pdf\|\.gz\|\.tar\|\.tar\.gz\|\.tgz\|\.doc\|\.docx\|\.xls\|\.xlsx\|\.conf"


##############################################################
### FUNCTIONS

banner() {
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
    echo "                   $VERSION"
    echo "                                 ...by w00dyl3g & 5amu"
    echo ""
}

echo_color() { echo "$1$2$Color_Off"; }

usage() 
{
    echo ""
    echo "Usage: burpfeeder.sh [-h|-l <urls-list>|-t <target>]"
    echo ""
    echo "    -h|--help    display this message and quit"
    echo "    -l|--list    urls file (new-line separated)"
    echo "    -t|--target  target to be evaluated"
    echo "    -p|--proxy   proxy string (http://127.0.0.1:8080)"
    echo ""
}

init() 
{
    echo_color $Yellow "[INFO] - Initialyzing Program"
    [ -d burpfeeder.old ] && rm -rf burpfeeder.old
    [ -d burpfeeder ] && mv burpfeeder burpfeeder.old
    mkdir -p burpfeeder/eyewitness
    mkdir -p burpfeeder/gobuster
    for t in $NEEDED_SOFTWARE; do
        if ! command -v "$t" >/dev/null; then
            echo_color $Red "[ERROR] - You need $t"
            exit 1
        fi
    done

    # Check if ~/.local/opt/eyewitness exists, or installs it
    EYEWITNESS_PATH="$HOME/.local/opt/eyewitness"
    EYEWITNESS_REPO="https://github.com/FortyNorthSecurity/EyeWitness"
    if [ ! -d $EYEWITNESS_PATH ]; then
        git clone "$EYEWITNESS_REPO" "$EYEWITNESS_PATH" 
    fi
    EYEWITNESS="$EYEWITNESS_PATH/Python/EyeWitness.py"

    echo_color $Green "[SUCCESS] - Initialization Completed"
}

identify() 
{
    #TECH DETECT
    echo_color $Yellow "[INFO] - Detecting Technologies used"
    
    if [ -n "$TARGET" ]; then
        echo "$TARGET" | httpx -http-proxy $PROXY_STRING \
            -sc -td -title -server -probe -t 1 -silent \
            -output burpfeeder/httpx.log 1>/dev/null 2>/dev/null
    else
        httpx -http-proxy $PROXY_STRING \
            -l $URLS_FILE \
            -sc -td -title -server -probe -t 1 -silent \
            -output burpfeeder/httpx.log 1>/dev/null 2>/dev/null
    fi
    echo_color $Green "[SUCCESS] - Detection Completed:"
    echo_color $Cyan "\t$(pwd)/burpfeeder/httpx.log"
    awk '$0="\t\t"$0' burpfeeder/httpx.log
}

spidering()
{
    #SPIDERING
    echo_color $Yellow "[INFO] - Start spidering websites"
    
    if [ -n "$TARGET" ]; then
        gospider -p $PROXY_STRING -s $TARGET \
            --sitemap --robots --js -t 1 -a \
            --output burpfeeder/gospider 1>/dev/null 2>/dev/null
    else
        gospider -p $PROXY_STRING -S $URLS_FILE \
            --sitemap --robots --js -t 1 -a \
            --output burpfeeder/gospider 1>/dev/null 2>/dev/null
    fi

    mkdir -p burpfeeder/gospider
    for file in $( find burpfeeder/gospider -type f ); do
        touch $file.juicy
        #CLEANING RESULTS
        mv $file $file.tmp
        cat $file.tmp \
            | rev \
            | cut -d" " -f1 \
            | rev \
            | sort -u \
            | grep http > $file
        rm $file.tmp
        #INTERESTING FILES
        cat $file \
            | cut -d"?" -f1 \
            | grep $JUICY_EXT > $file.juicy
    done

    echo_color $Green "[SUCCESS] - Spidering Completed"

    if find burpfeeder/gospider -name '*juicy' | grep -q '.'; then
        echo_color $Yellow "[INFO] - Juicy files found:"
        for file in $( find burpfeeder/gospider -name '*juicy' ); do
            echo_color $Cyan "\t$(pwd)/$file"
            awk '$0="\t\t"$0' $file
        done
    fi
}

recording() 
{
    EYEWITNESS_PATH="$HOME/.local/opt/eyewitness"
    EYEWITNESS="$EYEWITNESS_PATH/Python/EyeWitness.py"


    OUTDIR="burpfeeder/eyewitness"; mkdir -p $OUTDIR
    echo_color $Yellow "[INFO] - Start recording juicy pages"
    if find burpfeeder/gospider -name '*juicy' | grep -q '.'; then
        for file in $(ls -1 burpfeeder/gospider/*.juicy); do
            file="${file%.*}"; output_file="${OUTDIR}/${file##*/}"
            echo n | $EYEWITNESS -f $file -d $output_file >/dev/null
        done
    fi

    echo_color $Green "[SUCCESS] - Recording Completed"
    if find burpfeeder/eyewitness -name 'report.html' | grep -q '.'; then
        echo_color $Yellow "[INFO] - Screenshot files here:"
        for file in $(ls -1 burpfeeder/eyewitness/*/report.html); do
            echo_color $Cyan "\t$(pwd)/$file"
        done
    fi
}

wafwoof() 
{
    echo_color $Yellow "[INFO] - Detecting WAF used"
    if [ -n "$URLS_FILES" ]; then
        urls="$(cat $URLS_FILE| paste -sd ' ')"
    else
        urls="$TARGET"
    fi
    wafw00f -a -p $PROXY_STRING -o burpfeeder/waf.log $urls 1>/dev/null 2>/dev/null
    echo_color $Green "[SUCCESS] - Detection Completed:"
    echo_color $Cyan "\t$(pwd)/burpfeeder/waf.log"
    awk '$0="\t\t"$0' burpfeeder/waf.log
}

backupfinder() 
{
    echo_color $Yellow "[INFO] - Start finding backup pages from juicy pages"
    if ! find burpfeeder/gospider -name '*.juicy' >/dev/null; then
        for file in $(ls -1 burpfeeder/gospider/*.juicy); do
            output_file=$(echo "${file/gospider/gobuster}" | cut -d"." -f1)
            rm $output_file.juicy 2>/dev/null
            for line in $(cat $file)
            do
                url=${line%/*}
                echo ${line##*/} > $output_file.wordlist
                gobuster dir \
                    --proxy $PROXY_STRING \
                    -d -u $url \
                    -w $output_file.wordlist \
                    --exclude-length 0 \
                    -o $output_file 1>/dev/null 2>/dev/null
                awk '{print "'"$url"'" $1;}' $output_file >> $output_file.juicy
            done
        done
    fi
    echo_color $Green "[SUCCESS] - Detection Completed"
    if ! find burpfeeder/gospider -name '*.juicy' >/dev/null; then
        echo_color $Cyan "\tBackup files may be found here:"
        for file in $(ls -1 burpfeeder/gospider/*.juicy); do
            diff_file=$(echo "${file/gospider/gobuster}")
            diff $file $diff_file 2>/dev/null
            if [ $? -ne 0 ]
            then
                echo -E "\t\t$diff_file"
            fi
        done    
    fi
}

looting()
{
    echo_color $Yellow "[INFO] - Start looting for juicy pages"
    #TBC
}

leave()
{
    echo_color $Purple "[EXIT] Go to the Burp dashboard and analyze the results :)"
}

#####################################################
### CODE

banner

init 
echo

echo_color $Yellow "[INFO] - Parsing arguments"
while [ $# -ne 0 ]; do case $1 in
    -l|--list)
        shift
        if [ -f "$1" ]; then 
            export URLS_FILE="$1"
        else
            echo_color $Red "[ERROR] - File does not exist"
            exit 1
        fi
        ;;
    -t|--target) shift; export TARGET="$1" ;;
    -p|--proxy)  shift; export PROXY_STRING="$1" ;;
    -h|--help)   usage; exit 0 ;;
    *) echo_color $Red "[ERROR] - Unrecognised option: $1" && exit 1 ;;
esac; shift; done

if [ -z "$TARGET" ] && [ -z "$URLS_FILE" ]; then
    echo_color $Red "[ERROR] - Missing target"
    exit 1
fi

PROXY_STRING="${PROXY_STRING:-http://127.0.0.1:8080}"
export HTTP_PROXY="${PROXY_STRING}"
export HTTPS_PROXY="${PROXY_STRING}"

echo_color $Green "[SUCCESS] - Argument Parsed:"
[ -n "$TARGET" ]    && echo_color $Cyan "\tUsing Target: $TARGET"
[ -n "$URLS_FILE" ] && echo_color $Cyan "\tUsing TargetFile: $URLS_FILE"
echo_color $Cyan "\tUsing Proxy : $PROXY_STRING"
echo

FUNCS="identify wafwoof spidering recording backupfinder leave"
for f in $FUNCS; do
    $f && echo
done

#########################################################
### TO DO
# add httploot
