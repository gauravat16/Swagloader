#!/bin/bash

#!/bin/bash

#This script will load all the base data for internal reviews.
#Author Gaurav Sharma

#Colors

	RED='\033[0;31m'
	WHITE='\033[97m'
	NC='\033[0m'
	BOLD='\033[1m'
	GREEN='\033[92m'
	DIM='\033[2m'
	STOP='\033[0m'
    UNDERLINED='\033[4m'
    INVERTED='\033[7m'
    BLINK='\033[5m'
    BLUE='\033[34m'

#Setup what env this script is executed on
setup_env(){
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     machine=Linux;;
        Darwin*)    machine=Mac;;
        CYGWIN*)    machine=Cygwin;;
        MINGW*)     machine=MinGw;;
        *)          machine="UNKNOWN:${unameOut}"
    esac
}

function print_swag_logo(){
    cat << "EOF"


     _______.____    __    ____  ___       _______  __        ______        ___       _______   _______ .______      
    /       |\   \  /  \  /   / /   \     /  _____||  |      /  __  \      /   \     |       \ |   ____||   _  \     
   |   (----` \   \/    \/   / /  ^  \   |  |  __  |  |     |  |  |  |    /  ^  \    |  .--.  ||  |__   |  |_)  |    
    \   \      \            / /  /_\  \  |  | |_ | |  |     |  |  |  |   /  /_\  \   |  |  |  ||   __|  |      /     
.----)   |      \    /\    / /  _____  \ |  |__| | |  `----.|  `--'  |  /  _____  \  |  '--'  ||  |____ |  |\  \----.
|_______/        \__/  \__/ /__/     \__\ \______| |_______| \______/  /__/     \__\ |_______/ |_______|| _| `._____|
                                                                                                                     
EOF
}

function trim(){
    echo "$(echo "$1" | awk '{$1=$1};1')"
}

serverIP=$1

setup_vars(){
    setup_env

    swagger_paths=()

    if [ -z "$serverIP" ]
    then
        echo -e "No URL passes as the first argument, quitting!"
        exit
    fi

    review_data_path="review-data"
    bin="bin"
    resources="resources"
    swagger_data="swagger_data"
    swagger_info_file="swagger_api.info"
    make_dirs
    get_jq
    loadSwaggerPaths

}

function pressEnterToCont(){
   read -e -p $'\nPress enter to continue\n'
}

function make_dirs(){
    mkdir -p $(pwd)/$bin
    mkdir -p $(pwd)/$resources
    mkdir -p $(pwd)/$swagger_data
}

#Downloads os based jq implementation
get_jq(){
    curr_path="$(pwd)"
    cd $bin
    if [[ ! -f jq ]]
    then
        case $machine in
            Linux)
                wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
                mv jq-linux64 jq
            ;;
            
            Mac)
                wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-osx-amd64
                mv jq-osx-amd64 jq
                
            ;;
            
        esac
        
        chmod u+x jq
    fi
    
    cd $curr_path
}


function loadSwaggerPaths(){
    while  IFS= read -r line
    do
        swagger_paths+=($line)
        mkdir -p $swagger_data/$resources/$line
    done < $swagger_data/$swagger_info_file
}

function downloadSwaggerPath(){
        local path=$1
        if [[ ! -f $swagger_data/$path-api.json ]]
        then
            wget -q  "http://$serverIP/$path/v2/api-docs" -O  $swagger_data/$path-api.json
        fi
}

function apiCountFoundForSwaggerPath(){
    local service=$1
    local count_paths=$(./$bin/jq -r ".paths | length" $swagger_data/$service-api.json)
    echo $count_paths
}
function printAllSwaggerApi(){
    local service=$1
    local count=$(./$bin/jq -r ".paths | length" $swagger_data/$service-api.json)
    count=$((count -1));
    for i in $(seq 0 $count)
    do
        local api=$(./$bin/jq -r ".paths|keys[$i]" $swagger_data/$service-api.json)
        echo -e "   ${GREEN}$i:${STOP}" "${BLUE}$api${STOP}"
    done
}

function handleNumericMenuInput(){
    local __option=$1
    local __back_action=$2
    local __positive_action=$3
    local __negative_action=$4
    local __calling_function=$5
    local __count=$6

    local __num_regex="^[0-9]+$"

    if [ "$__option" == "<" ]
    then
        eval "$__back_action"
    fi

    if ! [[ "$__option" =~ $__num_regex ]]
    then
        eval "$__negative_action"
    fi

    if [ ! -z "$__option" ] && [ "$__option" -gt "$__count" ]
        then 
            eval "$__negative_action"
        else
            eval "$__positive_action"
            pressEnterToCont
            eval "$__calling_function"
    fi
}

function getAPIForIndexAndService(){
    local api=$(./$bin/jq -r ".paths|keys[$1]" $swagger_data/$2-api.json)
    echo $api
}

#Posts data ($1) to url($2)
function post(){
    jsonData="$1"
    url="$2"
    curl  -d "$jsonData" -H "Content-Type: application/json" -X POST "$url"
}

#Get request
function get(){
    echo -e "\n"
    url=$1
    curl -X GET $url
    echo -e "\n"

}

function handleAPISelection(){
    clear
    print_swag_logo
    path=$1
    api=$2
    local method=""
    local url="$serverIP/$path/$api"

    echo -e "\n${BOLD}Paramerters needed${STOP}"

    eval "$(showAPIInfo "$path" "$api")"
    if [ "$post" != "null" ]
    then
        echo -e "Post Request - \n $post"
        method="post"
    fi
    if [ "$get" != "null" ]
    then
        echo -e "Get Request - \n $get"
        method="get"
    fi

    echo -e "\n${BOLD}Choose the data you want to load${STOP}"

    listAllDataFilesForSwaggerPath $path
      echo -e "\n< Back"
        local __option
        local __count=${#data_files[@]}
        while [ -z $__option ]; do
            read __option
            __option=$(trim $__option)
        done

    handleNumericMenuInput "$__option" "swaggerAPIMenu $path" "executeAPI $method $url $swagger_data/$resources/$path/"'${data_files[$__option]}' "handleAPISelection $path $api" "handleAPISelection $path $api" "$__count"
}

function executeAPI(){
    method="$1"
    url="$2"
    jsonDataFile="$3"

    case $method in 
    "post")
        local __count=$(./$bin/jq -r "length" $jsonDataFile)
        __count=$((__count -1));
        for i in $(seq 0 $__count)
        do
            echo -e "${GREEN}Posting item - $(($i+1))${STOP}\n"
            post  "$(./$bin/jq -r ".[$i]" $jsonDataFile)" "$url"
            echo -e "\n"
        done
    ;;
    "get")
    ;;
    esac
}

function listAllDataFilesForSwaggerPath(){
    local __path=$1
    data_files=()
    local __count=0
    for entry in $(ls "$swagger_data/$resources/$__path"); do
        echo -e "   ${GREEN}$__count:${STOP}" ${BLUE}$entry${STOP}
        data_files+=$entry
        __count=$((__count+1))
    done
}

function showAPIInfo(){
    path=$1
    api=$2

    local post_result=$(jq -r ".paths|values| .[\""$api\""]|.post.parameters" $swagger_data/$path-api.json)
    local get_result=$(jq -r ".paths|values| .[\""$api\""]|.get.parameters" $swagger_data/$path-api.json)
    echo "post="\"$post_result"\";get="\"$get_result"\""
}

function swaggerAPIMenu(){
    clear
    print_swag_logo
    local path=$1
    downloadSwaggerPath $path
    local count=$(apiCountFoundForSwaggerPath $path)

    if [ ! -z "$count" ] && [ "$count" -ge 0 ]
    then
        echo -e "\n${BOLD}Swagger API available for ${RED}$path${STOP}\n"
        printAllSwaggerApi $path
        echo -e "\n< Back"
        
        local option
        while [ -z $option ]; do
            read option
            option=$(trim $option)
        done

        handleNumericMenuInput "$option" "swaggerPathMenu" "handleAPISelection $path $(getAPIForIndexAndService $option $path)" "swaggerAPIMenu $path" "swaggerAPIMenu $path" "$count"
    else
        echo -e "\n${RED}No API found for $path${STOP}"
        pressEnterToCont
        swaggerPathMenu
    fi
   
}

function swaggerPathMenu(){
    clear
    print_swag_logo
    echo -e "\n${BOLD}Swagger Paths available\n$STOP"
    local count=${#swagger_paths[@]}
    for i in $(seq 0 $((count-1)))
    do
        echo -e "   ${GREEN}$i:${STOP}" ${BLUE}${swagger_paths[$i]}${STOP}
    done
    echo -e "\n< Exit"
    read option
    handleNumericMenuInput "$option" "exit" "swaggerAPIMenu "'${swagger_paths[$option]}' "swaggerPathMenu" "swaggerPathMenu" "$count"
}

#init the script here
function init(){
    setup_vars
    swaggerPathMenu
    # downloadAllSwaggerPaths
}

#Start the flow
init