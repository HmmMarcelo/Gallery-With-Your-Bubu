# Simple & Sweet

Main Priority Windows - Download the "Final Product Bubu" file. And open the exe and you're golden.


# Gallery With Your Bubu
Yap Yap:

Gallery With Your Bubu is a fast, modern, cross-platform media gallery app for Windows, Linux, macOS, and Android, built with Flutter. Browse, sort, view, and play all your photos, videos, and audio files in a beautiful dark mode interface — with a built-in media player, video trimming, image cropping, and batch file operations.

## Features

- **Cross-platform:** Works on Windows, Linux, macOS, and Android.
- **Multi-folder scanning:** Manage multiple folders to scan via the folder manager — add or remove directories at any time. Folder choices are persisted across sessions.
- **In-app media player:** Play videos and audio directly in the app with full controls: play/pause, seek bar, skip ±10 seconds, playback speed (0.25x to 5x), and volume control.
- **Video trimming:** Cut/trim videos and audio with a visual range selector. Choose output resolution (same, 2K, 1080p, 720p, 480p) and format (same or GIF), with estimated file size preview. Requires FFmpeg.
- **Image cropping:** Crop images with a visual tool featuring draggable handles, rule-of-thirds grid, and pixel dimension display. Save as a copy or overwrite the original.
- **Selection mode:** Select multiple files with checkboxes for batch operations:
  - **Section headers act as select-all toggles** — tap a section header to select or deselect all files in that group.
  - **Delete** — permanently remove files (with confirmation dialog).
  - **Cut & Move** — move files to a chosen destination folder.
  - **Copy & Paste** — copy files to a chosen destination folder.
  - **Safe Move** — copy files, verify each copy, then delete originals.
- **Fullscreen viewer:** Navigate images and videos with left/right arrow buttons, keyboard arrows, swipe gestures, zoom, and file info overlay.
- **Direct video playback:** Tapping a video in the gallery opens the in-app media player immediately — no intermediate preview step.
- **File type filter:** Filter the gallery by file type — toggle entire categories (Images, Videos, Audio) or individual extensions, with None/Default/All quick-set buttons.
- **Section headers:** Files are grouped into sections (by month, size range, or first letter) with toggleable separators in the grid.
- **Sorting:** Sort media by date, size, or name, ascending or descending.
- **Search & date filter:** Search by filename and filter by date range.
- **File size on tiles:** Each grid tile shows the file size at a glance.
- **Settings:** Customize the gallery background with a solid color (preset swatches or custom hex) or an image. Settings and folders persist across app restarts.
- **Context menus:** Right-click or long-press for quick actions: view, open with default app, open file location, properties.
- **Modern UI:** Clean dark mode interface with adjustable grid size and a compact single-row toolbar.

## Usage

1. Run the app on your platform (Windows, Linux, macOS, or Android).
2. The app scans your default Pictures directory. Click the folder icon to add more folders — they'll be remembered.
3. Use the search bar to filter by name, the date chip for date range, and the filter icon for file types.
4. Sort by date, size, or name; toggle section headers on/off from the sort menu.
5. Click the checkbox icon to enter selection mode — select files, then use the action bar to delete, move, or copy.
6. Click a thumbnail to view images fullscreen. Use the left/right arrows to navigate. Click the crop icon to crop images.
7. Click a video thumbnail to open the in-app player. Use the scissors icon to trim — set start/end points, pick quality and format, then save.
8. Click the gear icon for settings — change the background or view version info.

## Getting Started

To build and run Gallery With Your Bubu locally:

```sh
flutter pub get
flutter run -d windows # or linux, macos, android
```

## Running on Android

You can test on a physical Android device or an emulator:

### Using an emulator
1. Install Android Studio and create an AVD (Android Virtual Device) via **Tools > Device Manager**.
2. Start the emulator from Android Studio or via command line:
   ```sh
   emulator -avd <avd_name>
   ```
3. Check that Flutter sees the device:
   ```sh
   flutter devices
   ```
4. Run the app:
   ```sh
   flutter run -d emulator-5554
   ```

### Using a physical device
1. Enable **Developer Options** on your Android phone (tap Build Number 7 times in Settings > About Phone).
2. Enable **USB debugging** in Developer Options.
3. Connect your phone via USB and accept the debugging prompt.
4. Verify the device is detected:
   ```sh
   flutter devices
   ```
5. Run the app:
   ```sh
   flutter run
   ```

> **Note:** If multiple devices are connected, specify one with `flutter run -d <device_id>`. Use `flutter devices` to see available device IDs.

## License

MIT License. See LICENSE file for details.
