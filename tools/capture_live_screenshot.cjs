// LIVE review of the user-approved unified Frontier Mountain HUD and four-tab market.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { chromium } = require("playwright-core");
const URL = "https://frontier-mountain-godot.onrender.com/?review=unified-hud-bbf47d44";
const OUTPUT = path.resolve("docs/screenshots");
async function capture(page, name) {
  const filename = path.join(OUTPUT,name);
  await page.screenshot({path:filename});
  const hash = crypto.createHash("sha256").update(fs.readFileSync(filename)).digest("hex").slice(0,12);
  console.log("CAPTURE",name,hash);
}
async function load(page) {
  await page.goto(URL,{waitUntil:"domcontentloaded",timeout:120000});
  await page.locator("canvas").waitFor({state:"visible",timeout:120000});
  await page.waitForTimeout(10700);
  await page.locator("canvas").click({position:{x:600,y:350}});
}
(async()=>{
  fs.mkdirSync(OUTPUT,{recursive:true});
  const browser = await chromium.launch({
    headless:true,
    executablePath:process.env.CHROME_BIN||"/usr/bin/google-chrome",
    args:["--no-sandbox","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]
  });
  const page = await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
  const errors = [];
  page.on("pageerror",err=>errors.push(err.message));
  page.on("console",msg=>{if(msg.type()==="error")console.error("BROWSER",msg.text().slice(0,300));});
  try {
    await load(page);
    // The initial message must have vanished after five seconds.
    await capture(page,"30-unified-world-hud.png");
    await page.keyboard.press("Space");
    await page.waitForTimeout(230);
    await capture(page,"31-world-hint-visible.png");
    await page.waitForTimeout(5350);
    await capture(page,"32-world-hint-faded.png");

    // Open Market from keyboard: removed world quick tabs are not required.
    await page.keyboard.press("m");
    await page.waitForTimeout(230);
    await capture(page,"33-unified-sell-timber.png");
    await page.keyboard.press("e");
    await page.waitForTimeout(180);
    await capture(page,"34-unified-contracts.png");
    await page.keyboard.press("e");
    await page.waitForTimeout(180);
    await capture(page,"35-unified-equipment-shop.png");
    await page.keyboard.press("ArrowDown");
    await page.waitForTimeout(120);
    await capture(page,"36-unified-selected-item.png");
    await page.keyboard.press("e");
    await page.waitForTimeout(180);
    await capture(page,"37-unified-supplies.png");
    await page.keyboard.press("Escape");
    await page.keyboard.press("p");
    await page.waitForTimeout(180);
    await capture(page,"38-unified-camp-ledger.png");
    await page.keyboard.press("Escape");
    await page.keyboard.press("i");
    await page.waitForTimeout(180);
    await capture(page,"39-unified-gear-ledger.png");
    await page.keyboard.press("Escape");

    // A true phone-landscape browser, not a resized mockup.
    const mobile = await browser.newPage({viewport:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
    mobile.on("pageerror",err=>errors.push("MOBILE "+err.message));
    await load(mobile);
    await capture(mobile,"40-unified-mobile-world.png");
    await mobile.keyboard.press("m");
    await mobile.waitForTimeout(200);
    await capture(mobile,"41-unified-mobile-sell.png");
    await mobile.keyboard.press("e");
    await mobile.waitForTimeout(160);
    await capture(mobile,"42-unified-mobile-contracts.png");
    await mobile.keyboard.press("e");
    await mobile.waitForTimeout(160);
    await capture(mobile,"43-unified-mobile-shop.png");
    await mobile.keyboard.press("e");
    await mobile.waitForTimeout(160);
    await capture(mobile,"44-unified-mobile-supplies.png");
    await mobile.close();
    if(errors.length) {
      console.error("WEBGL PAGE ERRORS",errors);
      process.exitCode=1;
    }
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
