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

# Fungsi untuk menambahkan startup task untuk sync_time.sh
add_startup_task() {
    local rc_local="/etc/rc.local"
    local startup_cmd="sleep 60 && /usr/bin/sync_time.sh google.com &"
    
    # Pastikan rc.local ada dan executable
    if [ ! -f "$rc_local" ]; then
        log "Membuat $rc_local..."
        echo "#!/bin/sh" > "$rc_local" || { log "Gagal membuat $rc_local."; return 1; }
    fi
    chmod 0755 "$rc_local" || { log "Gagal mengatur izin untuk $rc_local."; return 1; }

    # Periksa apakah perintah sudah ada
    if grep -Fx "$startup_cmd" "$rc_local" >/dev/null; then
        log "Startup task untuk sync_time.sh sudah ada di $rc_local."
        return 0
    fi

    # Tambahkan perintah sebelum 'exit 0' jika ada, atau di akhir file
    if grep -q "^exit 0" "$rc_local"; then
        sed -i "/^exit 0/i $startup_cmd" "$rc_local" || { log "Gagal menambahkan startup task ke $rc_local."; return 1; }
    else
        echo "$startup_cmd" >> "$rc_local" || { log "Gagal menambahkan startup task ke $rc_local."; return 1; }
    fi
    log "Startup task untuk sync_time.sh berhasil ditambahkan ke $rc_local."
    return 0
}

# Fungsi untuk menambahkan aturan FIX TTL ke nftables
add_fix_ttl_rules() {
    local nft_file="/etc/nftables.d/10-custom-filter-chains.nft"
    local nft_rules="
chain mangle_postrouting_tt65 {
     type filter hook postrouting priority 300; policy accept;
     counter ip ttl set 65
}
chain mangle_prerouting_ttl65 {
     type filter hook prerouting priority 300; policy accept;
     counter ip ttl set 65
}"

    # Validasi folder nftables
    local nft_dir=$(dirname "$nft_file")
    if [ ! -d "$nft_dir" ]; then
        log "Membuat folder $nft_dir..."
        mkdir -p "$nft_dir" || { log "Gagal membuat folder $nft_dir."; return 1; }
    fi

    # Backup file jika sudah ada
    if [ -f "$nft_file" ]; then
        local backup_path="$nft_file.bak"
        log "Membackup $nft_file ke $backup_path..."
        cp "$nft_file" "$backup_path" || { log "Gagal membackup $nft_file."; return 1; }
    fi

    # Periksa apakah aturan sudah ada
    if [ -f "$nft_file" ] && grep -q "chain mangle_postrouting_tt65" "$nft_file" && grep -q "chain mangle_prerouting_ttl65" "$nft_file"; then
        log "Aturan FIX TTL sudah ada di $nft_file."
        return 0
    fi

    # Tambahkan aturan ke file
    log "Menambahkan aturan FIX TTL ke $nft_file..."
    echo "$nft_rules" >> "$nft_file" || { log "Gagal menambahkan aturan FIX TTL ke $nft_file."; return 1; }
    chmod 0644 "$nft_file" || { log "Gagal mengatur izin untuk $nft_file."; return 1; }

    # Muat ulang nftables untuk menerapkan aturan
    if command -v nft >/dev/null 2>&1; then
        log "Memuat ulang nftables..."
        nft flush ruleset && nft -f "$nft_file" || { log "Gagal memuat ulang nftables."; return 1; }
    else
        log "Peringatan: nftables tidak ditemukan. Aturan ditambahkan tetapi tidak diterapkan."
    fi

    log "Aturan FIX TTL berhasil ditambahkan ke $nft_file."
    return 0
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
        # Tambahkan startup task jika file adalah sync_time.sh
        if [ "$filename" = "sync_time.sh" ]; then
            add_startup_task || return 1
        fi
    else
        log "Gagal mengunduh $filename dari $url."
        return 1
    fi
}

# Validasi dependensi
command -v wget >/dev/null 2>&1 || { log "Error: wget tidak ditemukan. Silakan instal wget."; exit 1; }
command -v sed >/dev/null 2>&1 || { log "Error: sed tidak ditemukan. Silakan instal sed."; exit 1; }

# Validasi panjang array
if [ ${#URLS[@]} -ne ${#DESTINATIONS[@]} ]; then
    log "Error: Jumlah URL (${#URLS[@]}) tidak sesuai dengan jumlah tujuan (${#DESTINATIONS[@]})."
    exit 1
fi

# Bangun opsi menu
OPTIONS=()
for i in "${!URLS[@]}"; do
    filename=$(basename "${URLS[$i]}")
    OPTIONS+=("$filename")
done
OPTIONS+=("FIX TTL" "Semua" "Keluar")

# Tampilkan menu interaktif
log "Pilih file atau opsi yang ingin di-restore:"
PS3="Masukkan nomor pilihan: "
select opt in "${OPTIONS[@]}"; do
    if [ "$opt" = "Keluar" ]; then
        log "Keluar dari skrip."
        exit 0
    elif [ "$opt" = "Semua" ]; then
        selected_indices=$(seq 0 $(( ${#URLS[@]} - 1 )))
        selected_fix_ttl=1
        break
    elif [ "$opt" = "FIX TTL" ]; then
        selected_fix_ttl=1
        break
    elif [ -n "$opt" ]; then
        # Cari indeks file yang dipilih
        for i in "${!URLS[@]}"; do
            if [ "$(basename "${URLS[$i]}")" = "$opt" ]; then
                selected_indices="$i"
                break 2
            fi
        done
        log "Pilihan tidak valid. Silakan pilih lagi."
    else
        log "Pilihan tidak valid. Silakan pilih lagi."
    fi
done

# Proses file yang dipilih
success_count=0
failure_count=0

# Proses file unduhan
for i in $selected_indices; do
    download_and_set_permissions "${URLS[$i]}" "${DESTINATIONS[$i]}"
    if [ $? -eq 0 ]; then
        success_count=$((success_count + 1))
    else
        failure_count=$((failure_count + 1))
    fi
done

# Proses FIX TTL jika dipilih
if [ -n "$selected_fix_ttl" ]; then
    add_fix_ttl_rules
    if [ $? -eq 0 ]; then
        success_count=$((success_count + 1))
    else
        failure_count=$((failure_count + 1))
    fi
fi

# Ringkasan
log "Proses selesai. Berhasil: $success_count, Gagal: $failure_count."
[ $failure_count -eq 0 ] && exit 0 || exit 1
