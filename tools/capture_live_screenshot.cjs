const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright-core");

const URL = "https://frontier-mountain-godot.onrender.com/";
const OUTPUT = path.resolve("docs/screenshots");

async function hold(page, key, ms) {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(100);
}

(async () => {
  fs.mkdirSync(OUTPUT, { recursive: true });
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_BIN || "/usr/bin/google-chrome",
    args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
  });
  const page = await browser.newPage({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
    reducedMotion: "reduce"
  });
  page.on("pageerror", e => console.error("PAGE ERROR:", e.message));
  page.on("console", m => {
    if (m.type() === "error") console.error("BROWSER:", m.text().slice(0, 300));
  });
  try {
    await page.goto(URL, { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.locator("canvas").waitFor({ state: "visible", timeout: 120000 });
    await page.waitForTimeout(12000);
    await page.screenshot({ path: path.join(OUTPUT, "01-forest.png") });
    console.log("Captured live Godot forestry screenshot 01");

    // Walk near the approved birch to exercise actions via the real Web build.
    await page.locator("canvas").click({ position: { x: 640, y: 420 } });
    await hold(page, "a", 1220);
    await hold(page, "s", 470);
    await hold(page, "Space", 130);
    await hold(page, "Space", 130);
    await page.waitForTimeout(270);
    await page.screenshot({ path: path.join(OUTPUT, "02-tree-fall.png") });
    console.log("Captured tree-fall gameplay screenshot 02");

    await page.waitForTimeout(1050);
    await hold(page, "Space", 120);
    await page.waitForTimeout(180);
    await page.screenshot({ path: path.join(OUTPUT, "03-bucked-logs.png") });
    console.log("Captured bucked-logs gameplay screenshot 03");
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
