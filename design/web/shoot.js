// Usage: node shoot.js page.html out.png [selector] [scale]
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [page, out, sel = '#shot', scale = '2'] = process.argv.slice(2);
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: Number(scale) });
  const p = await ctx.newPage();
  await p.goto('file://' + path.resolve(page));
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const el = await p.$(sel);
  await el.screenshot({ path: out, omitBackground: true });
  await browser.close();
  console.log('shot', out);
})();
