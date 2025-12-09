# Salary Calculator (China & Japan)

Flutter-based salary/tax tool with multi-country support (China, Japan) and multi-language (zh/en/jp).

Features
- Country switch: China / Japan
- Languages: Chinese / English / Japanese
- China modes: monthly estimate, cumulative withholding (annual brackets)
- Monthly override (China): salary, social base, housing base, special deductions; one-click fill
- Japan: health/pension caps, employment insurance, care (40+), income tax incl. 2.1% surcharge; resident tax simplified to 10% + 5,000 (from 2nd year)

Run
```bash
flutter pub get
flutter run -d web-server --web-port 8000   # web debug
# or device/emulator:
flutter run
```

Build
- Web: `flutter build web`
- Android APK: `flutter build apk --release` (output: `build/app/outputs/flutter-apk/app-release.apk`)

Calculation summary
- China (monthly): monthly brackets (3k/12k/...) with quick deduction.
- China (cumulative): YTD income, social/housing, special deductions, standard deduction (5000×months) -> annual brackets (36k/144k/...) + quick deduction; current month tax = current cumulative tax - prior cumulative; rounded to cents.
- Japan: annual income -> employment income deduction -> social insurance (capped health/pension) -> basic/spouse/dependents -> income tax table + 2.1% surcharge; resident tax simplified to taxable×10% + 5,000 (0 in first year if desired).
