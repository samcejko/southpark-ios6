const https = require('https');
const fs = require('fs');
const path = require('path');

function fetchUrl(url, maxRedirects = 5) {
    return new Promise((resolve, reject) => {
        if (maxRedirects <= 0) return reject(new Error('Too many redirects'));
        const u = new URL(url);
        const req = https.get({
            hostname: u.hostname,
            path: u.pathname + u.search,
            headers: {
                'User-Agent': 'Mozilla/5.0 (iPad; CPU OS 12_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9'
            }
        }, res => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                let loc = res.headers.location;
                if (!loc.startsWith('http')) loc = 'https://www.southparkstudios.com' + loc;
                return resolve(fetchUrl(loc, maxRedirects - 1));
            }
            let data = [];
            res.on('data', chunk => data.push(chunk));
            res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(data).toString('utf8') }));
        });
        req.setTimeout(8000, () => {
            req.destroy(new Error('HTTP request timed out: ' + url));
        });
        req.on('error', reject);
    });
}

function extractData(html) {
    const idx = html.indexOf('window.__DATA__');
    if (idx === -1) return null;
    const start = html.indexOf('{', idx);
    let depth = 0, inStr = false, esc = false, end = -1;
    for (let i = start; i < html.length; i++) {
        const c = html[i];
        if (esc) { esc = false; continue; }
        if (c === '\\') { esc = true; continue; }
        if (c === '"') { inStr = !inStr; continue; }
        if (!inStr) {
            if (c === '{') depth++;
            else if (c === '}') {
                depth--;
                if (depth === 0) { end = i + 1; break; }
            }
        }
    }
    return end !== -1 ? JSON.parse(html.substring(start, end)) : null;
}

function findComponents(node, type, results) {
    if (!node || typeof node !== 'object') return;
    if (node.type === type) results.push(node);
    if (Array.isArray(node.children)) {
        for (const c of node.children) findComponents(c, type, results);
    }
}

async function main() {
    console.log('Fetching seasons list...');
    const page = await fetchUrl('https://www.southparkstudios.com/seasons/south-park');
    const data = extractData(page.body);
    if (!data) throw new Error('Could not extract DATA from seasons page');

    const selectors = [];
    findComponents(data, 'SeasonSelector', selectors);
    let rawSeasons = [];
    for (const sel of selectors) {
        if (sel.props && Array.isArray(sel.props.items)) {
            rawSeasons = sel.props.items;
            break;
        }
    }
    console.log(`Found ${rawSeasons.length} seasons.`);

    const catalog = [];
    for (const s of rawSeasons) {
        const seasonNum = s.seasonNumber;
        const seasonTitle = s.label || `Season ${seasonNum}`;
        let url = s.url ? (s.url.startsWith('http') ? s.url : `https://www.southparkstudios.com${s.url}`) : null;
        if (!url && seasonNum === 1) url = 'https://www.southparkstudios.com/seasons/south-park/yjy8n9/season-1';
        if (!url && seasonNum === 2) url = 'https://www.southparkstudios.com/seasons/south-park/cfnwds/season-2';
        if (!url || !seasonNum) continue;

        console.log(`Fetching ${seasonTitle} (${url})...`);
        try {
            const sPage = await fetchUrl(url);
            const sData = extractData(sPage.body);
            if (!sData) {
                console.warn(`Could not parse data for ${seasonTitle}`);
                continue;
            }
            const lineLists = [];
            findComponents(sData, 'LineList', lineLists);
            let epCount = 0;
            for (const list of lineLists) {
                if (list.props && Array.isArray(list.props.items)) {
                    for (const it of list.props.items) {
                        if (it.entityType !== 'episode' && it.itemType !== 'episode') continue;
                        const meta = it.meta || {};
                        const header = meta.header || {};
                        const headerTitle = header.title || {};
                        const media = it.media || {};
                        const img = media.image || {};
                        const ep = {
                            uuid: it.id || '',
                            title: meta.subHeader || it.title || '',
                            summary: meta.description || it.description || '',
                            seasonNumber: seasonNum,
                            episodeNumber: it.episodeNumber || 0,
                            seasonEpisodeString: headerTitle.text || `S${seasonNum} • E${it.episodeNumber || 0}`,
                            airDate: meta.date || '',
                            durationSeconds: 0,
                            durationString: media.duration || '',
                            urlPath: it.url || '',
                            thumbnailURL: img.url || ''
                        };
                        catalog.push(ep);
                        epCount++;
                    }
                }
            }
            console.log(`  -> ${epCount} episodes found.`);
        } catch (e) {
            console.error(`Error fetching ${seasonTitle}:`, e.message);
        }
    }

    console.log(`\nTotal catalog size: ${catalog.length} episodes.`);
    const outPath = path.join(__dirname, '..', 'Resources', 'catalog.json');
    fs.writeFileSync(outPath, JSON.stringify(catalog, null, 2), 'utf8');
    console.log(`Wrote catalog to ${outPath} (${fs.statSync(outPath).size} bytes).`);
}

main().catch(console.error);
