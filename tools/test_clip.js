const https = require('https');

function fetchUrl(url) {
    return new Promise((resolve, reject) => {
        const u = new URL(url);
        https.get({
            hostname: u.hostname,
            path: u.pathname + u.search,
            headers: { 'User-Agent': 'Mozilla/5.0' }
        }, res => {
            let data = [];
            res.on('data', c => data.push(c));
            res.on('end', () => resolve(Buffer.concat(data).toString('utf8')));
        }).on('error', reject);
    });
}

function extractDataJson(html) {
    const idx = html.indexOf('window.__DATA__');
    if (idx === -1) return null;
    const start = html.indexOf('{', idx);
    let depth = 0, inString = false, escape = false;
    for (let i = start; i < html.length; i++) {
        const ch = html[i];
        if (escape) { escape = false; continue; }
        if (ch === '\\') { escape = true; continue; }
        if (ch === '"') { inString = !inString; continue; }
        if (!inString) {
            if (ch === '{') depth++;
            else if (ch === '}') {
                depth--;
                if (depth === 0) return JSON.parse(html.substring(start, i + 1));
            }
        }
    }
    return null;
}

fetchUrl('https://www.southparkstudios.com/').then(html => {
    const data = extractDataJson(html);
    function findItems(node) {
        if (!node) return;
        if (node.props && Array.isArray(node.props.items)) {
            for (const item of node.props.items) {
                if (item.entityType === 'showvideo' || item.itemType === 'showvideo') {
                    console.log('CLIP ITEM KEYS:', Object.keys(item));
                    console.log('CLIP META:', item.meta);
                    console.log('CLIP MEDIA:', item.media);
                    process.exit(0);
                }
            }
        }
        if (Array.isArray(node)) node.forEach(findItems);
        else if (typeof node === 'object') Object.values(node).forEach(findItems);
    }
    findItems(data);
    console.log('None found');
}).catch(console.error);
