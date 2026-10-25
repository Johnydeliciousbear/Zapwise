# ZapWise

ZapWise is an Android app that estimates how much of certain packaging chemicals can move from a
container into frozen food while it is heated in a microwave, and shows the amount as a share of the
tolerable daily intake (% TDI) with a likely range. You photograph the package, the app recognizes the
product and the container, converts the printed cooking time to your microwave's wattage, and predicts
the intake for this meal. When the amount looks high, it compares lower-exposure options such as moving
the food to a plate or using the stove, and it warns about containers that should not be microwaved at
all. Results are kept per family member and tracked over a week.

Made by a California high-school student for the Congressional App Challenge 2026.

## What is in this repository

| Path | Contents |
|---|---|
| `app/` | The Flutter app. 56 Dart files under `lib/`, 8 unit tests and 1 on-device integration test under `test/` and `integration_test/`. |
| `app/lib/core/` | The backend: calculation engine (`engine/`), recognition (`recognition/`: text reader, container cues, wattage-label reader, image model, product matcher), local database and services (`data/`, `services/`), meal tracking (`tracking/`), quests (`quests/`). |
| `app/lib/screens`, `sheets`, `ui` | The frontend: app state, theme and pixel widgets, the four tabs (Kitchen, Log, Learn, Me), the scan flow and the bottom sheets. |
| `app/assets/` | 133 products (`data/products.json`), model coefficients (`data/zapwise_params.json`), the container-recognition model (`models/zapwise_vision.tflite`), fonts and pixel art. |
| `engine_py/` | The Python reference engine (`zapwise_engine.py`), its validation script, and the generator for the test vectors shared with the Dart engine. |
| `db/` | The product database workbook and the scripts that build it and export the app assets. |
| `ml/` | Training and export scripts for the container model and the partition-coefficient model, and a Colab notebook. |
| `design/` | Design sources: the pixel-art generators for icons, objects, the mascot and the brand, and their exported PNG and SVG assets. |
| `research/` | Notes on the packages and sources used. |
| `docs/` | Key references (`REFERENCES.md`) and the validation figures. |
| `web_demo/` | A JavaScript port of the engine with the screens adapted from the app, for viewing in a browser. |

## How the estimate works

The printed recipe is scaled to the user's wattage by energy equivalence. From the container material
and the food's fat content, the engine runs temperature, then diffusion through the plastic, then the
partition between plastic and food, then Crank migration, and converts the result to micrograms eaten
and a % of the tolerable daily intake. The inputs carry uncertainty, so the engine repeats the
calculation 300 times (Monte Carlo) and reports a value with a 5th-to-95th-percentile range. The model
equations come from published literature; the sources are listed in `docs/REFERENCES.md` and in the
database workbook. No large language model runs inside the app: recognition uses on-device Google ML Kit
and a TensorFlow Lite model, and every estimate comes from the deterministic engine.

## Build

Requires the Flutter SDK (Dart SDK ^3.12.0) and the Android SDK.

```
cd app
flutter pub get
flutter run            # on a connected device or emulator
flutter build apk      # release APK
```

The barcode lookup can use Open Food Facts; credentials, when used, are passed at build time with
`--dart-define` and are not stored in this repository.

## Use of AI

The science research, parts of the code, and the Spanish translation were produced with help from AI
tools (ChatGPT for literature search and Spanish wording, Claude for coding help). The app design, the
decisions about what to build, the code changes, the testing, and the final build were done by the
student. Every number the app shows traces back to a cited source. The in-app About text states the same.

## License

The app code in this repository is released under the MIT License (see `LICENSE`). The fonts keep their
own licenses (SIL Open Font License, see the files under `app/assets/fonts/`). Publisher PDFs of the
cited papers are not redistributed here; see `docs/REFERENCES.md` for the citations.
