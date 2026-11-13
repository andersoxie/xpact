// Screenshots: validator with a rejected result (light), home and benchmarks (dark), validator at phone width.
const dir = "C:/Users/masou/AppData/Local/Temp/claude/c--xpact-xpact-student-Mass/09591cf7-f6e1-4cff-be09-d3daaf6fa72a/scratchpad/";
export default async function run(page) {
  const base = "http://127.0.0.1:5099";
  await page.setViewportSize({ width: 1360, height: 900 });

  await page.goto(base + "/validator");
  await page.getByLabel("Load an example").selectOption("mismatch");
  await page.getByRole("button", { name: /Validate/ }).click();
  await page.waitForSelector(".verdict.rejected");
  await page.screenshot({ path: dir + "shot-validator-light.png" });

  await page.evaluate(() => document.documentElement.setAttribute("data-theme", "dark"));
  await page.goto(base + "/");
  await page.evaluate(() => document.documentElement.setAttribute("data-theme", "dark"));
  await page.waitForFunction(() => document.querySelector(".stat .value")?.textContent !== "…");
  await page.screenshot({ path: dir + "shot-home-dark.png", fullPage: true });

  await page.goto(base + "/benchmarks");
  await page.evaluate(() => document.documentElement.setAttribute("data-theme", "dark"));
  await page.waitForSelector(".bar-chart");
  await page.screenshot({ path: dir + "shot-benchmarks-dark.png", fullPage: true });

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(base + "/validator");
  await page.evaluate(() => document.documentElement.removeAttribute("data-theme"));
  await page.getByRole("button", { name: /Validate/ }).click();
  await page.waitForSelector(".verdict");
  await page.screenshot({ path: dir + "shot-validator-phone.png", fullPage: true });
  return { scrollWidth: await page.evaluate(() => document.documentElement.scrollWidth) };
}
