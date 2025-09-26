#!/bin/sh

# ==============================================================================
# Skrip untuk Mengunduh dan Mengonfigurasi File di OpenWrt
# Deskripsi: Skrip ini menyediakan menu interaktif untuk mengunduh file,
#            mengatur izin, menambahkan tugas startup, dan mengonfigurasi
#            aturan firewall (FIX TTL).
# ==============================================================================

# ------------------------------------------------------------------------------
# KONFIGURASI
# ------------------------------------------------------------------------------
# Daftar URL file yang akan diunduh
readonly URLS=(
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/nikkibackup.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/sync_time.sh"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/s"
    "https://github.com/antifragile0/nikki-backup-restore/raw/refs/heads/main/vnstat.db"
)

# Daftar direktori tujuan yang sesuai dengan URLS
readonly DESTINATIONS=(
    "/usr/bin"
    "/usr/bin"
    "/usr/bin"
    "/etc/vnstat"
)

# Daftar nama file yang memerlukan izin eksekusi (+x)
readonly EXECUTABLE_FILES=(
    "nikkibackup.sh"
    "sync_time.sh"
    "s"
)

# ==============================================================================
# FUNGSI UTILITAS
# ==============================================================================

# Fungsi untuk mencatat pesan dengan stempel waktu
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Fungsi untuk memeriksa apakah sebuah file ada di dalam daftar file eksekusi
is_executable() {
    local filename="$1"
    local exec_file
    for exec_file in "${EXECUTABLE_FILES[@]}"; do
        if [ "$filename" = "$exec_file" ]; then
            return 0 # 0 artinya true (ditemukan)
        fi
    done
    return 1 # 1 artinya false (tidak ditemukan)
}

# ==============================================================================
# FUNGSI INTI
# ==============================================================================

# Fungsi untuk mengunduh file, membackup yang lama, dan mengatur izin
download_and_setup_file() {
    local url="$1"
    local dest_folder="$2"
    local filename
    filename=$(basename "$url")
    local dest_path="$dest_folder/$filename"

    # Buat direktori tujuan jika belum ada
    if [ ! -d "$dest_folder" ]; then
        log "Membuat direktori $dest_folder..."
        mkdir -p "$dest_folder" || { log "Gagal membuat direktori $dest_folder."; return 1; }
    fi

    # Backup file yang ada jika ditemukan
    if [ -f "$dest_path" ]; then
        log "Membackup file lama: $dest_path -> ${dest_path}.bak"
        mv "$dest_path" "${dest_path}.bak" || { log "Gagal membackup $dest_path."; return 1; }
    fi

    # Unduh file menggunakan wget
    log "Mengunduh $filename ke $dest_folder..."
    if ! wget -q -O "$dest_path" "$url"; then
        log "Gagal mengunduh $filename dari $url."
        return 1
    fi
    
    log "Unduhan $filename berhasil."

    # Atur izin file
    if is_executable "$filename"; then
        chmod 0755 "$dest_path" || { log "Gagal mengatur izin eksekusi untuk $dest_path."; return 1; }
        log "Izin eksekusi (0755) diterapkan pada $dest_path."
    else
        chmod 0644 "$dest_path" || { log "Gagal mengatur izin standar untuk $dest_path."; return 1; }
        log "Izin standar (0644) diterapkan pada $dest_path."
    fi

    # Jika file adalah sync_time.sh, tambahkan ke startup
    if [ "$filename" = "sync_time.sh" ]; then
        add_startup_task
    fi
}

# Fungsi untuk menambahkan sync_time.sh ke /etc/rc.local
add_startup_task() {
    local rc_local="/etc/rc.local"
    local startup_cmd="sleep 60 && /usr/bin/sync_time.sh google.com"

    log "Menambahkan tugas startup untuk sync_time.sh..."
    # Buat file jika tidak ada dan pastikan executable
    if [ ! -f "$rc_local" ]; then
        log "Membuat file $rc_local..."
        (
            echo "#!/bin/sh"
            echo ""
            echo "exit 0"
        ) > "$rc_local"
    fi
    chmod 0755 "$rc_local"

    # Periksa apakah perintah sudah ada
    if grep -qF "$startup_cmd" "$rc_local"; then
        log "Tugas startup sudah ada di $rc_local."
        return 0
    fi

    # Tambahkan perintah sebelum "exit 0"
    if sed -i "/^exit 0/i $startup_cmd" "$rc_local"; then
        log "Tugas startup berhasil ditambahkan ke $rc_local."
    else
        log "Gagal menambahkan tugas startup ke $rc_local."
        return 1
    fi
}

# Fungsi untuk menambahkan aturan FIX TTL ke nftables
add_fix_ttl_rules() {
    local nft_dir="/etc/nftables.d"
    local nft_file="$nft_dir/10-custom-filter-chains.nft"
    # Menggunakan 'cat <<EOF' untuk teks multi-baris yang lebih bersih
    local nft_rules
    nft_rules=$(cat <<EOF
chain mangle_postrouting_tt65 {
    type filter hook postrouting priority 300; policy accept;
    counter ip ttl set 65
}
chain mangle_prerouting_ttl65 {
    type filter hook prerouting priority 300; policy accept;
    counter ip ttl set 65
}
EOF
)

    log "Menambahkan aturan FIX TTL ke nftables..."
    # Buat direktori jika belum ada
    if [ ! -d "$nft_dir" ]; then
        log "Membuat direktori $nft_dir..."
        mkdir -p "$nft_dir" || { log "Gagal membuat direktori $nft_dir."; return 1; }
    fi

    # Periksa apakah aturan sudah ada
    if [ -f "$nft_file" ] && grep -q "chain mangle_postrouting_tt65" "$nft_file"; then
        log "Aturan FIX TTL sepertinya sudah ada di $nft_file."
        return 0
    fi

    # Tambahkan aturan ke file
    log "Menulis aturan FIX TTL ke $nft_file..."
    echo "$nft_rules" >> "$nft_file" || { log "Gagal menulis ke $nft_file."; return 1; }
    chmod 0644 "$nft_file"

    # Muat ulang nftables jika tersedia
    if command -v nft >/dev/null 2>&1; then
        log "Memuat ulang aturan nftables..."
        if ! nft flush ruleset && nft -f "$nft_file"; then
             log "Gagal memuat ulang nftables. Periksa konfigurasi Anda."
             return 1
        fi
        log "Aturan nftables berhasil dimuat ulang."
    else
        log "Peringatan: Perintah 'nft' tidak ditemukan. Aturan ditambahkan tetapi belum aktif."
    fi

    log "Aturan FIX TTL berhasil ditambahkan."
}

# ==============================================================================
# FUNGSI UTAMA (MAIN)
# ==============================================================================
main() {
    # Validasi dependensi
    for cmd in wget sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "Error: Perintah '$cmd' tidak ditemukan. Mohon install terlebih dahulu."
            exit 1
        fi
    done

    # Validasi konsistensi konfigurasi
    if [ ${#URLS[@]} -ne ${#DESTINATIONS[@]} ]; then
        log "Error: Konfigurasi tidak sinkron. Jumlah URL tidak sama dengan jumlah tujuan."
        exit 1
    fi

    # Bangun opsi menu dari konfigurasi
    local options=()
    local i
    for i in "${!URLS[@]}"; do
        options+=("$(basename "${URLS[$i]}")")
    done
    options+=("FIX TTL" "Semua" "Keluar")

    # Tampilkan menu interaktif
    log "Pilih file atau opsi yang ingin di-restore:"
    PS3="Masukkan nomor pilihan: "
    select opt in "${options[@]}"; do
        case "$opt" in
            "Keluar")
                log "Keluar dari skrip."
                exit 0
                ;;
            "Semua")
                log "Memproses semua file dan FIX TTL..."
                local total=${#URLS[@]}
                for i in $(seq 0 $((total - 1))); do
                    download_and_setup_file "${URLS[$i]}" "${DESTINATIONS[$i]}"
                done
                add_fix_ttl_rules
                break
                ;;
            "FIX TTL")
                log "Memproses FIX TTL..."
                add_fix_ttl_rules
                break
                ;;
            "") 
                # Input kosong (misalnya menekan Enter)
                log "Pilihan tidak valid. Silakan coba lagi."
                ;;
            *)
                # Pilihan file individu
                log "Memproses file: $opt"
                local found=0
                for i in "${!URLS[@]}"; do
                    if [ "$(basename "${URLS[$i]}")" = "$opt" ]; then
                        download_and_setup_file "${URLS[$i]}" "${DESTINATIONS[$i]}"
                        found=1
                        break
                    fi
                done
                if [ "$found" -eq 0 ]; then
                    log "Terjadi kesalahan dalam memilih file."
                fi
                break
                ;;
        esac
    done

    log "Proses selesai."
}

# ==============================================================================
# EKSEKUSI SKRIP
# ==============================================================================
main "$@"
