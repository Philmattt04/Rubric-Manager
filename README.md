# Audio/Video Uploader

A Flutter app for converting and uploading audio/video files, with two builds:

- **Portfolio version** (`lib/main_portfolio.dart`) — a client-only converter. Drop in an audio or video file, pick a target format, and it's converted entirely in the browser using FFmpeg compiled to WebAssembly, then downloaded straight to your device. No files are ever sent to a server. Live at [uploader.philmathieu.com](https://uploader.philmathieu.com/).
- **Full version** (`lib/main.dart`) — adds a login screen and uploads files directly to an S3 bucket, built for a specific internal workflow (rubric/audio management).

## Features

- Drag-and-drop or click-to-select file picker
- Audio and video format conversion (MP3, WAV, AAC, OGG, FLAC, M4A, MP4, WEBM, MOV, AVI, MKV) via FFmpeg WASM
- Real-time conversion progress
- Dark/light theme toggle
- Built with Flutter Web (Material 3)

## Getting started

Run the portfolio (client-only) build in Chrome:

```bash
flutter run -d chrome --target=lib/main_portfolio.dart
```

Run the full build (login + S3 upload) — requires `lib/config/aws_config.dart` (see `aws_config.example.dart`):

```bash
flutter run -d chrome --target=lib/main.dart
```

## Deployment

The portfolio build is deployed to S3 + CloudFront. See `deploy.sh` for the reference deploy flow (targets a different app's infra by default — adjust the bucket and distribution ID for your target).
