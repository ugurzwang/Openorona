# Openorona

Openorona is a Flutter implementation of Fanorona, the traditional strategy board game from Madagascar.

## Features

- Fanorona-Telo (3×3), Fanorona-Dimy (5×5), and Fanorona-Tsivy (9×5)
- Play against the computer or pass and play on one device
- Five computer difficulty levels
- Optional per-player timers for pass and play
- Automatic save and continue, move undo, and vibration setting

## Run locally

Install Flutter, then run:

```sh
flutter pub get
flutter run
```

Run checks and build a debug Android APK:

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## License

Openorona is released under the MIT License. See [LICENSE](LICENSE).
