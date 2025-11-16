import Testing
@testable import spmsift

@Suite("SPMSift Core Tests")
struct SPMSiftTests {
    @Test("Command detector correctly identifies different Swift package commands")
    func commandDetector() {
        // Test dump-package detection
        let dumpPackageOutput = """
        {
          "name": "ExamplePackage",
          "targets": [
            {"name": "ExampleTarget", "type": "executable"}
          ]
        }
        """
        #expect(CommandDetector.detectCommandType(from: dumpPackageOutput) == .dumpPackage)

        // Test show-dependencies detection
        let showDepsOutput = """
        Dependencies:
        ├─ SomeDependency (1.2.3)
        └─ AnotherDependency (4.5.6)
        """
        #expect(CommandDetector.detectCommandType(from: showDepsOutput) == .showDependencies)

        // Test resolve detection
        let resolveOutput = """
        Resolving dependencies...
        Fetching https://github.com/example/repo.git
        Resolved
        """
        #expect(CommandDetector.detectCommandType(from: resolveOutput) == .resolve)
    }

    @Test("Error detection correctly identifies and extracts error messages")
    func errorDetection() {
        let errorOutput = """
        error: Invalid package manifest
        warning: Deprecated syntax
        """
        #expect(CommandDetector.hasErrorOutput(errorOutput))

        let errors = CommandDetector.extractErrorMessages(from: errorOutput)
        #expect(errors.count == 1)
        #expect(errors.first?.contains("Invalid package manifest") == true)
    }
}