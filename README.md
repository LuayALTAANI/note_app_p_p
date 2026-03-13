# Note App P P (Flutter)

Offline-first locked private notes/media organizer with nested folders, in-app viewers, free sort + detail blocks.

## How to run

1. Install Flutter (stable).
2. Create a Flutter app folder and copy this project into it OR run:

```bash
flutter create note_app_pp
cd note_app_pp
# replace lib/, pubspec.yaml, analysis_options.yaml, build.yaml from this zip into your project
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Features in this MVP
- PIN lock on launch + optional biometrics
- Auto-lock on background + inactivity timer
- Nested folders and items (Note / Photo / Video / Voice / PDF)
- In-app viewers (text, image, video, audio, pdf)
- Item details: main content + unlimited reorderable detail blocks
- Search in folder (titles + text)
- Free sort mode (drag reorder) with persistence

## Notes
- All files are copied to app-private storage (documents directory) under `note_app_pp_assets/`.
