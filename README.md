# Gallery With Your Bubu

Gallery With Your Bubu is a fast, modern, cross-platform media gallery app for Windows, Linux, macOS, and Android, built with Flutter. Browse, sort, view, and play all your photos, videos, and audio files in a beautiful dark mode interface — with a built-in media player and video trimming tools.

## Features

- **Cross-platform:** Works on Windows, Linux, macOS, and Android.
- **Multi-folder scanning:** Manage multiple folders to scan via the folder manager — add or remove directories at any time.
- **In-app media player:** Play videos and audio directly in the app with full controls: play/pause, seek bar, skip ±10 seconds, playback speed (0.25x to 5x), and volume control.
- **Video trimming:** Cut/trim videos and audio with a visual range selector. Choose output resolution (same, 2K, 1080p, 720p, 480p) and format (same or GIF), with estimated file size preview. Requires FFmpeg.
- **File type filter:** Filter the gallery by file type — toggle entire categories (Images, Videos, Audio) or individual extensions, with None/Default/All quick-set buttons.
- **Section headers:** Files are grouped into sections (by month, size range, or first letter) with toggleable thin separators in the grid.
- **Sorting:** Sort media by date, size, or name, ascending or descending.
- **Search & date filter:** Search by filename and filter by date range.
- **File size on tiles:** Each grid tile shows the file size at a glance, so you don't have to open properties.
- **Fullscreen viewer:** Swipe through images and videos with zoom, keyboard navigation, and file info overlay.
- **Context menus:** Right-click or long-press for quick actions: view, open with default app, open file location, properties.
- **Modern UI:** Clean dark mode interface with adjustable grid size and a compact single-row toolbar.

## Usage

1. Run the app on your platform (Windows, Linux, macOS, or Android).
2. The app scans your default Pictures directory. Click the folder icon to add more folders.
3. Use the search bar to filter by name, the date chip for date range, and the filter icon for file types.
4. Sort by date, size, or name; toggle section headers on/off from the sort menu.
5. Click a thumbnail to view images fullscreen or play videos/audio in the built-in player.
6. In the player, use the scissors icon to trim — set start/end points, pick quality and format, then save.

## Getting Started

To build and run Gallery With Your Bubu locally:

```sh
flutter pub get
flutter run -d windows # or linux, macos, android
```

## License

MIT License. See LICENSE file for details.
