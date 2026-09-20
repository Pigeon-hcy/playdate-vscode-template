// Rasterize the approved browser composition at the device's native resolution.
// NODE_PATH=<playwright location> node tools/render_title_frames.cjs <output dir>
// Set CHROME_PATH when Chrome is installed elsewhere. No server is required.
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const output = path.resolve(process.argv[2] || '/private/tmp/bun-rush-title-frames');
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ headless: true, executablePath:
    process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
  try {
    const page = await browser.newPage({ viewport: { width: 400, height: 240 }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(path.resolve(__dirname, '../art/title-screen/shutter-v2/preview.html')).href);
    await page.evaluate(() => preview.stop());
    await page.addStyleTag({ content: 'body{display:block;padding:0;min-height:0;background:transparent}main{width:400px}h1,p,.tools,small{display:none}.screen{outline:none}' });
    await page.evaluate(() => Promise.all(Array.from(document.images, image => image.decode())));
    for (let i = 0; i < 81; i++) {
      await page.evaluate(ms => preview.render(ms), i * 1000 / 30);
      await page.locator('#screen').screenshot({ path: path.join(output, `road-${String(i + 1).padStart(3, '0')}.png`) });
    }
    await page.evaluate(() => {
      preview.render(2700);
      document.getElementById('vehicleBounce').setAttribute('transform', 'translate(0 0)');
      document.getElementById('bob').setAttribute('transform', 'translate(0 0)');
    });
    await page.locator('#screen').screenshot({ path: path.join(output, 'shutter.png') });
    for (const id of ['title', 'start']) {
      const svg = await page.evaluate(id => {
        const source = document.getElementById('screen');
        const root = source.cloneNode(false);
        root.removeAttribute('class'); root.removeAttribute('id');
        root.setAttribute('width', 400); root.setAttribute('height', 240);
        root.append(source.querySelector('defs').cloneNode(true));
        const layer = document.getElementById(id).cloneNode(true);
        layer.removeAttribute('transform'); layer.style.visibility = 'visible';
        root.append(layer);
        for (const image of root.querySelectorAll('image')) {
          image.setAttribute('href', new URL(image.getAttribute('href'), location.href).href);
        }
        return root.outerHTML;
      }, id);
      const layerPage = await browser.newPage({ viewport: { width: 400, height: 240 }, deviceScaleFactor: 1 });
      // Keep a local file origin so the existing local image layers may load.
      await layerPage.goto(page.url());
      await layerPage.evaluate(svg => { preview.stop(); document.body.innerHTML = svg; }, svg);
      await layerPage.addStyleTag({ content: 'body{display:block;margin:0;padding:0;min-height:0;background:transparent}svg{display:block}' });
      await layerPage.locator('body > svg').screenshot({ path: path.join(output, `${id}.png`), omitBackground: true });
      await layerPage.close();
    }
    if (errors.length) throw new Error(errors.join('\n'));
    console.log(`Rendered 81 road frames and 3 reusable layers to ${output}`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
