# Benchmarks

There are currently **no verified benchmark figures** for MacOptimizer Pro.

Earlier versions of this page and of the README listed speed-ups (for example Mach-O detection
"~120x faster" than `lipo`, telemetry reads "< 0.02 ms", a "0.42 s" scan of 50,000 files,
"1.2 GB/s" hashing and "~0.01 %" watchdog CPU). None of them had a reproducible measurement in
this repository, and some described code that did not exist at the time (the junk scan was not
parallel). They have been removed.

## What is measured

[docs/PERFORMANCE_BASELINE.md](docs/PERFORMANCE_BASELINE.md) and
[docs/PERFORMANCE_REPORT.md](docs/PERFORMANCE_REPORT.md) contain figures from the monitoring and
concurrency hardening work. Each figure is labelled as measured (run against the source), simulated
(the scheduler driven by a fake clock), static (counted from the code) or
`REQUIRES_INSTRUMENTS_VALIDATION` (not measured yet).

## How to measure

- **Resource use of the app**: build a release app with `./Scripts/build_app.sh` and follow the
  Instruments runs listed at the end of [docs/PERFORMANCE_REPORT.md](docs/PERFORMANCE_REPORT.md)
  (Allocations, Leaks, Time Profiler, System Trace, Energy Log).
- **A single operation**: time it on your own machine and state the hardware, macOS version,
  build configuration and data set (for example the number and size of files) with the result.

Please include that context with any number you contribute to this page.

## Design notes

These describe how the code works, not how fast it is:

- `MachOArchitectureDetector` reads the first 4096 bytes of a binary with `FileHandle` and checks
  the magic number (`0xFEEDFACF` for 64-bit Mach-O, `0xCAFEBABE` for universal binaries) instead
  of spawning `lipo`.
- Live metrics come from `host_statistics64`, `sysctl`, IOKit and `getifaddrs`. Only the process
  list uses `/bin/ps`, and only while a screen or the watchdog needs it.
- The duplicate finder compares a 64 KB prefix before hashing whole files with SHA-256.
