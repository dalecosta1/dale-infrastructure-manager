#!/bin/bash

# Function to check if the OS is macOS
is_macos() {
    [ "$(uname -s)" == "Darwin" ]
}


# //////////////////////////////////////////////////////////
#  Install cli and tools required to run the project       /
# //////////////////////////////////////////////////////////

#set -euxo pipefail

# If mac_os, it checks if the architecture is arm or amd
ARCHITECTURE_FINAL=""
if is_macos; then
    # Before check if brew is installed
    if ! command -v "brew" >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew_v=$(brew --version)
        echo "[INFORMATION] Brew version: $brew_v"
        echo "[INFORMATION] Brew installed."
    fi 
    # Check system architecture now
    architecture=$(uname -m)
    if [ "$architecture" == "x86_64" ]; then
        echo "[INFORMATION] MacOS architecture: AMD64"
        ARCHITECTURE_FINAL="AMD64"
        sudo wget -qO /usr/local/bin/yq  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    elif [ "$architecture" == "arm64" ]; then
        echo "[INFORMATION] MacOS architecture: ARM"
        ARCHITECTURE_FINAL="ARM"
        sudo wget -qO /usr/local/bin/yq  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64
    else
        echo "[ERROR] Unknown architecture on macOS installing yq: $architecture"
        exit 1
    fi
fi


############################
# TOOLS & CLI INSTALLATION #
############################

# Install curl if not installed
if ! command -v "curl" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing curl..."
    if is_macos; then
        # macOS
        brew install curl
    else
        # Ubuntu
        sudo apt-get install -y curl
    fi
    echo "[INFORMATION] Curl version: $(curl --version)"
    echo "[INFORMATION] Curl installed."
fi

# Install sed if not installed
if ! command -v "sed" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing sed..."
    if is_macos; then
        # macOS
        brew install coreutils
    else
        # Ubuntu
        sudo apt-get install -y sed 
    fi
    echo "[INFORMATION] Sed version: $(sed --version)"
    echo "[INFORMATION] Sed installed."
fi

# Install jq if not installed
if ! command -v "jq" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing jq..."
    if is_macos; then
        # macOS
        brew install jq
    else
        # Ubuntu
        sudo apt-get install -y jq 
    fi
    echo "[INFORMATION] Jq version: $(jq --version)"
    echo "[INFORMATION] Jq installed."
fi

# wget
if ! command -v "wget" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing wget..."
    if is_macos; then
        # macOS
        brew install wget
    else
        # Ubuntu
        sudo apt-get install -y wget
    fi  
    echo "[INFORMATION] Wget version: $(wget --version)"
    echo "[INFORMATION] Wget installed."
fi

# unzip
if ! command -v "unzip" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing unzip..."
    if is_macos; then
        # macOS
        brew install unzip
    else
        # Ubuntu
        sudo apt-get install -y unzip
    fi
    echo "[INFORMATION] Unzip version: $(unzip --version)"
    echo "[INFORMATION] Unzip installed."
fi

# yq
if ! command -v "yq" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing yq..."  
    if is_macos; then
        # macOS.. For binaries we need to understand the architecture
        if [ "$ARCHITECTURE_FINAL" == "AMD64" ]; then
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_amd64
        elif [ "$ARCHITECTURE_FINAL" == "ARM" ]; then
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_arm64
        else
            echo "[ERROR] Unknown architecture on macOS installing yq: $ARCHITECTURE_FINAL"
            exit 1
        fi 
    else
        # Ubuntu
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    fi
    sudo chmod a+x /usr/local/bin/yq
    echo "[INFORMATION] Yq version: $(yq --version)"
    echo "[INFORMATION] Yq installed."
fi

# Python3
if ! command -v "python3" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing Python3..."
    if is_macos; then
        # macOS
        brew install python3
    else
        # Ubuntu
        sudo apt-get install -y python3
    fi
    echo "[INFORMATION] Python3 version: $(python3 --version)"
    echo "[INFORMATION] Python3 installed."
fi

# Install pipx for ansible if not installed
if ! command -v "pipx" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing pipx..."
    if is_macos; then
        # macOS
        brew install pipx
    else
        # Ubuntu
        sudo apt-get install -y pipx
    fi
    echo "[INFORMATION] Pipx version: $(pipx --version)"
    echo "[INFORMATION] Pipx installed."
fi

# Install ansible & ansible-core
if ! command -v "ansible" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing Ansible..."
    if is_macos; then
        # macOS
        brew install ansible
        brew install ansible-core
    else
        # Ubuntu
        sudo apt-get install -y ansible
        sudo apt-get install -y ansible-core
    fi
    echo "[INFORMATION] Ansible version: $(ansible -v)"
    echo "[INFORMATION] Ansible installed."
fi

# Nodejs
if ! command -v "node" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing Nodejs..."
    if is_macos; then
        # macOS
        brew install node
    else
        # Ubuntu
        sudo apt-get update
        sudo apt-get install -y nodejs
    fi
    echo "[INFORMATION] Nodejs version: $(node -v)"
    echo "[INFORMATION] Nodejs installed."
fi

# Npm
if ! command -v "npm" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing Npm..."
    if is_macos; then
        # macOS
        brew install npm
    else
        # Ubuntu
        sudo apt-get install -y npm
    fi
    echo "[INFORMATION] Npm version: $(npm -v)"
    echo "[INFORMATION] Npm installed."
fi

# Storj
if ! command -v "uplink" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing Storj CLI..."
    if is_macos; then
        # macOS
        brew install storj-uplink
    else
        # Ubuntu
        curl -L -k https://github.com/storj/storj/releases/latest/download/uplink_linux_amd64.zip -o storj-cli.zip
        unzip storj-cli.zip
        sudo chmod +x uplink
        sudo mv uplink /usr/local/bin/
        sudo rm storj-cli.zip
    fi
    echo "[INFORMATION] Storj CLI uplink installed successfully!"
fi

# Kubectl
if ! command -v "kubectl" >/dev/null 2>&1; then
    echo "Installing Kubectl..."
    if is_macos; then
        # macOS
        brew install kubectl
        brew install kubernetes-cli
    else
        # Ubuntu
        sudo apt-get install -y apt-transport-https ca-certificates
        sudo curl -fsSL "https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update -y
        sudo apt-get install -y kubectl
    fi
    echo "[INFORMATION] Kubectl version: $(kubectl version --client)"
    echo "[INFORMATION] Kubectl installed."
fi


#############################
# CHMOD SH + NPM INSTALL UI #
#############################

# Print message
echo "[INFORMATION] Making the script configure_cluster.sh executable..."

# Chmod on scripts
sudo chmod +x "$PWD/scripts/k8s_cluster_creation/configure_cluster.sh"

# Print message
echo "[INFORMATION] Making the script add_new_haproxy.sh executable..."

# Chmod on scripts
sudo chmod +x "$PWD/scripts/k8s_cluster_creation/add_new_haproxy.sh"

# Print message
echo "[INFORMATION] Initializing UI with 'npm i'..."

# Install npm packages for UI
cd $PWD/ui
sudo npm i
sudo npm i --save-dev @types/file-saver

# Come back to main folder
cd ..

# Print message
echo "[INFORMATION] Setup completed!"
