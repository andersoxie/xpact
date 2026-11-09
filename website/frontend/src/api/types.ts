// Mirrors website/backend/src/Xpact.Contracts/ValidationResult.cs (JSON, camelCase).

export type Verdict = "accepted" | "rejected" | "crashed" | "timeout" | "error";

export interface ParseError {
  code: number;
  message: string;
  line: number;
  /** 0-based, as Expat reports it. */
  column: number;
  byteIndex: number;
}

export interface ParseEvent {
  kind: "start" | "end" | "text" | "comment" | "pi";
  name: string;
  value: string;
  line: number;
}

export interface EventSummary {
  startElements: number;
  endElements: number;
  textChunks: number;
  comments: number;
  processingInstructions: number;
  sample: ParseEvent[];
  truncated: boolean;
}

export interface ValidationResult {
  parser: string;
  version: string;
  build: string;
  verdict: Verdict;
  wellFormed: boolean;
  parseMs: number;
  totalMs: number;
  inputBytes: number;
  mode: "whole" | "chunks";
  chunkSize: number;
  parseCalls: number;
  error: ParseError | null;
  events: EventSummary;
  diagnostic: string | null;
}

export interface ServerInfo {
  parser: string;
  builds: { name: string; available: boolean }[];
  limits: {
    maxDocumentBytes: number;
    timeoutSeconds: number;
    workerMemoryMb: number;
    requestsPerMinute: number;
    maxEvents: number;
  };
}

export interface Conformance {
  source: string;
  date: string;
  suite: { name: string; version: string; url: string; cases: number };
  profile: string;
  builds: {
    build: string;
    total: number;
    passed: number;
    noCrashOnly: number;
    failed: number;
    errors: number;
    skipped: number;
    accepted: number;
    rejected: number;
    elapsedMs: number;
  }[];
  lanes: { lane: string; title: string; judgedBy: string; cases: number }[];
  dllExternalEntities: { cases: number; results: Record<string, Record<string, number>> };
  adjustments: { case_id: string; catalog_expected: string; expected: string; reason: string }[];
}

export interface Benchmarks {
  source: string;
  generated: string;
  workload: string;
  rows: {
    engine: string;
    version: string;
    iterations: number;
    bytesPerDoc: number;
    medianMs: number;
    docsPerSecond: number;
    mibPerSecond: number;
    notes: string;
  }[];
}

export interface Metric {
  icon: string;
  label: string;
  /** A count, or an already formatted value such as "0 / 0 / 0". */
  value: number | string;
  /** Rounded: shown with "≈". */
  approx: boolean;
  sub: string;
  /** The outcome in words, e.g. "✅ 0 crashes · 0 hangs". */
  result?: { text: string; tone: "good" | "plain" };
}

export interface Testing {
  source: string;
  date: string;
  revision: string;
  note: string;
  testing: Metric[];
  results: Metric[];
  project: { asOf: string; period: string; note: string; items: Metric[] };
}

export interface Comparison {
  source: string;
  title: string;
  pairs: number | null;
  sameVerdict: number | null;
  sameVerdictCodeAndEvents: number | null;
  note: string;
}
