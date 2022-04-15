#!/bin/bash
##################################
# 
# bash script to wrap snmpset to transfer configuration files via SNMP settings.
# Use to transfer configs (running startup other files) to or from routers (cisco) 
# transfer protocol can be  tftp,scp,rcp,ftp,sftp 
# snmp version 1,2,2c, default 2c
# named options are case sensative
#
# Note: with mac os it still uses bash v3, this script uses bash 4 features.  
# You can brew / port install bash version 4 which be placed in /usr/local/bin/bash
# With bash 4 installed you can run it as $bash snmp-copy.sh or change the #! path above.
# Linux (ubuntu) is fine.
#  
#################################

set -e

if ! (( ${BASH_VERSION%%.*} >= 4 )); then
    echo "This script requires bash 4"
    exit 1
fi

####### LOOKUP REFERENCES ########
declare -A copy_protocol
copy_protocol=(["tftp"]=1 \
    ["ftp"]=2 \
    ["rcp"]=3 \
    ["scp"]=4 \
    ["sftp"]=5)

declare -A copy_source_file_type
copy_source_file_type=(["networkFile"]=1 \
    ["iosFile"]=2 \
    ["startupConfig"]=3 \
    ["runningConfig"]=4 \
    ["terminal"]=5 \
    ["fabricStartupConfig"]=5)

declare -A copy_dest_file_type
copy_dest_file_type=(["networkFile"]=1 \
    ["iosFile"]=2 \
    ["startupConfig"]=3 \
    ["runningConfig"]=4 \
    ["terminal"]=5 \
    ["fabricStartupConfig"]=5)

######## USAGE ########

usage() {
    cat << EOF

    usage: $0 [-c] [-v] [-p] -s -d -n -t -a

    Requires snmpwalk. For all transfers the following is required:

    OPTIONS:
      -h           help
      -c COMMUNITY SNMP community string, default 'public'
      -p PROTOCOL  Transfer Protocol, values: "${!copy_protocol[@]}", default 'tftp'
      -v VERSION   SNMP version, default '2c'
      -t TARGET    IP Address of the target network device
      -a SERVER    IP Address of the server TFTP, SCP etc.
      -n FILENAME  Name of the file on server
      -s SOURCE    copy source file type, values: "${!copy_source_file_type[@]}"
      -d DEST      copy dest file type, values: "${!copy_dest_file_type[@]}"
    
    AUTH OPTIONS:
      -U USERNAME  SCP etc. username
      -P PASSWORD  SCP etc. password
       
    Examples:
        # copy from router to TFTP server
        snmp-copy.sh -p tftp -s runningConfig -d networkFile -n config.txt -t a.b.c.d -a w.x.y.z

        # copy from TFTP server to router
        snmp-copy.sh -p tftp -s networkFile -d runningConfig -n config.txt -t a.b.c.d -a w.x.y.z

    If using an authenticating protocol then a username and password are also required.

EOF
}

####### DEFAULTS ########
COMMUNITY="public"
VERSION="2c"
PROTO="tftp"
ROW=$RANDOM

while getopts ":hc:v:t:a:d:s:n:p:U:P:" OPTION
do
    case $OPTION in
        h)
            usage; exit 1;;
        c)
            COMMUNITY=$OPTARG;;
        v)
            VERSION=$OPTARG;;
        t)
            TARGET=$OPTARG;;
        a)
            SERVERADDR=$OPTARG;;
        d)
            DESTFILE=$OPTARG;;
        s)
            SRCFILE=$OPTARG;;
        n)
            FILENAME=$OPTARG;;
        p)
            PROTO=$OPTARG;;
        U)
            USERNAME=$OPTARG;;
        P)
            PASSWORD=$OPTARG;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 1;;
        :)
            echo "Option -$OPTARG requres and argument."
            exit 1;;
    esac
done

#check that snmpwalk is installed
if ! type "snmpwalk" >/dev/null 2>&1;  then
    echo "Need to install snmp tools"
    echo "Eg: apt-get install snmp."
    exit 1;      
fi

# If no options print usage and exit
if [[ $# -eq 0 ]]; then
    usage
    exit 1;
fi

# Check for mandatory arguments
if [[ -z "$COMMUNITY" ]] || [[ -z "$VERSION" ]] || [[ -z "$TARGET" ]] || [[ -z "$SERVERADDR" ]] || \
         [[ -z "$SRCFILE" ]] || [[ -z "$DESTFILE" ]] || [[ -z "$FILENAME" ]]; then
    echo -e "\nMandatory options missing.\n"
    echo -e "Require: SRCFILE, DESTFILE, FILENAME, TARGET, and SERVER."
    usage;
    exit 1;
fi
  
declare -A OID
OID=(["set_copy_protocol"]="1.3.6.1.4.1.9.9.96.1.1.1.1.2.${ROW} i ${copy_protocol["$PROTO"]}" \
    ["set_copy_source_file_type"]="1.3.6.1.4.1.9.9.96.1.1.1.1.3.${ROW} i ${copy_source_file_type["$SRCFILE"]}" \
    ["set_copy_dest_file_type"]="1.3.6.1.4.1.9.9.96.1.1.1.1.4.${ROW} i ${copy_dest_file_type["$DESTFILE"]}" \
    ["set_copy_server_address"]="1.3.6.1.4.1.9.9.96.1.1.1.1.5.${ROW} a ${SERVERADDR}" \
    ["set_copy_filename"]="1.3.6.1.4.1.9.9.96.1.1.1.1.6.${ROW} s ${FILENAME}" \
    ["set_copy_username"]="1.3.6.1.4.1.9.9.96.1.1.1.1.7.${ROW} s ${USERNAME}" \
    ["set_copy_password"]="1.3.6.1.4.1.9.9.96.1.1.1.1.8.${ROW} s ${PASSWORD}" \
    ["set_copy_table_active"]="1.3.6.1.4.1.9.9.96.1.1.1.1.14.${ROW} i 1")

######## SNMPSET #######

if [[ -z ${USERNAME} ]] && [[ -z ${PASSWORD} ]]; then

# snmpset -v "${VERSION}" -c "${COMMUNITY}" "${TARGET}" \
OIDSET="${OID["set_copy_protocol"]} \
 ${OID["set_copy_source_file_type"]} \
 ${OID["set_copy_dest_file_type"]} \
 ${OID["set_copy_server_address"]} \
 ${OID["set_copy_filename"]}"

elif [[ -n ${USERNAME} ]] && [[ -n ${PASSWORD} ]]; then

# snmpset -v "${VERSION}" -c "${COMMUNITY}" "${TARGET}" \
OIDSET="${OID["set_copy_protocol"]} \
 ${OID["set_copy_source_file_type"]} \
 ${OID["set_copy_dest_file_type"]} \
 ${OID["set_copy_server_address"]} \
 ${OID["set_copy_filename"]} \
 ${OID["set_copy_username"]} \
 ${OID["set_copy_password"]}"

fi

#set oid values
snmpset -v "${VERSION}" -c "${COMMUNITY}" "${TARGET}" ${OIDSET}

#exec oid settings
snmpset -v "${VERSION}" -c "${COMMUNITY}" "${TARGET}" ${OID["set_copy_table_active"]}

exit 0
