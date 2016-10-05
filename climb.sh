#!/bin/bash
### FILL THESE VARIABLES TO CORRECT WORK OF THE SCRIPT ###
USER_NAME=
SERVER_ADDRESS=
JSON_PATH=
IMAGE_PATH=
########################################################

TEMP_FILE="temp.json"
# Force delete the temp file before starting
rm -f ${TEMP_FILE} 2> /dev/null

# The function that displays help/usage for the script
function usage()
{
    echo
    echo "Basic usage: ${0} -c 'a comment for the image' image.jpg"
    echo
    echo 'At least, one of the parameters need to be provided.'
    echo 'The script tries to download a JSON file using a path in the variable JSON_PATH in the head of the script.'
    echo 'Next, the script creates the JSON file, if not exists, '
    echo 'and appends to the top of it a new record with "img":"image command line parameter" and '
    echo '"comment":"a comment from the -c command line option" key/value pairs. '
    echo 'Finally, the script push using scp: the image to the server using '
    echo 'the variable IMAGE_PATH in the head of the script, '
    echo 'the result JSON file using the variable JSON_PATH.'
    echo 'The user name and the server address of the connection to the server '
    echo 'are contained in the variables USER_NAME and SERVER_ADDRESS in the head of the script.'
    echo
    echo "Return codes:"
    echo "1 - missing values in the variables in the head of the script"
    echo "2 - no command line parameters are provided"
    echo "3 - provided invalid option"
    echo "4 - not provided value for the option -c"
    echo "5 - some troubles with SSH connection"
    echo
    echo "For print this help type ${0} -h"
}

function prepare_json_record()
{
    # ${1} - IMAGE_NAME
    # ${2} - COMMENT
    # ${3} - delimiter (\t or \n)
    local result
    if [ ! -z "${1}" ] && [ ! -z "${2}" ]
    then
	result="{${3}\"img\":\"${1}\",${3}\"comment\":\"${2}\"${3}}"
    elif [ ! -z "${1}" ]
    then
	result="{${3}\"img\":\"${1}\"${3}}"
    else
	result="{${3}\"comment\":\"${2}\"${3}}"
    fi
    echo "${result}"
}

# Check the case when nothing is provided to the script
if [ -z "$*" ]
then
    echo "At least, one of the parameters need to be provided!" >&2
    usage
    exit 2
fi

# Check the case when the user provided to the script more than three parameters
if [ $# -gt 3 ]
then
    echo "You have provided too many parameters!" >&2
    usage
    exit 2
fi

# Check the case when the user provided to the script the option -i and something else
if [ "${1}" == "-i" ] && [ $# -gt 1 ]
then
    echo "You should not provide any options or parameters after the option -i!" >&2
    usage
    exit 2
fi

# If a user entered the command line like "./bash_json.sh image -c 'comment'" try to parse this string
if [ "${2}" == "-c" ]
then
    if [ ! -z "${1}" ]
    then
	IMAGE_NAME="${1}"
	shift
    fi
fi

# Parsing -c, -h and -i options
while getopts ":hic:" opt; do
    case $opt in
	c)
	    if [[ ! "${OPTARG}" == -* ]]
	    then
		COMMENT="${OPTARG}"
	    else
		echo "Invalid argument: $OPTARG" >&2
		usage
		exit 3
	    fi
	    ;;
	h)
	    usage
	    exit 0
	    ;;
	i)
	    echo "-i handles here!"
	    ;;
	\?)
	    echo "Invalid argument: $OPTARG" >&2
	    usage
	    exit 3
	    ;;
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    usage
	    exit 4
	    ;;
    esac
done
shift $((OPTIND-1))

#echo ${COMMENT}
#exit 0

# Get a value of the positional parameter (an image name)
IMAGE_NAME="${1}"

# The block that checks all variables in the header of the script that need to be filled
if [ -z ${USER_NAME} ]
then
    echo "The script hasn't been setup properly. Please, fill a user name on the server in the variable USER_NAME in the head of the script" >&2
    exit 1
fi
if [ -z ${SERVER_ADDRESS} ]
then
    echo "The script hasn't been setup properly. Please, fill the server address in the variable SERVER_ADDRESS in the head of the script" >&2
    exit 1
fi
if [ -z "${JSON_PATH}" ]
then
    echo "The script hasn't been setup properly. Please, fill a path to the JSON file on the server in the variable JSON_PATH in the head of the script" >&2
    exit 1
fi
if [ ! -z "${IMAGE_NAME}" ] && [ -z "${IMAGE_PATH}" ]
then
    echo "The script hasn't been setup properly. Please, fill a path to the image on the server in the variable IMAGE_PATH in the head of the script" >&2
    exit 1
fi

# Try to download JSON file from the server in batch mode
SCP_BATCH_ERROR_MESSAGE=$(scp -Bq ${USER_NAME}@${SERVER_ADDRESS}:"${JSON_PATH}" ${TEMP_FILE} 2>&1 >/dev/null)
SCP_BATCH_RETURN_CODE=$(echo $?)

if [ ${SCP_BATCH_RETURN_CODE} -eq 0 ]
then
    BATCH_MODE=true
    JSON_IS_EMPTY=false
elif [ ${SCP_BATCH_RETURN_CODE} -ne 0 ] && [[ ${SCP_BATCH_ERROR_MESSAGE} == *"No such file or directory" ]]
then
    BATCH_MODE=true
    JSON_IS_EMPTY=true
else
    # If the connection in batch mode is failed, try to download using common way
    echo -e "There is a problem with a connection to the server in a batch mode.\nIf you have not setup your server to use a public key for SSH connections, you can do this by using command 'ssh-copy-id'" >&2
    SCP_ERROR_MESSAGE=$(scp -q ${USER_NAME}@${SERVER_ADDRESS}:"${JSON_PATH}" ${TEMP_FILE} 2>&1 >/dev/null)
    SCP_RETURN_CODE=$(echo $?)
    if [ ${SCP_RETURN_CODE} -eq 0 ]
    then
	# The remote file is exists
	BATCH_MODE=false
	JSON_IS_EMPTY=false
    elif [ ${SCP_RETURN_CODE} -ne 0 ] && [[ ${SCP_ERROR_MESSAGE} == *"No such file or directory" ]]
    then
	# The remote file is not exists
	BATCH_MODE=false
	JSON_IS_EMPTY=true
    else
	echo -e "There is an error in your SSH connection. The exit code is ${SCP_RETURN_CODE}.\nThe error message: ${SCP_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
	exit 5
    fi
fi

# If there is no JSON before, then create it
if [[ ${JSON_IS_EMPTY} == "true" ]]
then
    json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\n')
    echo -e "[\n${json_output}\n]" > ${TEMP_FILE}
else
    if [ $(grep -Pzoq '\[[[:space:]]*{[[:space:]]*"comment"' ${TEMP_FILE} ; echo $?) -eq 0 ]
    then
	temp_var="$(<${TEMP_FILE})"
	json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\t')
	# The case then the top record contains begins with word "comment"
	echo -e "${temp_var}" | tr '\n' '\t' | sed "s/\[[[:space:]]*\({[[:space:]]*\"comment\"\)/\[\t${json_output},\t\1/g" | tr '\t' '\n' > ${TEMP_FILE}
    elif [ $(grep -Pzoq '\[[[:space:]]*{[[:space:]]*"img"' ${TEMP_FILE} ; echo $?) -eq 0 ]
    then
	temp_var="$(<${TEMP_FILE})"
	json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\t')
	# The case then the top record contains begins with word "img"
	echo -e "${temp_var}" | tr '\n' '\t' | sed "s/\[[[:space:]]*\({[[:space:]]*\"img\"\)/\[\t${json_output},\t\1/g" | tr '\t' '\n' > ${TEMP_FILE}
    else
	json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\n')
	# If there is no previous records in the JSON - just append new block to it
	echo -e "[\n${json_output}\n]" >> ${TEMP_FILE}
    fi
fi

# Upload the image and the result JSON file to the server
SCP_ERROR_MESSAGE=$(scp -q ${TEMP_FILE} ${USER_NAME}@${SERVER_ADDRESS}:"${JSON_PATH}" 2>&1 >/dev/null)
SCP_RETURN_CODE=$(echo $?)
if [ ${SCP_RETURN_CODE} -ne 0 ]
then
    echo -e "There is an error in your SSH connection. The exit code is ${SCP_RETURN_CODE}.\nThe error message: ${SCP_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
    exit 5
fi

if [ ! -z "${IMAGE_NAME}" ]
then
    SCP_ERROR_MESSAGE=$(scp -q "${IMAGE_NAME}" ${USER_NAME}@${SERVER_ADDRESS}:"${IMAGE_PATH}" 2>&1 >/dev/null)
    SCP_RETURN_CODE=$(echo $?)
    if [ ${SCP_RETURN_CODE} -ne 0 ]
    then
	echo -e "There is an error in your SSH connection. The exit code is ${SCP_RETURN_CODE}.\nThe error message: ${SCP_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
	exit 5
    fi
fi

rm -f ${TEMP_FILE}
