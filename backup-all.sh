#!/bin/sh

# Daftar URL
URLS=(
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/nikkibackup.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/sync_time.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/s"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/vnstat.db"
)

# Daftar lokasi tujuan
DESTINATIONS=(
    "/usr/bin"
    "/usr/bin"
    "/usr/bin"
    "/etc/vnstat"
)

# Fungsi untuk mengunduh dan mengatur izin file
download_and_set_permissions() {
    local url=$1
    local dest_folder=$2
    local filename=$(basename $url)
    local dest_path="$dest_folder/$filename"

    # Buat folder tujuan jika belum ada
    mkdir -p $dest_folder

    echo "Mengunduh $filename ke $dest_folder..."
    wget -O $dest_path $url

    if [ $? -eq 0 ]; then
        echo "Unduhan berhasil. Mengatur izin..."
        chmod 0755 $dest_path
    else
        echo "Gagal mengunduh $filename."
    fi
}

# Proses setiap file
for i in "${!URLS[@]}"; do
    download_and_set_permissions "${URLS[$i]}" "${DESTINATIONS[$i]}"
done
