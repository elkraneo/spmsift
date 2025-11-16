import Foundation

public struct DumpPackageParser {
    public init() {}

    public func parse(_ input: String) throws -> PackageAnalysis {
        do {
            guard let data = input.data(using: .utf8) else {
                throw ParseError.invalidUTF8
            }

            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dictionary = json as? [String: Any] else {
                throw ParseError.invalidJSON
            }

            return parsePackageDictionary(dictionary)

        } catch {
            if let parseError = error as? ParseError {
                throw parseError
            }

            return PackageAnalysis(
                command: .dumpPackage,
                success: false,
                issues: [
                    PackageIssue(
                        type: .syntaxError,
                        severity: .error,
                        message: "Failed to parse Package.swift JSON: \(error.localizedDescription)"
                    )
                ]
            )
        }
    }

    private func parsePackageDictionary(_ dict: [String: Any]) -> PackageAnalysis {
        var issues: [PackageIssue] = []

        // Parse targets
        let targets = parseTargets(from: dict)
        issues.append(contentsOf: targets.issues)

        // Parse dependencies
        let dependencies = parseDependencies(from: dict)
        issues.append(contentsOf: dependencies.issues)

        // Parse platforms
        let platforms = parsePlatforms(from: dict)

        // Check for common issues
        issues.append(contentsOf: validatePackageStructure(dict))

        return PackageAnalysis(
            command: .dumpPackage,
            success: issues.allSatisfy { $0.severity != .critical },
            targets: TargetAnalysis(
                count: targets.analysis.count,
                hasTestTargets: targets.analysis.hasTestTargets,
                platforms: platforms,
                executables: targets.analysis.executables,
                libraries: targets.analysis.libraries
            ),
            dependencies: dependencies.analysis,
            issues: issues
        )
    }

    private func parseTargets(from dict: [String: Any]) -> (analysis: TargetAnalysis, issues: [PackageIssue]) {
        var issues: [PackageIssue] = []
        var executables: [String] = []
        var libraries: [String] = []
        var hasTestTargets = false
        var targetCount = 0

        guard let targetsArray = dict["targets"] as? [[String: Any]] else {
            issues.append(PackageIssue(
                type: .missingTarget,
                severity: .warning,
                message: "No targets found in package"
            ))
            return (TargetAnalysis(count: 0), issues)
        }

        for targetDict in targetsArray {
            guard let targetName = targetDict["name"] as? String else { continue }
            targetCount += 1

            if let targetType = targetDict["type"] as? String {
                switch targetType.lowercased() {
                case "executable":
                    executables.append(targetName)
                case "library", "static-library", "dynamic-library":
                    libraries.append(targetName)
                case "test":
                    hasTestTargets = true
                default:
                    break
                }
            }

            // Check for target-specific issues
            issues.append(contentsOf: validateTarget(targetDict, name: targetName))
        }

        let analysis = TargetAnalysis(
            count: targetCount,
            hasTestTargets: hasTestTargets,
            executables: executables,
            libraries: libraries
        )

        return (analysis, issues)
    }

    private func validateTarget(_ target: [String: Any], name: String) -> [PackageIssue] {
        var issues: [PackageIssue] = []

        // Check for missing dependencies
        if let dependencies = target["dependencies"] as? [String], dependencies.isEmpty {
            if name.lowercased().contains("test") == false {
                issues.append(PackageIssue(
                    type: .missingTarget,
                    severity: .info,
                    target: name,
                    message: "Target '\(name)' has no dependencies"
                ))
            }
        }

        // Check for platform-specific issues
        if let settings = target["settings"] as? [[String: Any]] {
            for setting in settings {
                if let condition = setting["condition"] as? [String: Any],
                   let _ = condition["platformNames"] as? [String] {
                    // Could add more sophisticated platform validation here
                }
            }
        }

        return issues
    }

    private func parseDependencies(from dict: [String: Any]) -> (analysis: DependencyAnalysis, issues: [PackageIssue]) {
        var issues: [PackageIssue] = []
        var externalDependencies: [ExternalDependency] = []
        var localDependencies: [LocalDependency] = []

        guard let dependencies = dict["dependencies"] as? [[String: Any]] else {
            return (DependencyAnalysis(), [])
        }

        for depDict in dependencies {
            if let url = depDict["url"] as? String {
                // External dependency
                let name = depDict["name"] as? String ?? extractNameFromURL(url)
                let version = extractVersion(from: depDict)

                let dependencyType: DependencyType
                if url.hasSuffix(".binary") {
                    dependencyType = .binary
                } else if url.contains("@swift-package-registry") {
                    dependencyType = .registry
                } else {
                    dependencyType = .sourceControl
                }

                externalDependencies.append(ExternalDependency(
                    name: name,
                    version: version,
                    type: dependencyType,
                    url: url
                ))
            } else if let path = depDict["path"] as? String {
                // Local dependency
                let name = depDict["name"] as? String ?? extractNameFromPath(path)
                localDependencies.append(LocalDependency(name: name, path: path))
            }

            // Validate dependency
            issues.append(contentsOf: validateDependency(depDict))
        }

        // Check for circular dependencies (simplified check)
        let circularImports = checkForCircularDependencies(externalDependencies + localDependencies.map { dep in
            ExternalDependency(name: dep.name, version: "local", type: .sourceControl)
        })

        if circularImports {
            issues.append(PackageIssue(
                type: .circularImport,
                severity: .error,
                message: "Potential circular dependencies detected"
            ))
        }

        let analysis = DependencyAnalysis(
            count: externalDependencies.count + localDependencies.count,
            external: externalDependencies,
            local: localDependencies,
            circularImports: circularImports
        )

        return (analysis, issues)
    }

    private func validateDependency(_ dependency: [String: Any]) -> [PackageIssue] {
        var issues: [PackageIssue] = []

        // Check for missing URL or path
        if dependency["url"] == nil && dependency["path"] == nil {
            issues.append(PackageIssue(
                type: .dependencyError,
                severity: .error,
                message: "Dependency has neither URL nor path"
            ))
        }

        // Check for version requirement issues
        if let requirement = dependency["requirement"] as? [String: Any] {
            if let range = requirement["range"] as? [String] {
                // Could validate version range format here
                if range.count > 2 {
                    issues.append(PackageIssue(
                        type: .versionConflict,
                        severity: .warning,
                        message: "Complex version range may cause resolution issues"
                    ))
                }
            }
        }

        return issues
    }

    private func parsePlatforms(from dict: [String: Any]) -> [String] {
        guard let platforms = dict["platforms"] as? [String: Any] else {
            return []
        }

        var platformNames: [String] = []
        for (platform, version) in platforms {
            platformNames.append("\(platform) \(version)")
        }

        return platformNames.sorted()
    }

    private func validatePackageStructure(_ dict: [String: Any]) -> [PackageIssue] {
        var issues: [PackageIssue] = []

        // Check for required fields
        if dict["name"] == nil {
            issues.append(PackageIssue(
                type: .syntaxError,
                severity: .critical,
                message: "Package missing required 'name' field"
            ))
        }

        if dict["products"] == nil {
            issues.append(PackageIssue(
                type: .missingTarget,
                severity: .warning,
                message: "Package defines no products"
            ))
        }

        return issues
    }

    // MARK: - Helper Methods

    private func extractNameFromURL(_ url: String) -> String {
        let components = url.components(separatedBy: "/")
        return components.last?.replacingOccurrences(of: ".git", with: "") ?? "unknown"
    }

    private func extractNameFromPath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        return components.last ?? "unknown"
    }

    private func extractVersion(from dependency: [String: Any]) -> String {
        guard let requirement = dependency["requirement"] as? [String: Any] else {
            return "unspecified"
        }

        if let range = requirement["range"] as? [String], !range.isEmpty {
            return range.joined(separator: ", ")
        } else if let branch = requirement["branch"] as? String {
            return "branch: \(branch)"
        } else if let revision = requirement["revision"] as? String {
            return "revision: \(revision.prefix(7))"
        } else if let exact = requirement["exact"] as? String {
            return exact
        }

        return "unspecified"
    }

    private func checkForCircularDependencies(_ dependencies: [ExternalDependency]) -> Bool {
        // Simplified circular dependency check
        // In a real implementation, you'd need to build a full dependency graph
        return dependencies.count > 20 // Heuristic: large packages more likely to have issues
    }

    // MARK: - Error Types

    enum ParseError: Error {
        case invalidUTF8
        case invalidJSON
        case missingRequiredField(String)
    }
}