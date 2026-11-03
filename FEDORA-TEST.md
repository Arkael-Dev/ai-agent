# Uji cepat di Fedora (Raku OS)

## 1. Dependensi
```
sudo dnf install bash curl jq git dialog
# emulator terminal (pilih salah satu, biasanya sudah ada):
sudo dnf install gnome-terminal      # GNOME
sudo dnf install konsole             # KDE
sudo dnf install xfce4-terminal alacritty kitty foot xterm
```

## 2. Pasang
```
git clone <repo> ~/ai-agent && cd ~/ai-agent && ./install.sh
```

## 3. Cek lingkungan
```
ai doctor
```
Yang diharapkan: `platform : linux`, `gui : yes (dialog)`, dan `terminal : <nama emulator>`.
Kalau `terminal : none found` → opsi 1 akan menyarankan opsi 2; pasang salah satu emulator di atas.

## 4. Jalankan
```
ai
```
Uji kelima opsi:
1. **Chat in a new terminal window** → jendela terminal baru terbuka dengan chat.
2. **Chat in this terminal** → menu hilang, langsung masuk chat.
3. **Choose AI / API key / model** → provider/key/model tersimpan.
4. **Update** → `git pull` jalan.
5. **Close** → keluar bersih.

## 5. Fallback (opsional)
```
AI_NO_GUI=1 ai            # menu teks
unset DISPLAY WAYLAND_DISPLAY; ai   # tanpa sesi grafis
```

## Kalau ada masalah
```
ai doctor
echo $DISPLAY $WAYLAND_DISPLAY      # Wayland punya keduanya
```
Laporkan baris `gui:` dan `terminal:` dari `ai doctor` — itu cukup untuk tahu penyebabnya.
