#!/bin/bash

 read -p "Enter miner number: " Miner

# Nama file konfigurasi
CONFIG_FILE="miner$Miner.conf"

# Fungsi untuk membaca atau membuat konfigurasi
load_config() {
  # Jika file konfigurasi tidak ditemukan, buat baru
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "File konfigurasi tidak ditemukan. Membuat file baru..."

    # Meminta input dari pengguna untuk setiap parameter
    read -p "Enter your wallet (e.g., TEXASSDSA): " WALLET
    read -p "Enter number of threads (e.g., 80): " THREAD
    read -p "Enter your Type (e.g., AVX512): " TYPE

    # Validasi nama worker minimal 4 karakter
    while true; do
      read -p "Enter worker name (min 4 characters, e.g., Rig_XAS): " NAME
      if [ ${#NAME} -ge 4 ]; then
        break
      else
        echo "Worker name harus memiliki minimal 4 karakter. Silakan coba lagi."
      fi
    done

    # Meminta input dari pengguna untuk normal mode
    read -p "Enable normal mode (disables speedhack)? (true/false) (e.g., true): " NORMAL

    # Jika normal mode true, speed di-set ke 1, jika false tanyakan
    if [ "$NORMAL" = "true" ]; then
      SPEED=1
      echo "Normal mode diaktifkan. Miner speed diatur ke nilai default 1."
    else
      read -p "Enter miner speed (e.g., 0.6): " SPEED
    fi

    read -p "Enable Verus mining? (true/false) (e.g., true): " RunVerus

    # Menuliskan input pengguna ke file konfigurasi
    echo "TYPE=$TYPE" > "$CONFIG_FILE"  # Default ke AVX2
    echo "WALLET=$WALLET" >> "$CONFIG_FILE"
    echo "THREAD=$THREAD" >> "$CONFIG_FILE"
    echo "NAME=$NAME" >> "$CONFIG_FILE"
    echo "Miner=$Miner" >> "$CONFIG_FILE"
    echo "SPEED=$SPEED" >> "$CONFIG_FILE"
    echo "RunVerus=$RunVerus" >> "$CONFIG_FILE"
    echo "NORMAL=$NORMAL" >> "$CONFIG_FILE"

    echo "Konfigurasi telah disimpan ke $CONFIG_FILE."
  fi

  # Memuat konfigurasi dari file
  source "$CONFIG_FILE"
}

# Panggil fungsi untuk memuat atau membuat konfigurasi
load_config

# --- Script utama dimulai di sini, setelah konfigurasi di-load ---
echo "Menggunakan konfigurasi:"
echo "TYPE: $TYPE"
echo "WALLET: $WALLET"
echo "THREAD: $THREAD"
echo "NAME: $NAME"
echo "Miner: $Miner"
echo "SPEED: $SPEED"
echo "RunVerus: $RunVerus"
echo "NORMAL: $NORMAL"

#Deklarasi Variable
first_loop=true  # Menandakan iterasi pertama
first_idling=true  # Menandakan iterasi pertama
bIdle=false  # Variabel untuk menentukan apakah dalam status idle

# Direktori dasar
MINER_BASE_PATH=~/Mining/Qubic/
SANTET_BASE_PATH=~/Mining/MySantet/
LOG_DIR=~/Mining/Qubic/QubicMine"${Miner}"  # Direktori tempat log disimpan
MINER_LOG_PATH="${LOG_DIR}/miner.log"  # Path ke log miner
SANTET_PIPE="/tmp/santet${Miner}_pipe"

# Membuat file log miner jika belum ada
if [ ! -f "$MINER_LOG_PATH" ]; then
  touch "$MINER_LOG_PATH"
fi

# Fungsi untuk memeriksa apakah cpu_avx512_trainer sedang berjalan
check_cpu_avx512_trainer() {
  CPU_AVX_TRAINER_PIDS=$(pgrep -f cpu_avx512_trainer)
  if [ -z "$CPU_AVX_TRAINER_PIDS" ]; then
    return 0
  else
    return 1
  fi
}

# Fungsi untuk memeriksa apakah cpu_avx2_trainer sedang berjalan
check_cpu_avx2_trainer() {
  CPU_AVX_TRAINER_PIDS=$(pgrep -f cpu_avx2_trainer)
  if [ -z "$CPU_AVX_TRAINER_PIDS" ]; then
    return 0
  else
    return 1
  fi
}

# Fungsi untuk memeriksa apakah gpu_cuda_trainer sedang berjalan
check_gpu_cuda_trainer() {
  GPU_CUDA_TRAINER_PIDS=$(pgrep -f gpu_cuda_trainer)
  if [ -z "$GPU_CUDA_TRAINER_PIDS" ]; then
    return 0
  else
    return 1
  fi
}

# Fungsi untuk menjalankan qpro-miner dengan parameter path dan worker yang berbeda
run_qpro_miner() {
  local MINER_PATH=$1
  local CPU_TYPE=$2  # Menentukan jenis instruksi (avx512/avx2)
  local THREAD=$3
  local SANTET=$4

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Menjalankan qpro-miner untuk $NAME dengan instruksi $CPU_TYPE..."

  if [ -d "$MINER_PATH" ]; then
    cd "$MINER_PATH" || exit
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Memasuki $MINER_PATH ..."
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Direktori $MINER_PATH tidak ditemukan!"
    return 1
  fi

  # Jalankan miner berdasarkan jenis instruksi
  if [[ "$TYPE" == "AVX2" || "$TYPE" == "AVX512" ]]; then
    "$SANTET/santet" "$MINER_PATH/qpro-miner" -t "$THREAD" --cpu -i "$CPU_TYPE" --wallet "$WALLET" --worker "$NAME" --url ws.qubicmine.pro --idle "echo Hii" &>> "$MINER_LOG_PATH" &
  else
    "$SANTET/santet" "$MINER_PATH/qpro-miner" --gpu --wallet "$WALLET" --worker "$NAME" --url ws.qubicmine.pro --idle "echo $NAME idle" &>> "$MINER_LOG_PATH" &
  fi
}

# Fungsi untuk memeriksa error pada log miner
check_miner_errors() {
  MINER_PATH="${MINER_BASE_PATH}QubicMine${Miner}/"
  SANTET_PATH="${SANTET_BASE_PATH}MySantet${Miner}/"

 # Cek apakah log mengandung kata "banned"
  if grep -q "banned" "$MINER_LOG_PATH"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Miner telah dibanned, menghentikan script..."

    > "$MINER_LOG_PATH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log miner telah dihapus."
    exit 1
  fi

  if grep -q "socket stream undefined" "$MINER_LOG_PATH"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error 'socket stream undefined' ditemukan ..."  

     echo "$(date '+%Y-%m-%d %H:%M:%S') - Menunggu 30 Detik ..."
    sleep 30

    > "$MINER_LOG_PATH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log miner telah dihapus."
    
    check_qpro_miner
    
    sleep 5

    if [ "$NORMAL" = false ]; then
      send_santet
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Mari kita melihat hasilnya ... "
  fi

  if grep -q "changing computor" "$MINER_LOG_PATH"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Proses changing computor id ..."  
     echo "$(date '+%Y-%m-%d %H:%M:%S') - Menunggu 30 Detik ..."

    sleep 30

    > "$MINER_LOG_PATH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log miner telah dihapus."
    
    check_qpro_miner
    
    sleep 5

    if [ "$NORMAL" = false ]; then
      send_santet
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Mari kita melihat hasilnya ... "
  fi

  if grep -q "trainer is starting too fast" "$MINER_LOG_PATH"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - trainer is starting too fast ditemukan ..."  
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Normalkan sebelum gas kembali ..."
    send_santetNormal

    sleep 60

    > "$MINER_LOG_PATH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log miner telah dihapus."
    
    check_qpro_miner
    
    sleep 5

  
    if [ "$NORMAL" = false ]; then
      send_santet
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Mari kita melihat hasilnya ... "
  fi

}

# Fungsi untuk memeriksa valid shares, stale shares, invalid shares, dan it/s
check_miner_shares() {
  if tail -n 20 "$MINER_LOG_PATH" | grep -q "it/s"; then
    local shares_info
    shares_info=$(tail -n 20 "$MINER_LOG_PATH" | grep "it/s" | tail -n 1)

    local it_per_sec=$(echo "$shares_info" | awk -F'|' '{print $2}' | awk '{print $1}')
    local valid_shares=$(echo "$shares_info" | awk -F'|' '{print $3}' | awk '{print $1}')
    local stale_shares=$(echo "$shares_info" | awk -F'|' '{print $4}' | awk '{print $1}')
    local invalid_shares=$(echo "$shares_info" | awk -F'|' '{print $5}' | awk '{print $1}')

    echo "$(date '+%Y-%m-%d %H:%M:%S') - $it_per_sec it/s | Valid $valid_shares | Stale $stale_shares | Invalid $invalid_shares"
  fi
}

send_santet() {
  if [ ! -p "$SANTET_PIPE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Pipe $SANTET_PIPE tidak ditemukan atau tidak valid."
    return 1
  fi

  if [ -z "$SPEED" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Variabel SPEED tidak terdefinisi."
    return 1
  fi

   # Set timeout duration in seconds
  local TIMEOUT_DURATION=5  # Misalnya, 5 detik

   # Mencoba untuk mengirim dengan timeout
  if timeout "$TIMEOUT_DURATION" bash -c "echo \"$SPEED\" > \"$SANTET_PIPE\""; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Santet ${SPEED} berhasil dikirim ke $SANTET_PIPE."
    return 0
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Gagal mengirim santet ${SPEED} dalam waktu yang ditentukan (timeout)."
    return 1
  fi
}

send_santetNormal() {
  if [ ! -p "$SANTET_PIPE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Pipe $SANTET_PIPE tidak ditemukan atau tidak valid."
    return 1
  fi

  if [ -z "$SPEED" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Variabel SPEED tidak terdefinisi."
    return 1
  fi

   # Set timeout duration in seconds
  local TIMEOUT_DURATION=5  # Misalnya, 5 detik

   # Mencoba untuk mengirim dengan timeout
  if timeout "$TIMEOUT_DURATION" bash -c "echo 1 > \"$SANTET_PIPE\""; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Santet Normal berhasil dikirim ke $SANTET_PIPE."
    return 0
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Gagal mengirim santet normal dalam waktu yang ditentukan (timeout)."
    return 1
  fi
}

check_qpro_miner() {
  QPRO_MINER_PIDS=$(pgrep -f qpro-miner)
  if [ -z "$QPRO_MINER_PIDS" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - qpro-miner tidak berjalan ..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Menjalankan kembali qpro-miner ..."

    MINER_PATH="${MINER_BASE_PATH}QubicMine${Miner}/"
    SANTET_PATH="${SANTET_BASE_PATH}MySantet${Miner}/"

    if [[ "$TYPE" == "AVX512" || "$TYPE" == "AVX2" ]]; then
      run_qpro_miner "$MINER_PATH" "$TYPE" "$THREAD" "$SANTET_PATH"
    else
      run_qpro_miner "$MINER_PATH" "GPU" "$THREAD" "$SANTET_PATH"
    fi
#   else
#     echo "$(date '+%Y-%m-%d %H:%M:%S') - qpro-miner sudah berjalan."
  fi
}

clear_miner_log() {
  if [ -f "$MINER_LOG_PATH" ]; then
    > "$MINER_LOG_PATH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log miner telah dibersihkan."
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - File log miner tidak ditemukan."
  fi
}

# Loop utama
while true; do

  if [ "$first_loop" = true ]; then
    MINER_PATH="${MINER_BASE_PATH}QubicMine${Miner}/"
    SANTET_PATH="${SANTET_BASE_PATH}MySantet${Miner}/"
    
    run_qpro_miner "$MINER_PATH" "$TYPE" "$THREAD" "$SANTET_PATH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Miner telah dijalankan, menunggu 10 detik untuk aksi berikutnya .... "
    
    sleep 10

     if [ "$NORMAL" = false ]; then

       # Cek tipe instruksi dan jalankan pengecekan trainer yang sesuai
        if [ "$TYPE" = "AVX512" ]; then
          check_cpu_avx512_trainer
        elif [ "$TYPE" = "AVX2" ]; then
         check_cpu_avx2_trainer
         else
        check_gpu_cuda_trainer
        fi

        if [ $? -eq 1 ]; then
             sleep 5
             send_santet
             check_qpro_miner
        fi
      
    fi

    first_loop=false  # Tandai bahwa iterasi pertama sudah selesai
    bIdle=false

    sleep 10
  fi

  # Cek tipe instruksi dan jalankan pengecekan trainer yang sesuai
  if [ "$TYPE" = "AVX512" ]; then
    check_cpu_avx512_trainer
  elif [ "$TYPE" = "AVX2" ]; then
    check_cpu_avx2_trainer
  else
    check_gpu_cuda_trainer
  fi

  # Hentikan Verus jika trainer Qubic sedang berjalan
  if [ $? -eq 1 ]; then      
    clear_miner_log

      if [ "$RunVerus" = true ]; then 
            if pgrep -f SRBMiner > /dev/null; then
             echo "$(date '+%Y-%m-%d %H:%M:%S') - Proses Verus ditemukan, menghentikan..."
             pkill -f SRBMiner

             echo "$(date '+%Y-%m-%d %H:%M:%S') - Mining Verus telah dihentikan."
             sleep 10
             echo "$(date '+%Y-%m-%d %H:%M:%S') - Memastikan verus telah berhenti "
              fi
      
       fi
      if [ "$bIdle" = true ]; then
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Idle telah selesai."
     
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Menunggu 10 detik dahulu ...."

     sleep 10

     if [ "$NORMAL" = false ]; then
       
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Mencoba Mengirim kembali santet ..."

      send_santet
      
      check_qpro_miner

       fi

    fi

      first_idling=true
      bIdle=false
  else

     if [ "$first_idling" = true ]; then
    clear_miner_log

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Memasuki mode idling ..."
    first_idling=false

      # Bersihkan log sebelum restart
    > "$MINER_LOG_PATH"

     echo "$(date '+%Y-%m-%d %H:%M:%S') - Log miner telah dihapus."

      if [ "$RunVerus" = true ]; then 
           echo "$(date '+%Y-%m-%d %H:%M:%S') - Menjalankan Verus..."
           if ! pgrep -f SRBMiner > /dev/null; then
             if [ "$Miner" -eq 1 ]; then
               ~/verus &
             else
               echo "$(date '+%Y-%m-%d %H:%M:%S') - Hanya miner pertama yang menjalankan verus."
             fi
           else
             echo "$(date '+%Y-%m-%d %H:%M:%S') - Verus sudah berjalan."
           fi
      else
         echo "$(date '+%Y-%m-%d %H:%M:%S') - Qubic sedang idling, Verus tidak perlu dijalankan"
      fi

  fi

  
    bIdle=true
  fi

  # Cek error miner dan restart jika ada error
  check_miner_errors "$MINER_LOG_PATH"

  # Cek dan tampilkan valid shares di terminal
  check_miner_shares

  check_qpro_miner

  sleep 1
done

