import type { Benchmarks, Comparison, Conformance, ServerInfo, ValidationResult } from "./types";

/** A refused request (400, 413, 429 …) with the API's explanation. */
export class ApiError extends Error {
  constructor(public status: number, public title: string, detail: string) {
    super(detail || title);
  }
}

async function readJson<T>(response: Response): Promise<T> {
  if (response.ok) return (await response.json()) as T;
  let title = response.statusText;
  let detail = "";
  try {
    const problem = await response.json();
    title = problem.title ?? title;
    detail = problem.detail ?? "";
  } catch {
    // Not a problem-details body (for example 429 from the rate limiter).
  }
  if (response.status === 429) {
    title = "Too many requests";
    detail = "Please wait a minute before validating again.";
  }
  throw new ApiError(response.status, title, detail);
}

export interface ValidateOptions {
  build: string;
  /** 0 = the whole document in one call. */
  chunkSize: number;
}

/** Pasted text: sent as JSON (UTF-8). */
export async function validateText(xml: string, options: ValidateOptions): Promise<ValidationResult> {
  const response = await fetch("/api/validate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ xml, build: options.build, chunkSize: options.chunkSize }),
  });
  return readJson<ValidationResult>(response);
}

/** An uploaded file: sent as is, so its original bytes and encoding reach the parser. */
export async function validateFile(file: File, options: ValidateOptions): Promise<ValidationResult> {
  const form = new FormData();
  form.append("file", file, file.name);
  form.append("build", options.build);
  form.append("chunkSize", String(options.chunkSize));
  const response = await fetch("/api/validate", { method: "POST", body: form });
  return readJson<ValidationResult>(response);
}

export const getInfo = () => fetch("/api/info").then((r) => readJson<ServerInfo>(r));
export const getConformance = () => fetch("/api/results/conformance").then((r) => readJson<Conformance>(r));
export const getBenchmarks = () => fetch("/api/results/benchmarks").then((r) => readJson<Benchmarks>(r));
export const getComparison = () => fetch("/api/results/comparison").then((r) => readJson<Comparison>(r));
