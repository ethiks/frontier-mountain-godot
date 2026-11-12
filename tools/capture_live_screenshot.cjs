// Frontier Mountain phases 2-4: true Godot WebGL captures of unified mobile HUD, market, gear, saves and game loop.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { chromium } = require("playwright-core");
const URL = "https://frontier-mountain-godot.onrender.com/";
const OUTPUT = path.resolve("docs/screenshots");

async function hold(page, key, ms) {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(120);
}
async function screenshot(page, name) {
  const dest = path.join(OUTPUT, name);
  await page.screenshot({ path: dest });
  const hash = crypto.createHash("sha256").update(fs.readFileSync(dest)).digest("hex").slice(0, 12);
  console.log("CAPTURE:", name, hash);
  return hash;
}
async function start(page) {
  await page.goto(URL, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.locator("canvas").waitFor({ state: "visible", timeout: 120000 });
  await page.waitForTimeout(11500);
  await page.locator("canvas").click({ position: { x: 650, y: 360 } });
}

(async () => {
  fs.mkdirSync(OUTPUT, { recursive: true });
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_BIN || "/usr/bin/google-chrome",
    args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
  });
  const errors = [];
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  page.on("pageerror", e => errors.push(e.message));
  page.on("console", m => { if (m.type() === "error") console.error("BROWSER:", m.text().slice(0, 250)); });
  try {
    await start(page);
    await screenshot(page, "01-forest.png");
    // Desktop market/shop/camp panels are inspected without altering world state.
    await page.locator("canvas").click({ position: { x: 1096, y: 577 } });
    await page.waitForTimeout(240);
    await screenshot(page, "14-trader-market.png");
    await page.keyboard.press("Escape");
    await page.locator("canvas").click({ position: { x: 1209, y: 577 } });
    await page.waitForTimeout(240);
    await screenshot(page, "15-equipment-upgrades.png");
    await page.keyboard.press("Escape");
    await page.locator("canvas").click({ position: { x: 983, y: 577 } });
    await page.waitForTimeout(240);
    await screenshot(page, "16-camp-and-saves.png");
    await page.keyboard.press("Escape");
    await screenshot(page, "12-approved-terrain-homestead.png");
    await hold(page, "a", 960);
    await hold(page, "s", 480); // approach approved birch at the clearing edge
    await screenshot(page, "02-approach-tree.png");
    // Spruce needs three axe swings in the approved parity rules.
    await hold(page, "Space", 110);
    await hold(page, "Space", 110);
    await hold(page, "Space", 110);
    await page.waitForTimeout(320);
    await screenshot(page, "03-tree-fall.png");
    await page.waitForTimeout(980);
    await hold(page, "Space", 110);
    await page.waitForTimeout(250);
    await screenshot(page, "04-bucked-logs.png");
    await hold(page, "Space", 110);
    await screenshot(page, "05-carrying.png");
    await hold(page, "d", 1900);
    await hold(page, "Space", 110);
    await screenshot(page, "06-loading-yard.png");
    await hold(page, "d", 3200);
    await screenshot(page, "09-east-woods.png");
    await screenshot(page, "13-approved-terrain-east-forest.png");
    await hold(page, "w", 3100);
    await screenshot(page, "10-north-woods.png");
    await page.locator("canvas").click({ position: { x: 1093, y: 44 } });
    await screenshot(page, "07-audio-mixer.png");
    await page.locator("canvas").click({ position: { x: 1204, y: 44 } });
    await page.waitForTimeout(450);
    console.log("FULLSCREEN_FROM_USER_CLICK:", await page.evaluate(() => Boolean(document.fullscreenElement)));
    await screenshot(page, "08-fullscreen.png");
    if (errors.length) {
      console.error("PAGE ERRORS:", errors);
      process.exitCode = 1;
    }
    const mobile = await browser.newPage({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
    await mobile.goto(URL, { waitUntil: "domcontentloaded", timeout: 120000 });
    await mobile.locator("canvas").waitFor({ state: "visible", timeout: 120000 });
    await mobile.waitForTimeout(10500);
    await screenshot(mobile, "11-landscape-mobile.png");
    await mobile.locator("canvas").click({ position: { x: 678, y: 257 } });
    await mobile.waitForTimeout(260);
    await screenshot(mobile, "17-market-landscape-mobile.png");
    await mobile.close();
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
