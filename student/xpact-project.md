<div align="center">

# 📬 xpact project

**XML parsing, by contract.** · An open, tested XML parser written in Eiffel · November 2026

![W3C](https://img.shields.io/badge/W3C_conformance-1974%2F1974-1a7f37?style=for-the-badge)
![Regression](https://img.shields.io/badge/regression-910%2F910-1a7f37?style=for-the-badge)
![DLL tests](https://img.shields.io/badge/C_API_tests-4308%2F4308-1a7f37?style=for-the-badge)
![Fuzzing](https://img.shields.io/badge/fuzz_inputs-870k%2C_0_crashes-8a2be2?style=for-the-badge)

</div>

---

Hello,

My name is **Masoud Dehdar**, and I want to tell you about a project I helped build: **[xpact](https://github.com/andersoxie/xpact)**, an XML parser written in Eiffel that behaves like [libexpat](https://github.com/libexpat/libexpat), the C parser used by billions of devices. It can replace libexpat through the same C interface, but its rules are checked by contracts (Design by Contract) instead of trust.

## 🌱 Where we started

It began with an article. **[Finnian Reilly](https://github.com/finnianr)** ([Eiffel-Loop](http://www.eiffel-loop.com)) wrote *[Finding a billion-user project for Eiffel: how DbC catches the security flaws that Rust misses](https://www.eiffel.org/blog/Finnian%20Reilly/2026/05/finding-billion-user-project-eiffel-how-dbc-catches-security-flaws-rust-misses)* and built the first parser, Xpact-core. **[Anders Persson](https://www.linkedin.com/in/andersperssonbsharpab/)** ([GitHub](https://github.com/andersoxie)) at **[Bsharp](https://bsharp.se/)** turned that idea into a project and became my supervisor. Through my school, **[Medieinstitutet](https://medieinstitutet.se/)**, with **[Hossein Niromand](https://www.linkedin.com/in/hossein-niromand/)** as my LIA supervisor, I joined for an eight-week internship (6 October – 27 November 2026).

## 🤝 Who built it

| | Who | What they gave |
|---|---|---|
| 💡 | [Finnian Reilly](https://github.com/finnianr) | the idea, the article and the first parser (Xpact-core) |
| 🧭 | [Anders Persson](https://www.linkedin.com/in/andersperssonbsharpab/) · [Bsharp](https://bsharp.se/) | the project, the parser design, the Jenkins CI and the direction (the second parser) |
| 🧪 | [Masoud Dehdar](https://github.com/CodTanium) | tests, parser fixes, conformance runs, benchmarks, the website, the reports |
| 🎓 | [Hossein Niromand](https://www.linkedin.com/in/hossein-niromand/) · [Medieinstitutet](https://medieinstitutet.se/) | the school side: guidance and the internship frame |
| 🛠️ | [Eric Bezault](https://github.com/gobo-eiffel) · Gobo Eiffel | the second compiler; his fix made our Gobo build work on Windows |
| 🏗️ | [Eiffel Software](https://www.eiffel.org) · [libexpat](https://github.com/libexpat/libexpat) · [W3C](https://www.w3.org/XML/Test/) | the compiler, the reference parser and the official XML test suite we measure against |

## 🏆 What we can show today

| Check | Result |
|---|---|
| W3C XML conformance (official suite) | ✅ **1,974 / 1,974** cases, and **0 failures in all 2,585** |
| Same result with two different Eiffel compilers | ✅ EiffelStudio and Gobo give identical verdicts |
| Incremental parsing (whole, every split point, byte by byte) | ✅ **910 / 910** |
| The C interface, tested like a C program uses it | ✅ **4,308 / 4,308** cases |
| libexpat's own test suite, run against xpact | ✅ quality gate passed (361 of 399 checks) |
| Fuzzing and differential testing against Expat | ✅ **1.9 million** generated inputs, **0 crashes**, 99.99 % same verdict |

**The four-way comparison** (same tests, same machine, 23 November 2026):

| Parser | W3C cases passed | Speed (µs per document, lower is better) |
|---|---:|---:|
| **xpact** | ✅ **100 %** (1,974) | 98.4 |
| Gobo's XML parser | 96.8 % | about 4–9× slower than xpact |
| libexpat | 83.8 % | **19.6** |
| Xpact-core | 62.4 % | 40.4 |

xpact is the **most correct** of the four; libexpat is still the **fastest**, and closing that gap is the next chapter. Everything above can be re-run with one command: see [the test suites](../reports/four-way-2026-11-23/TEST-SUITES.md) and [the full report](../reports/four-way-2026-11-23/REPORT.md).

## 💬 Why I am writing

This project taught me what it means to **prove** that software works: a baseline before every fix, one issue per problem, and no "passed" without output that shows it. If you work with testing, quality, parsers, C/C#/Eiffel or CI, I would be glad to talk, whether about a job, an internship, or just to get to know each other.

Thank you for reading.

**Masoud Dehdar** · [GitHub](https://github.com/CodTanium) · [the xpact repository](https://github.com/andersoxie/xpact/tree/incremental-test)
