#!/bin/bash

# Define color codes
YELLOW='\033[1;33m'  # Bold Yellow
GREEN='\033[1;32m'   # Bold Green
RED='\033[1;31m'     # Bold Red
NC='\033[0m'         # No Color

# Function to display help
show_help() {
    echo -e "${YELLOW}Usage: ./xray.sh -f <file.txt> | -s <url> | -d | -h${NC}"
    echo -e "  -f <file.txt>   Scan a list of URLs from a file."
    echo -e "  -s <url>       Scan a single URL."
    echo -e "  -d             Download Xray if not installed."
    echo -e "  -h             Display this help message."
}

# Check if xray exists
if [ -f "/usr/bin/xray" ]; then
    echo -e "${GREEN}Xray is already available.${NC}"
else
    # If -d is specified, download Xray
    if [[ "$1" == "-d" ]]; then
        echo -e "${YELLOW}Xray not found. Downloading...${NC}"
        wget -nv https://github.com/chaitin/xray/releases/download/1.8.2/xray_linux_amd64.zip
        if [ $? -ne 0 ]; then
            echo -e "${RED}Download failed! Please check your internet connection or the URL.${NC}"
            exit 1
        fi

        # Create a virtual environment for installing yamllint
        python3 -m venv venv
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create virtual environment. Please ensure python3-venv is installed.${NC}"
            exit 1
        fi

        source venv/bin/activate
        pip install --upgrade pip
        pip install yamllint || { echo -e "${RED}Failed to install yamllint.${NC}"; exit 1; }
        
        unzip xray_linux_amd64.zip || { echo -e "${RED}Unzip failed!${NC}"; exit 1; }
        mv xray_linux_amd64 xray
        chmod +x ./xray
        mv xray /usr/bin/ || { echo -e "${RED}Failed to move xray to /usr/bin.${NC}"; exit 1; }
        echo -e "${GREEN}Xray downloaded successfully.${NC}"
        
        deactivate
        rm -rf venv xray_linux_amd64.zip  # Remove virtual environment and downloaded ZIP
        exit 0
    else
        echo -e "${RED}Xray not found. Use -d to download.${NC}"
        exit 1
    fi
fi

# Parse command line arguments
while getopts ":f:s:h" opt; do
    case ${opt} in
        f )
            if [ -f "$OPTARG" ]; then
                domains=$(<"$OPTARG")
            else
                echo -e "${RED}File not found: $OPTARG${NC}"
                exit 1
            fi
            ;;
        s )
            domain="$OPTARG"
            ;;
        h )
            show_help
            exit 0
            ;;
        \? )
            echo -e "${RED}Invalid option: $OPTARG${NC}" 1>&2
            show_help
            exit 1
            ;;
    esac
done

# If no domains are set, prompt for a single URL
if [ -z "$domains" ] && [ -z "$domain" ]; then
    echo -e "${RED}No input provided. Please specify a domain or a file.${NC}"
    show_help
    exit 1
fi

# Use the domain variable for scanning
if [ ! -z "$domain" ]; then
    domains="$domain"
fi

# Convert domains to an array
IFS=',' read -r -a domain_array <<< "$domains"

# Scan each domain
for domain in "${domain_array[@]}"; do
    domain=$(echo "$domain" | xargs)  # Trim whitespace
    echo -e "${YELLOW}Scanning $domain...${NC}"
    
    # Run the scan and output both to the terminal and to the file
    xray ws --basic-crawler --plugins xss,sqldet,cmd-injection,dirscan,path-traversal,xxe,phantasm,upload,brute-force,jsonp,ssrf,baseline,redirect,crlf-injection,xstream,struts,thinkphp,shiro,fastjson "$domain" --html-output | tee -a vuln.txt || {
        echo -e "${RED}Scan failed for $domain${NC}"
        continue
    }
done

# Process output
if [ -f vuln.txt ]; then
    sort vuln.txt | uniq > temp && mv temp vuln.txt
    echo -e "${GREEN}Scanning complete. Results saved to vuln.txt.${NC}"
else
    echo -e "${RED}No output generated.${NC}"
fi
