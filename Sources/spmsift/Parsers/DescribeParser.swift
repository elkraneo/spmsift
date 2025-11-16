import Foundation

public struct DescribeParser {
    public init() {}

    public func parse(_ input: String) throws -> PackageAnalysis {
        let lines = input.components(separatedBy: .newlines)
        var issues: [PackageIssue] = []
        var packageName: String?
        var packageVersion: String?
        var platforms: [String] = []

        // Parse package description output
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.lowercased().hasPrefix("package name:") {
                packageName = trimmed.replacingOccurrences(of: "Package Name:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            }

            if trimmed.lowercased().hasPrefix("package version:") {
                packageVersion = trimmed.replacingOccurrences(of: "Package Version:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            }

            if trimmed.lowercased().contains("platform:") || trimmed.lowercased().contains("platforms:") {
                platforms.append(trimmed)
            }

            // Check for errors in description
            if trimmed.lowercased().contains("error") {
                issues.append(PackageIssue(
                    type: .syntaxError,
                    severity: .error,
                    message: trimmed
                ))
            }
        }

        return PackageAnalysis(
            command: .describe,
            success: packageName != nil,
            issues: issues,
            metrics: PackageMetrics()
        )
    }
}