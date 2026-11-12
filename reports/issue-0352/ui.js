const { chromium } = require('playwright-core');
const [,, port, file, label] = process.argv;
(async () => {
  const b = await chromium.launch({ executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
  const p = await b.newPage();
  await p.goto(`http://localhost:${port}/validator`, { waitUntil: 'networkidle' }).catch(()=>p.goto(`http://localhost:${port}/`));
  if (!(await p.$('input[type=file]'))) { await p.click('text=Validator').catch(()=>{}); }
  const t0 = Date.now();
  await p.setInputFiles('input[type=file]', file);
  await p.waitForSelector('.file-chip', { timeout: 120000 });
  const tLoad = Date.now() - t0;
  const nodes = await p.evaluate(() => document.querySelectorAll('.gutter div').length);
  const t1 = Date.now();
  await p.evaluate(() => 1); // page responsive?
  const tEval = Date.now() - t1;
  const t2 = Date.now();
  await p.click('button:has-text("Validate")');
  await p.waitForSelector('.verdict', { timeout: 120000 });
  const verdict = (await p.textContent('.verdict .title')).trim();
  const note = await p.$('text=Large file') ? 'note shown' : 'no note';
  const ro = await p.$eval('textarea', e => e.readOnly);
  console.log(`${label}: load ${tLoad} ms, gutter rows ${nodes}, eval ${tEval} ms, validate ${Date.now()-t2} ms -> ${verdict}; ${note}; readOnly=${ro}`);
  await b.close();
})().catch(e => { console.log(label, 'FAIL', e.message.split('\n')[0]); process.exit(1); });
