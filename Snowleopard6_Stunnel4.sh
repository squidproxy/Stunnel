#!/bin/bash
#===========================================================================
# Function Description: Setup a secure web proxy using SSL encryption, Squid Caching Proxy and PAM authentication
# Techlonogy Support : https://github.com/squidproxy
# Author:Dave feng
# Version： 1.1
# https://www.stunnel.org/index.html
# Stunnel is a proxy designed to add TLS encryption functionality to existing clients and servers without any changes in the programs' code.
# Its architecture is optimized for security, 
# portability, and scalability (including load-balancing), making it suitable for large deployments.
#===========================================================================

KeyPath=/etc/stunnel/snowleopard.key
CaPath=/etc/stunnel/snowleopard-ca.pem
StunnelCa=/etc/stunnel/stunnel.pem
StunnelConfPath=/etc/stunnel/stunnel.conf
squidconf1=/etc/squid3/squid.conf
squidconf2=/etc/squid/squid.conf
#stunnel port
PORT=8081

function print_info(){
    echo -n -e '\e[1;36m'
    echo -n $1
    echo -e '\e[0m'
}


function coloredEcho(){
    local exp=$1;
    local color=$2;
    if ! [[ $color =~ '^[0-9]$' ]] ; then
       case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput setaf $color;
    echo $exp;
    tput sgr0;
}



check_process() {
#  echo "$ts: checking $1"
  [ "$1" = "" ]  && return 0
  [ `pgrep -n $1` ] && return 1 || return 0
}



function check_stunnel_installed_status() {
#  echo "$ts: checking $1"
  dpkg-query -W -f='${Status} ${Version}\n' stunnel4
  OUT=$?
  if [ $OUT -eq 0 ];then
   coloredEcho "Stunnel4 installed on OS!" green
  else
   coloredEcho "Stunnel does not found,installing now" red
   apt-get install stunnel4 -y
fi
}

function get_squid_port()
{

for SquidconfPath  in $squidconf1 $squidconf2
do

if [ -f $SquidconfPath ]; then
 coloredEcho  "Checking Squid installed " green
 SquidPort=`grep 'http_port' $SquidconfPath | cut -d' ' -f2- | sed -n 1p`
 coloredEcho "Check your Squid running on $SquidPort "  green
  coloredEcho "Squid config path : $SquidconfPath "  green

 else

    if  [ $SquidconfPath == $squidconf1 ];then
    coloredEcho  "Squid3 package no found,skip  ........" green
    continue #skip squid3 conf path

    else
    coloredEcho  "Squid installing ........" green
    read -r -p "${1:-Are you continue? [y/N]} " response

    case "$response" in
            [yY][eE][sS]|[yY])
            wget -N --no-check-certificate https://git.io/vD67J  -O ./SLSrv.sh
            chmod +x SLSrv.sh
            bash SLSrv.sh
            ;;
        *)
            false
            exit 1
            ;;
     esac
fi

fi

done

}


function CheckStunnelStatus()

{

lsof -Pi :$PORT -sTCP:LISTEN -t

if  [ $? -eq 0 ];then

coloredEcho " running," green
service stunnel4 restart

else
coloredEcho  " no running, restarting... " red
service stunnel4 restart
fi

}



function Update_ECC_OR_Conf()
{

for filename  in $KeyPath $CaPath $StunnelCa $StunnelConfPath
do
if [ -f $filename ]; then
coloredEcho  "File '$filename' Exists,will deleted" green
rm $filename
else
coloredEcho  "The File '$filename ' Does Not Exist" red
fi
done

}

function Generate_Stunnel_config()
{

cat << EOF > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/stunnel.pem
[squid]
# Ensure the .connect. line matches your squid port. Default is 3128
accept = 8081
connect = 127.0.0.1:$SquidPort
EOF

}

function Generate_ECC_Certificate()
{



Server_add=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
# generate 384bit ca certicate
openssl ecparam -out /etc/stunnel/snowleopard.key -name  secp384r1 -genkey
openssl req -x509 -new -key /etc/stunnel/snowleopard.key \
-out /etc/stunnel/snowleopard-ca.pem -outform PEM -days 3650 \
-subj "/emailAddress=Snowleopard/CN=$Server_add/O=Snowleopard/OU=Snowleopard/C=Sl/ST=cn/L=Hacker6"

#Create the stunnel private key (.pem) and put it in /etc/stunnel.
cat /etc/stunnel/snowleopard.key /etc/stunnel/snowleopard-ca.pem >> /etc/stunnel/stunnel.pem
#Show Algorithm
openssl x509 -in  /etc/stunnel/stunnel.pem -text -noout
#openssl ecparam -list_curves

}

function Generate_RSA_Certificate()

{

 Server_add=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
openssl genrsa -out /etc/stunnel/snowleopard.key  $RSA_Key_Size
openssl req -new -x509 -key /etc/stunnel/snowleopard.key -out /etc/stunnel/snowleopard-ca.pem -days 1095 \
-subj "/emailAddress=Snowleopard/CN=$Server_add/O=Snowleopard/OU=Snowleopard/C=Sl/ST=cn/L=Hacker6"
cat /etc/stunnel/snowleopard.key /etc/stunnel/snowleopard-ca.pem >> /etc/stunnel/stunnel.pem
#Show Algorithm
openssl x509 -in  /etc/stunnel/stunnel.pem -text -noout
#openssl ecparam -list_curves
}

function  Choose_Encryption_Algorithm()

{

   echo -e "Choose a Encryption Algorithm:\n 1:rsa\n 2:ECC\n"
    read text
if [ $text -eq 1 ];then

# Set RSA KeySize
        echo -e "Enter RSA KeySize ,Choose:\n 1:2048\n 2:4096\n"
    read text

        if [ $text -eq 1 ];then
        RSA_Key_Size=2048
        fi

        if [ $text -eq 2 ];then
        RSA_Key_Size=4096
        fi
$RSA_Key_Size
    Encryption_Algorithm=RSA
    echo "You RSA_Key_Size is: $RSA_Key_Size"
    Generate_RSA_Certificate

  fi

  if  [ $text -eq 2 ];then
  Encryption_Algorithm=ECC
   Generate_ECC_Certificate

  fi
  

}


function Show_StunnelClient_config()
{
coloredEcho "Add below info for your stunnel client" green
coloredEcho "=============================================" green
coloredEcho "Client conf"

echo "; Encrypted HTTP proxy authenticated with a client certificate"
echo "; located in the Windows certificate store"
echo "[Hacker-proxy]"
echo "client = yes"
echo "accept = 127.0.0.1:8000"
echo "connect = $Server_add:8081"
echo ";engineId = capi"
coloredEcho "=============================================" green
lsof -Pi :$PORT -sTCP:LISTEN -t &> /dev/null && print_info "Stunnel Service running,port:$PORT"
lsof -Pi :$SquidPort -sTCP:LISTEN -t &> /dev/null && print_info "Squid Service running,port: $SquidPort"
print_info "$Encryption_Algorithm"

check_stunnel_installed_status
Update_ECC_OR_Conf
get_squid_port
Generate_Stunnel_config
Choose_Encryption_Algorithm
CheckStunnelStatus
Show_StunnelClient_config
exit 0