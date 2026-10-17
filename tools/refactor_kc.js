const fs = require('fs');
const path = require('path');

function replaceInDir(dir) {
    const files = fs.readdirSync(dir);
    for (const f of files) {
        const full = path.join(dir, f);
        const stat = fs.statSync(full);
        if (stat.isDirectory()) {
            replaceInDir(full);
        } else if (f.endsWith('.h') || f.endsWith('.m')) {
            let content = fs.readFileSync(full, 'utf8');
            content = content.replace(/com\.samcejko\.kicker/g, 'com.samcejko.cityvod');
            content = content.replace(/\[Kicker\]/g, '[CityVOD]');
            content = content.replace(/"Kicker"/g, '"City VOD"');
            content = content.replace(/KCCommon\.h/g, 'CVCommon.h');
            content = content.replace(/KCAppDelegate/g, 'CVAppDelegate');
            content = content.replace(/KCConnectionPool/g, 'CVConnectionPool');
            content = content.replace(/KCHTTPRequest/g, 'CVHTTPRequest');
            content = content.replace(/KCHTTP/g, 'CVHTTP');
            content = content.replace(/KCImageLoader/g, 'CVImageLoader');
            content = content.replace(/KCMediaProxy/g, 'CVMediaProxy');
            content = content.replace(/KCTLSSocket/g, 'CVTLSSocket');
            content = content.replace(/KCWebSocket/g, 'CVWebSocket');
            content = content.replace(/KCLinks/g, 'CVLinks');
            content = content.replace(/KCModern/g, 'CVModern');
            content = content.replace(/KCSettings/g, 'CVSettings');
            content = content.replace(/KCUtils/g, 'CVUtils');
            content = content.replace(/KCTheme/g, 'CVTheme');
            content = content.replace(/KCNavigator/g, 'CVNavigator');
            content = content.replace(/KCRootViewController/g, 'CVRootViewController');
            content = content.replace(/KCGridViewController/g, 'CVGridViewController');
            content = content.replace(/KCPlayerViewController/g, 'CVPlayerViewController');
            content = content.replace(/KCPlayerView/g, 'CVPlayerView');
            content = content.replace(/KCChoiceViewController/g, 'CVChoiceViewController');
            content = content.replace(/KCExternalOpen/g, 'CVExternalOpen');
            content = content.replace(/KCFavorites/g, 'CVFavorites');
            content = content.replace(/KCModels/g, 'CVModels');
            content = content.replace(/KCPlayback/g, 'CVPlayback');
            content = content.replace(/KCAPI/g, 'CVAPI');
            content = content.replace(/\bKC([A-Za-z0-9_]+)/g, 'CV$1');
            fs.writeFileSync(full, content, 'utf8');
            console.log('Processed', f);
        }
    }
}

replaceInDir('southpark-ios6/src');
console.log('All files refactored successfully.');
