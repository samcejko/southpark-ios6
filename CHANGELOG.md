# Changelog

All notable changes to **City VOD** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-10-17

### Changed
- **City VOD Red Glossy Action Buttons**: replaced lime-green accent buttons with rich crimson-red skeuomorphic buttons (`#EB2D37` gradient) matching the City Wok branding, complete with classic iOS 6 embossed white text shadow.
- **Thumbnail Duration Pill & Progress Bar Spacing**: separated the thumbnail duration pill and playback progress bar by 4pt to prevent visual collisions, refined margins and padding, and hidden duration pills on missing/zero duration (`00:00`).

## [0.1.2] - 2026-10-17

### Fixed
- **Dark mode for Season list**: fixed white table view cells on iOS 14–17 by applying dark theme cell styling (`stylePlainCell:`, dark background, clear content view, and dark interface override) to `CVSeasonViewController`.
- **Table view appearance**: explicitly configured table views across all controllers with `applyToTableView:` so dark indicator styles and iOS 13+ dark mode overrides are applied consistently.

## [0.1.1] - 2026-10-17

### Fixed
- **Instant offline-ready search**: bundled offline catalog of all South Park episodes across Seasons 1–28 for instant live search as you type.
- **Player scrubber label backgrounds**: fixed white rectangular artifacts around elapsed and remaining time labels on iOS 6 by making label backgrounds clear.
- **Streamlined player controls**: removed act/chapter buttons at the bottom of the video player for a clean, unobstructed view.

## [0.1.0] - 2026-10-17

### Added
- **Initial release of City VOD** – Unofficial native South Park Studios client for iOS 6.0+ (armv7 & arm64).
- **Core Engine & Networking**:
  - Embedded **Mbed TLS 3.6.7** stack enabling modern TLS 1.2/1.3 communication on legacy iOS.
  - Local HTTP media relay proxy (`CVMediaProxy`) running on `127.0.0.1` that resolves, rewrites, and strips unsupported HLS tags for iOS 6 `AVPlayer`.
  - Transparent relaying of RFC 8216 AES-128 keys and media segments with desktop browser User-Agent and Referer headers.
  - Automatic token expiration tracking (`expirydateepoch`) and transparent re-resolution without stream interruption.
  - Custom WebVTT subtitle fetcher and parser (`CVSubtitles`) with real-time synchronized overlay (`CVCaptionView`).
  - WebP image decoder via `libwebp 1.5.0` with disk and memory caching.
- **User Interface**:
  - Classic glossy skeuomorphic iOS 6 interface (custom vector navigation and tab bar artwork).
  - City Wok restaurant parody branding ("City VOD - Try our City VOD!").
  - **Home**: "Continue Watching" carousel, featured clips, and recent full episodes.
  - **Seasons & Episodes**: Full catalogue from Season 1 to Season 27+, with episode counts, air dates, and summaries.
  - **Clips**: Browse memorable South Park clips.
  - **Search**: Instant local and cached search across all seasons, episodes, and clips.
  - **Library**: Segmented view for Favorites and Watch History, with progress indicator pills and resume positions.
  - **Video Player**:
    - Fullscreen landscape playback with custom transport controls.
    - Act (chapter) markers and quick-jump buttons parsed from `mica.json`.
    - Scrubber with elapsed and remaining timestamps, ±15s jump buttons.
    - Quality selector (Auto capability-filtered, Source, 1080p, 720p, 480p, 360p).
    - Subtitle overlay with CC toggle.
    - Lock-screen Now Playing metadata and remote transport controls.
    - Background audio playback (`AVAudioSessionCategoryPlayback`).
  - **Settings**:
    - Quality preferences, auto-play next episode, subtitles default toggle.
    - Dark and Light theme toggle (with City VOD crimson red accents).
    - Audio language selection (English / Español).
    - TLS certificate verification toggle, image cache clearer, and live connection test.
- **Platform Support**:
  - Dual build system via Theos:
    - 32-bit `armv7` `.deb` package targeting iOS 6.0–10.x (e.g. iPad 2, iPhone 4S, iPhone 5).
    - 64-bit `arm64` rootless `.deb` and TrollStore `.ipa` targeting iOS 14.0–17.x.
  - Universal layout optimized for both iPhone and iPad (all device orientations).
  - Full English and Czech (`cs`) localizations.
