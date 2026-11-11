// Background removal verification: captures the actual deployed Godot canvas, not concept art.
const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright-core");
const URL = "https://frontier-mountain-godot.onrender.com/";
const OUTPUT = path.resolve("docs/screenshots");
async function hold(page, key, ms) {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(180);
}
async function capture(page, file) {
  await page.screenshot({ path: path.join(OUTPUT, file) });
  console.log("CAPTURE:", file);
}
(async () => {
  fs.mkdirSync(OUTPUT, { recursive: true });
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_BIN || "/usr/bin/google-chrome",
    args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  page.on("pageerror", e => console.error("PAGE ERROR:", e.message));
  page.on("console", m => { if (m.type() === "error") console.error("BROWSER:", m.text().slice(0, 320)); });
  try {
    await page.goto(URL, { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.locator("canvas").waitFor({ state: "visible", timeout: 120000 });
    await page.waitForTimeout(10500);
    await page.locator("canvas").click({ position: { x: 640, y: 420 } });
    await capture(page, "01-forest.png");
    await hold(page, "Space", 115);
    await capture(page, "02-tree-fall.png");
    await hold(page, "Space", 115);
    await hold(page, "Space", 115);
    await page.waitForTimeout(1050);
    await capture(page, "03-bucked-logs.png");
    await hold(page, "Space", 115); // buck the fallen tree
    await page.waitForTimeout(220);
    await capture(page, "04-scale-bucked.png");
    await hold(page, "s", 280); // approach the full-size logs
    await hold(page, "Space", 115); // pick up
    await page.waitForTimeout(220);
    await capture(page, "05-carrying.png");
    await hold(page, "d", 1900); // approach signed log landing
    await hold(page, "Space", 115); // unload
    await page.waitForTimeout(200);
    await capture(page, "06-loading-yard.png");
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
