const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const PORT = parseInt(process.env.GESTALT_PORT || '3000', 10);
const FLAKE_DIR = process.env.GESTALT_FLAKE_DIR;
const APP_ATTR = process.env.GESTALT_APP_ATTR;
const WATCH_DIRS = (process.env.GESTALT_WATCH_DIRS || '').split(':').filter(Boolean);
const HTML_TEMPLATE_PATH = process.env.GESTALT_HTML_TEMPLATE || path.join(__dirname, 'index.html');
const HTML_TEMPLATE = fs.readFileSync(HTML_TEMPLATE_PATH, 'utf-8');

function buildAppJS() {
    return new Promise((resolve, reject) => {
        exec(
            `ulimit -s unlimited && nix build "${FLAKE_DIR}#${APP_ATTR}.extraTargets.web.passthru.appJS" --no-link --print-out-paths --option max-call-depth 100000000`,
            { encoding: 'utf-8', timeout: 120000 },
            (err, stdout, stderr) => {
                if (err) return reject(err);
                try {
                    const outPath = stdout.trim();
                    resolve(fs.readFileSync(outPath, 'utf-8'));
                } catch (e) {
                    reject(e);
                }
            }
        );
    });
}

let cachedAppJS = null;
let buildInProgress = null;

function getAppJS() {
    if (cachedAppJS) return Promise.resolve(cachedAppJS);
    if (buildInProgress) return buildInProgress;
    buildInProgress = buildAppJS().then(js => {
        cachedAppJS = js;
        buildInProgress = null;
        return js;
    }).catch(err => {
        buildInProgress = null;
        throw err;
    });
    return buildInProgress;
}

// SSE clients for live reload
const sseClients = new Set();

const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const pathname = url.pathname;

    if (pathname === '/__events') {
        res.writeHead(200, {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
        });
        res.write('data: connected\n\n');
        sseClients.add(res);
        req.on('close', () => sseClients.delete(res));
        return;
    }

    if (pathname === '/' || pathname === '/index.html') {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(HTML_TEMPLATE);
    } else if (pathname === '/app.js') {
        getAppJS().then(js => {
            res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
            res.end(js);
        }).catch(e => {
            res.writeHead(500, { 'Content-Type': 'application/javascript; charset=utf-8' });
            res.end('// Build error:\n// ' + e.message.replace(/\n/g, '\n// '));
        });
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

function notifyClients(event, data) {
    const msg = data ? JSON.stringify({ event, data }) : event;
    for (const client of sseClients) {
        try { client.write(`data: ${msg}\n\n`); } catch { }
    }
}

// File watcher
if (WATCH_DIRS.length > 0) {
    const debounceMs = 500;
    let timer = null;

    function onFileChange(filename) {
        if (timer) clearTimeout(timer);
        timer = setTimeout(() => {
            console.log(`[gestalt-dev] Change detected${filename ? ': ' + filename : ''}, rebuilding...`);
            cachedAppJS = null;
            notifyClients('building');
            getAppJS().then(() => {
                console.log('[gestalt-dev] Build succeeded, reloading clients.');
                notifyClients('reload');
            }).catch(e => {
                console.error('[gestalt-dev] Build failed:', e.message);
                notifyClients('error', e.message + (e.stderr || ''));
            });
        }, debounceMs);
    }

    for (const dir of WATCH_DIRS) {
        if (!fs.existsSync(dir)) continue;
        fs.watch(dir, { recursive: true }, (_event, filename) => {
            onFileChange(filename);
        });
        console.log(`[gestalt-dev] Watching: ${dir}`);
    }
}

server.listen(PORT, () => {
    console.log(`[gestalt-dev] Dev server running at http://localhost:${PORT}`);
});
