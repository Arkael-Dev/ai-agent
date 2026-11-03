# ⚡ AI Agent — asisten AI untuk Android (Termux): bubble melayang dan chat di terminal

🌐 [English](README.md) · **Bahasa Indonesia**

> Asisten AI agentik yang berjalan **hanya di Termux pada Android**. Dua tampilan: **bubble melayang** di atas semua aplikasi, atau **chat di terminal Termux**. Bawa API key sendiri: DeepSeek (default), OpenAI, Gemini, Claude, OpenRouter, Groq, atau model Ollama lokal. Murni Bash — tanpa Node, tanpa Python, tanpa build.

**Branch ini (`main`) adalah versi Termux.** Dia bergantung pada tumpukan Android/Termux: `termux-gui-bash` (shebang `tgui-bash`), aplikasi Termux:GUI untuk overlay, dan aplikasi Termux:API untuk clipboard, toast, serta suara. Port Linux/macOS ada di branch [`portable-linux`](https://github.com/Arkael-Dev/ai-agent/tree/portable-linux) — jangan dicampur.

Ada dua tampilan yang berbagi pengaturan, key, dan provider yang sama:

- **`ai-agent-bubble.sh`**: bubble kecil yang bisa digeser, muncul di atas semua aplikasi. Ketuk untuk membuka panel berisi **aksi cepat untuk teks di clipboard** (terjemah, ringkas, jelaskan, perbaiki, balas) dan **chat agentik** yang bisa menjalankan perintah shell di HP kamu untuk benar-benar menyelesaikan tugas. Butuh Termux:GUI.
- **`ai-agent-chat.sh`**: chat agentik yang sama langsung di terminal Termux. Tanpa overlay dan tanpa Termux:GUI — cukup `curl` dan `jq`.

## Maksud dan tujuan

- **Satu agen, banyak AI.** Tidak terkunci ke satu penyedia. Pakai DeepSeek, ChatGPT, Gemini, Claude, atau model lokal lewat Ollama.
- **Bawa key sendiri (BYOK).** Tidak ada key di repo ini dan tidak ada server perantara. Key kamu disimpan di HP kamu sendiri dan hanya dikirim langsung ke penyedia yang kamu pilih.
- **AI yang bisa bekerja, bukan cuma mengobrol.** Model bisa membaca file, menjalankan program, mengambil data, dan memperbaiki hal di perangkatmu lewat tool `run_bash`.
- **Ringan dan murni Bash.** Chat terminal hanya butuh Termux, `curl`, dan `jq`. Bubble butuh Termux:GUI juga.

Proyek ini adalah turunan dari [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble) (GPL-3.0) dengan tambahan dukungan banyak provider.

## Penyedia yang didukung

Semuanya memakai format API yang kompatibel dengan OpenAI. DeepSeek tetap menjadi **default**.

| Provider | Nama (`--provider`) | Variabel key | Model bawaan |
|---|---|---|---|
| DeepSeek (default) | `deepseek` | `DEEPSEEK_API_KEY` | `deepseek-flash` |
| OpenAI (ChatGPT) | `openai` | `OPENAI_API_KEY` | `gpt-4o-mini` |
| Google Gemini | `gemini` | `GEMINI_API_KEY` | `gemini-2.5-flash` |
| Anthropic Claude | `claude` | `ANTHROPIC_API_KEY` | `claude-sonnet-5-5` |
| OpenRouter | `openrouter` | `OPENROUTER_API_KEY` | `openrouter/auto` |
| Groq | `groq` | `GROQ_API_KEY` | `llama-3.3-70b-versatile` |
| Ollama (lokal) | `ollama` | tidak perlu key | `qwen2.5:3b` |
| Lainnya | `custom` | `AI_API_KEY` | isi lewat `AI_MODEL` |

Catatan:
- Nama model bawaan bisa ketinggalan zaman. Kalau muncul error *model not found*, pakai `--model NAMA_MODEL` atau pilih dari daftar yang dimuat script dari provider-mu.
- Endpoint Claude yang kompatibel OpenAI masih eksperimental, jadi tool calling bisa tidak sempurna.
- Untuk chat agentik (menjalankan perintah), pilih model yang mendukung tool calling. Model lokal yang terlalu kecil sering gagal di bagian ini.

## Kebutuhan (khusus Termux)

Install **tiga aplikasi** dari sumber yang **sama** (semuanya F-Droid, atau semuanya GitHub Releases). Jangan dicampur, karena tanda tangan yang berbeda membuat Android menolak pemasangan plugin.

- [Termux](https://github.com/termux/termux-app/releases)
- [Termux:GUI](https://github.com/termux/termux-gui/releases), mesin overlay (hanya untuk bubble)
- [Termux:API](https://github.com/termux/termux-api/releases), untuk clipboard, toast, dan suara

Jangan pakai build Play Store karena sudah usang dan tidak bisa berkomunikasi dengan plugin.

Lalu di Termux:

```
pkg update && pkg install jq curl coreutils git termux-api termux-gui-bash
```

- Aktifkan izin **Tampilkan di atas aplikasi lain** untuk Termux:GUI (Setelan > Aplikasi > Termux:GUI). Tanpa ini bubble tidak akan muncul.
- Beri izin **clipboard / mikrofon / notifikasi** ke Termux:API saat Android meminta. Tanpa ini aksi cepat dan tombol mic tidak berfungsi.
- Disarankan: jalankan `termux-setup-storage` supaya agen bisa membaca dan menulis file di penyimpanan bersama (`~/storage/shared`, misalnya Downloads).

## Mulai cepat (disarankan)

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
bash install.sh
```

`install.sh` memasang paket yang dibutuhkan, membuat perintah **`ai`**, dan bisa membuka menu otomatis setiap kali Termux dibuka. Setelah itu cukup ketik:

```
ai
```

```
⚡ AI Agent
 AI: openai · gpt-4o-mini · key ✓
 Bubble: stopped

  1) Chat in terminal
  2) Start floating bubble (GUI)
  3) Stop bubble
  4) Choose AI / API key / model
  5) Update
  6) Open this menu when Termux starts: ON
  q) Quit
```

Pintasan: `ai chat`, `ai bubble`, `ai stop`, `ai setup`, `ai update`, `ai autostart on|off`, atau `ai "pertanyaanmu"` untuk satu jawaban langsung.

**Autostart:** dengan `ai autostart on`, menu terbuka di setiap sesi Termux baru. Tekan `q` untuk menutup sesi (jadi saat Termux dibuka lagi menu muncul lagi) atau `s` untuk tetap di shell. Untuk melewatinya sekali: `AI_AGENT_SKIP=1 ai`.

## Instalasi (manual)

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
chmod +x ai-agent ai-agent-bubble.sh ai-agent-chat.sh
./ai-agent-bubble.sh      # bubble melayang (butuh Termux:GUI)
./ai-agent-chat.sh        # chat di terminal
```

Saat pertama kali menjalankan bubble, panel membuka layar **Settings**. Pilih **provider**, tempel **API key**, pilih **model**, lalu ketuk **Save**. Key dan model dicek dulu sebelum disimpan.

## Chat di terminal (tanpa GUI)

`ai-agent-chat.sh` memberi agen yang sama di terminal Termux. Provider, key, dan model-nya sama dengan bubble, jadi tidak perlu mengatur dua kali. Mode ini yang dipakai kalau tidak ada Termux:GUI, atau saat masuk lewat `ssh` dari PC ke HP.

Saat dijalankan, muncul **menu** untuk memilih AI sebelum mulai chat:

```
⚡ AI Agent — choose your AI
  1) DeepSeek    ✓ key saved          deepseek-flash   ◀ current
  2) OpenAI      ✗ needs API key      gpt-4o-mini
  ...
  7) Ollama      local · no key needed qwen2.5:3b
  Enter = start with DeepSeek · deepseek-flash
  m = choose model   k = change API key   q = quit
```

- **Ketik nomor** untuk ganti AI. **API key wajib** untuk semua provider cloud (hanya Ollama yang berjalan lokal tidak butuh). Key diketik tersembunyi dan dicek dengan request tes kecil sebelum disimpan.
- Setelah itu kamu **memilih model** dari daftar bernomor yang diambil dari provider (ketik nomor, atau ketik sendiri id model apa pun).
- **Enter** mulai chat dengan AI yang sedang aktif. **m** hanya ganti model, **k** hanya ganti API key.

```
./ai-agent-chat.sh                                   # menu, lalu chat
./ai-agent-chat.sh --no-menu                         # lewati menu, pakai AI tersimpan
./ai-agent-chat.sh --provider claude --model claude-opus-5-5
./ai-agent-chat.sh "tampilkan file terbesar di folder home"     # satu jawaban lalu keluar
cat error.log | ./ai-agent-chat.sh "apa arti error ini?"
```

Perintah di dalam chat:

| Perintah | Fungsi |
|---|---|
| `/menu` | Buka menu AI lagi (provider, key, model) |
| `/key` | Ganti API key AI yang sedang aktif |
| `/models` | Tampilkan daftar model provider dan pilih satu |
| `/model [id]` | Lihat model, atau set lewat id |
| `/provider [nama]` | Tanpa nama: buka menu. Dengan nama: pindah ke provider itu (minta key kalau perlu) |
| `/reset` | Hapus percakapan |
| `/confirm on\|off` | Minta konfirmasi sebelum perintah shell berisiko |
| `/help` | Tampilkan daftar perintah |
| `/exit` atau Ctrl-D | Keluar |

Tekan **Ctrl-C** untuk menghentikan jawaban yang sedang berjalan. Jawaban tampil bertahap saat ditulis, dan percakapan tersimpan antar sesi (`--new` untuk mulai dari kosong).

## Memilih provider dan model

**Lewat bubble (paling mudah):** ketuk tombol **⚙** di header panel.

- **Provider ▸** berganti antara DeepSeek, OpenAI, Gemini, Claude, OpenRouter, Groq, dan Ollama.
- **API key:** tempel key milikmu sendiri. Kosongkan untuk tetap memakai key yang sudah tersimpan untuk provider itu.
- **Model:** ketik id model apa saja, atau ketuk **Models** untuk memuat daftar dari provider lalu ketuk lagi untuk berpindah antar model.
- **Save** mengecek key dan model dengan permintaan uji kecil, lalu menyimpannya. **Cancel** kembali tanpa perubahan.

**Lewat baris perintah**, pakai flag atau variabel lingkungan:

```
./ai-agent-bubble.sh                                    # DeepSeek (default)
./ai-agent-bubble.sh --provider openai                  # ChatGPT
./ai-agent-bubble.sh --provider gemini --model gemini-2.5-pro
./ai-agent-bubble.sh --provider ollama --model qwen2.5:3b
```

Atau langsung dengan key lewat environment:

```
OPENAI_API_KEY="sk-..." ./ai-agent-bubble.sh --provider openai
```

Semua key yang pernah kamu simpan tetap tersimpan, jadi kamu bisa berpindah provider tanpa memasukkan ulang.

### Ollama (model lokal)

Tanpa key dan tanpa internet. Menjalankan Ollama **di dalam Termux** bisa, tapi berat: install dulu, jalankan server, lalu:

```
ollama serve &                     # sekali per sesi Termux
./ai-agent-bubble.sh --provider ollama --model qwen2.5:3b
```

Kalau Ollama berjalan di PC dalam Wi-Fi yang sama, arahkan ke sana — jauh lebih cepat daripada di HP:

```
OLLAMA_HOST="http://192.168.1.10:11434" ./ai-agent-bubble.sh --provider ollama
```

Model besar berat dijalankan di HP. Untuk di HP, pilih model kecil (sekitar 1–3B).

### Provider kustom

Untuk layanan lain yang kompatibel OpenAI:

```
AI_BASE_URL="https://contoh.com/v1/chat/completions" AI_API_KEY="..." AI_MODEL="nama-model" ./ai-agent-bubble.sh --provider custom
```

## Cara pakai

- **Geser** bubble ke mana saja, **ketuk** untuk membuka panel.
- **Aksi clipboard:** salin teks di aplikasi apa pun, lalu ketuk *Trans / Sum / Expl / Fix / Reply*.
- **Chat:** ketik permintaan lalu **Send**. Model bisa menjalankan perintah bash di HP untuk menyelesaikan tugas. Ketuk **Stop** untuk membatalkan.
- **Copy / Speak:** salin atau bacakan jawaban terakhir. **Mic** untuk input suara (butuh Termux:API dan paket pengenal suara bawaan Android).
- **Reset** menghapus percakapan. **▽** menciutkan panel. **✕** menutup aplikasi.
- **⚙** membuka Settings untuk mengganti provider, key, dan model kapan saja.
- **Memindahkan panel:** geser lewat area header (baris judul). Bisa juga ketuk **▽** untuk menciutkan jadi bubble, geser bubble ke mana saja, lalu ketuk untuk membukanya lagi.

Opsi baris perintah:

| Opsi | Fungsi |
|---|---|
| `--provider NAMA` | Pilih provider |
| `--model ID` | Pilih model |
| `--update` | Menjalankan `git pull` untuk memperbarui (khusus bubble) |
| `--help` | Bantuan |

## Konfigurasi

File: `~/.config/ai-agent/config` (izin `600`, hanya bisa dibaca pemilik).

| Variabel | Fungsi |
|---|---|
| `AI_PROVIDER` | Provider aktif |
| `AI_MODEL` | Model yang dipakai (menimpa bawaan) |
| `AI_BASE_URL` | URL endpoint untuk provider `custom` |
| `OLLAMA_HOST` | Alamat server Ollama |
| `AI_THINKING` | `off` (cepat, default), `on`, atau `default` (khusus DeepSeek) |
| `AI_MAX_TOKENS` | Batas token jawaban |
| `BASH_CONFIRM` | `1` = minta konfirmasi sebelum perintah berisiko |

Riwayat percakapan disimpan di `history.json` (bubble) dan `history-cli.json` (chat terminal) di folder yang sama, dan dihapus lewat **Reset**. Setiap perintah yang dijalankan AI dicatat di `cmd.log`.

> **Upgrade dari versi lama?** Folder pengaturan pindah dari `~/.config/deepseek-bubble` ke `~/.config/ai-agent`. Dipindahkan otomatis saat pertama kali jalan, jadi key dan riwayatmu tetap ada. Nama lama `DEEPSEEK_THINKING` dan `DEEPSEEK_MAX_TOKENS` masih dibaca dan akan ditulis ulang sebagai `AI_THINKING` dan `AI_MAX_TOKENS` saat pengaturan disimpan berikutnya.

## Keamanan — mohon dibaca

Chat agentik (bubble dan terminal) bisa **menjalankan perintah shell di HP kamu**. Pakai dengan hati-hati:

- Nyalakan konfirmasi untuk perintah berisiko (`rm`, `mv`, `chmod`, `dd`, `reboot`, dan sejenisnya) dengan menambahkan `BASH_CONFIRM=1` ke file config. Di bubble perintah tersebut menunggu sampai kamu ketuk **Run**; di chat terminal ditanya `y/N` (atau pakai `/confirm on`).
- Jangan minta AI memproses teks atau repo dari sumber yang tidak kamu percaya. Bisa ada instruksi tersembunyi yang menyuruh AI menjalankan perintah berbahaya.
- Periksa `cmd.log` untuk melihat semua yang sudah dijalankan.
- **Jangan pernah membagikan atau meng-commit API key.** Jangan pakai key orang lain yang dikirim lewat chat. Key yang dibagikan bisa dicabut kapan saja, dan pemiliknya bisa melihat seluruh pemakaianmu.
- Teks clipboard dan pesanmu dikirim ke provider yang kamu pilih. Jangan menyalin rahasia saat memakai aksi cepat.

## Pemecahan masalah

| Gejala | Perbaikan |
|---|---|
| `bad interpreter: tgui-bash` | Jalankan `pkg install termux-gui-bash` |
| Termux:GUI "App not installed" | Sumber aplikasi beda dengan Termux. Cek dengan `termux-info \| grep -i apk`, lalu install dari sumber yang sama (F-Droid atau GitHub) |
| Bubble tidak muncul | Aktifkan *Tampilkan di atas aplikasi lain* untuk Termux:GUI dan pastikan aplikasinya terpasang |
| Bubble hilang setelah beberapa saat | Android mematikan Termux di latar belakang. Jalankan `termux-wake-lock`, dan set Termux ke **Tanpa batas** di penghemat baterai (Setelan > Aplikasi > Termux > Baterai) |
| Bubble hilang setelah layar mati | Sebab sama: wake lock + baterai tanpa batas. Jangan menutup Termux dari Recents |
| `Invalid key` | Cek key, provider, dan model. Coba `--model` lain |
| Clipboard, toast, atau suara tidak jalan | Install `termux-api` dan aplikasi Termux:API, lalu beri izinnya |
| `SCREEN_H_PX: unbound variable` | Sudah diperbaiki di versi ini. Jalankan `./ai-agent-bubble.sh --update` |
| Panel tidak mau digeser | Geser dari baris judul. Kalau tetap gagal, ciutkan dengan **▽**, geser bubble, lalu buka lagi. Untuk laporan, jalankan dengan `DRAG_DEBUG=1` dan kirim `~/.config/ai-agent/touch.log`. Bisa juga naikkan `DRAG_EXTRA_PX` (default 110) |

## Pengembangan

- GitHub Actions menjalankan syntax check dan ShellCheck di setiap push (lihat `.github/workflows`).
- Script shell di branch ini wajib mempertahankan path Termux: shebang `/data/data/com.termux/files/usr/bin/bash` (atau `tgui-bash` untuk bubble) dan `${PREFIX:-/data/data/com.termux/files/usr}` untuk `$BIN`.
- Pembagian branch: `main` = Termux/Android (yang ini), `portable-linux` = Linux dan macOS (membuang layer platform Termux, README berbeda).

Kontribusi lewat Issue dan Pull Request sangat diterima.

## Lisensi dan kredit

GPL-3.0, lihat [LICENSE](LICENSE).

- **Pembuat asli:** [ExTV](https://github.com/ExTV), pembuat [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble) yang menjadi dasar proyek ini.
- **Dimodifikasi oleh:** [Arkael-Dev](https://github.com/Arkael-Dev): dukungan banyak provider, chat terminal, launcher `ai` dan installer, serta perubahan lainnya.

Terima kasih kepada ExTV dan pembuat Termux serta Termux:GUI.
