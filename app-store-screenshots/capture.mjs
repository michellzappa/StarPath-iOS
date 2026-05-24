// Captures each screenshot slide at all required App Store resolutions
// Usage: npx playwright test capture.mjs  (or just: node capture.mjs with playwright installed)

import { chromium } from "playwright";
import { mkdirSync } from "fs";
import { join } from "path";

const SIZES = [
  { label: "6.9", w: 1320, h: 2868 },
  { label: "6.5", w: 1284, h: 2778 },
  { label: "6.3", w: 1206, h: 2622 },
  { label: "6.1", w: 1125, h: 2436 },
];

const SLIDES = ["hero", "widget", "wheel", "details"];
const BASE_URL = "http://localhost:3000";
const OUT_DIR = join(import.meta.dirname, "exports");

mkdirSync(OUT_DIR, { recursive: true });

async function main() {
  const browser = await chromium.launch();

  for (const size of SIZES) {
    console.log(`\n── ${size.label}" (${size.w}x${size.h}) ──`);

    const page = await browser.newPage({
      viewport: { width: size.w, height: size.h },
      deviceScaleFactor: 1,
    });

    await page.goto(BASE_URL, { waitUntil: "networkidle" });

    // Wait for images to load
    await page.waitForTimeout(2000);

    // Find all offscreen export containers and capture each
    const offscreens = await page.locator("[data-offscreen]").all();

    for (let i = 0; i < offscreens.length; i++) {
      const slideId = SLIDES[i];
      const num = String(i + 1).padStart(2, "0");
      const filename = `${num}-${slideId}-${size.w}x${size.h}.png`;

      // Move on-screen for capture
      await offscreens[i].evaluate((el, { w, h }) => {
        el.style.left = "0px";
        el.style.top = "0px";
        el.style.position = "fixed";
        el.style.zIndex = "9999";
        el.style.width = `${w}px`;
        el.style.height = `${h}px`;
      }, { w: size.w, h: size.h });

      await page.waitForTimeout(500);

      await offscreens[i].screenshot({
        path: join(OUT_DIR, filename),
        type: "png",
      });

      // Move back off-screen
      await offscreens[i].evaluate((el) => {
        el.style.left = "-9999px";
        el.style.position = "absolute";
        el.style.zIndex = "";
      });

      console.log(`  ✓ ${filename}`);
    }

    await page.close();
  }

  await browser.close();
  console.log(`\nDone! Screenshots saved to ${OUT_DIR}`);
}

main().catch(console.error);
