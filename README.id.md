# ⚡ AI Bubble — asisten AI melayang untuk Android (Termux)

🌐 [English](README.md) · **Bahasa Indonesia**

> A floating, agentic AI assistant that overlays every Android app. Bring your own API key: DeepSeek (default), OpenAI, Gemini, Claude, OpenRouter, Groq, or a local Ollama model. Pure Termux + Termux:GUI bash.

Bubble kecil yang bisa digeser muncul di atas semua aplikasi. Ketuk untuk membuka panel berisi **aksi cepat untuk teks di clipboard** (terjemah, ringkas, jelaskan, perbaiki, balas) dan **chat agentik** yang bisa menjalankan perintah shell di HP kamu untuk benar-benar menyelesaikan tugas.

## Maksud dan tujuan

- **Satu bubble, banyak AI.** Tidak terkunci ke satu penyedia. Pakai DeepSeek, ChatGPT, Gemini, Claude, atau model lokal lewat Ollama.
- **Bawa key sendiri (BYOK).** Tidak ada key di repo ini dan tidak ada server perantara. Key kamu disimpan di HP kamu sendiri dan hanya dikirim langsung ke penyedia yang kamu pilih.
- **AI yang bisa bekerja, bukan cuma mengobrol.** Model bisa membaca file, menjalankan program, mengambil data, dan memperbaiki hal di perangkatmu lewat tool `run_bash`.
- **Ringan dan murni Bash.** Hanya butuh Termux, Termux:GUI, `curl`, dan `jq`.

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
chmod +x deepseek-bubble.sh
./deepseek-bubble.sh
```

Saat pertama kali jalan, panel meminta API key. Tempel key lalu ketuk **Save key**. Key divalidasi dulu sebelum disimpan.

## Memilih provider

Pakai flag atau variabel lingkungan:

```
./deepseek-bubble.sh                                    # DeepSeek (default)
./deepseek-bubble.sh --provider openai                  # ChatGPT
./deepseek-bubble.sh --provider gemini --model gemini-2.5-pro
./deepseek-bubble.sh --provider ollama --model qwen2.5:3b
```

Atau langsung dengan key lewat environment:

```
OPENAI_API_KEY="sk-..." ./deepseek-bubble.sh --provider openai
```

Semua key yang pernah kamu simpan tetap tersimpan, jadi kamu bisa berpindah provider tanpa memasukkan ulang.

### Ollama (model lokal)

Tanpa key dan tanpa internet. Pastikan server Ollama berjalan, lalu:

```
./deepseek-bubble.sh --provider ollama --model qwen2.5:3b
```

Kalau Ollama berjalan di PC dalam jaringan yang sama, arahkan dengan:

```
OLLAMA_HOST="http://192.168.1.10:11434" ./deepseek-bubble.sh --provider ollama
```

Model besar berat dijalankan di HP. Untuk di HP, pilih model kecil (sekitar 1–3B).

### Provider kustom

Untuk layanan lain yang kompatibel OpenAI:

```
AI_BASE_URL="https://contoh.com/v1/chat/completions" AI_API_KEY="..." AI_MODEL="nama-model" ./deepseek-bubble.sh --provider custom
```

## Cara pakai

- **Geser** bubble ke mana saja, **ketuk** untuk membuka panel.
- **Aksi clipboard:** salin teks di aplikasi apa pun, lalu ketuk *Trans / Sum / Expl / Fix / Reply*.
- **Chat:** ketik permintaan lalu **Send**. Model bisa menjalankan perintah bash di HP untuk menyelesaikan tugas. Ketuk **Stop** untuk membatalkan.
- **Copy / Speak:** salin atau bacakan jawaban terakhir. **Mic** untuk input suara.
- **Reset** menghapus percakapan. **▽** menciutkan panel. **✕** menutup aplikasi.
- **M** berganti model: untuk DeepSeek bergantian `deepseek-flash` dan `deepseek-v4-pro`, lalu lanjut ke provider berikutnya yang sudah punya key.

Opsi baris perintah:

| Opsi | Fungsi |
|---|---|
| `--provider NAMA` | Pilih provider |
| `--model ID` | Pilih model |
| `--update` | Menjalankan `git pull` untuk memperbarui |
| `--help` | Bantuan |

## Konfigurasi

File: `~/.config/deepseek-bubble/config` (izin `600`, hanya bisa dibaca pemilik).

| Variabel | Fungsi |
|---|---|
| `AI_PROVIDER` | Provider aktif |
| `AI_MODEL` | Model yang dipakai (menimpa bawaan) |
| `AI_BASE_URL` | URL endpoint untuk provider `custom` |
| `OLLAMA_HOST` | Alamat server Ollama |
| `DEEPSEEK_THINKING` | `off` (cepat, default), `on`, atau `default` (khusus DeepSeek) |
| `DEEPSEEK_MAX_TOKENS` | Batas token jawaban |
| `BASH_CONFIRM` | `1` = minta konfirmasi sebelum perintah berisiko |

Riwayat percakapan disimpan di `history.json` di folder yang sama dan dihapus saat **Reset**. Setiap perintah yang dijalankan AI dicatat di `cmd.log`.

## Keamanan — baca ini

Chat agentik bisa **menjalankan perintah shell di HP kamu**. Gunakan dengan hati-hati:

- Aktifkan konfirmasi untuk perintah berisiko (`rm`, `mv`, `chmod`, `dd`, `reboot`, dan sejenisnya) dengan menambahkan `BASH_CONFIRM=1` di file config. Perintah itu akan menunggu kamu mengetuk **Run**.
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
| `SCREEN_H_PX: unbound variable` | Sudah diperbaiki di versi ini. Jalankan `./deepseek-bubble.sh --update` |

## Pengembangan

- GitHub Actions menjalankan pengecekan sintaks dan ShellCheck pada setiap push (lihat `.github/workflows`).
- Rencana: mode agen yang memperbaiki kode di repo secara mandiri (membaca error, mengedit, menjalankan pengecekan, lalu menampilkan diff untuk disetujui), dukungan pembuatan gambar, dan perintah update yang lebih lengkap.

Kontribusi lewat Issues dan Pull Request dipersilakan.

## Lisensi dan kredit

GPL-3.0, lihat [LICENSE](LICENSE). Berdasarkan [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble). Terima kasih kepada ExTV dan pembuat Termux serta Termux:GUI.
