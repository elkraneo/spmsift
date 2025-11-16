import ArgumentParser
import Foundation

@main
struct SPMSift: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Context-efficient Swift Package Manager analysis tool",
        discussion: """
        spmsift converts verbose Swift Package Manager output into structured,
        minimal-context JSON designed for Claude agents and AI development workflows.

        Examples:
          swift package dump-package | spmsift
          swift package show-dependencies | spmsift --format summary
          swift package resolve | spmsift --format detailed
        """,
        version: "1.0.0"
    )

    @Option(name: .shortAndLong, help: "Output format (json, summary, detailed)")
    var format: OutputFormat = .json

    @Option(name: .long, help: "Minimum issue severity to include (info, warning, error, critical)")
    var severity: Severity = .info

    @Flag(name: .shortAndLong, help: "Include raw output for debugging")
    var verbose: Bool = false

    @Flag(name: .long, help: "Enable performance metrics")
    var metrics: Bool = false

    mutating func run() throws {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Read from stdin if piped, otherwise exit with help
        if isatty(STDIN_FILENO) != 0 {
            print("spmsift: No input detected. Pipe Swift Package Manager output to spmsift.")
            print("Usage: swift package <command> | spmsift")
            throw ExitCode.failure
        }

        let input = FileHandle.standardInput.readDataToEndOfFile()
        let output = String(data: input, encoding: .utf8) ?? ""

        guard !output.isEmpty else {
            print("{\"error\": \"No input received\"}")
            throw ExitCode.failure
        }

        let parseStartTime = CFAbsoluteTimeGetCurrent()
        let result = try parseInput(output)
        let parseEndTime = CFAbsoluteTimeGetCurrent()

        // Add metrics if requested
        var finalResult = result
        if metrics {
            finalResult.metrics = PackageMetrics(
                parseTime: parseEndTime - parseStartTime,
                complexity: determineComplexity(from: result),
                estimatedIndexTime: estimateIndexTime(from: result)
            )
        }

        // Filter issues by severity
        let filteredIssues = filterIssues(finalResult.issues, minSeverity: severity)
        var filteredResult = finalResult
        filteredResult.issues = filteredIssues

        // Add raw output if verbose
        if verbose {
            filteredResult.rawOutput = output
        }

        // Output based on format
        switch format {
        case .json:
            try outputJSON(filteredResult)
        case .summary:
            try outputSummary(filteredResult)
        case .detailed:
            try outputDetailed(filteredResult)
        }

        // Return appropriate exit code
        // Exit 0 for analysis success, 1 only for tool failures
        throw ExitCode.success
    }

    private func parseInput(_ input: String) throws -> PackageAnalysis {
        let commandType = CommandDetector.detectCommandType(from: input)
        let hasError = CommandDetector.hasErrorOutput(input)

        if hasError {
            let errors = CommandDetector.extractErrorMessages(from: input)
            return PackageAnalysis(
                command: commandType,
                success: false,
                issues: errors.map { PackageIssue(type: .unknown, severity: .error, message: $0) }
            )
        }

        switch commandType {
        case .dumpPackage:
            return try DumpPackageParser().parse(input)
        case .showDependencies:
            return try ShowDependenciesParser().parse(input)
        case .resolve:
            return try ResolveParser().parse(input)
        case .describe:
            return try DescribeParser().parse(input)
        case .update:
            return try UpdateParser().parse(input)
        case .unknown:
            return PackageAnalysis(
                command: .unknown,
                success: false,
                issues: [PackageIssue(type: .unknown, severity: .warning, message: "Unknown command output format")]
            )
        }
    }

    private func outputJSON(_ result: PackageAnalysis) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(result)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func outputSummary(_ result: PackageAnalysis) throws {
        var summary: [String: Any] = [
            "command": result.command.rawValue,
            "success": result.success
        ]

        if let targets = result.targets {
            summary["targets"] = targets.count
        }

        if let dependencies = result.dependencies {
            summary["dependencies"] = dependencies.count
        }

        if !result.issues.isEmpty {
            summary["issues"] = result.issues.count
        }

        let jsonData = try JSONSerialization.data(withJSONObject: summary, options: .prettyPrinted)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func outputDetailed(_ result: PackageAnalysis) throws {
        // Similar to JSON but with more context
        try outputJSON(result)
    }

    private func filterIssues(_ issues: [PackageIssue], minSeverity: Severity) -> [PackageIssue] {
        let severityOrder: [Severity] = [.info, .warning, .error, .critical]
        guard let minIndex = severityOrder.firstIndex(of: minSeverity) else {
            return issues
        }

        return issues.filter { issue in
            guard let issueIndex = severityOrder.firstIndex(of: issue.severity) else {
                return false
            }
            return issueIndex >= minIndex
        }
    }

    private func determineComplexity(from result: PackageAnalysis) -> ComplexityLevel {
        let targetCount = result.targets?.count ?? 0
        let dependencyCount = result.dependencies?.count ?? 0
        let issueCount = result.issues.count

        switch (targetCount, dependencyCount, issueCount) {
        case (0...10, 0...5, 0...2):
            return .low
        case (11...30, 6...15, 3...10):
            return .medium
        case (_, _, _):
            return .high
        }
    }

    private func estimateIndexTime(from result: PackageAnalysis) -> String {
        let targetCount = result.targets?.count ?? 0
        let dependencyCount = result.dependencies?.count ?? 0
        let complexity = targetCount + dependencyCount * 2

        if complexity < 20 {
            return "5-15s"
        } else if complexity < 50 {
            return "15-45s"
        } else if complexity < 100 {
            return "45-90s"
        } else {
            return "90s+"
        }
    }
}
