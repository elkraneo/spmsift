import Foundation

public struct CommandDetector {

    public static func detectCommandType(from output: String) -> SwiftPackageCommand {
        let output = output.lowercased()

        // Check for dump-package output (JSON format)
        if output.contains("\"name\"") && output.contains("\"targets\"") {
            return .dumpPackage
        }

        // Check for show-dependencies output (tree format)
        if output.contains("├─") || output.contains("└─") || output.contains("│") {
            return .showDependencies
        }

        // Check for resolve output
        if output.contains("resolving") || output.contains("fetching") ||
           output.contains("resolved") || output.contains("updating") {
            return .resolve
        }

        // Check for describe output
        if output.contains("package name:") || output.contains("package version:") {
            return .describe
        }

        // Check for update output
        if output.contains("updating") || output.contains("updated") ||
           output.contains("checking out") {
            return .update
        }

        return .unknown
    }

    public static func hasErrorOutput(_ output: String) -> Bool {
        let output = output.lowercased()
        return output.contains("error:") ||
               output.contains("failed") ||
               output.contains("cannot") ||
               output.contains("unable to") ||
               output.contains("invalid")
    }

    public static func extractErrorMessages(from output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var errors: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().contains("error:") ||
               trimmed.lowercased().hasPrefix("error") {
                errors.append(trimmed)
            }
        }

        return errors
    }
}