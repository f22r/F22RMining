#!/bin/bash

# Cek jika VerusConfig ada, jika ada, baca parameter dari file
if [ -f VerusConfig ]; then
  source VerusConfig
else
  # Tanyakan kepada pengguna untuk memasukkan parameter jika VerusConfig tidak ada
  read -p "Thread for Mining Verus (e.g., 24): " VerusThread
  read -p "Your Verus Wallet (e.g., Texxsasa): " VerusWallet
  read -p "Your Verus Worker Name (e.g., Worker1): " VerusWorkerName
  read -p "Your Verus Password (e.g., x): " VerusPassword

  # Simpan sesi ke VerusConfig
  echo "Saving session..."
  echo "VerusThread=$VerusThread" > VerusConfig
  echo "VerusWallet=$VerusWallet" >> VerusConfig
  echo "VerusWorkerName=$VerusWorkerName" >> VerusConfig
  echo "VerusPassword=$VerusPassword" >> VerusConfig
  echo "Session saved to VerusConfig"
fi

cd ~/
rm -rf miner.sh run.sh verus

# Hapus direktori Mining jika ada dan buat direktori baru
rm -rf ~/Mining && mkdir ~/Mining && cd ~/Mining

# Buat direktori Qubic dan salin miner
mkdir Qubic && cd Qubic
mkdir QubicMine && cd QubicMine
wget https://dl.qubicmine.pro/qpro-miner
chmod +x qpro-miner
cd ..

# Salin QubicMine ke QubicMine1, QubicMine2, ... QubicMine5 dan QubicMineGPU
for i in {1..5}; do
  cp -r QubicMine QubicMine$i
done
cp -r QubicMine QubicMineGPU

# Kembali ke direktori Mining
cd ..

# Buat direktori Verus dan unduh miner
mkdir Verus && cd Verus
wget https://github.com/doktor83/SRBMiner-Multi/releases/download/2.6.6/SRBMiner-Multi-2-6-6-Linux.tar.gz
tar -xzvf SRBMiner-Multi-2-6-6-Linux.tar.gz
rm -rf SRBMiner-Multi-2-6-6-Linux.tar.gz
mv SRBMiner-Multi-2-6-6 SRBMiner

# Kembali ke direktori Mining
cd ~/Mining/

# Klon repository MySantet dan install dependencies
git clone https://github.com/f22r/MySantet.git && cd MySantet
sudo apt update && sudo apt install -y build-essential git cmake

# Berikan izin eksekusi pada file santet di setiap direktori
for i in {1..5}; do
  cd MySantet$i/
  chmod +x santet
  cd ..
done

# Buat run.sh untuk menjalankan miner.sh
cd ~/
echo -e "#!/bin/bash\n\n./miner.sh" > run.sh

# Buat skrip verus dengan parameter yang diberikan
echo -e "#!/bin/bash\n\n# Cek jika VerusConfig ada, jika ada, baca parameter dari file\nif [ -f ~/VerusConfig ]; then\n  source ~/VerusConfig\nelse\n  echo \"VerusConfig not found! Please create it first.\"\n  exit 1\nfi\n\n# Menjalankan miner dengan parameter yang sudah dimuat\n~/Mining/Verus/SRBMiner/SRBMiner-MULTI --cpu-threads \"\$VerusThread\" --disable-gpu --algorithm verushash --pool ap.luckpool.net:3960 --wallet \"\$VerusWallet.\$VerusWorkerName\" --password \"\$VerusPassword\" --force-msr-tweaks --worker \"\$VerusWorkerName\"" > verus

chmod +x run.sh verus

# Pastikan miner.sh dapat dieksekusi
chmod +x miner.sh
