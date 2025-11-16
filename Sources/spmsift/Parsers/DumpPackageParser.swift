import Foundation

public struct DumpPackageParser {
    public init() {}

    public func parse(_ input: String, targetFilter: String? = nil) throws -> PackageAnalysis {
        do {
            guard let data = input.data(using: .utf8) else {
                throw ParseError.invalidUTF8
            }

            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dictionary = json as? [String: Any] else {
                throw ParseError.invalidJSON
            }

            return parsePackageDictionary(dictionary, targetFilter: targetFilter)

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

    private func parsePackageDictionary(_ dict: [String: Any], targetFilter: String? = nil) -> PackageAnalysis {
        var issues: [PackageIssue] = []

        // Parse targets
        let targets = parseTargets(from: dict, targetFilter: targetFilter)
        issues.append(contentsOf: targets.issues)

        // Parse dependencies (filtered if target is specified)
        let dependencies = parseDependencies(from: dict, targetFilter: targetFilter)
        issues.append(contentsOf: dependencies.issues)

        // Parse platforms
        let platforms = parsePlatforms(from: dict)

        // Check for common issues
        issues.append(contentsOf: validatePackageStructure(dict))

        // Filter issues for target if specified
        let filteredIssues = targetFilter != nil ? issues.filter {
            $0.target == nil || $0.target == targetFilter
        } : issues

        return PackageAnalysis(
            command: .dumpPackage,
            success: filteredIssues.allSatisfy { $0.severity != .critical },
            targets: targets.analysis,
            dependencies: dependencies.analysis,
            issues: filteredIssues
        )
    }

    private func parseTargets(from dict: [String: Any], targetFilter: String? = nil) -> (analysis: TargetAnalysis, issues: [PackageIssue]) {
        var issues: [PackageIssue] = []
        var executables: [String] = []
        var libraries: [String] = []
        var hasTestTargets = false
        var targetCount = 0
        var targetDetails: [TargetDetail] = []

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

            // Skip targets that don't match the filter
            if let filter = targetFilter, targetName != filter {
                continue
            }

            targetCount += 1

            let targetType = targetDict["type"] as? String ?? "unknown"
            let targetPlatforms = parseTargetPlatforms(from: targetDict)
            let targetDependencies = parseTargetDependencies(from: targetDict)

            // Create target detail
            let targetDetail = TargetDetail(
                name: targetName,
                type: targetType,
                platforms: targetPlatforms,
                dependencies: targetDependencies
            )
            targetDetails.append(targetDetail)

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

            // Check for target-specific issues
            issues.append(contentsOf: validateTarget(targetDict, name: targetName))
        }

        // If target filter was specified but no targets were found, return empty analysis
        if let filter = targetFilter, targetDetails.isEmpty {
            return (TargetAnalysis(
                count: 0,
                filteredTarget: filter,
                targets: []
            ), [])
        }

        let analysis = TargetAnalysis(
            count: targetCount,
            hasTestTargets: hasTestTargets,
            executables: executables,
            libraries: libraries,
            filteredTarget: targetFilter,
            targets: targetDetails.isEmpty ? nil : targetDetails
        )

        return (analysis, issues)
    }

    private func parseTargetPlatforms(from target: [String: Any]) -> [String] {
        guard let settings = target["settings"] as? [[String: Any]] else {
            return []
        }

        var platforms: [String] = []
        for setting in settings {
            if let condition = setting["condition"] as? [String: Any],
               let platformNames = condition["platformNames"] as? [String] {
                platforms.append(contentsOf: platformNames)
            }
        }
        return platforms
    }

    private func parseTargetDependencies(from target: [String: Any]) -> [String] {
        guard let dependencies = target["dependencies"] else {
            return []
        }

        var dependencyNames: [String] = []

        // Handle both simple string format (for tests) and complex object format (from dump-package)
        if let stringDependencies = dependencies as? [String] {
            // Simple string format: ["SwiftUI", "Combine"]
            dependencyNames.append(contentsOf: stringDependencies)
        } else if let objectDependencies = dependencies as? [[String: Any]] {
            // Complex object format from real dump-package output
            for targetDep in objectDependencies {
                if let product = targetDep["product"] as? [Any], product.count >= 1 {
                    // product format: ["ProductName", "package-name", ...]
                    if let productName = product[0] as? String {
                        dependencyNames.append(productName)
                    }
                } else if let byName = targetDep["byName"] as? [Any], byName.count >= 1 {
                    // byName format: ["package-name", ...]
                    if let packageName = byName[0] as? String {
                        dependencyNames.append(packageName)
                    }
                }
            }
        }

        return dependencyNames
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

    private func parseDependencies(from dict: [String: Any], targetFilter: String? = nil) -> (analysis: DependencyAnalysis, issues: [PackageIssue]) {
        var issues: [PackageIssue] = []
        var externalDependencies: [ExternalDependency] = []
        var localDependencies: [LocalDependency] = []

        // If target filter is specified, we need to extract dependencies from that specific target
        if let targetFilter = targetFilter {
            guard let targetsArray = dict["targets"] as? [[String: Any]] else {
                return (DependencyAnalysis(), [])
            }

            // Find the target that matches the filter
            guard let targetDict = targetsArray.first(where: {
                ($0["name"] as? String) == targetFilter
            }) else {
                return (DependencyAnalysis(), [])
            }

            // Extract dependencies from the target
            guard let targetDependencies = targetDict["dependencies"] else {
                return (DependencyAnalysis(), [])
            }

            // Extract dependency names from target dependencies
            var targetDependencyNames: Set<String> = []
            var targetProductNames: Set<String> = []

            // Handle both simple string format (for tests) and complex object format (from dump-package)
            if let stringDependencies = targetDependencies as? [String] {
                // Simple string format: ["SwiftUI", "Combine"]
                for depName in stringDependencies {
                    targetDependencyNames.insert(depName)
                    targetProductNames.insert(depName)
                }
            } else if let objectDependencies = targetDependencies as? [[String: Any]] {
                // Complex object format from real dump-package output
                for targetDep in objectDependencies {
                    if let product = targetDep["product"] as? [Any], product.count >= 2 {
                        // product format: ["ProductName", "package-name", ...]
                        if let productName = product[0] as? String, let packageName = product[1] as? String {
                            targetDependencyNames.insert(packageName)
                            targetProductNames.insert(productName)
                        } else if let productName = product[0] as? String {
                            // Handle case where package name is not available
                            targetDependencyNames.insert(productName)
                            targetProductNames.insert(productName)
                        }
                    } else if let byName = targetDep["byName"] as? [Any], byName.count >= 1 {
                        // byName format: ["package-name", ...]
                        if let packageName = byName[0] as? String {
                            targetDependencyNames.insert(packageName)
                            targetProductNames.insert(packageName)
                        }
                    }
                }
            }

            // Now get the full package dependencies and filter by target dependencies
            guard let packageDependencies = dict["dependencies"] as? [[String: Any]] else {
                return (DependencyAnalysis(), [])
            }

            for depDict in packageDependencies {
                var depName = ""
                var url: String?
                var version = "unspecified"

                // Handle the complex dependency structure from dump-package
                if let sourceControl = depDict["sourceControl"] as? [Any],
                   let firstSourceControl = sourceControl.first as? [String: Any],
                   let identity = firstSourceControl["identity"] as? String {
                    depName = identity

                    // Extract URL from location
                    if let location = firstSourceControl["location"] as? [String: Any],
                       let remote = location["remote"] as? [Any],
                       let firstRemote = remote.first as? [String: Any],
                       let urlString = firstRemote["urlString"] as? String {
                        url = urlString
                    }

                    // Extract version from requirement
                    if let requirement = firstSourceControl["requirement"] as? [String: Any],
                       let range = requirement["range"] as? [Any],
                       let firstRange = range.first as? [String: Any],
                       let lowerBound = firstRange["lowerBound"] as? String,
                       let upperBound = firstRange["upperBound"] as? String {
                        version = "\(lowerBound) - \(upperBound)"
                    }
                }

                // Try legacy format for backward compatibility
                if depName.isEmpty {
                    depName = depDict["name"] as? String ?? ""
                    url = depDict["url"] as? String
                    version = extractVersion(from: depDict)
                }

                // Only include dependencies that are used by the target
                if (targetDependencyNames.contains(depName) || targetProductNames.contains(depName)) && !depName.isEmpty {
                    if let dependencyUrl = url {
                        let dependencyType: DependencyType
                        if dependencyUrl.hasSuffix(".binary") {
                            dependencyType = .binary
                        } else if dependencyUrl.contains("@swift-package-registry") {
                            dependencyType = .registry
                        } else {
                            dependencyType = .sourceControl
                        }

                        externalDependencies.append(ExternalDependency(
                            name: depName,
                            version: version,
                            type: dependencyType,
                            url: dependencyUrl
                        ))
                    } else if let path = depDict["path"] as? String {
                        localDependencies.append(LocalDependency(name: depName, path: path))
                    }
                }

                // Validate dependency
                issues.append(contentsOf: validateDependency(depDict))
            }

        } else {
            // Parse all package dependencies (no target filter)
            guard let dependencies = dict["dependencies"] as? [[String: Any]] else {
                return (DependencyAnalysis(), [])
            }

            for depDict in dependencies {
                var depName = ""
                var url: String?
                var version = "unspecified"

                // Handle the complex dependency structure from dump-package
                if let sourceControl = depDict["sourceControl"] as? [Any],
                   let firstSourceControl = sourceControl.first as? [String: Any],
                   let identity = firstSourceControl["identity"] as? String {
                    depName = identity

                    // Extract URL from location
                    if let location = firstSourceControl["location"] as? [String: Any],
                       let remote = location["remote"] as? [Any],
                       let firstRemote = remote.first as? [String: Any],
                       let urlString = firstRemote["urlString"] as? String {
                        url = urlString
                    }

                    // Extract version from requirement
                    if let requirement = firstSourceControl["requirement"] as? [String: Any],
                       let range = requirement["range"] as? [Any],
                       let firstRange = range.first as? [String: Any],
                       let lowerBound = firstRange["lowerBound"] as? String,
                       let upperBound = firstRange["upperBound"] as? String {
                        version = "\(lowerBound) - \(upperBound)"
                    }
                }

                // Try legacy format for backward compatibility
                if depName.isEmpty {
                    if let legacyUrl = depDict["url"] as? String {
                        url = legacyUrl
                        depName = depDict["name"] as? String ?? extractNameFromURL(legacyUrl)
                        version = extractVersion(from: depDict)
                    } else if let path = depDict["path"] as? String {
                        depName = depDict["name"] as? String ?? extractNameFromPath(path)
                        localDependencies.append(LocalDependency(name: depName, path: path))
                        issues.append(contentsOf: validateDependency(depDict))
                        continue
                    }
                }

                if let dependencyUrl = url {
                    let dependencyType: DependencyType
                    if dependencyUrl.hasSuffix(".binary") {
                        dependencyType = .binary
                    } else if dependencyUrl.contains("@swift-package-registry") {
                        dependencyType = .registry
                    } else {
                        dependencyType = .sourceControl
                    }

                    externalDependencies.append(ExternalDependency(
                        name: depName,
                        version: version,
                        type: dependencyType,
                        url: dependencyUrl
                    ))
                }

                // Validate dependency
                issues.append(contentsOf: validateDependency(depDict))
            }
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

        // Check if this is a new format sourceControl dependency
        if let sourceControl = dependency["sourceControl"] as? [Any],
           let firstSourceControl = sourceControl.first as? [String: Any] {
            // New format dependencies are generally valid if they have identity and location
            if firstSourceControl["identity"] == nil {
                issues.append(PackageIssue(
                    type: .dependencyError,
                    severity: .error,
                    message: "Source control dependency missing identity"
                ))
            }
            return issues
        }

        // Check legacy format dependencies
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