# ⚡ AI Agent — asisten AI untuk Android (Termux): bubble melayang dan chat di terminal

🌐 [English](README.md) · **Bahasa Indonesia**

> Asisten AI agentik untuk Android yang bisa dipakai dua cara: **bubble melayang** di atas semua aplikasi, atau **chat di terminal Termux**. Bawa API key sendiri: DeepSeek (default), OpenAI, Gemini, Claude, OpenRouter, Groq, atau model Ollama lokal. Murni Bash.

Ada dua tampilan yang berbagi pengaturan, key, dan provider yang sama:

- **`ai-agent-bubble.sh`**: bubble kecil yang bisa digeser muncul di atas semua aplikasi. Ketuk untuk membuka panel berisi **aksi cepat untuk teks di clipboard** (terjemah, ringkas, jelaskan, perbaiki, balas) dan **chat agentik** yang bisa menjalankan perintah shell di HP kamu untuk benar-benar menyelesaikan tugas.
- **`ai-agent-chat.sh`**: chat agentik yang sama langsung di terminal Termux. Tanpa overlay dan tanpa Termux:GUI.

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
- Nama model bawaan bisa ketinggalan zaman. Kalau muncul error *model not found*, ganti dengan `--model NAMA_MODEL`.
- Endpoint Claude yang kompatibel OpenAI masih bersifat eksperimental, jadi fitur tool-call mungkin tidak sempurna.
- Untuk chat agentik (menjalankan perintah), pilih model yang mendukung tool calling. Model lokal yang terlalu kecil sering gagal di bagian ini.

## Kebutuhan

Install **tiga aplikasi** dari sumber yang **sama** (semuanya F-Droid, atau semuanya GitHub Releases). Jangan dicampur, karena tanda tangan yang berbeda membuat Android menolak pemasangan plugin.

- [Termux](https://github.com/termux/termux-app/releases)
- [Termux:GUI](https://github.com/termux/termux-gui/releases), mesin overlay
- [Termux:API](https://github.com/termux/termux-api/releases), untuk clipboard, toast, dan suara

Jangan pakai build Play Store karena sudah usang.

Lalu di Termux:

```
pkg update && pkg install termux-gui-bash jq curl termux-api git
```

Aktifkan izin **Tampilkan di atas aplikasi lain** untuk Termux:GUI (Setelan > Aplikasi > Termux:GUI).

## Instalasi

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
chmod +x ai-agent-bubble.sh ai-agent-chat.sh
./ai-agent-bubble.sh      # bubble melayang (butuh Termux:GUI)
./ai-agent-chat.sh        # chat di terminal
```

Saat pertama kali menjalankan bubble, panel membuka layar **Settings**. Pilih **provider**, tempel **API key**, pilih **model**, lalu ketuk **Save**. Key dan model dicek dulu sebelum disimpan.

## Chat di terminal (tanpa GUI)

`ai-agent-chat.sh` memberi agen yang sama di terminal Termux. Provider, key, dan model-nya sama dengan bubble, jadi tidak perlu mengatur dua kali.

Saat dijalankan, muncul **menu** untuk memilih AI sebelum mulai chat:

```
⚡ AI Agent — choose your AI
  1) DeepSeek    ✓ key saved          deepseek-v4-pro  ◀ current
  2) OpenAI      ✗ needs API key      gpt-4o-mini
  ...
  7) Ollama      local · no key needed qwen2.5:3b
  Enter = start with DeepSeek · deepseek-v4-pro
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

**Lewat aplikasi (paling mudah):** ketuk tombol **⚙** di header panel.

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

Tanpa key dan tanpa internet. Pastikan server Ollama berjalan, lalu:

```
./ai-agent-bubble.sh --provider ollama --model qwen2.5:3b
```

Kalau Ollama berjalan di PC dalam jaringan yang sama, arahkan dengan:

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
- **Copy / Speak:** salin atau bacakan jawaban terakhir. **Mic** untuk input suara.
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

Riwayat percakapan disimpan di `history.json` (bubble) dan `history-cli.json` (chat terminal) di folder yang sama dan dihapus saat **Reset**. Setiap perintah yang dijalankan AI dicatat di `cmd.log`.

> **Upgrade dari versi lama?** Folder pengaturan pindah dari `~/.config/deepseek-bubble` ke `~/.config/ai-agent`. Pemindahan dilakukan otomatis saat pertama jalan, jadi key dan riwayat tetap aman. Nama lama `DEEPSEEK_THINKING` dan `DEEPSEEK_MAX_TOKENS` masih dibaca dan akan ditulis ulang sebagai `AI_THINKING` dan `AI_MAX_TOKENS` saat pengaturan disimpan berikutnya.

## Keamanan — baca ini

Chat agentik bisa **menjalankan perintah shell di HP kamu**. Gunakan dengan hati-hati:

- Aktifkan konfirmasi untuk perintah berisiko (`rm`, `mv`, `chmod`, `dd`, `reboot`, dan sejenisnya) dengan menambahkan `BASH_CONFIRM=1` di file config. Di bubble perintah itu menunggu kamu mengetuk **Run**; di chat terminal akan ditanya `y/N` (atau pakai `/confirm on`).
- Jangan minta AI memproses teks atau repo dari sumber yang tidak kamu percaya. Isinya bisa berisi instruksi tersembunyi untuk menyuruh AI menjalankan perintah berbahaya.
- Periksa `cmd.log` untuk melihat apa saja yang pernah dijalankan.
- **Jangan pernah membagikan atau meng-commit API key.** Jangan memakai key milik orang lain yang dikirim lewat chat. Key bersama bisa dicabut kapan saja dan semua pemakaianmu terlihat oleh pemiliknya.
- Teks di clipboard dan pesanmu dikirim ke provider yang kamu pilih. Jangan salin data rahasia saat memakai aksi cepat.

## Pemecahan masalah

| Gejala | Solusi |
|---|---|
| `bad interpreter: tgui-bash` | Jalankan `pkg install termux-gui-bash` |
| Termux:GUI "Aplikasi tidak diinstal" | Sumber aplikasi tidak sama dengan Termux. Cek dengan `termux-info \| grep -i apk`, lalu pasang dari sumber yang sama (F-Droid atau GitHub) |
| Bubble tidak muncul | Aktifkan izin *Tampilkan di atas aplikasi lain* untuk Termux:GUI, dan pastikan aplikasinya terpasang |
| `Invalid key` | Periksa key, provider, dan model. Coba `--model` lain |
| Clipboard, toast, atau suara tidak jalan | Pasang `termux-api` dan aplikasi Termux:API |
| `SCREEN_H_PX: unbound variable` | Sudah diperbaiki di versi ini. Jalankan `./ai-agent-bubble.sh --update` |
| Panel tidak bisa digeser | Geser dari baris judul. Kalau tetap gagal, ciutkan dengan **▽**, pindahkan bubble, lalu buka lagi. Untuk melapor, jalankan dengan `DRAG_DEBUG=1` dan kirim `~/.config/ai-agent/touch.log`. Bisa juga naikkan `DRAG_EXTRA_PX` (bawaan 110) |

## Pengembangan

- GitHub Actions menjalankan pengecekan sintaks dan ShellCheck pada setiap push (lihat `.github/workflows`).
- Rencana: mode agen yang memperbaiki kode di repo secara mandiri (membaca error, mengedit, menjalankan pengecekan, lalu menampilkan diff untuk disetujui), dukungan pembuatan gambar, dan perintah update yang lebih lengkap.

Kontribusi lewat Issues dan Pull Request dipersilakan.

## Lisensi dan kredit

GPL-3.0, lihat [LICENSE](LICENSE). Berdasarkan [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble). Terima kasih kepada ExTV dan pembuat Termux serta Termux:GUI.
