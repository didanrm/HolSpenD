# Menjalankan HolSpenD

Prasyarat: Flutter 3.44+, JDK 17, Android SDK 36.

```bash
git clone https://github.com/didanrm/HolSpenD.git && cd HolSpenD
flutter pub get
```

## Firebase

`lib/firebase_options.dart` dan `android/app/google-services.json` tidak ikut
di-commit — repo ini publik, dan project ID yang terbuka mengundang orang asing
menghabiskan kuota free-tier (security rules tetap menjaga isi datanya). Pakai
project Firebase sendiri.

Sebelum dikonfigurasi, aplikasi sengaja membuka layar "Firebase belum
dikonfigurasi", bukan crash.

1. Buat project di [Firebase Console](https://console.firebase.google.com).

2. **Authentication → Sign-in method → Google → Enable.**

3. **Firestore Database → Create database** → Standard edition → Production mode
   → lokasi `asia-southeast2`.

4. Siapkan debug keystore kalau belum ada:

   ```bash
   keytool -genkeypair -v -keystore ~/.android/debug.keystore -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
   ```

   Ambil SHA-1-nya:

   ```bash
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | grep SHA1
   ```

5. Pasang CLI dan generate config:

   ```bash
   npm install -g firebase-tools && dart pub global activate flutterfire_cli
   export PATH="$HOME/.pub-cache/bin:$PATH"
   firebase login && flutterfire configure
   ```

   Pilih platform **android**, package name `com.holspend.app`. Perintah ini
   menulis `lib/firebase_options.dart` dan `android/app/google-services.json`.

6. Daftarkan SHA-1 dari langkah 4 di **Settings → General → Your apps → Add
   fingerprint**. Tanpa ini Google Sign-In gagal dengan `ApiException: 10`.

7. Deploy security rules — tiap user hanya bisa membaca/menulis datanya sendiri:

   ```bash
   firebase deploy --only firestore:rules
   ```

## Jalankan

```bash
flutter run
```

## Test

Logika wallet murni Dart, tidak butuh Firebase maupun emulator:

```bash
flutter test
```

Satu file, atau satu test saja:

```bash
flutter test test/wallet_calculator_test.dart --plain-name "carry over"
```

## CI

Satu workflow, dan hanya tag yang memicunya:

| Workflow | Pemicu | Hasil |
|---|---|---|
| [`release.yml`](../.github/workflows/release.yml) | tag semver | analyze + test, lalu release APK terbit di **Releases** |

Push ke branch dan pull request **tidak** menjalankan apa pun. Selama
mengerjakan sesuatu, jalankan `flutter analyze` dan `flutter test` sendiri di
lokal — tidak ada lagi jaring pengaman otomatis di PR.

Job `verify` jalan tanpa secret apa pun — ia memakai
`lib/firebase_options.dart.example` sebagai stub — dan job `release` tidak akan
jalan kalau `verify` gagal, jadi tag tidak pernah merilis kode yang tesnya merah.

Butuh APK untuk dites di HP tanpa merilis versi sungguhan? Pakai tag
pre-release, misal `1.0.2-rc1`. Pola tag sudah mencakupnya, dan tag bertanda
hubung otomatis ditandai *pre-release* sehingga tidak menggeser rilis terbaru.

### Repository secrets

Wajib untuk job yang membangun APK:

| Secret | Isi |
|---|---|
| `FIREBASE_OPTIONS` | `lib/firebase_options.dart`, base64 |
| `GOOGLE_SERVICES_JSON` | `android/app/google-services.json`, base64 |
| `DEBUG_KEYSTORE` | `~/.android/debug.keystore`, base64 |

Opsional, untuk APK release yang ditandatangani sungguhan:

| Secret | Isi |
|---|---|
| `RELEASE_KEYSTORE` | keystore release `.jks`, base64 |
| `RELEASE_KEY_ALIAS` | alias key |
| `RELEASE_STORE_PASSWORD` | password keystore |
| `RELEASE_KEY_PASSWORD` | password key |

Isi semuanya dengan `gh` CLI:

```bash
gh secret set FIREBASE_OPTIONS     < <(base64 -i lib/firebase_options.dart)
gh secret set GOOGLE_SERVICES_JSON < <(base64 -i android/app/google-services.json)
gh secret set DEBUG_KEYSTORE       < <(base64 -i ~/.android/debug.keystore)
```

**Kenapa `DEBUG_KEYSTORE` penting.** Google Sign-In hanya jalan kalau SHA-1
sertifikat penanda tangan APK terdaftar di Firebase. Tanpa secret ini runner
membuat keystore baru tiap build, SHA-1-nya asing, dan login gagal dengan
`ApiException: 10` di APK yang kelihatannya baik-baik saja.

## Merilis

Versi diambil dari nama tag, bukan dari `pubspec.yaml` — jadi label rilis tidak
mungkin berbeda dari isinya.

```bash
git tag 1.0.0 && git push origin 1.0.0
```

Format `v1.0.0` juga diterima, begitu juga pre-release seperti `1.1.0-beta.1`.
Pipeline akan menjalankan analyze + test dulu; kalau gagal, tidak ada rilis yang
terbit. Kalau lolos, APK `holspend-<versi>.apk` muncul di halaman Releases
lengkap dengan catatan perubahan yang dihasilkan otomatis dari commit.

### Keystore release

Tanpa `RELEASE_KEYSTORE`, APK rilis ditandatangani dengan debug key — cukup
untuk dibagikan dan dipasang manual, tapi tidak layak untuk Play Store. Untuk
keystore sungguhan:

```bash
keytool -genkeypair -v -keystore holspend-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias holspend
```

Simpan file dan passwordnya baik-baik: **kalau hilang, kamu tidak bisa lagi
merilis update untuk aplikasi yang sama.** Lalu daftarkan SHA-1 keystore itu
juga di Firebase, dan unggah sebagai secret:

```bash
gh secret set RELEASE_KEYSTORE < <(base64 -i holspend-release.jks)
```

Untuk build release di lokal, buat `android/key.properties` (sudah di
`.gitignore`):

```properties
storeFile=holspend-release.jks
storePassword=...
keyAlias=holspend
keyPassword=...
```

`android/app/build.gradle` memakainya kalau ada, dan jatuh ke debug key kalau
tidak — jadi clone yang bersih tetap bisa `flutter build apk --release`.
