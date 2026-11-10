// QA for the XPact website: every page renders; the validator accepts the default sample
// and rejects a broken one with the error line marked.
export default async function run(page) {
  const out = {};
  const base = "http://127.0.0.1:5099";

  for (const path of ["/", "/docs", "/benchmarks", "/project"]) {
    await page.goto(base + path);
    await page.waitForSelector("h1");
    out[path] = { h1: await page.locator("h1").first().innerText() };
  }
  // Data-driven content arrived on the benchmarks page.
  await page.goto(base + "/benchmarks");
  await page.waitForSelector(".bar-chart");
  out.benchmarkBars = await page.locator(".bar-row").count();
  out.conformanceRows = await page.locator("table").first().locator("tbody tr").count();

  // Validator: default sample is accepted.
  await page.goto(base + "/validator");
  await page.getByRole("button", { name: /Validate/ }).click();
  await page.waitForSelector(".verdict");
  out.validVerdict = await page.locator(".verdict .title").innerText();
  out.eventRows = await page.locator(".events-table tbody tr").count();

  // Broken sample is rejected, and the error line is marked in the gutter.
  await page.getByLabel("Load an example").selectOption("mismatch");
  await page.getByRole("button", { name: /Validate/ }).click();
  await page.waitForSelector(".verdict.rejected");
  out.brokenVerdict = await page.locator(".verdict .title").innerText();
  out.brokenDetail = await page.locator(".verdict .detail").innerText();
  out.markedLine = await page.locator(".gutter .err").innerText();

  // Chunked mode, 1 byte per call: same verdict.
  await page.getByLabel("Feed the document").selectOption("chunks");
  await page.getByRole("button", { name: /Validate/ }).click();
  await page.waitForFunction(() => document.querySelector(".kv")?.textContent?.includes("×"));
  out.chunkedVerdict = await page.locator(".verdict .title").innerText();
  return out;
}
