#!/bin/sh

# Daftar URL dan lokasi tujuan
FILES=(
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/nikkibackup.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/sync_time.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/s"
)

# Folder tujuan
DEST_FOLDER="/usr/bin"

# Fungsi untuk mengunduh dan mengatur izin file
download_and_set_permissions() {
    local url=$1
    local dest_folder=$2
    local filename=$(basename $url)
    local dest_path="$dest_folder/$filename"

    echo "Mengunduh $filename..."
    wget -O $dest_path $url

    if [ $? -eq 0 ]; then
        echo "Unduhan berhasil. Mengatur izin..."
        chmod 0755 $dest_path
    else
        echo "Gagal mengunduh $filename."
    fi
}

# Proses setiap file
for file_url in "${FILES[@]}"; do
    download_and_set_permissions $file_url $DEST_FOLDER
done
