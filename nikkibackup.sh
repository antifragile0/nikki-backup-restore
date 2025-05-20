#!/bin/bash

# Define a lock file
LOCKFILE="/tmp/nikkitproxy.lock"

# Function to remove the lock file on exit
cleanup() {
    rm -f "$LOCKFILE"
    exit
}

# Check if the lock file exists
if [ -e "$LOCKFILE" ]; then
    echo "Script is already running. Exiting..."
    exit 1
else
    # Create a lock file
    touch "$LOCKFILE"
    trap cleanup EXIT
fi

cd /tmp || { echo "Failed to change directory to /tmp"; cleanup; }

echo "Script Version: 1.8"
sleep 3
clear

while true; do
    clear
    echo "================================================"
    echo "           Auto Script | nikkiTProxy           "
    echo "================================================"
    echo ""
    echo "    [*]   Auto Script By : RizkiKotet  [*]"
    echo ""
    echo "================================================"
    echo ""
    echo " >> MENU BACKUP"
    echo " > 1 - Backup Full Config"
    echo ""
    echo " >> MENU RESTORE"
    echo " > 2 - Restore Backup Full Config"
    echo ""
    echo " >> MENU CONFIG"
    echo " > 3 - Download Full Backup Config By RTA-WRT"
    echo ""
    echo "================================================"
    echo " > X - Exit Script"
    echo "================================================"
    read -r choice

    case $choice in
        1)
            echo "Backup Full Config..."
            sleep 2
            current_time=$(date +"%Y-%m-%d_%H-%M-%S")
            output_tar_gz="/root/backup_config_nikki_${current_time}.tar.gz"
            files_to_backup=(
                "/etc/nikki/mixin.yaml"
                "/etc/nikki/profiles"
                "/etc/nikki/run"
                "/etc/config/nikki"
            )
            echo "Archiving and compressing files and folders..."
            tar -czvf "$output_tar_gz" "${files_to_backup[@]}"
            if [ $? -eq 0 ]; then
                echo "Files successfully archived into $output_tar_gz"
            else
                echo "Failed to create the archive"
            fi
            sleep 3
            ;;
        2)
            echo "Restore Backup Full Config..."
            read -p "Enter the path to the backup archive (e.g., /tmp/backup.tar.gz): " backup_file
            if [ -f "$backup_file" ]; then
                echo "Restoring files..."
                tar -xzvf "$backup_file" -C / --overwrite
                if [ $? -eq 0 ]; then
                    echo "Backup successfully restored and files overwritten."
                else
                    echo "Failed to restore from the backup."
                fi
            else
                echo "Backup file does not exist: $backup_file"
            fi
            sleep 3
            ;;
        3)
            echo "Download Full Backup Config By RTA-WRT"
            sleep 2
            wget -O /tmp/main.zip https://github.com/rtaserver/Config-Open-ClashMeta/archive/refs/heads/main.zip
            unzip -o /tmp/main.zip -d /tmp  # Use -o to overwrite existing files
            rm -rf /tmp/main.zip
            cd /tmp/Config-Open-ClashMeta-main || { echo "Failed to change directory"; cleanup; }
            mv -f config/Country.mmdb /etc/nikki/run/Country.mmdb && chmod +x /etc/nikki/run/Country.mmdb
            mv -f config/GeoIP.dat /etc/nikki/run/GeoIP.dat && chmod +x /etc/nikki/run/GeoIP.dat
            mv -f config/GeoSite.dat /etc/nikki/run/GeoSite.dat && chmod +x /etc/nikki/run/GeoSite.dat
            mv -fT config/proxy_provider /etc/nikki/run/proxy_provider && chmod +x /etc/nikki/run/proxy_provider/*
            mv -fT config/rule_provider /etc/nikki/run/rule_provider && chmod +x /etc/nikki/run/rule_provider/*
            mv -f confignikki/cache.db /etc/nikki/run/cache.db && chmod +x /etc/nikki/run/cache.db
            mv -f confignikki/config-wrt.yaml /etc/nikki/profiles/config-wrt.yaml && chmod +x /etc/nikki/profiles/config-wrt.yaml
            mv -f confignikki/config.yaml /etc/nikki/run/config.yaml && chmod +x /etc/nikki/run/config.yaml
            mv -f confignikki/nikki /etc/config/nikki
            rm -rf /tmp/Config-Open-ClashMeta-main
            clear
            echo "Download Dashboard Yacd"
            sleep 2
            cd /tmp
            wget -O /tmp/gh-pages.zip https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip
            unzip -o /tmp/gh-pages.zip -d /tmp  # Use -o to overwrite existing files
            rm -rf /tmp/gh-pages.zip
            mv -fT /tmp/Yacd-meta-gh-pages /etc/nikki/run/ui/dashboard
            echo "Installation completed successfully!"
            sleep 3
            ;;
        x|X)
            echo "Exiting..."
            cleanup
            ;;
        *)
            echo "Invalid option selected!"
            ;;
    esac

    echo "Returning to the menu..."
    cd /tmp || { echo "Failed to change directory to /tmp"; cleanup; }
    sleep 2
done
