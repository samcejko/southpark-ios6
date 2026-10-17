const https = require('https');
const fs = require('fs');

function fetchUrl(url, headers = {}) {
    return new Promise((resolve, reject) => {
        const u = new URL(url);
        const options = {
            hostname: u.hostname,
            path: u.pathname + u.search,
            method: 'GET',
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                ...headers
            }
        };
        https.get(options, (res) => {
            let data = [];
            res.on('data', chunk => data.push(chunk));
            res.on('end', () => {
                const buffer = Buffer.concat(data);
                resolve({ statusCode: res.statusCode, headers: res.headers, body: buffer });
            });
        }).on('error', reject);
    });
}

function extractDataJson(html) {
    const idx = html.indexOf('window.__DATA__');
    if (idx === -1) return null;
    const start = html.indexOf('{', idx);
    let depth = 0;
    let inString = false;
    let escape = false;
    let end = -1;
    for (let i = start; i < html.length; i++) {
        const ch = html[i];
        if (escape) {
            escape = false;
            continue;
        }
        if (ch === '\\') {
            escape = true;
            continue;
        }
        if (ch === '"') {
            inString = !inString;
            continue;
        }
        if (!inString) {
            if (ch === '{') depth++;
            else if (ch === '}') {
                depth--;
                if (depth === 0) {
                    end = i + 1;
                    break;
                }
            }
        }
    }
    if (end === -1) return null;
    return JSON.parse(html.substring(start, end));
}

function findEpisodes(node) {
    let eps = [];
    if (!node) return eps;
    if (node.props && node.props.items && Array.isArray(node.props.items)) {
        for (const it of node.props.items) {
            if (it.entityType === 'episode' || it.itemType === 'episode') eps.push(it);
        }
    }
    if (Array.isArray(node.children)) {
        for (const c of node.children) eps = eps.concat(findEpisodes(c));
    }
    return eps;
}

function findSeasons(node) {
    if (!node) return null;
    if (node.type === 'SeasonSelector' && node.props && Array.isArray(node.props.items)) {
        return node.props.items;
    }
    if (Array.isArray(node.children)) {
        for (const c of node.children) {
            const res = findSeasons(c);
            if (res) return res;
        }
    }
    return null;
}

async function run() {
    console.log('=== Step 1: Probe Season 2 page ===');
    const s2Res = await fetchUrl('https://www.southparkstudios.com/seasons/south-park/cfnwds/season-2');
    console.log('Season 2 HTTP Status:', s2Res.statusCode, 'Length:', s2Res.body.length);
    const s2Html = s2Res.body.toString('utf8');
    const s2Data = extractDataJson(s2Html);
    if (!s2Data) {
        console.error('Failed to extract __DATA__ from Season 2');
        return;
    }
    const s2Eps = findEpisodes(s2Data);
    console.log('Season 2 episode count:', s2Eps.length);
    console.log('Sample Season 2 episode:');
    console.log(JSON.stringify(s2Eps[0], null, 2));

    console.log('\n=== Step 2: Probe Episode Video Service & mica.json ===');
    const epUrl = 'https://www.southparkstudios.com' + s2Eps[0].url;
    console.log('Fetching episode page:', epUrl);
    const epRes = await fetchUrl(epUrl);
    const epHtml = epRes.body.toString('utf8');
    const epData = extractDataJson(epHtml);

    // Look for videoServiceUrl or mica
    let videoServiceUrl = null;
    function findVideoService(obj) {
        if (!obj || typeof obj !== 'object') return;
        if (obj.videoServiceUrl) {
            videoServiceUrl = obj.videoServiceUrl;
            return;
        }
        for (const k of Object.keys(obj)) {
            findVideoService(obj[k]);
            if (videoServiceUrl) return;
        }
    }
    findVideoService(epData);
    console.log('Found raw videoServiceUrl:', videoServiceUrl);

    if (videoServiceUrl) {
        const cleanVideoServiceUrl = videoServiceUrl
            .replace('{clientPlatform}', 'desktop')
            .replace(/&[a-zA-Z]+=\{[a-zA-Z]+\}/g, '')
            .replace(/\?[a-zA-Z]+=\{[a-zA-Z]+\}&?/, '?');
        console.log('Clean videoServiceUrl:', cleanVideoServiceUrl);

        const micaRes = await fetchUrl(cleanVideoServiceUrl);
        console.log('mica.json status:', micaRes.statusCode);
        const mica = JSON.parse(micaRes.body.toString('utf8'));
        console.log('mica stitchedstream source:', mica.stitchedstream ? mica.stitchedstream.source : null);
        console.log('mica duration:', mica.stitchedstream ? mica.stitchedstream.duration : null);
        console.log('mica chapters count:', mica.content && mica.content[0] ? mica.content[0].chapters.length : 0);

        if (mica.stitchedstream && mica.stitchedstream.source) {
            console.log('\n=== Step 3: Test HLS Master & Variant & Media Segments ===');
            const masterUrl = mica.stitchedstream.source;
            const masterRes = await fetchUrl(masterUrl, {
                'Referer': 'https://www.southparkstudios.com/'
            });
            console.log('Master HLS status:', masterRes.statusCode);
            const masterContent = masterRes.body.toString('utf8');
            console.log('Master HLS first 500 chars:\n', masterContent.slice(0, 500));

            // Test relative resolution
            // Master URL format: https://ns-stream.paramount.tech/h/a/.../master.m3u8?query...
            const u = new URL(masterUrl);
            const basePath = u.pathname.substring(0, u.pathname.lastIndexOf('/') + 1);
            console.log('Base path without query:', basePath);

            // Find first variant line in masterContent
            const lines = masterContent.split(/\r?\n/);
            let variantRel = null;
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
                    variantRel = lines[i + 1].trim();
                    break;
                }
            }
            console.log('First variant relative URI:', variantRel);
            if (variantRel) {
                // If variantRel starts with "hdntl=...", we resolve it against basePath
                const variantAbsUrl = u.protocol + '//' + u.host + basePath + variantRel;
                console.log('Testing variant absolute URL:', variantAbsUrl);
                const variantRes = await fetchUrl(variantAbsUrl, {
                    'Referer': 'https://www.southparkstudios.com/'
                });
                console.log('Variant HLS status:', variantRes.statusCode, 'Length:', variantRes.body.length);
                const variantContent = variantRes.body.toString('utf8');
                console.log('Variant first 400 chars:\n', variantContent.slice(0, 400));

                // Find first media segment in variantContent
                const vLines = variantContent.split(/\r?\n/);
                let segmentRel = null;
                for (const line of vLines) {
                    const trimmed = line.trim();
                    if (trimmed && !trimmed.startsWith('#')) {
                        segmentRel = trimmed;
                        break;
                    }
                }
                // The segment URL in the playlist is already absolute!
                const lines = variantContent.split(/\r?\n/);
                const segAbsUrl = lines.find(l => l.startsWith('https://'));
                console.log('Testing segment absolute URL:', segAbsUrl);
                if (segAbsUrl) {
                    const segRes = await fetchUrl(segAbsUrl, {
                        'Referer': 'https://www.southparkstudios.com/'
                    });
                    console.log('Segment status:', segRes.statusCode, 'Segment byte length:', segRes.body.length);
                    if (segRes.statusCode === 200 && segRes.body.length > 1000) {
                        console.log('SUCCESS! Segment fetched perfectly!');
                    }
                }
            }
        }
    }

    console.log('\n=== Step 4: Probe Video Clip Page ===');
    const clipRes = await fetchUrl('https://www.southparkstudios.com/video-clips/0gatmf/south-park-ike-wins-the-aura-battle');
    console.log('Clip page status:', clipRes.statusCode);
    const clipData = extractDataJson(clipRes.body.toString('utf8'));
    let clipVideoServiceUrl = null;
    function findClipVideo(obj) {
        if (!obj || typeof obj !== 'object') return;
        if (obj.videoServiceUrl) { clipVideoServiceUrl = obj.videoServiceUrl; return; }
        for (const k of Object.keys(obj)) { findClipVideo(obj[k]); if (clipVideoServiceUrl) return; }
    }
    findClipVideo(clipData);
    console.log('Found clip videoServiceUrl:', clipVideoServiceUrl);
    if (clipVideoServiceUrl) {
        const cleanClipUrl = clipVideoServiceUrl.replace('{clientPlatform}', 'desktop').replace(/&[a-zA-Z]+=\{[a-zA-Z]+\}/g, '');
        const clipMicaRes = await fetchUrl(cleanClipUrl);
        console.log('Clip mica status:', clipMicaRes.statusCode);
        const clipMica = JSON.parse(clipMicaRes.body.toString('utf8'));
        console.log('Clip stitchedstream source:', clipMica.stitchedstream ? clipMica.stitchedstream.source : null);
    }

    console.log('\n=== Step 5: Probe Home Page ===');
    const homeRes = await fetchUrl('https://www.southparkstudios.com/');
    console.log('Home status:', homeRes.statusCode);
    const homeData = extractDataJson(homeRes.body.toString('utf8'));
    function dumpHomeLists(n) {
        if (!n) return;
        if (n.type === 'LineList' && n.props && n.props.items && n.props.items.length) {
            console.log('Home LineList:', n.props.header ? n.props.header.title : '(no title)', 'count:', n.props.items.length, 'type:', n.props.items[0].entityType || n.props.items[0].itemType);
        }
        if (Array.isArray(n.children)) n.children.forEach(dumpHomeLists);
    }
    dumpHomeLists(homeData);
}

run().catch(console.error);
