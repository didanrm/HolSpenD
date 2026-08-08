# Product Requirements Document (PRD)

# HolSpenD

**Version:** MVP v1.0
**Platform:** Android
**Author:** Didan
**Status:** Draft

---

# 1. Overview

HolSpenD adalah aplikasi mobile Android yang membantu pengguna mengontrol pengeluaran harian melalui konsep **Daily Wallet**.

Berbeda dengan aplikasi expense tracker pada umumnya, HolSpenD memberikan **jatah pengeluaran harian (Daily Allowance)**. Apabila pengguna berhemat pada hari tersebut, sisa uang akan otomatis dibawa ke hari berikutnya (**Carry Over**). Sebaliknya, apabila pengguna menghabiskan lebih dari jatah yang tersedia, maka kelebihan tersebut akan mengurangi jatah hari berikutnya.

Tujuan utama HolSpenD adalah membangun kebiasaan finansial yang sehat melalui sistem yang sederhana, mudah dipahami, dan memberikan motivasi untuk berhemat.

---

# 2. Problem Statement

Sebagian besar aplikasi pencatat pengeluaran hanya menampilkan:

* Total pengeluaran
* Sisa budget
* Grafik

Namun tidak memberikan panduan yang jelas mengenai:

> "Berapa uang yang aman saya keluarkan hari ini?"

Akibatnya pengguna tetap kesulitan mengontrol pengeluaran sehari-hari.

HolSpenD menjawab masalah tersebut dengan memberikan satu angka yang sangat mudah dipahami:

> **Wallet Hari Ini**

---

# 3. Goals

### Primary Goals

* Membantu pengguna menjaga pengeluaran harian.
* Membentuk kebiasaan hidup hemat.
* Mengurangi kemungkinan budget habis sebelum akhir periode.
* Memberikan rekomendasi sederhana yang mudah dipahami.

---

# 4. Target User

### Primary

* Mahasiswa
* Fresh Graduate
* Karyawan

### Secondary

* Freelancer
* Pasangan muda
* Siapa saja yang memiliki budget bulanan tetap

---

# 5. Core Concept

HolSpenD menggunakan konsep:

## Daily Wallet

Setiap hari pengguna menerima allowance.

Contoh

Budget

Rp1.400.000

Periode

5 Agustus - 31 Agustus

Jumlah hari

27

Allowance

Rp51.851/hari

Hari pertama

Wallet

Rp51.851

Pengeluaran

Rp20.000

Sisa

Rp31.851

Hari kedua

Wallet

Rp31.851

*

Rp51.851

=

Rp83.702

Semakin hemat pengguna, semakin besar Wallet Hari Berikutnya.

---

# 6. Business Rules

## Rule 1

Allowance hanya diberikan satu kali setiap pergantian hari.

---

## Rule 2

Carry Over selalu dibawa ke hari berikutnya.

---

## Rule 3

Wallet boleh bernilai negatif.

Contoh

Wallet

70.000

Pengeluaran

90.000

Wallet berikutnya

51.851 - 20.000

=

31.851

---

## Rule 4

Budget selesai ketika:

* Tanggal selesai tercapai
* User membuat budget baru

---

## Rule 5

Satu user hanya memiliki satu budget aktif pada MVP.

---

# 7. User Flow

## Login

Splash

↓

Login Google

↓

Dashboard

↓

Create Budget

↓

Dashboard

↓

Tambah Pengeluaran

↓

Insight

---

# 8. Features

## Authentication

* Login Google
* Logout

---

## Budget

User dapat membuat budget baru.

Input:

* Nama Budget
* Budget
* Tanggal Mulai
* Tanggal Selesai

Output

* Jumlah Hari
* Daily Allowance

---

## Dashboard

Menampilkan

* Wallet Hari Ini
* Budget Awal
* Budget Tersisa
* Pengeluaran Hari Ini
* Carry Over
* Hari Ke-
* Progress Budget

---

## Expense

Tambah Pengeluaran

Field

* Nominal
* Kategori
* Catatan
* Tanggal

Kategori

* 🍜 Makan
* 🚗 Transport
* 🛒 Belanja
* ☕ Nongkrong
* 🎮 Hiburan
* 💊 Kesehatan
* 📚 Pendidikan
* 💡 Lainnya

---

## Expense History

List seluruh transaksi

Filter

* Hari
* Bulan

Edit

Delete

---

## Daily Insight

Contoh

"Hari ini kamu masih memiliki Rp43.000."

atau

"Kamu berhasil menghemat Rp18.000 hari ini."

atau

"Wallet besok akan menjadi Rp70.000."

---

# 9. Dashboard Layout

```
------------------------------------

👋 Halo Didan

Wallet Hari Ini

Rp83.000

----------------------------

Budget

Rp1.400.000

Terpakai

Rp320.000

Sisa

Rp1.080.000

----------------------------

Progress

██████░░░░░

23%

----------------------------

Hari

6 dari 27

----------------------------

Pengeluaran Hari Ini

Rp20.000

Sisa Wallet

Rp63.000

----------------------------

Insight

Besok wallet kamu menjadi

Rp115.000

------------------------------------
```

---

# 10. Formula

## Daily Allowance

```
dailyAllowance =
budget
/
jumlahHari
```

---

## Wallet Hari Pertama

```
wallet =
dailyAllowance
```

---

## Wallet Hari Berikutnya

```
walletToday =
walletYesterdayRemaining
+
dailyAllowance
```

---

## Sisa Wallet

```
walletRemaining =
walletToday
-
expenseToday
```

---

## Budget Remaining

```
budgetRemaining =
budget
-
totalExpense
```

---

# 11. Notification (Optional MVP)

Jam 20.00

"Hari ini kamu masih memiliki Rp31.000."

atau

"Hari ini kamu melebihi wallet sebesar Rp15.000."

---

# 12. Tech Stack

## Mobile

Flutter

---

## Backend

Firebase

---

## Authentication

Firebase Auth

Google Login

---

## Database

Cloud Firestore

---

## Notification

Firebase Cloud Messaging

---

## Analytics

Firebase Analytics

Crashlytics

---

# 13. Firestore Structure

```
users

    uid

        profile

        activeBudget

        budgets

            budgetId

                expenses

                    expenseId
```

---

# 14. Budget Document

```
budgetId

name

amount

dailyAllowance

startDate

endDate

walletToday

walletRemaining

carryOver

currentDay

status
```

---

# 15. Expense Document

```
expenseId

amount

category

note

date

createdAt
```

---

# 16. Success Metrics

* User berhasil membuat budget < 1 menit.
* Menambah transaksi < 10 detik.
* Dashboard terbuka < 2 detik.
* Tidak ada kehilangan data.
* Perhitungan wallet selalu konsisten.

---

# 17. Future Roadmap (v2)

* OCR Scan Struk
* Voice Input
* AI Financial Assistant
* Widget Android
* Shared Budget
* Multi Wallet
* Savings Goal
* Export PDF / Excel
* Dark Mode
* Repeat Transaction
* Reminder Pengeluaran
* Statistik Bulanan
* AI Insight
* Integrasi rekening/e-wallet (opsional)

---

# 18. Product Vision

HolSpenD bukan sekadar aplikasi pencatat pengeluaran.

HolSpenD adalah **Daily Financial Companion** yang membantu pengguna mengambil keputusan finansial setiap hari melalui konsep **Daily Wallet**, sehingga pengguna terdorong untuk hidup lebih hemat tanpa merasa dibatasi.
