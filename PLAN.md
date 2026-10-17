# City VOD: southparkstudios.com client for jailbroken iOS 6 - implementation plan

Audience: an implementing model (Gemini Flash). Read this whole file first. Do not skip the "Verify first" phase.
Language of code/comments/docs: English. UI strings: English + Czech (like the other apps).

## 0. Goal and ground rules

- A native, universal (iPhone + iPad) client of **southparkstudios.com** (free episodes and clips), armv7 for iOS 6.0+,
  plus a second arm64 build for iOS 14-17 (rootless + TrollStore IPA), exactly like `..\kick-ios6` (Kicker).
- **Clone the structure of `..\kick-ios6` and reuse its code.** Read these first and copy/adapt (rename prefix `KC` -> `CV`):
  `Makefile`, `control`, `entitlements*.xml`, `.github/workflows/build.yml`, `src/Net/*` (TLS socket, HTTP client,
  connection pool, image loader, **KCMediaProxy = the local 127.0.0.1 HLS proxy**), `src/Util/*`, `src/UI/KCTheme`,
  `KCNavigator`, `KCPlayerView(Controller)`, `KCGridViewController`, `KCSettingsViewController`, `KCFavorites`,
  `README.md`/`CHANGELOG.md` style, `tools/ipad.ps1`. Also read `..\twitch-ios6` for VOD seeking + resume code and
  `..\cydia-repo\README.md` for publishing.
- App name **City VOD**, bundle/package `com.samcejko.cityvod`, folder `southpark-ios6`, Theos `APPLICATION_NAME := CityVOD`.
- Look: glossy iOS 6 (same theme code as Kicker), dark by default, light optional.
- **Legal/ethical rules (must follow):**
  - Play exactly what the site serves, no DRM circumvention, no ad blocking/skipping logic, no geo-bypass code.
  - Every request uses the same public endpoints the website itself uses; send a normal browser User-Agent.
  - README states: unofficial, not affiliated with or endorsed by Paramount/Comedy Central/South Park Digital Studios;
    all content belongs to its owners; the app only shows what southparkstudios.com shows publicly.
  - **Icon and screenshots: City VOD parody sign** (a parody homage to the City Wok sign with "CITY VOD", bowl, chopsticks,
    flames, and skyline, styled for iOS 6).
    Episode/clip thumbnails shown inside the app come from the site's own image URLs at runtime (fine), but never bundle them.

## 1. What I already verified (from a machine in Czechia, no VPN)

All of this returned HTTP 200 from Czechia, so the region is not a blocker for the user.

1. **Site is a React SPA but server-renders the data.** `GET https://www.southparkstudios.com/seasons/south-park/`
   (with a normal browser UA) returns ~330 KB HTML containing `window.__DATA__ = {...};` (JSON, with `\u002F` escapes
   for `/`; parse with `NSJSONSerialization` after cutting the balanced `{...}`; do not use regex for the JSON itself).
   It also contains `window.__PUSH_STATE__`.
2. **Episode URLs** appear in that data: `/episodes/<6-char-id>/<slug>-season-<N>-ep-<M>`
   e.g. `/episodes/940f8z/south-park-cartman-gets-an-anal-probe-season-1-ep-1`. Clip URLs: `/video-clips/<id>/<slug>`.
3. Season object keys seen: `seasonLabel`, `seasonMgid` (`mgid:arc:season:southpark.intl:<uuid>`). Series mgid:
   `mgid:arc:series:southpark.intl:27964d3c-ecfd-11e0-aca6-0026b9414f30`. Episode mgids look like
   `mgid:arc:episode:southpark.intl:<uuid>` (page data) and `mgid:arc:episode:shared.southpark.global:<same uuid>` (video service).
4. **Episode page data contains `videoServiceUrl`**:
   `https://topaz.paramount.tech/topaz/api/mgid:arc:episode:shared.southpark.global:<uuid>/mica.json?clientPlatform={clientPlatform}&advertId={advertisingid}&ssus={ssus}&bundle={bundle}&idfv={idfv}&deviceType={deviceType}&gppString={gppstring}&gppSid={gppsid}`
   Calling it with only `?clientPlatform=desktop` works (placeholders may simply be dropped/emptied).
5. **mica.json** (schema 1.0.20) key fields: `stitchedstream.source` = HLS master URL on `ns-stream.paramount.tech`
   (`.../master.m3u8?mgid=...&ts=...&pthash=...&hdnts=exp=...~acl=...~hmac=...`), `stitchedstream.manifesttype:"hls"`,
   `streamingtype:"vod"`, `duration:"00:21:59.986"`, `minrenditionheight 216` / `maxrenditionheight 1080`,
   `renditioncount 7`, `adstitchingprovider:"googledai"`, `content[0].chapters[]` (acts: `sequence`, `id`,
   `streamoffset`, `contentoffset`, `duration`), `content[0].adbreaks`, `imasdk`, `thumbnails`.
   **The URL token expires in about 4.5 minutes (`expirydate`, `hdnts exp`)**: always request mica.json right before
   playback and again if the proxy gets 403 later (resume/seek after long pauses).
6. **The master playlist is plain HLS, no DRM**: no `#EXT-X-KEY`/`SAMPLE-AES` seen. Variants are H.264 Main
   (`avc1.4d401f` etc.) + AAC-LC (`mp4a.40.2`), e.g. 960x540 @ ~795 kbps, 384x216, 512x288 ... up to 1080p. Separate
   AUDIO renditions (American English default, also "espanol latinoamericano") and a SUBTITLES rendition (WebVTT, `index-f10.m3u8`).
   Variant URIs are relative and start with a path token segment `hdntl=exp=...~acl=...~hmac=.../index-f1-v1.m3u8`.
7. Images: `https://images.paramount.tech/uri/mgid:arc:imageassetref:<...>?format=jpg&width=<w>&crop=true` works; **always
   request `format=jpg`** (default may be WebP). Kicker's libwebp decoder is still included as a fallback.

## 2. Verify first (phase 0, ~small): write `tools/probe.ps1` and confirm; adapt the plan if reality differs

I could NOT verify these; do it before writing app code and record results in `docs/API.md`:

1. **Resolve relative variant URIs correctly.** My own test failed with "Access Denied" because I resolved the relative
   URI against a base cut at the last `/` of the whole URL *including the query string*. Correct: take the master URL,
   drop `?query`, keep the path up to the last `/`, append the variant URI. Then fetch a variant and a segment and
   confirm 200. If still 403, try a browser UA / `Referer: https://www.southparkstudios.com/` / `Origin` headers.
2. **Does the stream contain ads?** `adstitchingprovider:googledai` suggests ad-stitched or DAI. Fetch a media playlist and
   look for `#EXT-X-DISCONTINUITY`, `#EXT-X-DATERANGE`, ad-looking segment paths, and compare total duration with
   `stitchedstream.duration` and the chapters. Document what you find. **Play the stream as served; do not strip anything
   except what iOS 6 cannot parse (section 6).** If separate content-only chapters exist, still just play the served stream.
3. **How to list all seasons and all episodes of a season.** Inspect `__DATA__` of `/seasons/south-park/` for a season
   list/URLs (likely `/seasons/south-park/<id>/season-<N>`, or a pagination/"load more" API under `api.neutron.paramount.tech`
   or `/api/...`; the site HTML mentions `api.neutron.paramount.tech`). Find the JSON key paths for: episode title,
   description, season/episode number, air date, duration, thumbnail URL, rating, url path, mgid. Also check whether one
   page returns a full season or is paginated, and how to get latest/featured, the clips list, and search.
4. **Which episodes are available** (some are removed by Paramount for rights reasons): detect unavailable ones
   (missing `videoServiceUrl`, non-200 mica) and show them greyed out with "Not available".
5. **Subtitle language list** and whether Czech exists (probably English only; app UI Czech anyway).
6. Confirm mica.json works without `clientPlatform` variants; pick the value that returns the best/most compatible
   renditions (`desktop` worked).
7. Check `robots`/ToS risk is acceptable: low request rate, cache aggressively (section 8).

Write the findings into `docs/API.md` (endpoint, example URL, JSON key paths). Everything in section 4 refers to that file.

## 3. Repository layout (mirror Kicker)

```
southpark-ios6/
  Makefile  control  entitlements.xml  entitlements-arm64.xml  LICENSE  README.md  CHANGELOG.md  CONTRIBUTING.md
  .github/workflows/build.yml          (copy from kick-ios6, rename; fetches mbedtls + libwebp into vendor/)
  docs/API.md  docs/PLAN.md(optional copy)
  tools/probe.ps1  tools/ipad.ps1  tools/local.json.example  tools/make-icon.ps1
  Resources/                            (Info.plist, Icon*.png original, Default*.png, en.lproj, cs.lproj Localizable.strings)
  vendor/                               (mbedtls_glue.c + fetched mbedtls, libwebp: same as Kicker)
  packages/                             (as in Kicker: deb/ipa staging)
  src/
    main.m  SPAppDelegate.{h,m}  SPCommon.{h,m}
    Net/   (copy of KC* -> SP*: TLSSocket, HTTP, HTTPRequest, ConnectionPool, ImageLoader, MediaProxy)
    Util/  (copy)
    SP/    SPAPI  SPModels  SPPageData  SPFavorites  SPHistory  SPPlayback  SPSubtitles
    UI/    SPRootViewController  SPNavigator  SPTheme  SPGridViewController  SPSeasonViewController
           SPEpisodeCell  SPEpisodeViewController  SPClipsViewController  SPSearchViewController
           SPFavoritesViewController  SPHistoryViewController  SPPlayerViewController  SPPlayerView
           SPCaptionView  SPChoiceViewController  SPSettingsViewController  SPExternalOpen
```

## 4. Data layer (`src/SP/`)

- **SPHTTP usage**: all requests through the copied TLS/HTTP stack (hosts: `www.southparkstudios.com`,
  `topaz.paramount.tech`, `ns-stream.paramount.tech`, `images.paramount.tech`). Header set: browser-like UA
  (`Mozilla/5.0 (iPad; CPU OS 12_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1`),
  `Accept-Language: en-US,en;q=0.9`, `Referer: https://www.southparkstudios.com/` for stream hosts.
- **SPPageData**: `+ (NSDictionary *)extractDataFromHTML:(NSData *)html` finds `window.__DATA__ =`, scans braces
  honoring strings/escapes to find the matching `}`, parses with `NSJSONSerialization`. Must be tolerant: return nil on failure.
- **SPModels** (immutable, `NSCoding` for caching): `SPSeason` (number, title, urlPath, episodeCount), `SPEpisode`
  (mgid, uuid, title, summary, season, number, airDate, durationSeconds, thumbURL, urlPath, available, rating),
  `SPClip` (same minus season/number). Key paths come from `docs/API.md`.
- **SPAPI** (all async with blocks, callbacks on main thread, cancelable tokens like `KCAPI`):
  - `fetchSeasons` -> `NSArray<SPSeason>`
  - `fetchEpisodesForSeason:` -> episodes (handle pagination if phase 0 found any)
  - `fetchLatest` / `fetchFeatured` (home page `/` data)
  - `fetchClipsPage:` (and a "clips of episode" if available)
  - `search:` if an endpoint is found; otherwise **local search** over the cached all-episodes index (title+summary), built
    lazily by fetching all seasons once (cache 7 days). Do not invent an endpoint.
  - `resolveStreamForItem:` -> `SPStream` { masterURL, durationSeconds, chapters[], expiresAt, audioTracks, subtitleURL }:
    1. GET the episode (or clip) page, extract `videoServiceUrl` from the embedded data;
    2. substitute placeholders: `{clientPlatform}`=`desktop`, all others = empty string (or drop those params);
    3. GET it, parse `stitchedstream.source`, `duration`, `content[0].chapters`;
    4. store `expiresAt` from `expirydateepoch`; **SPPlayback re-resolves when `now > expiresAt - 30s`**.
- **Caching**: in-memory + on-disk (Caches dir) JSON caches: seasons 24 h, episode lists 6 h, latest 15 min, resolved
  stream NEVER cached beyond expiry. Images via the copied `SPImageLoader` (memory + disk cache, downscaled for 2x/1x).
- **SPFavorites** (episodes and clips, `NSUserDefaults` or plist like KCFavorites), **SPHistory** (resume position per
  episode uuid, `watched` flag when > 92 %, "continue watching" list, last 50). Both device-local.

## 5. UI (iOS 6 glossy style, reuse SPTheme from KCTheme)

Root: tab bar on iPhone, split/master-detail or the same tab bar on iPad (follow how Kicker does it in `KCRootViewController`).

1. **Home**: "Continue watching" row (from history), "Latest episodes", "Featured clips". Grid/list cells with thumbnail,
   title, "S05 E08 - 22 min", watched checkmark, progress bar.
2. **Seasons**: list of seasons -> episode list (`SPEpisodeCell`: thumbnail left, title, S/E, air date, 2-line summary,
   duration, favourite star, watched mark, greyed if unavailable). Pull to refresh.
3. **Clips**: grid, paginated (infinite scroll).
4. **Search**: search bar over episodes+clips (see SPAPI).
5. **Library** tab: Favourites + History (segmented control).
6. **Episode detail** (push before playing): big thumbnail with play button, title, S/E, air date, summary, buttons
   Play / Resume from mm:ss / Favourite / Share (copies the southparkstudios.com URL), "Open on website" (via `SPExternalOpen`).
7. **Settings**: language (system/English/Czech), theme (dark/light), default quality (auto / 540p / 360p / audio-only is NOT
   offered), audio language (English default; Spanish if present), subtitles on/off (default off), "Play next episode
   automatically" (default on), clear caches, about + disclaimer text.
8. Czech strings for everything in `cs.lproj/Localizable.strings`; use `NSLocalizedString` keys; never hardcode UI text.
9. Errors: friendly states ("Can't reach the server", "This episode isn't available right now", retry button) - never a blank screen.
10. Autorotation: iPad all orientations; iPhone portrait + landscape (player fullscreen landscape).

## 6. Playback (`SPPlayback`, `SPPlayerViewController`, reuse `KCMediaProxy`)

iOS 6 `MPMoviePlayerController`/`AVPlayer` cannot speak modern TLS and dislikes some playlist features, so, exactly as in Kicker:

1. Start the local HTTP proxy on `127.0.0.1:<random port>`. The player is given
   `http://127.0.0.1:<port>/master.m3u8?u=<base64url(original master URL)>`.
2. Proxy fetches the real master via the TLS stack and **rewrites it**:
   - resolve every relative URI per section 2.1 and rewrite each to `http://127.0.0.1:<port>/p?u=<base64url(abs URL)>`;
   - keep only renditions the device can decode: iPad 2/iPhone 4S class -> H.264 up to 720p/Main@3.1, bitrate <= ~2.5 Mbps
     (use the same capability helper Kicker uses; on arm64 allow everything up to 1080p);
   - drop `#EXT-X-MEDIA:TYPE=SUBTITLES` and the `SUBTITLES=` attribute (iOS 6 AVPlayer is unreliable with them; we render
     our own captions, section 6.5); keep only the selected AUDIO group (default English);
   - strip unknown tags the 2012 player rejects (`#EXT-X-DEFINE`, `#EXT-X-SESSION-DATA`, `#EXT-X-SESSION-KEY`,
     `CHARACTERISTICS`/`SUPPLEMENTAL-CODECS` attributes, `VIDEO-RANGE`, `HDCP-LEVEL`, newer `#EXT-X-VERSION` > 4 -> set to 3/4
     as Kicker does; check what Kicker's proxy already strips and reuse).
3. Media playlists and segments go through the same proxy: playlist = rewrite URIs; segments = stream through unmodified
   with `Range` support. Keep-alive pooled connections (`SPConnectionPool`), 3 retries, on **403/410 re-resolve the stream**
   (call `resolveStreamForItem:` again and swap the upstream base/token transparently, keep the same local URLs: the proxy maps
   local id -> current token, so playback continues after the token expired).
4. Player UI: reuse `KCPlayerView`: play/pause, scrubber with elapsed/remaining, ±15 s buttons (or 10 s), full screen,
   AirPlay button if available, lock-screen/now-playing info (title, "South Park - S01E01"), **audio keeps playing in the
   background** (UIBackgroundModes audio, AVAudioSession playback category), quality picker, audio-language picker,
   captions picker, next-episode button (on last 20 s or on end if the setting is on).
5. **Captions**: fetch the WebVTT subtitle playlist (`index-f10.m3u8`), download its segments once via the proxy,
   parse WebVTT in `SPSubtitles` (cues: start, end, text with simple `<i>`/`<b>` tags; handle `X-TIMESTAMP-MAP`
   offset), and draw them in `SPCaptionView` over the video, synced to the player's currentPlaybackTime. Size/background options in Settings.
6. **Resume**: save position every 5 s and on pause/exit into `SPHistory`; on start, seek after `readyToPlay`.
7. Chapters (acts) from mica.json: optional "Act 1-4" jump buttons in the scrubber (only if `chapters.count > 1`).
8. Clean up the proxy and connections on dismiss; never leave sockets open in background (except audio playback).

## 7. Build, packaging, repo

- `Makefile`/`control`/entitlements/CI: copy from Kicker and rename (`Parkway_FILES`, frameworks the same). Two builds:
  armv7 iOS 6 (`iphone:clang:9.3:6.0`) and arm64 rootless (`iphone:clang:16.5:14.0`, TrollStore IPA). `control`:
  `Package: com.samcejko.parkway`, `Name: Parkway`, `Section: Multimedia`, `Depends: firmware (>= 6.0), firmware (<< 11.0)`,
  Description "Unofficial South Park Studios client for iOS 6 (universal): episodes, clips, subtitles".
- `Resources/Info.plist`: bundle id, `UIBackgroundModes` = audio, universal, `UIStatusBarStyle` like Kicker, localizations en+cs,
  icon files at all sizes (57/72/114/144 + arm64 sizes) generated by `tools/make-icon.ps1` (original artwork!).
- `README.md` in the style of Kicker's: why it is special (own TLS stack because iOS 6 cannot negotiate today's TLS; proxy
  that cleans playlists; no relay server, only requests to southparkstudios.com / paramount.tech hosts), features, install
  (repo `http://repo.samcejko.eu/`), build, disclaimer (section 0). `CHANGELOG.md` starting at 0.1.0.
- Publish later via `..\cydia-repo` (`site/data.json` entry in en+cs, icon `Icon-72@2x.png`, screenshots dir, banner,
  `colors.json`); **do this only after the user confirms**, do not run `repo-publish.ps1` yourself.

## 8. Performance / etiquette

- iPad 2 has 512 MB RAM: downscale thumbnails on decode, `NSCache` limits, reuse cells, cap parallel image loads (4), cap
  parallel HTTP connections (4 per host), cancel requests of off-screen cells.
- One request per user action; do not crawl the whole site on launch. The local-search index is built only when the user
  opens Search (progress indicator), cached 7 days.
- Handle low-memory warnings (drop caches, stop prefetching).

## 9. Milestones (do in this order; commit after each)

1. **M0** Probe + `docs/API.md` (section 2). STOP and report if streams need DRM/auth or ad-stitching requires the IMA SDK to
   obtain a playable URL.
2. **M1** Project skeleton builds (armv7 + arm64) with Kicker's Net/Util copied and renamed; empty tab UI; TLS GET to the
   site works on the device (log the `__DATA__` size).
3. **M2** Seasons -> episode lists with thumbnails (SPAPI + models + cells), caching, Czech/English strings.
4. **M3** Playback of one episode through the proxy on the iPad (rewrite + capability filter + token refresh), fullscreen,
   scrubbing, background audio, lock-screen info. Test seek far ahead after waiting > 5 min (token refresh path).
5. **M4** History/resume, favourites, home, clips, search, settings, subtitles, next-episode, chapters.
6. **M5** Polish: errors, memory, rotation, icon, README, CHANGELOG, CI, arm64 build, `.deb`/`.ipa`.

## 10. Acceptance checklist

- [ ] Fresh install on iPad 2 (iOS 6.1.x): Seasons load in < 5 s on Wi-Fi, thumbnails sharp, no crashes after 30 min of use.
- [ ] Episode starts within ~8 s, seeks work (start/middle/end), audio continues with the screen locked, lock-screen buttons work.
- [ ] Playback survives a token expiry (pause 6 min, resume; or seek after 6 min) with no user-visible error.
- [ ] English captions show/hide; audio language switch works if Spanish exists.
- [ ] Resume offers "Resume from mm:ss"; watched marks and "continue watching" correct; favourites persist across relaunch.
- [ ] Unavailable episodes are greyed with a clear message; offline/server errors give a retry state, never a blank screen.
- [ ] All UI text exists in en + cs; no hardcoded user-facing strings.
- [ ] arm64 build runs on an iOS 14-17 device with the same look.
- [ ] README disclaimer present; icon and screenshots contain no show characters/logos.
- [ ] No ad-blocking, DRM, or geo-bypass code anywhere in the repo.
