import Foundation
import Collections

public struct ShowDependenciesParser {
    public init() {}

    public func parse(_ input: String) throws -> PackageAnalysis {
        let lines = input.components(separatedBy: .newlines)
        var issues: [PackageIssue] = []
        var externalDependencies: [ExternalDependency] = []
        var localDependencies: [LocalDependency] = []
        var circularImports = false

        // Parse tree structure
        let (dependencies, localDeps, parsedIssues) = parseDependencyTree(lines)
        issues.append(contentsOf: parsedIssues)

        // Combine local dependencies from parsing with the ones from tree parsing
        localDependencies.append(contentsOf: localDeps)

        // Separate external and local dependencies
        for dep in dependencies {
            if dep.url != nil || (!dep.version.isEmpty && dep.version != "unspecified") {
                externalDependencies.append(dep)
            } else if dep.version == "unspecified" {
                localDependencies.append(LocalDependency(name: dep.name, path: dep.name))
            }
        }

        // Check for circular dependencies
        circularImports = checkCircularDependencies(lines)

        if circularImports {
            issues.append(PackageIssue(
                type: .circularImport,
                severity: .error,
                message: "Circular dependency detected in package graph"
            ))
        }

        let dependencyAnalysis = DependencyAnalysis(
            count: dependencies.count,
            external: externalDependencies,
            local: localDependencies,
            circularImports: circularImports
        )

        let hasErrors = issues.contains { $0.severity == .error || $0.severity == .critical }
        return PackageAnalysis(
            command: .showDependencies,
            success: !hasErrors,
            dependencies: dependencyAnalysis,
            issues: issues
        )
    }

    private func parseDependencyTree(_ lines: [String]) -> (dependencies: [ExternalDependency], localDependencies: [LocalDependency], issues: [PackageIssue]) {
        var dependencies: [ExternalDependency] = []
        var localDependencies: [LocalDependency] = []
        var issues: [PackageIssue] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and headers
            if trimmedLine.isEmpty ||
               trimmedLine.contains("Dependencies:") ||
               trimmedLine.contains("Package:") ||
               trimmedLine.lowercased().contains("no dependencies") {
                continue
            }

            // Check for errors first
            if trimmedLine.lowercased().contains("error") ||
               trimmedLine.lowercased().contains("failed") ||
               trimmedLine.lowercased().contains("warning") {
                issues.append(PackageIssue(
                    type: .dependencyError,
                    severity: trimmedLine.lowercased().contains("error") ? .error : .warning,
                    message: trimmedLine
                ))
                continue
            }

            // Parse dependency line
            let dependency = parseDependencyLine(trimmedLine)
            if let dep = dependency {
                dependencies.append(dep)
            } else if !trimmedLine.isEmpty && !isTreeCharacter(trimmedLine.first) {
                // Unparsed line that's not an error might be a local dependency or other format
                if !trimmedLine.contains("Dependencies:") && !trimmedLine.contains("Package:") {
                    // Treat as local dependency if it looks like a path
                    if trimmedLine.contains("/") || trimmedLine.contains("\\") {
                        localDependencies.append(LocalDependency(name: trimmedLine, path: trimmedLine))
                    }
                }
            }
        }

        // Validate dependency versions
        issues.append(contentsOf: validateDependencyVersions(dependencies))

        return (dependencies, localDependencies, issues)
    }

    private func parseDependencyLine(_ line: String) -> ExternalDependency? {
        // Remove tree characters and whitespace (├── └── │── )
        let cleanLine = line.replacingOccurrences(of: "^[├│└─ ]+", with: "", options: .regularExpression)
        let trimmed = cleanLine.trimmingCharacters(in: .whitespaces)

        // Parse different dependency formats:
        // 1. "package-name (version)"
        // 2. "package-name@version"
        // 3. "package-name [url]"
        // 4. "package-name"

        if let range = trimmed.range(of: #" \(([^)]+)\)$"#, options: .regularExpression) {
            // Format: "package-name (version)"
            let name = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let version = String(trimmed[range].dropFirst(2).dropLast(1)) // Remove "( )"

            return ExternalDependency(
                name: name,
                version: version,
                type: determineDependencyType(from: version)
            )
        } else if let atIndex = trimmed.firstIndex(of: "@") {
            // Format: "package-name@version"
            let name = String(trimmed[..<atIndex])
            let version = String(trimmed[atIndex...].dropFirst())

            return ExternalDependency(
                name: name,
                version: version,
                type: determineDependencyType(from: version)
            )
        } else if let bracketRange = trimmed.range(of: #" \[([^\]]+)\]$"#, options: .regularExpression) {
            // Format: "package-name [url]"
            let name = String(trimmed[..<bracketRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let url = String(trimmed[bracketRange].dropFirst(2).dropLast(1)) // Remove "[ ]"

            return ExternalDependency(
                name: name,
                version: "source-control",
                type: .sourceControl,
                url: url
            )
                } else if let urlRange = trimmed.range(of: #"<[^>]+>"#, options: .regularExpression) {
            // Format: "package-name<url@version>"
            let name = String(trimmed[..<urlRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let urlWithVersion = String(trimmed[urlRange].dropFirst().dropLast()) // Remove < >

            // Split URL and version
            let components = urlWithVersion.components(separatedBy: "@")
            let url = components.first ?? urlWithVersion
            let version = components.count > 1 ? components[1] : "unspecified"

            
            return ExternalDependency(
                name: name,
                version: version,
                type: .sourceControl,
                url: url
            )
        } else {
            // Format: "package-name" (no version specified)
            return ExternalDependency(
                name: trimmed,
                version: "unspecified",
                type: .sourceControl
            )
        }
    }

    private func determineDependencyType(from version: String) -> DependencyType {
        if version.contains("registry") || version.hasPrefix("1.") || version.hasPrefix("2.") || version.hasPrefix("3.") {
            return .registry
        } else if version.contains(".binary") || version.lowercased().contains("xcframework") {
            return .binary
        } else {
            return .sourceControl
        }
    }

    private func validateDependencyVersions(_ dependencies: [ExternalDependency]) -> [PackageIssue] {
        var issues: [PackageIssue] = []

        // Group dependencies by name to check for version conflicts
        var dependencyGroups: [String: [ExternalDependency]] = [:]
        for dep in dependencies {
            if dependencyGroups[dep.name] == nil {
                dependencyGroups[dep.name] = []
            }
            dependencyGroups[dep.name]?.append(dep)
        }

        // Check for version conflicts
        for (name, deps) in dependencyGroups {
            let versions = Set(deps.map { $0.version })
            if versions.count > 1 {
                issues.append(PackageIssue(
                    type: .versionConflict,
                    severity: .warning,
                    message: "Multiple versions of \(name): \(versions.joined(separator: ", "))"
                ))
            }

            // Check for problematic version specifications
            for dep in deps {
                if dep.version.lowercased().contains("main") ||
                   dep.version.lowercased().contains("master") ||
                   dep.version.lowercased().contains("develop") {
                    issues.append(PackageIssue(
                        type: .versionConflict,
                        severity: .info,
                        target: dep.name,
                        message: "Using branch '\(dep.version)' may cause instability"
                    ))
                }
            }
        }

        return issues
    }

    private func checkCircularDependencies(_ lines: [String]) -> Bool {
        // Look for indicators of circular dependencies in the output
        let output = lines.joined(separator: "\n").lowercased()

        return output.contains("circular") ||
               output.contains("cycle") ||
               output.contains("loop") ||
               checkForRepeatedDependencies(lines)
    }

    private func checkForRepeatedDependencies(_ lines: [String]) -> Bool {
        var seenDependencies: Set<String> = []

        for line in lines {
            if let dependency = parseDependencyLine(line) {
                if seenDependencies.contains(dependency.name) {
                    // Same dependency appearing multiple times might indicate a cycle
                    return true
                }
                seenDependencies.insert(dependency.name)
            }
        }

        return false
    }

    private func isTreeCharacter(_ char: Character?) -> Bool {
        guard let char = char else { return false }
        return char == "├" || char == "│" || char == "└" || char == "─" || char == " "
    }
}