# spmsift

Context-efficient Swift Package Manager analysis tool for Claude agents and AI development workflows.

## Overview

spmsift converts verbose Swift Package Manager output into structured, minimal-context JSON designed specifically for Claude agents, saving >95% of context while preserving all diagnostic information.

## Problem It Solves

Swift Package Manager commands output hundreds of lines of verbose information:
- `swift package dump-package` → 200+ lines of JSON manifest
- `swift package show-dependencies` → Tree with 100+ dependencies
- `swift package resolve` → Verbose resolution logs

For Claude agents working with complex packages like Scroll (61 targets, 17 dependencies), this consumes massive context budgets and makes analysis inefficient.

## Solution

spmsift filters the signal from the noise:

```bash
swift package dump-package | spmsift
# → {"targets": 61, "dependencies": 17, "issues": []}

swift package show-dependencies | spmsift
# → {"dependencies": [{"name": "TCA", "version": "1.23.1"}], "circular": false}
```

Context savings: 95%+ while preserving all diagnostic information.

## Installation

### From Source

```bash
git clone https://github.com/elkraneo/spmsift.git
cd spmsift
swift build -c release
cp .build/release/spmsift /usr/local/bin/
```

### Homebrew

```bash
# Install via custom tap
brew tap elkraneo/tap
brew install spmsift

# Verify installation
which spmsift  # Should show /opt/homebrew/bin/spmsift
```

## Usage

### Basic Usage

```bash
# Analyze package structure
swift package dump-package | spmsift

# Analyze dependencies
swift package show-dependencies | spmsift

# Analyze resolution process
swift package resolve | spmsift
```

### Output Formats

```bash
# JSON output (default)
swift package dump-package | spmsift

# Summary format (minimal)
swift package dump-package | spmsift --format summary

# Detailed format (includes diagnostics)
swift package dump-package | spmsift --format detailed
```

### Filtering by Severity

```bash
# Only show errors and critical issues
swift package dump-package | spmsift --severity error

# Show all issues including info
swift package dump-package | spmsift --severity info
```

### Performance Metrics

```bash
# Include parse time and complexity metrics
swift package dump-package | spmsift --metrics
```

### Verbose Output

```bash
# Include raw output for debugging
swift package dump-package | spmsift --verbose
```

## Output Examples

### JSON Output

```json
{
  "command": "dump-package",
  "success": true,
  "targets": {
    "count": 61,
    "hasTestTargets": true,
    "platforms": ["iOS 15.0", "macOS 12.0"],
    "executables": ["MyApp"],
    "libraries": ["MyLibrary"]
  },
  "dependencies": {
    "count": 17,
    "external": [
      {
        "name": "swift-composable-architecture",
        "version": "1.23.1",
        "type": "source-control",
        "url": "https://github.com/pointfreeco/swift-composable-architecture"
      }
    ],
    "local": [],
    "circularImports": false,
    "versionConflicts": []
  },
  "issues": [
    {
      "type": "version_conflict",
      "severity": "warning",
      "target": "MyTarget",
      "message": "Using branch 'main' may cause instability"
    }
  ],
  "metrics": {
    "parseTime": 0.001,
    "complexity": "high",
    "estimatedIndexTime": "45-90s"
  }
}
```

### Summary Output

```json
{
  "command": "dump-package",
  "success": true,
  "targets": 61,
  "dependencies": 17,
  "issues": 1
}
```

## Integration

### Smith Skill Integration

```bash
#!/bin/bash
# spm-analyze.sh
swift package dump-package 2>&1 | spmsift
swift package show-dependencies 2>&1 | spmsift
```

### GitHub Actions

```yaml
- name: Analyze Package
  run: |
    swift package dump-package | spmsift --format summary > package-analysis.json
    swift package show-dependencies | spmsift --format summary >> package-analysis.json
```

## Performance

| Metric          | Before spmsift | After spmsift |
|-----------------|----------------|---------------|
| Output Size     | 200KB+         | < 5KB         |
| Context Usage   | High           | Minimal       |
| Parse Time      | N/A            | < 1ms         |
| Error Detection | Manual         | Automated     |

## Features

- **Pipe-based interface** like xcsift for seamless integration
- **Multi-command support**: dump-package, show-dependencies, resolve, describe, update
- **Structured JSON output** for programmatic analysis
- **Context-optimized output** < 5KB for any package size
- **Error-aware** with detailed issue detection
- **Performance-focused** < 1ms parse time for large packages
- **Configurable output** formats and severity filtering
- **Built-in metrics** for performance analysis

## Requirements

- Swift 6.0+
- macOS 13.0+

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details.

## Related Tools

- [xcsift](https://github.com/ldomaradzki/xcsift) - Similar tool for Xcode build output

---

**spmsift**: Making Swift Package Manager analysis AI-friendly.