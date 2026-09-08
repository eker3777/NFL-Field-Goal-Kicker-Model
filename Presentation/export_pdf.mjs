#!/usr/bin/env node
// Export heres_the_kicker_slides.html to a paginated PDF.
//
// Usage:
//   node Presentation/export_pdf.mjs [input.html] [output.pdf]
// Defaults to Presentation/heres_the_kicker_slides.html -> Presentation/heres_the_kicker_slides.pdf
//
// Requires:
//   - A local Chrome/Chromium binary. Set CHROME_PATH to point at one if it
//     isn't auto-detected (see CHROME_CANDIDATES below).
//   - Python 3 with PyMuPDF (`pip install pymupdf`), used only for the final
//     screenshot-to-PDF assembly step (see assemble_pdf.py next to this
//     file, and the comment on assemblePdf() below for why that step isn't
//     done with Chrome itself).
//
// Why this exists instead of reveal.js's own PDF export (?print-pdf +
// Ctrl/Cmd+P, or a decktape-style headless "Page.printToPDF" call driven by
// reveal's print plugin): reveal's print pipeline wraps every slide in a
// .pdf-page div and lays it out with position:absolute against a page-sized
// canvas. That mechanism is what previously produced inconsistent, cut-off
// pages -- fixed in custom.scss (see the "Print / PDF export" section
// there) -- but headless Chrome's Page.printToPDF still silently drops
// paint for a subset of slides in that layout (confirmed present even in
// the stock, unpatched reveal.js print output; not something introduced by
// this deck's CSS). The bug is specific to PDF *page content serialization*
// for certain absolutely-positioned, flex-filled image layouts -- a live
// screenshot of the exact same DOM state renders correctly.
//
// This script sidesteps that bug entirely: it drives the deck through its
// normal, already-verified-correct LIVE rendering path (Reveal.slide(i),
// the same code path a person clicking through the deck in a browser uses),
// screenshots each slide at the deck's native 1600x900 canvas, and stitches
// the screenshots into a PDF with one full-bleed page per slide. The
// tradeoff is a raster (not vector/selectable-text) PDF; for a slide deck
// export that's an acceptable trade for a pipeline that reliably matches
// what's on screen.

import { spawn, spawnSync } from "node:child_process";
import http from "node:http";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SLIDE_WIDTH = 1600;
const SLIDE_HEIGHT = 900;
const SCALE = 2; // 2x device scale factor for a crisp raster export.
const PORT = 9922;

const CHROME_CANDIDATES = [
  process.env.CHROME_PATH,
  "/opt/pw-browsers/chromium-1194/chrome-linux/chrome", // Playwright-provisioned Chromium, if present
  "/usr/bin/google-chrome",
  "/usr/bin/google-chrome-stable",
  "/usr/bin/chromium",
  "/usr/bin/chromium-browser",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
].filter(Boolean);

function findChrome() {
  for (const candidate of CHROME_CANDIDATES) {
    if (fs.existsSync(candidate)) return candidate;
  }
  throw new Error(
    "No Chrome/Chromium binary found. Set CHROME_PATH to a Chrome/Chromium " +
      "executable, e.g. CHROME_PATH=/path/to/chrome node export_pdf.mjs"
  );
}

function httpJson(path_, method = "GET") {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: "127.0.0.1", port: PORT, path: path_, method }, (res) => {
      let data = "";
      res.on("data", (d) => (data += d));
      res.on("end", () => {
        try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
      });
    });
    req.on("error", reject);
    req.end();
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const scriptDir = path.dirname(new URL(import.meta.url).pathname);
  const inputPath = path.resolve(process.argv[2] || path.join(scriptDir, "heres_the_kicker_slides.html"));
  const outputPath = path.resolve(process.argv[3] || path.join(scriptDir, "heres_the_kicker_slides.pdf"));
  const fileUrl = "file://" + inputPath;

  if (!fs.existsSync(inputPath)) {
    console.error("Input HTML not found:", inputPath);
    process.exit(1);
  }

  const chromePath = findChrome();
  console.error("Using Chrome at:", chromePath);

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "kicker-slides-"));
  const chrome = spawn(chromePath, [
    "--headless=new",
    "--disable-gpu",
    "--no-sandbox",
    `--remote-debugging-port=${PORT}`,
    `--window-size=${SLIDE_WIDTH},${SLIDE_HEIGHT}`,
    "--hide-scrollbars",
  ], { stdio: "ignore" });

  try {
    for (let i = 0; i < 50; i++) {
      try { await httpJson("/json/version"); break; } catch { await sleep(200); }
    }

    const target = await httpJson(`/json/new?${encodeURIComponent(fileUrl)}`, "PUT");
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    let id = 0;
    const pending = new Map();
    const events = [];
    ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
      else if (msg.method) events.push(msg);
    });
    await new Promise((resolve) => ws.addEventListener("open", resolve));
    function send(method, params = {}) {
      return new Promise((resolve) => {
        const thisId = ++id;
        pending.set(thisId, resolve);
        ws.send(JSON.stringify({ id: thisId, method, params }));
      });
    }

    await send("Page.enable");
    await send("Runtime.enable");
    await send("Emulation.setDeviceMetricsOverride", {
      width: SLIDE_WIDTH, height: SLIDE_HEIGHT, deviceScaleFactor: SCALE, mobile: false,
    });

    const navPromise = new Promise((resolve) => {
      const check = () => {
        if (events.some((e) => e.method === "Page.loadEventFired")) resolve();
        else setTimeout(check, 100);
      };
      check();
    });
    await send("Page.navigate", { url: fileUrl });
    await navPromise;
    await sleep(2000);

    const totalRes = await send("Runtime.evaluate", {
      // getTotalSlides() excludes data-visibility="uncounted" appendix
      // slides; count real DOM sections instead so appendix slides are
      // included in the export.
      expression: "document.querySelectorAll('.reveal .slides > section').length",
      returnByValue: true,
    });
    const total = totalRes.result.result.value;
    console.error("Slides to export:", total);

    // margin:0 fills the full 1600x900 viewport 1:1 (reveal's default
    // margin otherwise shrinks live content to make room for on-screen
    // breathing room, which we don't want in a full-bleed export). Hide
    // the on-screen controls/progress bar/menu button too.
    await send("Runtime.evaluate", {
      expression: `
        Reveal.configure({ margin: 0, controls: false, progress: false, menu: { openButton: false } });
        var css = document.createElement('style');
        css.textContent = '.slide-menu-button, .slide-menu-wrapper { display: none !important; }';
        document.head.appendChild(css);
      `,
    });
    await sleep(300);

    for (let i = 0; i < total; i++) {
      await send("Runtime.evaluate", { expression: `Reveal.slide(${i})` });
      await sleep(400);
      const shot = await send("Page.captureScreenshot", {
        format: "png",
        clip: { x: 0, y: 0, width: SLIDE_WIDTH, height: SLIDE_HEIGHT, scale: 1 },
        captureBeyondViewport: false,
      });
      if (!shot.result || !shot.result.data) {
        throw new Error(`Screenshot failed for slide ${i}: ${JSON.stringify(shot)}`);
      }
      const outPath = path.join(tmpDir, `slide-${String(i).padStart(3, "0")}.png`);
      fs.writeFileSync(outPath, Buffer.from(shot.result.data, "base64"));
      process.stderr.write(`\rCaptured ${i + 1}/${total}`);
    }
    process.stderr.write("\n");
    ws.close();

    console.error("Assembling PDF...");
    assemblePdf(tmpDir, outputPath);
    console.error("Wrote", outputPath);
  } finally {
    chrome.kill();
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

// Assembles the captured screenshots into a single PDF, one full-bleed page
// per slide. This is deliberately NOT done with Chrome's own
// Page.printToPDF: even a plain, non-reveal.js "one <img> per page" document
// triggers pathological slowness / hangs building a 34-page PDF from
// several 3200x1800 raster images in this pipeline (tested and abandoned --
// see git history on this file). PyMuPDF does the same job directly and
// fast, so Python does the assembly step.
function assemblePdf(tmpDir, outputPath) {
  const assembleScript = path.join(path.dirname(new URL(import.meta.url).pathname), "assemble_pdf.py");
  const result = spawnSync("python3", [
    assembleScript, tmpDir, outputPath, String(SLIDE_WIDTH), String(SLIDE_HEIGHT),
  ], { stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(
      "PDF assembly failed (python3 + PyMuPDF required -- `pip install pymupdf`)."
    );
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
