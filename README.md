<div align="center">

  <img src="assets/icon/app_icon.png" width="110" height="110" alt="Musify Logo" style="border-radius: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.3);" />

  # Musify

  ### High-Fidelity Music Streaming with Liquid Glass Optics

  [![Latest Release](https://img.shields.io/github/v/release/karvp91-art/musify?style=for-the-badge&color=84CC16&logo=github)](https://github.com/karvp91-art/musify/releases/latest)
  [![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/karvp91-art/musify/releases)
  [![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

  <p align="center">
    <b>Musify</b> is a sleek, modern, open-source music streaming client engineered with Flutter.<br/>
    Featuring authentic <b>Liquid Glass UI aesthetics</b>, real-time audio waveform editing, studio-grade equalization, synchronized lyrics, and interactive Android home screen widgets.
  </p>

  <p align="center">
    <a href="https://github.com/karvp91-art/musify/releases/latest/download/Musify.apk">
      <img src="https://img.shields.io/badge/⚡_DIRECT_DOWNLOAD_APK-LATEST-84CC16?style=for-the-badge&logo=android&logoColor=000000&labelColor=A3E635" height="44" alt="Direct Download APK" />
    </a>
    &nbsp;&nbsp;
    <a href="https://github.com/karvp91-art/musify/releases">
      <img src="https://img.shields.io/badge/📦_ALL_RELEASES-GITHUB-18181B?style=for-the-badge&logo=github&logoColor=white" height="44" alt="All Releases" />
    </a>
  </p>

  <p align="center">
    <a href="#-key-features"><b>Features</b></a> •
    <a href="#-download--installation"><b>Installation</b></a> •
    <a href="#-automated-github-releases"><b>CI/CD Releases</b></a> •
    <a href="#-build-from-source"><b>Build Guide</b></a>
  </p>

</div>

---

## ✨ Key Features

### 🎨 Liquid Glass & Shader Design
- **Authentic Liquid Glass Optics**: Specular rim lighting, refractive backdrop blur, dynamic lighting, and silky micro-animations powered by `liquid_glass_widgets`.
- **Dynamic Ambient Backdrop**: Real-time ambient mesh canvas reacting dynamically to album art palette tones.
- **Glass Mini Player**: Floating media capsule with phase-shifted 3-bar equalizer, rotating vinyl animations, and gesture dismiss.

### ✂️ Ringtone Studio
- **Real Audio Waveform Extraction**: Hardware-accelerated native audio sampling via Android's `MediaExtractor` (0 external dependencies, ~50ms extraction).
- **Draggable Trim Handles**: Dual tactile handles directly over the waveform with live time tooltips and haptic feedback.
- **Sliding Trim Window**: Drag the entire loop selection window across the track while preserving duration.
- **Live Fade-In & Fade-Out**: Interactive transition curves with real-time volume preview envelope.
- **One-Tap System Apply**: Set directly as Phone Ringtone, Notification Tone, or Alarm Sound.

### 📲 Interactive Android Home Screen Widget
- **Full Playback Control**: Play/Pause, Next, and Previous directly from your launcher without opening the app.
- **Live Metadata & Artwork**: Real-time track title, artist name, and high-res album cover updates.
- **Fully Resizable**: Seamlessly adapts from compact 2x1 to full 4x2 home screen widgets.

### 🎚️ Studio Equalizer
- **Multi-Band Parametric EQ**: Professional acoustic presets (Bass Boost, Vocal Clarity, Electronic, Rock, Acoustic, Flat).
- **Smooth Audio Processing**: Ultra-low latency playback powered by `just_audio` and `audio_service`.

### ⬇️ Offline Downloads & Dynamic Island
- **High-Quality Audio Caching**: Save your favorite songs for offline listening.
- **Dynamic Island Banner**: Floating progress indicator showing real-time download status.

### 📜 Synced Lyrics & Multi-Source Streaming
- **Synchronized Karaoke Lyrics**: Live line-by-line scrolling lyrics matching playback.
- **Multi-Source Music Catalogs**: Rich search, streaming, and metadata integration.
- **Playlist & Library Management**: Local SQLite persistence with Drift for favorites, history, and custom playlists.

---

## 📥 Download & Installation

<div align="center">

| 📱 Target | ⚡ Current Version | 📦 Package | ⬇️ 1-Click Direct Download |
| :---: | :---: | :---: | :---: |
| **Android 8.0+** <br/> *(Phone & Tablet)* | **v1.0.0** <br/> *(Latest Stable)* | `Musify.apk` <br/> *(Universal Build)* | <a href="https://github.com/karvp91-art/musify/releases/latest/download/Musify.apk"><img src="https://img.shields.io/badge/DIRECT_DOWNLOAD-APK-84CC16?style=for-the-badge&logo=android&logoColor=000000" height="36" alt="Direct Download APK"/></a> |

<br/>

<a href="https://github.com/karvp91-art/musify/releases/latest/download/Musify.apk">
  <img src="https://img.shields.io/badge/⬇️_DIRECT_DOWNLOAD_MUSIFY.APK-1--CLICK_INSTALL-84CC16?style=for-the-badge&logo=android&logoColor=000000&labelColor=A3E635" height="52" alt="Direct Download Musify APK" />
</a>

<p align="center"><sub>Direct fast CDN download • Clicking instantly starts download of Musify.apk • 100% Free</sub></p>

</div>

### Quick Installation:
1. Tap the green **[DIRECT DOWNLOAD MUSIFY.APK](https://github.com/karvp91-art/musify/releases/latest/download/Musify.apk)** button above. Download starts immediately!
2. Once the `.apk` finishes downloading, tap the notification on your phone to install.
3. If Android prompts *"Install unknown apps"*, toggle **Allow from this source**.
4. Open **Musify** and enjoy! 🎵

---

## 🚀 Automated GitHub Releases (CI/CD)

This repository includes a fully automated **GitHub Actions** workflow (`.github/workflows/release.yml`) for continuous delivery.

### How to Release a New Version:

#### Option 1: Using Git Tags (Recommended)
Simply tag your commit and push it to GitHub:
```bash
git tag v1.0.1
git push origin v1.0.1
```
*GitHub Actions will automatically spin up an Ubuntu build runner, install Flutter & Java 17, build `app-release.apk`, and publish a new GitHub Release with release notes and the APK attached.*

#### Option 2: Manual Trigger via GitHub Web UI
1. Go to the **Actions** tab in your repository: [GitHub Actions](https://github.com/karvp91-art/musify/actions).
2. Click on **Build & Release Musify APK** in the left sidebar.
3. Click **Run workflow**, specify your release tag (e.g. `v1.0.1`), and click the green button.

---

## 🛠️ Build from Source

### Prerequisites
- **Flutter SDK**: `^3.22.0` or later ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Java Development Kit**: JDK 17
- **Android SDK**: API level 34+

### Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/karvp91-art/musify.git
   cd musify
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on a connected device or emulator:**
   ```bash
   flutter run
   ```

4. **Build a production release APK:**
   ```bash
   flutter build apk --release
   ```
   The built APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🏗️ Architecture & Tech Stack

| Component | Technology |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev) (Dart SDK `^3.12`) |
| **State Management** | [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) |
| **Audio Engine** | [just_audio](https://pub.dev/packages/just_audio) & [audio_service](https://pub.dev/packages/audio_service) |
| **Local Database** | [Drift](https://pub.dev/packages/drift) (Type-safe SQLite ORM) |
| **Networking** | [Dio](https://pub.dev/packages/dio) |
| **Visual Effects** | [liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets) |
| **Native Integration** | Custom Android Plugins (`MediaExtractor`, `RingtoneManager`, `AppWidgetProvider`) |

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are always welcome!
Feel free to open an issue or submit a pull request:

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

<div align="center">
  <sub>Crafted with passion for music lovers. Star ⭐ the repository if you enjoy using Musify!</sub>
</div>
