const { chromium } = require('playwright-core');
(async () => {
  const b = await chromium.launch({ executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe' });
  const p = await b.newPage(); await p.goto('http://localhost:5098/validator', { waitUntil: 'networkidle' });
  for (const [f, build] of [[process.argv[2], 'production'], [process.argv[3], 'assertions']]) {
    await p.setInputFiles('input[type=file]', f); await p.waitForSelector('.file-chip');
    await p.selectOption('select >> nth=1', build).catch(async()=>{ await p.locator('label:has-text("Parser build") select').selectOption(build); });
    await p.click('button:has-text("Validate")'); await p.waitForSelector('.verdict', { timeout: 60000 });
    console.log(build, '|', (await p.textContent('.verdict')).replace(/\s+/g,' ').slice(0,260));
  }
  await b.close();
})().catch(e => console.log('FAIL', e.message.split('\n')[0]));
