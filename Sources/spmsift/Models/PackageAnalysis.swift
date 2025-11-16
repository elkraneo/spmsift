import Foundation
import ArgumentParser

// MARK: - Core Output Models
public struct PackageAnalysis: Codable {
    public let command: SwiftPackageCommand
    public let success: Bool
    public let targets: TargetAnalysis?
    public let dependencies: DependencyAnalysis?
    public internal(set) var issues: [PackageIssue]
    public internal(set) var metrics: PackageMetrics
    public internal(set) var rawOutput: String?

    public init(
        command: SwiftPackageCommand,
        success: Bool,
        targets: TargetAnalysis? = nil,
        dependencies: DependencyAnalysis? = nil,
        issues: [PackageIssue] = [],
        metrics: PackageMetrics = PackageMetrics(),
        rawOutput: String? = nil
    ) {
        self.command = command
        self.success = success
        self.targets = targets
        self.dependencies = dependencies
        self.issues = issues
        self.metrics = metrics
        self.rawOutput = rawOutput
    }
}

public struct TargetAnalysis: Codable {
    public let count: Int
    public let hasTestTargets: Bool
    public let platforms: [String]
    public let executables: [String]
    public let libraries: [String]

    public init(count: Int, hasTestTargets: Bool = false, platforms: [String] = [], executables: [String] = [], libraries: [String] = []) {
        self.count = count
        self.hasTestTargets = hasTestTargets
        self.platforms = platforms
        self.executables = executables
        self.libraries = libraries
    }
}

public struct DependencyAnalysis: Codable {
    public let count: Int
    public let external: [ExternalDependency]
    public let local: [LocalDependency]
    public let circularImports: Bool
    public let versionConflicts: [VersionConflict]

    public init(
        count: Int = 0,
        external: [ExternalDependency] = [],
        local: [LocalDependency] = [],
        circularImports: Bool = false,
        versionConflicts: [VersionConflict] = []
    ) {
        self.count = count
        self.external = external
        self.local = local
        self.circularImports = circularImports
        self.versionConflicts = versionConflicts
    }
}

public struct ExternalDependency: Codable {
    public let name: String
    public let version: String
    public let type: DependencyType
    public let url: String?

    public init(name: String, version: String, type: DependencyType, url: String? = nil) {
        self.name = name
        self.version = version
        self.type = type
        self.url = url
    }
}

public struct LocalDependency: Codable {
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public struct VersionConflict: Codable {
    public let dependency: String
    public let requiredVersions: [String]

    public init(dependency: String, requiredVersions: [String]) {
        self.dependency = dependency
        self.requiredVersions = requiredVersions
    }
}

public struct PackageIssue: Codable {
    public let type: IssueType
    public let severity: Severity
    public let target: String?
    public let message: String
    public let line: Int?

    public init(type: IssueType, severity: Severity, target: String? = nil, message: String, line: Int? = nil) {
        self.type = type
        self.severity = severity
        self.target = target
        self.message = message
        self.line = line
    }
}

public struct PackageMetrics: Codable {
    public let parseTime: TimeInterval
    public let complexity: ComplexityLevel
    public let estimatedIndexTime: String?

    public init(parseTime: TimeInterval = 0.0, complexity: ComplexityLevel = .unknown, estimatedIndexTime: String? = nil) {
        self.parseTime = parseTime
        self.complexity = complexity
        self.estimatedIndexTime = estimatedIndexTime
    }
}

// MARK: - Enums
public enum SwiftPackageCommand: String, Codable, CaseIterable {
    case dumpPackage = "dump-package"
    case showDependencies = "show-dependencies"
    case resolve = "resolve"
    case describe = "describe"
    case update = "update"
    case unknown = "unknown"
}

public enum DependencyType: String, Codable {
    case sourceControl = "source-control"
    case binary = "binary"
    case registry = "registry"
}

public enum IssueType: String, Codable {
    case circularImport = "circular_import"
    case missingTarget = "missing_target"
    case versionConflict = "version_conflict"
    case platformMismatch = "platform_mismatch"
    case syntaxError = "syntax_error"
    case dependencyError = "dependency_error"
    case networkError = "network_error"
    case unknown = "unknown"
}

public enum Severity: String, Codable, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

extension Severity: ExpressibleByArgument {}

public enum ComplexityLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case unknown = "unknown"
}

// MARK: - Output Format
public enum OutputFormat: String, CaseIterable {
    case json = "json"
    case summary = "summary"
    case detailed = "detailed"
}

extension OutputFormat: ExpressibleByArgument {}