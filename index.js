/**
 * Zephyrflick Ultimate Downloader (Termux Edition)
 * Features:
 * - Sandboxed .temp directory
 * - Double Selection (Quality + Language)
 * - Auto-Merge & Cleanup
 * - Progress Bar
 */

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
const { exec, spawn } = require('child_process');
const readline = require('readline');

// --- CONFIGURATION ---
const EXECUTABLE_PATH = '/data/data/com.termux/files/usr/bin/chromium-browser';
const USER_AGENT = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

// --- DIRECTORIES ---
const ROOT_DIR = __dirname;
const TEMP_DIR = path.join(ROOT_DIR, '.temp');

// --- UTILS ---
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = (q) => new Promise((resolve) => rl.question(q, resolve));

// Ensure temp dir exists and is clean
if (fs.existsSync(TEMP_DIR)) fs.rmSync(TEMP_DIR, { recursive: true, force: true });
fs.mkdirSync(TEMP_DIR);

function cookiesToNetscape(cookies) {
    let out = "# Netscape HTTP Cookie File\n";
    cookies.forEach(c => {
        const domain = c.domain.startsWith('.') ? c.domain : '.' + c.domain;
        out += `${domain}\tTRUE\t${c.path}\t${c.secure ? 'TRUE' : 'FALSE'}\t${c.expires === -1 ? 0 : Math.round(c.expires)}\t${c.name}\t${c.value}\n`;
    });
    return out;
}

function parseAttributes(line) {
    const attrs = {};
    const regex = /([A-Z0-9-]+)=(".*?"|[^,]+)/g;
    let match;
    while ((match = regex.exec(line)) !== null) {
        let val = match[2];
        if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
        attrs[match[1]] = val;
    }
    return attrs;
}

function formatBytes(bytes, decimals = 2) {
    if (!+bytes) return '0 B';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
}

async function main() {
    try {
        console.clear();
        console.log("=== Zephyrflick Ultimate Downloader ===");
        console.log("Note: Select Quality AND Language interactively.\n");

        const targetUrl = await ask("Enter Episode URL: ");
        let fileName = await ask("Output Filename (e.g. Episode1): ");
        if (!fileName.endsWith('.mp4')) fileName += '.mp4';

        console.log("\n[1/7] Launching Browser...");

        const browser = await puppeteer.launch({
            executablePath: EXECUTABLE_PATH,
            headless: true,
            args: ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage", "--disable-setuid-sandbox", "--mute-audio"]
        });

        const page = await browser.newPage();
        await page.setUserAgent(USER_AGENT);

        console.log("[2/7] Sniffing Network...");
        let masterUrl = null;

        await page.setRequestInterception(true);
        page.on('request', (req) => req.continue());

        const sniffPromise = new Promise((resolve) => {
            page.on('response', (response) => {
                const url = response.url();
                if ((url.includes('.m3u8') || url.includes('master.txt')) && !url.includes('cdn-cgi')) {
                    console.log(`      Found: ${url}`);
                    masterUrl = url;
                    resolve(url);
                }
            });
        });

        await page.goto(targetUrl, { timeout: 0, waitUntil: 'domcontentloaded' });

        const frameSrc = await page.evaluate(() => {
            const iframe = document.querySelector('iframe');
            return iframe ? iframe.src : null;
        });
        if (frameSrc && frameSrc.includes('zephyrflick')) {
            await page.goto(frameSrc, { timeout: 0, waitUntil: 'domcontentloaded' });
        }

        await new Promise(r => setTimeout(r, 2000));
        try {
            await page.waitForSelector('.jw-display-icon-container', { timeout: 3000 });
            await page.click('.jw-display-icon-container');
        } catch (e) {
            try { await page.click('video'); } catch(err) {}
        }

        const timeoutPromise = new Promise(r => setTimeout(r, 20000));
        await Promise.race([sniffPromise, timeoutPromise]);

        if (!masterUrl) {
            await browser.close();
            throw new Error("Timeout: Master URL not found.");
        }

        console.log(`      Saving Cookies...`);
        const cookies = await page.cookies();
        const cookiePath = path.join(TEMP_DIR, 'cookies.txt');
        fs.writeFileSync(cookiePath, cookiesToNetscape(cookies));
        
        await browser.close();

        // --- STEP 3: CURL ---
        console.log(`\n[3/7] Fetching Playlist...`);
        const originalPath = path.join(TEMP_DIR, 'original.m3u8');
        
        await new Promise((resolve, reject) => {
            exec(`curl -s -L -b "${cookiePath}" -H "User-Agent: ${USER_AGENT}" -H "Referer: ${frameSrc || targetUrl}" "${masterUrl}" -o "${originalPath}"`, (err) => {
                if (err) reject(err);
                else resolve();
            });
        });

        // --- STEP 4: PARSE ---
        console.log(`\n[4/7] Parsing Streams...`);
        const content = fs.readFileSync(originalPath, 'utf8');
        const lines = content.split('\n');
        
        const audioTracks = []; 
        const videoStreams = []; 
        let lastStreamInfo = null;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            if (line.startsWith('#EXT-X-MEDIA:TYPE=AUDIO')) {
                audioTracks.push({ line: line, attrs: parseAttributes(line) });
            } 
            else if (line.startsWith('#EXT-X-STREAM-INF')) {
                lastStreamInfo = { line: line, attrs: parseAttributes(line) };
            }
            else if (!line.startsWith('#') && lastStreamInfo) {
                videoStreams.push({ ...lastStreamInfo, url: line });
                lastStreamInfo = null;
            }
        }

        // --- SELECTION UI 1: VIDEO ---
        console.log("\n------------------------------------------------");
        console.log(" PART 1: SELECT VIDEO QUALITY");
        console.log("------------------------------------------------");
        
        videoStreams.forEach((v, idx) => {
            const res = v.attrs.RESOLUTION || 'Unknown';
            const bw = v.attrs.BANDWIDTH ? formatBytes(v.attrs.BANDWIDTH / 8) + '/s' : '?';
            console.log(` [${idx + 1}] Quality: ${res.padEnd(10)} | Speed: ${bw.padEnd(10)}`);
        });

        const vChoice = await ask("👉 Select Video (1-" + videoStreams.length + "): ");
        const vIndex = parseInt(vChoice) - 1;
        if (isNaN(vIndex) || vIndex < 0 || vIndex >= videoStreams.length) throw new Error("Invalid Video Selection");
        const selectedVideo = videoStreams[vIndex];

        // --- SELECTION UI 2: AUDIO ---
        let selectedAudioLine = null;
        const groupID = selectedVideo.attrs.AUDIO;

        if (groupID) {
            // Find compatible audio
            const compatibleAudio = audioTracks.filter(a => a.attrs['GROUP-ID'] === groupID);
            
            if (compatibleAudio.length > 0) {
                console.log("\n------------------------------------------------");
                console.log(" PART 2: SELECT AUDIO LANGUAGE");
                console.log("------------------------------------------------");
                
                compatibleAudio.forEach((a, idx) => {
                    const lang = a.attrs.NAME || 'Unknown';
                    const isDefault = a.attrs.DEFAULT === 'YES' ? '(Default)' : '';
                    console.log(` [${idx + 1}] Language: ${lang.padEnd(15)} ${isDefault}`);
                });

                const aChoice = await ask("👉 Select Audio (1-" + compatibleAudio.length + "): ");
                const aIndex = parseInt(aChoice) - 1;
                if (isNaN(aIndex) || aIndex < 0 || aIndex >= compatibleAudio.length) throw new Error("Invalid Audio Selection");
                
                selectedAudioLine = compatibleAudio[aIndex].line;
                console.log(`✅ Audio Selected: ${compatibleAudio[aIndex].attrs.NAME}`);
            } else {
                console.log("\n⚠️ No separate audio tracks found. Using embedded audio.");
            }
        }

        // --- STEP 5: BUILD SPECIFIC MANIFEST ---
        console.log(`\n[5/7] Building Custom Playlist...`);
        const urlObj = new URL(masterUrl);
        const baseDomain = `${urlObj.protocol}//${urlObj.host}`;

        let newManifest = "#EXTM3U\n#EXT-X-VERSION:3\n";

        // Add ONLY the selected audio line
        if (selectedAudioLine) {
            let l = selectedAudioLine;
            // Fix URI
            if (l.includes('URI="/')) l = l.replace('URI="/', `URI="${baseDomain}/`);
            newManifest += l + "\n";
        }

        // Add ONLY the selected video line
        newManifest += selectedVideo.line + "\n";
        let vidUrl = selectedVideo.url;
        if (vidUrl.startsWith('/')) vidUrl = baseDomain + vidUrl;
        newManifest += vidUrl + "\n";

        const fixedPath = path.join(TEMP_DIR, 'fixed.m3u8');
        fs.writeFileSync(fixedPath, newManifest);

        // --- STEP 6: DOWNLOAD ---
        console.log(`\n[6/7] Downloading...`);
        
        const tempOutput = path.join(TEMP_DIR, 'temp_video.mp4');
        const args = [
            '--no-check-certificate',
            '--enable-file-urls',
            '--cookies', cookiePath,
            '--user-agent', USER_AGENT,
            '--merge-output-format', 'mp4',
            '-o', tempOutput,
            `file://${fixedPath}`
        ];

        const child = spawn('yt-dlp', args);
        let currentStatus = "Initializing...";

        child.stdout.on('data', (data) => {
            const str = data.toString();
            
            // Status Logic
            if (str.includes('[Merger]')) currentStatus = "Merging Audio/Video...";
            else if (str.includes('[ExtractAudio]')) currentStatus = "Extracting Audio...";
            else if (str.includes('[download] Destination')) currentStatus = "Downloading...";
            
            // Progress Bar
            const match = str.match(/(\d+\.\d+)%\s+of\s+(~?\s?\d+\.\d+\w+)\s+at\s+(\d+\.\d+\w+\/s)\s+ETA\s+(\d+:?\d+)/);
            if (match) {
                const percent = parseFloat(match[1]);
                const width = 15;
                const completed = Math.floor(width * (percent / 100));
                const bar = '▓'.repeat(completed) + '░'.repeat(width - completed);
                
                readline.clearLine(process.stdout, 0);
                readline.cursorTo(process.stdout, 0);
                process.stdout.write(` [${bar}] ${percent.toFixed(0)}% | ${match[3]} | ${match[4]} | ${currentStatus}`);
            }
        });

        await new Promise((resolve, reject) => {
            child.on('close', (code) => {
                if (code === 0) resolve();
                else reject(new Error(`yt-dlp exited with code ${code}`));
            });
        });

        // --- STEP 7: CLEANUP ---
        console.log(`\n\n[7/7] Finalizing...`);
        const finalDest = path.join(ROOT_DIR, fileName);
        
        if (fs.existsSync(tempOutput)) {
            fs.renameSync(tempOutput, finalDest);
            console.log(`✅ Success! Video saved to main folder.`);
        } else {
            throw new Error("Video file missing after download.");
        }

        fs.rmSync(TEMP_DIR, { recursive: true, force: true });
        console.log(`   Temp files cleaned.`);
        rl.close();

    } catch (e) {
        console.error("\n❌ ERROR:", e.message);
        try { fs.rmSync(TEMP_DIR, { recursive: true, force: true }); } catch(err) {}
        rl.close();
    }
}

main();
