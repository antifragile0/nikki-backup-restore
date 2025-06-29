#!/bin/sh

# Daftar URL dan tujuan
URLS=(
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/nikkibackup.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/sync_time.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/s"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/vnstat.db"
)

DESTINATIONS=(
    "/usr/bin"
    "/usr/bin"
    "/usr/bin"
    "/etc/vnstat"
)

# File yang memerlukan izin eksekusi
EXECUTABLE_FILES=("nikkibackup.sh" "sync_time.sh" "s")

# Fungsi untuk memeriksa apakah file memerlukan izin eksekusi
is_executable() {
    local filename=$1
    for exec_file in "${EXECUTABLE_FILES[@]}"; do
        [ "$filename" = "$exec_file" ] && return 0
    done
    return 1
}

# Fungsi untuk logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Fungsi untuk mengunduh dan mengatur file
download_and_set_permissions() {
    local url=$1
    local dest_folder=$2
    local filename=$(basename "$url")
    local dest_path="$dest_folder/$filename"
    local backup_path="$dest_path.bak"

    # Validasi folder tujuan
    if [ ! -d "$dest_folder" ]; then
        log "Membuat folder $dest_folder..."
        mkdir -p "$dest_folder" || { log "Gagal membuat folder $dest_folder."; return 1; }
    fi

    # Backup file jika sudah ada
    if [ -f "$dest_path" ]; then
        log "Membackup $dest_path ke $backup_path..."
        mv "$dest_path" "$backup_path" || { log "Gagal membackup $dest_path."; return 1; }
    fi

    # Unduh file
    log "Mengunduh $filename ke $dest_folder..."
    wget -q -O "$dest_path" "$url" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "Unduhan $filename berhasil."
        # Atur izin
        if is_executable "$filename"; then
            chmod 0755 "$dest_path" || { log "Gagal mengatur izin eksekusi untuk $dest_path."; return 1; }
            log "Izin eksekusi diterapkan pada $dest_path."
        else
            chmod 0644 "$dest_path" || { log "Gagal mengatur izin untuk $dest_path."; return 1; }
            log "Izin standar diterapkan pada $dest_path."
        fi
    else
        log "Gagal mengunduh $filename dari $url."
        return 1
    fi
}

# Validasi dependensi
command -v wget >/dev/null 2>&1 || { log "Error: wget tidak ditemukan. Silakan instal wget."; exit 1; }

# Validasi panjang array
if [ ${#URLS[@]} -ne ${#DESTINATIONS[@]} ]; then
    log "Error: Jumlah URL (${#URLS[@]}) tidak sesuai dengan jumlah tujuan (${#DESTINATIONS[@]})."
    exit 1
fi

# Proses setiap file
success_count=0
failure_count=0

for i in "${!URLS[@]}"; do
    download_and_set_permissions "${URLS[$i]}" "${DESTINATIONS[$i]}"
    if [ $? -eq 0 ]; then
        success_count=$((success_count + 1))
    else
        failure_count=$((failure_count + 1))
    fi
done

# Ringkasan
log "Proses selesai. Berhasil: $success_count, Gagal: $failure_count."
[ $failure_count -eq 0 ] && exit 0 || exit 1
