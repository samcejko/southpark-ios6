# South Park Studios API Documentation

This document describes the endpoints, data extraction, streaming protocol, and schemas used by the **City VOD** iOS 6 app. All data is verified from live traffic to `southparkstudios.com` and Paramount media servers.

---

## 1. Page Architecture & `window.__DATA__` Extraction

`southparkstudios.com` is a Next.js / React application with Server-Side Rendering (SSR). Every page includes a complete JSON payload embedded in the HTML:

```html
<script>
  window.__DATA__ = { ... };
</script>
```

### Extraction Algorithm (`CVPageData`)
1. Scan HTML for `window.__DATA__`.
2. Locate the first opening brace `{` after the declaration.
3. Walk characters with a brace counter (`depth`), taking care of string literals (`"..."`) and escape sequences (`\"` and `\\`).
4. When `depth == 0`, slice the JSON substring.
5. Parse using `NSJSONSerialization JSONObjectWithData:options:error:`.

---

## 2. Seasons and Episodes

### 2.1 Season List
- **Source**: `GET https://www.southparkstudios.com/seasons/south-park/`
- **JSON Path**: Find component where `node.type == "SeasonSelector"`.
- **Items Array**: `SeasonSelector.props.items`
- **Item Fields**:
  - `label` (NSString): e.g. `"Season 1"`, `"Season 2"`, ...
  - `seasonNumber` (NSInteger): `1`, `2`, `3`, ..., `29`
  - `url` (NSString, optional):
    - Season 1: `nil` (or `/seasons/south-park/`)
    - Season 2: `"/seasons/south-park/cfnwds/season-2"`
    - Season N: `"/seasons/south-park/<slug>/season-<N>"`

### 2.2 Season Episodes List
- **Source**: `GET https://www.southparkstudios.com` + `season.url`
- **JSON Path**: Traverse the tree to find `LineList` components where items have `entityType == "episode"` or `itemType == "episode"`.
- **Episode Fields**:
  - `id` (NSString): Episode UUID, e.g. `"5fd82670-ecfd-11e0-aca6-0026b9414f30"`.
  - `url` (NSString): Relative page path, e.g. `"/episodes/utrgmi/south-park-terrance-and-phillip-in-not-without-my-anus-season-2-ep-1"`.
  - `meta.header.title.text` (NSString): e.g. `"S2 • E1"`.
  - `meta.subHeader` (NSString): Episode title, e.g. `"Terrance and Phillip in Not Without My Anus"`.
  - `meta.description` (NSString): Synopsis.
  - `meta.date` (NSString): Air date, e.g. `"04/01/1998"`.
  - `meta.itemMgid` (NSString): e.g. `"mgid:arc:episode:southpark.intl:5fd82670-ecfd-11e0-aca6-0026b9414f30"`.
  - `meta.seasonMgid` (NSString): Season MGID.
  - `media.duration` (NSString): e.g. `"22:00"`.
  - `media.image.url` (NSString): Thumbnail image URL. **Append `&format=jpg`** to ensure standard JPEG format.

---

## 3. Video Stream Resolution (`mica.json`)

### 3.1 Obtaining `videoServiceUrl`
1. Fetch the episode or clip HTML page.
2. Extract `window.__DATA__`.
3. Recursively search for the key `"videoServiceUrl"`.
   Example raw template:
   ```
   https://topaz.paramount.tech/topaz/api/mgid:arc:episode:shared.southpark.global:<UUID>/mica.json?clientPlatform={clientPlatform}&advertId={advertisingid}&ssus={ssus}&bundle={bundle}&idfv={idfv}&deviceType={deviceType}&gppString={gppstring}&gppSid={gppsid}
   ```
4. Clean placeholders:
   - `{clientPlatform}` -> `desktop`
   - Strip all unused `&key={value}` query parameters.
   Result:
   ```
   https://topaz.paramount.tech/topaz/api/mgid:arc:episode:shared.southpark.global:<UUID>/mica.json?clientPlatform=desktop
   ```

### 3.2 `mica.json` Schema & Response
- **HTTP**: `GET` with browser `User-Agent`. Returns HTTP 200 application/json.
- **Fields**:
  - `stitchedstream.source`: Absolute URL to master HLS playlist on `ns-stream.paramount.tech` with authentication tokens (`hdnts` query parameter).
  - `stitchedstream.duration`: Formatted duration, e.g. `"00:22:00.613"`.
  - `expirydateepoch`: Unix timestamp string when the stream token expires (~4.5 minutes).
  - `content[0].chapters`: Array of acts (`sequence`, `duration`, `streamoffset`, `contentoffset`).
  - `content[0].adbreaks`: Commercial cue points.

---

## 4. HLS Playback & Proxy Specifications

### 4.1 Master Playlist Resolution
The master playlist URL format:
```
https://ns-stream.paramount.tech/h/a/<token_path>/master.m3u8?mgid=...&hdnts=exp=...~hmac=...
```
- Base path for relative variants: strip query string and filename:
  ```
  https://ns-stream.paramount.tech/h/a/<token_path>/
  ```
- Variant lines in master playlist (e.g. `hdntl=exp=.../index-f1-v1.m3u8`):
  Append directly to the base path:
  ```
  https://ns-stream.paramount.tech/h/a/<token_path>/hdntl=exp=.../index-f1-v1.m3u8
  ```

### 4.2 Variant Playlist & Encryption
- In variant playlists, segments are encrypted with standard **AES-128**:
  ```m3u8
  #EXT-X-KEY:METHOD=AES-128,URI="encryption-f1.key"
  ```
- **Key Resolution**: `encryption-f1.key` is resolved relative to the variant playlist path.
  Key request returns HTTP 200 with exactly 16 bytes (raw AES key).
- **Segment URIs**: Lines in the variant playlist are already absolute URLs pointing to `southpark.orchestrator.viacomcbs-tech.com`.
  Segment request returns HTTP 200 with raw MPEG-TS data.

### 4.3 Proxy Rewriting for iOS 6 (`CVMediaProxy`)
1. Local proxy runs on `http://127.0.0.1:<port>/`.
2. Master playlist rewrites:
   - Filter renditions by device capabilities (armv7: up to 720p / 2.5 Mbps; arm64: up to 1080p).
   - Strip unknown tags (`#EXT-X-PLACEMENT-OPPORTUNITY`, `#EXT-X-DEFINE`, etc.).
   - Set `#EXT-X-VERSION:3`.
   - Rewrite variant URLs to `http://127.0.0.1:<port>/v?u=<base64url>`.
   - Strip `#EXT-X-MEDIA:TYPE=SUBTITLES` (rendered natively by `CVCaptionView`).
3. Variant playlist rewrites:
   - Rewrite `#EXT-X-KEY:URI="encryption-f1.key"` to `http://127.0.0.1:<port>/k?u=<base64url>`.
   - Rewrite segment URLs to `http://127.0.0.1:<port>/s?u=<base64url>`.
4. On 403 / token expiry during streaming:
   The proxy transparently calls `mica.json` again, extracts the fresh master URL and token, and seamlessly fetches the new key/segments without interrupting playback.

---

## 5. Subtitles (WebVTT)
- The master playlist contains a WebVTT subtitles group:
  ```m3u8
  #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs0",NAME="American English",LANGUAGE="en",URI="hdntl=.../index-f9.m3u8"
  ```
- Subtitle segment files end in `.vtt`.
- Each segment returns standard WebVTT text with timestamps (`00:00:02.711 --> 00:00:05.714`).
- `CVSubtitles` downloads and parses all cues at stream start into memory, and `CVCaptionView` renders the active cue in real time over `AVPlayer`.

---

## 6. Clips & Home Page
- **Home**: `https://www.southparkstudios.com/` contains `LineList` items with `NEW EPISODE CLIPS` and featured collections.
- **Clips**: `/video-clips/<id>/<slug>` uses the identical `videoServiceUrl` -> `mica.json` pipeline.
