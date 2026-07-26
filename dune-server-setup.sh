#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

G_SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOWNLOAD_PATH="$G_SCRIPT_PATH/download"
STEAM_APP_ID=4754530

K3S_CONFIG_DIR="/etc/rancher/k3s"

RUN_STEAM_INSTALL=false
RUN_STEAM_INSTALL_ONLY=false

while getopts "sSh" opt; do
    case "$opt" in
        s)
        echo "Setting Steam install flag ..."
        RUN_STEAM_INSTALL=true
        ;;

        S)
        echo "Setting exit after Steam install flag ..."
        RUN_STEAM_INSTALL=true
        RUN_STEAM_INSTALL_ONLY=true
        ;;
        
        h)
        echo -e "==== Help ====\n" \
            "    -s\t\tRun with Steam install\n" \
            "    -h\t\tShow help\n" \
            "=============="
        exit 0
        ;;

        :|?)
        exit 1
        ;;
    esac
done

sudo echo "prepare sudo privilege..." >/dev/null

k3s_not_present=false
skip_k3s_config=false
if [ -z "$(which k3s)" ]; then
    echo -e "$RED=== ERROR: k3s is not installed$NC"
    k3s_not_present=true
else
    echo -e "$NS=== INFO: k3s found... checking for blocking custom configurations..."

    if [ -f "$K3S_CONFIG_DIR/config.yaml" ] || [ -f "$K3S_CONFIG_DIR/scheduler.yaml" ]; then
        echo -e "$YELLOW=== WARNING: k3s custom configurations files found... k3s configuration will be skipped and server may not work as expected.$NC"
        skip_k3s_config=true
    fi
fi

steamcmd_not_present=false
if [ -z "$(which steamcmd)" ]; then
    echo -e "$RED=== ERROR: steamcmd is not installed$NC"
    steamcmd_not_present=true
fi

if $k3s_not_present || $steamcmd_not_present ; then
    echo -e "$RED=== ERROR: ensure k3s and steamcmd are installed or k3s custom configuration files found$NC"
    exit 1
fi

# copy k3s custom configs - only if not done already
if ! (([ -f "$K3S_CONFIG_DIR/config.yaml" ] && [ -f "$K3S_CONFIG_DIR/scheduler.yaml" ]) || $skip_k3s_config); then
    echo -e "$NC=== INFO: Prepare k3s custom configurations..."

    sudo systemctl stop k3s

    sudo cp "$G_SCRIPT_PATH/all_k3s_resources/k3s_configs/config.yaml" "$K3S_CONFIG_DIR/config.yaml"
    sudo cp "$G_SCRIPT_PATH/all_k3s_resources/k3s_configs/scheduler.yaml" "$K3S_CONFIG_DIR/scheduler.yaml"

    sudo systemctl start k3s
fi


# download server client from Steam
matches_file="$G_SCRIPT_PATH/file_matches.txt"
regex_matches=( $(cat $matches_file 2> /dev/null) )

if $RUN_STEAM_INSTALL || $RUN_STEAM_INSTALL_ONLY ; then
    echo -e "$NC=== INFO: Steam app download/update..."
    steamcmd +force_install_dir "$DOWNLOAD_PATH" +login anonymous +app_update $STEAM_APP_ID +logoff +quit

    if $RUN_STEAM_INSTALL_ONLY ; then
        rm $matches_file 2> /dev/null 
        exit 0
    fi
fi

# create missing setup folder structure
mkdir -p ~/.dune/bin

# search for rc-service commands in sh scripts
echo -e "$NC=== INFO: Replace rc-service|rc-update commands and adjust Dune user path in sh scripts..."
if $RUN_STEAM_INSTALL  || [ -z $regex_matches ]; then
    grep -rl "rc-service\|rc-update\|/home/dune/.dune\|\$DUNE_USER_PATH/download\|\$(cd ~ && pwd)/.dune/download" $DOWNLOAD_PATH > $matches_file
fi

for file in ${regex_matches[@]}; do
    echo -e "$NC - Processing $file ..."
    sed -e "s/\(rc-service\)\s\([a-zA-Z0-9]*\)\s\([a-zA-Z0-9]*\)/systemctl \3 \2/g" \
        -e "s/\(rc-update\)\sadd\s\([^swap][a-zA-Z0-9]*\)/systemctl enable \2/g" \
        -e "s/\/home\/dune/\$\(cd ~ \&\& pwd\)/g" \
        -e "s/\$DUNE_USER_PATH\/download/${DOWNLOAD_PATH//\//\\\/}/g" \
        -e "s/\$(cd ~ && pwd)\/\.dune\/download/${DOWNLOAD_PATH//\//\\\/}/g" -i $file
done

# create missing k3s resources
FIRST_RUN_DONE="$G_SCRIPT_PATH/.first_run_done"
if [ ! -f "$FIRST_RUN_DONE" ]; then
    kubectl_create_log="$G_SCRIPT_PATH/kubectl_create.log"
    echo "==== Kubectl Create Log ====" | tee $kubectl_create_log

    if [ -z "$(sudo kubectl get namespace cert-manager --no-headers -o name)" ]; then
        echo "=== INFO: Install cert-manager..."
        sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.0/cert-manager.crds.yaml 2>&1 | tee -a $kubectl_create_log 
        sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.0/cert-manager.yaml 2>&1 | tee -a $kubectl_create_log
    fi
    
    echo -e "$NC=== INFO: Wait for cert-manger services to load..."
    sleep 10

    echo -e "$NC=== INFO: Install missing initial funcom resources..."
    sudo kubectl create -f $DOWNLOAD_PATH/images/operators/crds/,$G_SCRIPT_PATH/all_k3s_resources/namespaces/,$G_SCRIPT_PATH/all_k3s_resources/ 2>&1 | tee -a $kubectl_create_log

    touch "$FIRST_RUN_DONE"
fi

# call the main server setup file
$DOWNLOAD_PATH/scripts/setup.sh

echo -e "${GREEN}Setup completed.\nrun '$G_SCRIPT_PATH/download/scripts/battlegroup.sh' to start/stop the battlegroup or check its status."