<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/banner-dark.png">
  <img src="docs/banner.png" width="460" alt="HolSpenD">
</picture>

### Berapa uang yang aman saya keluarkan hari ini?

Aplikasi pengelola pengeluaran berbasis **Daily Wallet** — budget dibagi jadi
jatah harian, sisa hari ini dibawa ke besok, boros hari ini mengecilkan jatah
besok.

[![Build APK](https://github.com/didanrm/HolSpenD/actions/workflows/build.yml/badge.svg)](https://github.com/didanrm/HolSpenD/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/didanrm/HolSpenD?label=Unduh%20APK&color=3DDC84&logo=android&logoColor=white)](https://github.com/didanrm/HolSpenD/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## Masalahnya

Aplikasi pencatat pengeluaran biasanya menampilkan total, sisa budget, dan
grafik. Semuanya benar. Tak satu pun menjawab pertanyaan yang benar-benar muncul
saat kamu berdiri di depan kasir.

HolSpenD menjawabnya dengan **satu angka**: Wallet Hari Ini.

```
Budget    Rp1.400.000        Jatah harian    Rp51.851
Periode   5 – 31 Agustus     Hari ke-1       Rp51.851
27 hari                      Belanja 20rb    sisa Rp31.851
                             Hari ke-2       Rp83.702  ← sisa kemarin ikut
```

Hemat hari ini, wallet besok membesar. Boros hari ini, besok mengecil. Tanpa
denda, tanpa ceramah — hanya konsekuensi yang jujur.

## Isinya

|  |  |
|---|---|
| 🔐 **Login Google** | Satu ketukan, data tersimpan di akun Google |
| 💰 **Daily Wallet** | Jatah harian otomatis dari budget dan periode |
| 🔄 **Carry Over** | Sisa hari ini masuk wallet besok, otomatis |
| 📉 **Wallet negatif** | Boros dicatat jujur dan memotong jatah besok |
| ➕ **Catat cepat** | Nominal, kategori, catatan, tanggal |
| 🍜 **8 kategori** | Makan, Transport, Belanja, Nongkrong, Hiburan, Kesehatan, Pendidikan, Lainnya |
| 📜 **Riwayat** | Filter hari / bulan / semua, dengan edit dan hapus |
| 💡 **Daily Insight** | Sisa hari ini, dan wallet besok jadi berapa |

## Keputusan teknis yang menentukan segalanya

Wallet **tidak pernah disimpan** sebagai angka yang di-update tiap malam. Setiap
kali dibaca, ia dihitung ulang dari seluruh riwayat pengeluaran:

```dart
walletToday     = dailyAllowance * currentDay - totalSebelumHariIni
walletRemaining = walletToday - pengeluaranHariIni
carryOver       = walletToday - dailyAllowance
```

Terlihat sepele, dampaknya tidak:

- **Tidak ada job pergantian hari.** Aplikasi ditutup seminggu lalu dibuka lagi
  tetap menghasilkan angka yang benar. Tidak ada cron, tidak ada Cloud Function.
- **Koreksi retroaktif.** Edit atau hapus transaksi kemarin otomatis memperbaiki
  wallet hari ini.
- **Anti duplikat.** Penggandaan jatah akibat rollover jalan dua kali secara
  struktural mustahil — tidak ada state yang bisa diganda.
- **Bisa diuji.** `WalletCalculator.compute()` menerima `now` sebagai parameter,
  bukan memanggil `DateTime.now()`. 19 test mengunci tiap fase dan kasus tepi:
  contoh dari PRD, carry over negatif, budget yang sudah selesai, transaksi
  bertanggal masa depan, dan pergantian tengah malam.

Intinya ada di [`lib/logic/wallet_calculator.dart`](lib/logic/wallet_calculator.dart)
— murni Dart, tanpa Firebase, tanpa jam, tanpa widget.

## Bentuknya

```
lib/
├── logic/wallet_calculator.dart  ⭐ inti: matematika wallet
├── models/                       Budget, Expense, ExpenseCategory
├── services/                     Auth, Firestore repository, Analytics
├── providers/                    Riverpod: auth → budget → expenses → wallet
├── screens/                      login, create budget, dashboard, expense, history
├── widgets/                      WalletHero, BudgetSummary, Insight, ExpenseTile
└── core/                         date, format Rupiah, theme
```

```
users/{uid}                          profil, activeBudgetId
└── budgets/{budgetId}               budget + cermin wallet
    └── expenses/{expenseId}         nominal, kategori, catatan, tanggal
```

Satu user, satu budget aktif. Membuat budget baru akan menutup yang lama,
membuat yang baru, dan memindahkan `activeBudgetId` dalam **satu batch atomik** —
tidak pernah ada momen dengan dua budget aktif atau nol.

Semua perhitungan tanggal berjalan pada hari kalender dengan komponen waktu
dibuang: belanja jam 23:59 dan jam 00:01 wajib jatuh di hari berbeda, berapa pun
jamnya.

## Dibangun dengan

Flutter · Material 3 · Riverpod · Firebase Auth · Cloud Firestore · Firebase
Analytics · `intl` untuk Rupiah dan tanggal Indonesia

Antarmuka berbahasa Indonesia; kode, komentar, dan identifier bahasa Inggris.

---

<div align="center">

MIT © Didan

</div>
