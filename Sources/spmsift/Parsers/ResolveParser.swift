import Foundation

public struct ResolveParser {
    public init() {}

    public func parse(_ input: String) throws -> PackageAnalysis {
        let lines = input.components(separatedBy: .newlines)
        var issues: [PackageIssue] = []
        var resolvedPackages: [String] = []
        var failedPackages: [String] = []
        var downloadTime: TimeInterval = 0
        var success = true

        // Parse resolution output
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check for successful resolution
            if trimmed.contains("resolved") || trimmed.contains("Resolved") {
                if let packageName = extractPackageName(from: trimmed) {
                    resolvedPackages.append(packageName)
                }
            }

            // Check for failed resolution
            if trimmed.lowercased().contains("error") ||
               trimmed.lowercased().contains("failed") ||
               trimmed.lowercased().contains("cannot resolve") {
                success = false
                if let packageName = extractPackageName(from: trimmed) {
                    failedPackages.append(packageName)
                }
                issues.append(PackageIssue(
                    type: .dependencyError,
                    severity: .error,
                    message: trimmed
                ))
            }

            // Extract download time
            if trimmed.contains("seconds") || trimmed.contains("ms") {
                downloadTime += extractDownloadTime(from: trimmed)
            }

            // Check for network issues
            if trimmed.lowercased().contains("network") ||
               trimmed.lowercased().contains("connection") ||
               trimmed.lowercased().contains("timeout") {
                issues.append(PackageIssue(
                    type: .networkError,
                    severity: .error,
                    message: trimmed
                ))
            }

            // Check for version conflicts
            if trimmed.lowercased().contains("conflict") ||
               trimmed.lowercased().contains("incompatible") ||
               trimmed.lowercased().contains("requirement") {
                issues.append(PackageIssue(
                    type: .versionConflict,
                    severity: .warning,
                    message: trimmed
                ))
            }
        }

        // Check for resolution completion
        let resolutionComplete = lines.contains(where: { $0.contains("Resolve completed") || $0.contains("All packages resolved") })

        if !resolutionComplete && !issues.contains(where: { $0.type == .dependencyError }) {
            issues.append(PackageIssue(
                type: .dependencyError,
                severity: .info,
                message: "Resolution may not have completed successfully"
            ))
        }

        // Create dependency analysis
        let dependencyAnalysis = DependencyAnalysis(
            count: resolvedPackages.count,
            external: resolvedPackages.map { ExternalDependency(name: $0, version: "resolved", type: .sourceControl) },
            circularImports: false
        )

        return PackageAnalysis(
            command: .resolve,
            success: success && failedPackages.isEmpty,
            dependencies: dependencyAnalysis,
            issues: issues,
            metrics: PackageMetrics(
                estimatedIndexTime: downloadTime > 0 ? "\(String(format: "%.1f", downloadTime))s" : nil
            )
        )
    }

    private func extractPackageName(from line: String) -> String? {
        // Extract package name from various resolution messages
        let patterns = [
            #"Resolving ([^s]+)"#,
            #"Resolved ([^s]+)"#,
            #"error: ([^s]+)"#,
            #"failed to resolve ([^s]+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                if let range = Range(match.range(at: 1), in: line) {
                    return String(line[range])
                }
            }
        }

        return nil
    }

    private func extractDownloadTime(from line: String) -> TimeInterval {
        // Extract time from messages like "Downloaded in 2.3 seconds" or "Took 150ms"
        if let secondsRange = line.range(of: #"(\d+\.?\d*)\s*seconds?"#, options: .regularExpression) {
            let timeString = String(line[secondsRange]).replacingOccurrences(of: #"seconds?"#, with: "", options: .regularExpression)
            return TimeInterval(timeString) ?? 0
        }

        if let msRange = line.range(of: #"(\d+)\s*ms"#, options: .regularExpression) {
            let timeString = String(line[msRange]).replacingOccurrences(of: "ms", with: "").trimmingCharacters(in: .whitespaces)
            return (TimeInterval(timeString) ?? 0) / 1000.0
        }

        return 0
    }
}