// verify.js - Static verification of City VOD codebase
const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const srcDir = path.join(rootDir, 'src');

console.log('--- Verifying City VOD Project Integrity ---');

let errors = 0;
let warnings = 0;

// 1. Check critical files
const requiredFiles = [
    'Makefile',
    'control',
    'entitlements.xml',
    'entitlements-arm64.xml',
    'README.md',
    'CHANGELOG.md',
    'LICENSE',
    'PLAN.md',
    'Resources/Info.plist',
    'Resources/Icon.png',
    'Resources/Icon-72@2x.png',
    'Resources/en.lproj/Localizable.strings',
    'Resources/cs.lproj/Localizable.strings',
    '.github/workflows/build.yml',
    'vendor/mbedtls_config_ios6.h',
    'vendor/mbedtls_glue.c'
];

requiredFiles.forEach(f => {
    const full = path.join(rootDir, f);
    if (!fs.existsSync(full)) {
        console.error(`[ERROR] Missing required file: ${f}`);
        errors++;
    } else {
        console.log(`[OK] Found ${f}`);
    }
});

// 2. Collect all .h and .m files
function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(filePath));
        } else if (file.endsWith('.h') || file.endsWith('.m') || file.endsWith('.c')) {
            results.push(filePath);
        }
    });
    return results;
}

const allSources = walk(srcDir);
console.log(`\nFound ${allSources.length} source files in src/`);

// Collect header names
const headers = new Set();
allSources.forEach(s => {
    if (s.endsWith('.h')) {
        headers.add(path.basename(s));
    }
});
headers.add('mbedtls_config_ios6.h');

// 3. Check imports
const systemHeaders = new Set([
    'UIKit/UIKit.h', 'Foundation/Foundation.h', 'CoreGraphics/CoreGraphics.h',
    'QuartzCore/QuartzCore.h', 'CoreText/CoreText.h', 'Security/Security.h',
    'ImageIO/ImageIO.h', 'AVFoundation/AVFoundation.h', 'CoreMedia/CoreMedia.h',
    'MediaPlayer/MediaPlayer.h', 'AudioToolbox/AudioToolbox.h',
    'dlfcn.h', 'signal.h', 'mach/mach.h', 'sys/socket.h', 'netinet/in.h',
    'arpa/inet.h', 'unistd.h', 'fcntl.h', 'errno.h', 'netdb.h', 'string.h',
    'stdlib.h', 'stdio.h', 'stdbool.h', 'stdint.h', 'pthread.h',
    'webp/decode.h', 'mbedtls/ssl.h', 'mbedtls/entropy.h', 'mbedtls/ctr_drbg.h',
    'mbedtls/x509_crt.h', 'mbedtls/net_sockets.h', 'mbedtls/error.h',
    'mbedtls/version.h', 'zlib.h', 'time.h', 'poll.h', 'psa/crypto.h',
    'sys/types.h', 'netinet/tcp.h', 'strings.h', 'objc/runtime.h',
    'CommonCrypto/CommonDigest.h', 'sys/sysctl.h', 'math.h'
]);

allSources.forEach(file => {
    const content = fs.readFileSync(file, 'utf8');
    const importRegex = /#(?:import|include)\s+["<]([^">]+)[">]/g;
    let match;
    while ((match = importRegex.exec(content)) !== null) {
        const imp = match[1];
        const base = path.basename(imp);
        if (systemHeaders.has(imp) || imp.startsWith('mbedtls/') || imp.startsWith('webp/')) {
            continue;
        }
        if (!headers.has(base)) {
            console.error(`[ERROR] Unresolved import "${imp}" in ${path.relative(rootDir, file)}`);
            errors++;
        }
    }
});

// 4. Verify Localizable.strings formatting
['en', 'cs'].forEach(lang => {
    const p = path.join(rootDir, `Resources/${lang}.lproj/Localizable.strings`);
    const txt = fs.readFileSync(p, 'utf8');
    const lines = txt.split('\n');
    let lineNum = 0;
    lines.forEach(line => {
        lineNum++;
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('/*') || trimmed.startsWith('//') || trimmed.startsWith('*')) return;
        if (!trimmed.endsWith(';')) {
            console.error(`[ERROR] Syntax error in ${lang}.lproj line ${lineNum}: Missing semicolon: ${trimmed}`);
            errors++;
        }
    });
});

console.log('\n--- Verification Summary ---');
if (errors === 0) {
    console.log('ALL CHECKS PASSED! Project is cleanly structured and self-consistent.');
} else {
    console.error(`FAILED with ${errors} error(s).`);
    process.exit(1);
}
