#!/bin/bash
#  
#     _     _    _ _   _ ______  _____ 
#    | |   | |  | | \ | |  ____|/ ____|
#    | |   | |  | |  \| | |__  | (___  
#    | |   | |  | | . ` |  __|  \___ \ 
#    | |___| |__| | |\  | |____ ____) |
#    |______\____/|_| \_|______|_____/ 
#
#
# install_node.sh
# Description: Lunes Node install script
#
# Usage: 
#  $./install_node.sh <mainnet|testnet> <enter>
#
# Copyright (c) 2018 Lunes Platform.
#

# [ $1 == --help ] && { sed -n -e '/^# ./,/^$/ s/^# \?//p' < $0; exit; }
clear

# Valida diretórios de instalação
[ ! -d /opt/lunesnode ] && mkdir /opt/lunesnode
[ ! -d /etc/lunesnode ] && mkdir /etc/lunesnode

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
which yum &> /dev/null
rc=$?
if [[ $rc != 0 ]]; then
    PKG="$(which apt) -qq --yes"
     SO=ubuntu
else
    PKG="$(which yum) -q -y"
     so=centos
fi

APT=$(which apt)
CAT=$(which cat)
AWK=$(which awk)
CURL=$(which curl)               
WGET=$(which wget)
lunesnode_url="https://github.com/Lunes-platform/"
lunesnode_git="https://raw.githubusercontent.com/Lunes-platform/install_node/master/"

# ----> Inicio das Funcoes
ID=$(/usr/bin/which id)

# Get a sane screen width
[ -z "${COLUMNS:-}" ] && COLUMNS=80
# [ -z "${CONSOLETYPE:-}" ] && CONSOLETYPE="$(/sbin/consoletype)"

    BOOTUP=color
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \\033[0;39m"
    LOGLEVEL=1

echo_success() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n $"  OK  "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 0
}

echo_failure() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
  echo -n $"FAILED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

echo_passed() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"PASSED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

echo_warning() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"WARNING"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

is_root(){
   if ((${EUID:-0} || "$(/usr/bin/id -u)")); then
   echo "Este script deve ser executado como root!"
   exit 100
   fi
}

step() {
    /bin/echo -n "$@"

    STEP_OK=0
    [[ -w /tmp ]] && /bin/echo $STEP_OK > /tmp/step.$$
}

try() {
    # Check for `-b' argument to run command in the background.
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
    local BG=

    [[ $1 == -b ]] && { BG=1; shift; }
    [[ $1 == -- ]] && {       shift; }

    # Run the command.
    if [[ -z $BG ]]; then
        "$@"
    else
        "$@" &
    fi

    # Check if command failed and update $STEP_OK if so.
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -ne 0 ]]; then
        STEP_OK=$EXIT_CODE
        [[ -w /tmp ]] && /bin/echo $STEP_OK > /tmp/step.$$

        if [[ -n $LOG_STEPS ]]; then
            local FILE=$(readlink -m "${BASH_SOURCE[1]}")
            local LINE=${BASH_LINENO[0]}

            echo "$FILE: line $LINE: Command \`$*' failed with exit code $EXIT_CODE." >> "$LOG_STEPS"
        fi
    fi

    return $EXIT_CODE
}

next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); /bin/rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}

md5_check () {
    EXIT_MD5=0
    if [ ! -f /opt/lunesnode/lunesnode-latest.md5 ]; then
        echo "181818181" > /opt/lunesnode/lunesnode-latest.md5
    fi
    LOCAL_MD5=$($CAT /opt/lunesnode/lunesnode-latest.md5 | $AWK '{ print $1 }' )
    REMOTE_MD5=$($CURL -s https://lunes.io/install/lunesnode-latest.md5 | $AWK '{ print $1 }' )
    if [[ "$LOCAL_MD5" != "$REMOTE_MD5" ]]; then 
       return 
    else 
       echo "Node version is outdated."
       exit 100
    fi
}

wallet_pass () {
    mkdir -p /tmp/wallet
    cd /tmp/wallet    
    /usr/bin/java -jar /opt/lunesnode/walletgenerator.jar -p $WALLET_PASS > SENHAS.TXT
    echo $WALLET_PASS >> SENHAS.TXT
}

create_init () {
cat > /etc/systemd/system/lunesnode.service <<-  "EOF"
[Unit]
Description=Lunes Node Blockchain
After=network.target
[Service]
WorkingDirectory=/opt/lunesnode/
ExecStart=/usr/bin/java -jar /opt/lunesnode/lunesnode-latest.jar /etc/lunesnode/lunes.conf
LimitNOFILE=4096
Type=simple
User=lunesuser
Group=lunesuser
Restart=always
RestartSec=5000ms
StandardOutput=syslog
StandardError=journal
SyslogIdentifier=lunesnode
RestartPreventExitStatus=38
SuccessExitStatus=143
PermissionsStartOnly=true
TimeoutStopSec=300
[Install]
WantedBy=multi-user.target

EOF
}

get_data () {
while read line
 do
   CHAVE=$(echo -e "$line" | awk '{ print $1 }' )
   VALOR=$(echo -e "$line" | awk '{ print $3 }' )
   if [[ "$CHAVE" = "$1" ]]; then
      CHAVE_FINAL=$CHAVE
      VALOR_FINAL=$VALOR
   fi
done < /tmp/wallet/SENHAS.TXT
}

install_or_update () {
    # Valida diretórios de instalação
    UPDATE=1
    [ ! -d /opt/lunesnode ] && UPDATE=0
    [ ! -d /etc/lunesnode ] && UPDATE=0
    [ ! -f /etc/lunesnode/lunes.conf ] && UPDATE=0
}

my_ip () {
    IPV4=$(curl --silent https://checkip.amazonaws.com)
    FQDN=$(dig -x $IPV4 +short)
    NODE_NAME=$(echo "${FQDN%?}")
}

# ----> Termino das Funcoes
clear
echo -e "\e[35m"
echo "            _     _    _ _   _ ______  _____ ";
echo "           | |   | |  | | \ | |  ____|/ ____|";
echo "           | |   | |  | |  \| | |__  | (___  ";
echo "           | |   | |  | | . \`|  __|  \___ \ ";
echo "           | |___| |__| | |\  | |____ ____) |";
echo "           |______\____/|_| \_|______|_____/ ";
echo "                                             ";
echo "                                             ";
echo -e "\e[97m"
echo " "
echo " Lunes Node install script"
echo " "
echo " The script will perform the following settings at this node:"
echo " "
echo " 	* Update system packages"
echo " 	* create user lunesuser"
echo " 	* Download lunesnode.jar and github release utility software"
echo " 	* Make /opt/lunesnode and install lunesnode"
echo " 	* Make /etc/lunesnode and setup lunes.conf"
echo " 	* Make bootstrap script /etc/systemd/system/lunesnode.service"
echo " 	* Create your Wallet and SEED words"
echo " 	* Tell you about basic LunesNode commands."
echo " "
echo "*** Please, run this script as root or sudo bash! ***"
echo " "

read -p "Do you wish to proceed with install? <Y/n> " -n 1 -r


if [[ ! $REPLY =~ ^[YySs]$ ]]
   then
      exit 1
fi

# INCLUIR VALIDAÇÃO DE UPDATE !!!!
echo ""

# Valida root
step "Checking for root permissions..."
try is_root
next

# Validando necessidade de atualizacao LunesNode
step "Checking MD5 sum...."
try md5_check
next


# Atualizando pacotes
step "Updating your OS..."
try $PKG update &> /dev/null
try $PKG upgrade &> /dev/null
try $PKG install wget &> /dev/null
try $PKG install git &> /dev/null
next

# Instalando dependencia
step "Installing OpenJDK8...."
if [[ $SO != "ubuntu" ]]; then
    JRE=java-1.8.0-openjdk
else
    JRE=openjdk-8-jre
fi
try $PKG install $JRE &> /dev/null
next 

# Criação do usuário lunesuser
# Captura da Senha da Wallet"
echo ""
echo ""
echo -n "Please, set a password for lunesuser: ";
unset LUNESUSER;
while IFS= read -r -s -n1 pass; do
  if [[ -z $pass ]]; then
     echo
     break
  else
     echo -n '*'
     LUNESUSER+=$pass
  fi
done


step "Making lunesuser....."
try /usr/sbin/adduser lunesuser --gecos "Lunes User,,," --disabled-password &> /dev/null
try echo "lunesuser:$LUNESUSER" | /usr/bin/sudo chpasswd
next

# Download dos pacotes do LunesNode
cd /opt/lunesnode
step "Downloading LunesNode....."
try $WGET --no-cache "${lunesnode_url}/LunesNode/releases/download/0.0.7/lunesnode-latest.jar"  &> /dev/null
next

step "Downloading Wallet Generator...."
cd /opt/lunesnode
try $WGET --no-cache "${lunesnode_url}/WalletGenerator/releases/download/0.0.1/walletgenerator.jar"  &> /dev/null
next

# Criando o serviço
step "Setting up LunesNode service....."
try create_init
next

# Captura da Senha da Wallet"
echo ""
echo ""
echo -n "Setup a password for your Wallet: ";
unset WALLET_PASS;
while IFS= read -r -s -n1 pass; do
  if [[ -z $pass ]]; then
     echo
     break
  else
     echo -n '*'
     WALLET_PASS+=$pass
  fi
done
WALLET_PASS_FINAL=$WALLET_PASS
step "Creating Wallet for LunesNode...."
try wallet_pass
next

step "Setting up /etc/lunesnode/lunes-testnode.conf...."
mkdir /tmp/node
cd /tmp/node
try $WGET --no-cache "${lunesnode_git}/lunes-testnet.conf"  &> /dev/null
next

# Verifica IP e node do Node
my_ip
echo ""
echo ""
echo "Found network data: "
echo "    NODE: " $NODE_NAME
echo "    IPv4: " $IPV4
echo ""
read -p "Are those data correct? <Y/n> " -n 1 -r
if [[ ! $REPLY =~ ^[YySs]$ ]]
then
    echo "Please, adjust you DNS data and try again."
    exit 1
fi
NODE_NAME_FINAL=$NODE_NAME
IPV4_FINAL=$IPV4
echo ""
echo ""
step "Including NODE_NAME on lunes.conf...."
mv /tmp/node/lunes-testnet.conf /tmp/node/lunes.conf
try sed -i s/NODE_NAME/$NODE_NAME_FINAL/g /tmp/node/lunes.conf
next

step "Including IP on lunes.conf...."
try sed -i "s/IPV4/$IPV4_FINAL/g" /tmp/node/lunes.conf
next

step "Including Wallet password on lunes.conf....."
try sed -i "s/WALLET_PASS/$WALLET_PASS_FINAL/g" /tmp/node/lunes.conf
next

step "Including your SEED words on lunes.conf ....."
get_data seed_hash
try sed -i "s/WALLET_SEED/$VALOR_FINAL/g" /tmp/node/lunes.conf
next
mv /tmp/node/lunes.conf /etc/lunesnode/lunes.conf
chown -R lunesuser.lunesuser /home/lunesuser/
echo -e "\e[92m"
echo "  _____ _   _  _____ _______       _               _____   /\/|  ____  ";
echo " |_   _| \ | |/ ____|__   __|/\   | |        /\   / ____| |/\/  / __ \ ";
echo "   | | |  \| | (___    | |  /  \  | |       /  \ | |       / \ | |  | |";
echo "   | | | . \ |\___ \   | | / /\ \ | |      / /\ \| |      / _ \| |  | |";
echo "  _| |_| |\  |____) |  | |/ ____ \| |____ / ____ \ |____ / ___ \ |__| |";
echo " |_____|_| \_|_____/   |_/_/    \_\______/_/    \_\_____/_/   \_\____/ ";
echo "                                                    )_)                ";
echo "                                                                       ";

echo "   _____                 _       __    _         _ _ _ ";
echo "  / ____|               | |     /_/   | |       | | | |";
echo " | |     ___  _ __   ___| |_   _ _  __| | __ _  | | | |";
echo " | |    / _ \| '_ \ / __| | | | | |/ _\ |/ _\ | | | | |";
echo " | |___| (_) | | | | (__| | |_| | | (_| | (_| | |_|_|_|";
echo "  \_____\___/|_| |_|\___|_|\__,_|_|\__,_|\__,_| (_|_|_)";
echo "                                                       ";
echo "                                                       ";
echo -e "\e[97m"

echo "Next steps: "
echo " - on /tmp/wallet there is a file named SENHAS.TXT"
echo "   !!!!! KEEP IT !!!!!"
echo ""
echo "Basic Commands:"
echo " - Start node: systemctl start lunesnode"
echo " - Stop node: systemctl stop lunesnode"
echo " - Get node status: systemctl status lunesnode"
echo ""
echo "and welcom to Lunes Platform!"
echo

