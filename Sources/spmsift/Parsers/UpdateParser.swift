import Foundation

public struct UpdateParser {
    public init() {}

    public func parse(_ input: String) throws -> PackageAnalysis {
        let lines = input.components(separatedBy: .newlines)
        var issues: [PackageIssue] = []
        var updatedPackages: [String] = []
        var failedPackages: [String] = []
        var success = true

        // Parse update output
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check for successful updates
            if trimmed.lowercased().contains("updated") ||
               trimmed.lowercased().contains("updating") {
                if let packageName = extractPackageName(from: trimmed) {
                    updatedPackages.append(packageName)
                }
            }

            // Check for failed updates
            if trimmed.lowercased().contains("error") ||
               trimmed.lowercased().contains("failed") ||
               trimmed.lowercased().contains("cannot update") {
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

            // Check for network issues
            if trimmed.lowercased().contains("network") ||
               trimmed.lowercased().contains("connection") {
                issues.append(PackageIssue(
                    type: .networkError,
                    severity: .error,
                    message: trimmed
                ))
            }
        }

        let dependencyAnalysis = DependencyAnalysis(
            count: updatedPackages.count,
            external: updatedPackages.map { ExternalDependency(name: $0, version: "updated", type: .sourceControl) },
            circularImports: false
        )

        return PackageAnalysis(
            command: .update,
            success: success && failedPackages.isEmpty,
            dependencies: dependencyAnalysis,
            issues: issues
        )
    }

    private func extractPackageName(from line: String) -> String? {
        // Simple package name extraction
        let components = line.components(separatedBy: " ")
        return components.first { !$0.lowercased().contains("updated") && !$0.lowercased().contains("error") }
    }
}