# ⚡ AI Agent — asisten AI agentik untuk Linux: chat di terminal yang benar-benar menjalankan perintah

**Bahasa Indonesia** · 🌐 [English](README.md)

> Asisten AI agentik untuk Linux. Ngobrol dengan DeepSeek (default), OpenAI, Gemini, Claude, OpenRouter, Groq, atau model Ollama lokal — dan biarkan model membaca file, menjalankan program, serta mengambil data di mesinmu lewat tool `run_bash`. Murni Bash, tanpa runtime tambahan. Bawa API key sendiri.

Jalan di **Arch, Debian/Ubuntu, Fedora, openSUSE, Alpine, WSL, dan macOS**, termasuk di dalam container `proot-distro` / `chroot`. Lihat [Kompatibilitas](PORTABILITY.md) untuk tabel lengkapnya.

## Tujuan

- **Satu agen, banyak AI.** Tidak terikat satu vendor. Pakai DeepSeek, ChatGPT, Gemini, Claude, atau model lokal lewat Ollama.
- **Bawa API key sendiri (BYOK).** Tidak ada key di repo ini dan tidak ada server perantara. Key-mu tetap di mesinmu dan hanya dikirim ke provider yang kamu pilih.
- **AI yang bekerja, bukan cuma ngobrol.** Model bisa membaca file, menjalankan program, mengambil data, dan memperbaiki sesuatu di sistemmu lewat tool `run_bash`.
- **Ringan, murni Bash.** Cuma butuh `bash`, `curl`, dan `jq` — tanpa Python, Node, atau Docker.
- **Terminal first.** Tanpa GUI, tanpa overlay, tanpa sesi desktop. Jalan lewat SSH, di pane tmux, atau di server headless.

## Provider yang didukung

Semua provider memakai API chat yang kompatibel OpenAI. DeepSeek tetap jadi **default**.

| Provider | Nama (`--provider`) | Variabel key | Model default |
|---|---|---|---|
| DeepSeek (default) | `deepseek` | `DEEPSEEK_API_KEY` | `deepseek-flash` |
| OpenAI (ChatGPT) | `openai` | `OPENAI_API_KEY` | `gpt-4o-mini` |
| Google Gemini | `gemini` | `GEMINI_API_KEY` | `gemini-2.5-flash` |
| Anthropic Claude | `claude` | `ANTHROPIC_API_KEY` | `claude-sonnet-5-5` |
| OpenRouter | `openrouter` | `OPENROUTER_API_KEY` | `openrouter/auto` |
| Groq | `groq` | `GROQ_API_KEY` | `llama-3.3-70b-versatile` |
| Ollama (lokal) | `ollama` | tanpa key | `qwen2.5:3b` |
| Lainnya | `custom` | `AI_API_KEY` | atur lewat `AI_MODEL` |

Catatan:
- Nama model default bisa berubah. Kalau muncul error *model not found*, pakai `--model MODEL_KAMU`.
- Endpoint kompatibel-OpenAI milik Claude masih eksperimental, jadi tool calling bisa belum sempurna.
- Chat agentik (menjalankan perintah) butuh model yang mendukung tool calling. Model lokal yang sangat kecil sering gagal di bagian ini.

## Kebutuhan

- **bash 4 atau lebih baru** (macOS masih pakai 3.2 — pasang yang baru dengan `brew install bash`)
- **curl** dan **jq**
- **git** (untuk clone dan update)

Itu saja. Pasang dengan package manager-mu:

| Distro | Perintah |
|---|---|
| Arch / Manjaro | `sudo pacman -S --needed bash curl jq git` |
| Debian / Ubuntu / Mint | `sudo apt install bash curl jq git` |
| Fedora / RHEL | `sudo dnf install bash curl jq git` |
| openSUSE | `sudo zypper install bash curl jq git` |
| Alpine | `sudo apk add bash curl jq git` |
| macOS | `brew install bash curl jq git` |

Cek semuanya sekaligus dengan:

```
./ai-agent-chat.sh --doctor
```

## Mulai cepat (disarankan)

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
bash install.sh
```

`install.sh` mendeteksi package manager-mu, memasang dependency (minta `sudo` hanya kalau perlu), dan menaruh perintah **`ai`** di direktori yang sudah ada di `PATH`. Setelah itu, cukup ketik:

```
ai
```

```
⚡ AI Agent
 AI: deepseek · deepseek-flash · key ✓
 Host: Arch Linux

  1) Chat in terminal
  4) Choose AI / API key / model
  5) Update
  q) Quit
```

Pintasan: `ai chat`, `ai setup`, `ai update`, atau `ai "pertanyaanmu"` untuk jawaban sekali jalan.

## Instalasi manual

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
chmod +x ai-agent-chat.sh ai-agent
./ai-agent-chat.sh
```

Saat pertama dijalankan kamu akan diminta **provider**, **API key**, dan **model**. Key dan model dicek dengan request kecil sebelum disimpan.

## Chat di terminal

Saat mulai, muncul **menu** untuk memilih AI sebelum ngobrol:

```
⚡ AI Agent — choose your AI
  1) DeepSeek    ✓ key saved          deepseek-flash   ◀ current
  2) OpenAI      ✗ needs API key      gpt-4o-mini
  ...
  7) Ollama      local · no key needed qwen2.5:3b
  Enter = start with DeepSeek · deepseek-flash
  m = choose model   k = change API key   q = quit
```

- **Pilih nomor** untuk ganti AI. **API key wajib** untuk semua provider cloud (hanya Ollama yang lokal tidak butuh). Key diketik tersembunyi dan dicek dengan request kecil sebelum disimpan.
- Lalu **pilih model** dari daftar bernomor yang dimuat dari provider (ketik nomor, atau ketik id model sendiri).
- **Enter** mulai chat dengan AI aktif. **m** ganti model saja, **k** ganti API key saja.

```
./ai-agent-chat.sh                                   # menu, lalu chat
./ai-agent-chat.sh --no-menu                         # lewati menu, pakai AI tersimpan
./ai-agent-chat.sh --provider claude --model claude-opus-5-5
./ai-agent-chat.sh "cari file terbesar di home folder-ku"   # satu jawaban, lalu keluar
cat error.log | ./ai-agent-chat.sh "error ini maksudnya apa?"
```

Perintah di dalam chat:

| Perintah | Fungsinya |
|---|---|
| `/menu` | Buka menu AI lagi (provider, key, model) |
| `/key` | Ganti API key AI aktif |
| `/models` | Daftar model provider dan pilih satu |
| `/model [id]` | Tampilkan model, atau set lewat id |
| `/provider [name]` | Tanpa nama: buka menu. Dengan nama: pindah ke provider itu (minta key kalau perlu) |
| `/reset` | Hapus percakapan |
| `/confirm on\|off` | Tanya dulu sebelum perintah shell berisiko |
| `/help` | Tampilkan perintah |
| `/exit` atau Ctrl-D | Keluar |

Tekan **Ctrl-C** untuk menghentikan jawaban yang masih berjalan. Jawaban di-stream langsung, dan percakapan tersimpan antar sesi (`--new` mulai dari kosong).

## Memilih provider dan model

Cara tercepat adalah opsi **4** di menu `ai`, atau `./ai-agent-chat.sh --setup`:

```
./ai-agent-chat.sh --setup --provider openai
```

Atau lewat environment untuk sekali jalan:

```
DEEPSEEK_API_KEY=sk-... ./ai-agent-chat.sh --provider deepseek "halo"
```

## Ollama (model lokal)

Jalankan Ollama di mesinmu, dan agen ngobrol tanpa key maupun internet:

```
ollama serve
ollama pull qwen2.5:3b
./ai-agent-chat.sh --provider ollama --model qwen2.5:3b
```

Set `OLLAMA_HOST` di file config kalau server tidak di `127.0.0.1:11434`. Catatan: model lokal kecil sering tidak bisa tool calling, jadi bagian agentiknya tidak jalan.

## Provider custom

Apa pun yang bicara API chat kompatibel-OpenAI bisa dipakai. Set `AI_BASE_URL` dan `AI_MODEL` di file config lalu pakai `--provider custom`.

## Opsi command line

| Opsi | Fungsinya |
|---|---|
| `--provider NAME` | Pilih provider |
| `--model ID` | Pilih model |
| `--setup` | Buka menu AI saja, lalu keluar |
| `--no-menu` | Lewati menu, pakai setelan tersimpan |
| `--new` | Mulai percakapan kosong |
| `--doctor` | Tampilkan status platform dan dependency |
| `--help` | Tampilkan bantuan |

## Konfigurasi

File: `~/.config/ai-agent/config` (mode `600`, hanya bisa dibaca kamu).

| Variabel | Fungsinya |
|---|---|
| `AI_PROVIDER` | Provider aktif |
| `AI_MODEL` | Model yang dipakai (menimpa default) |
| `AI_BASE_URL` | URL endpoint untuk provider `custom` |
| `OLLAMA_HOST` | Alamat server Ollama |
| `AI_THINKING` | `off` (cepat, default), `on`, atau `default` (khusus DeepSeek) |
| `AI_MAX_TOKENS` | Maksimal token jawaban |
| `BASH_CONFIRM` | `1` = minta konfirmasi sebelum perintah berisiko |

Riwayat percakapan disimpan di `history-cli.json` di folder yang sama dan dihapus saat **Reset**. Setiap perintah yang dijalankan AI dicatat ke `cmd.log`.

## Keamanan — wajib dibaca

Chat agentik bisa **menjalankan perintah shell di mesinmu**. Pakai dengan hati-hati:

- Aktifkan konfirmasi untuk perintah berisiko (`rm`, `mv`, `chmod`, `dd`, `reboot`, dan sejenisnya) dengan menambahkan `BASH_CONFIRM=1` ke file config, atau pakai `/confirm on`. Perintah berisiko akan tanya `y/N` dulu.
- Jangan minta AI memproses teks atau repo dari sumber yang tidak kamu percaya. Bisa ada instruksi tersembunyi yang menyuruh AI menjalankan perintah berbahaya.
- Cek `cmd.log` untuk melihat semua yang pernah dijalankan.
- **Jangan pernah membagikan atau meng-commit API key-mu.** Jangan pakai key orang lain yang dikirim lewat chat. Key yang dibagikan bisa dicabut kapan saja, dan pemiliknya bisa melihat semua pemakaianmu.
- Di server bersama, ingat bahwa agen berjalan dengan izin *user-mu*. Pakai user khusus atau container kalau kamu tidak yakin dengan apa yang mungkin dilakukannya.
- Pesanmu dikirim ke provider yang kamu pilih. Jangan tempel rahasia.

## Troubleshooting

| Gejala | Solusi |
|---|---|
| `needs bash 4 or newer` | macOS masih bash 3.2: `brew install bash`, lalu jalankan `/opt/homebrew/bin/bash ./ai-agent-chat.sh` |
| `jq: command not found` | Pasang jq dengan package manager-mu (lihat [Kebutuhan](#kebutuhan)) |
| `Invalid key` | Cek key, provider, dan model. Coba `--model` lain |
| `model not found` | Nama model default bisa berubah; pakai `--model` dengan id yang valid |
| Hal lain terasa aneh | Jalankan `./ai-agent-chat.sh --doctor` dan cek baris platform |
| Jalan di dalam container | `--doctor` melaporkan PRoot/chroot secara eksplisit; chat terminal tetap jalan normal |

## Pengembangan

- `tests/test-stream-parser.sh` — tes parser SSE, offline
- `tests/test-stream-live.sh` — cek streaming live ke endpoint tiruan

```
bash tests/test-stream-parser.sh
```

Kontribusi lewat Issue dan Pull Request sangat diterima.

## Lisensi dan kredit

GPL-3.0, lihat [LICENSE](LICENSE).

- **Pembuat asli:** [ExTV](https://github.com/ExTV), pembuat [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble) yang menjadi dasar proyek ini.
- **Dimodifikasi oleh:** [Arkael-Dev](https://github.com/Arkael-Dev): dukungan banyak provider, chat terminal, dukungan Linux/macOS portabel, launcher `ai` dan installer, serta perubahan lainnya.

Terima kasih kepada ExTV dan pembuat Termux serta Termux:GUI.
