import Testing
@testable import spmsift

@Suite("Dump Package Parser Tests")
struct DumpPackageParserTests {
    let parser = DumpPackageParser()

    @Test("Parser correctly handles simple package structure")
    func parseSimplePackage() throws {
        let input = """
        {
            "name": "TestPackage",
            "platforms": {
                "iOS": "15.0",
                "macOS": "12.0"
            },
            "targets": [
                {
                    "name": "TestTarget",
                    "type": "executable",
                    "dependencies": []
                }
            ],
            "dependencies": [],
            "products": [
                {
                    "name": "test",
                    "type": "executable"
                }
            ]
        }
        """

        let result = try parser.parse(input)

        #expect(result.command == .dumpPackage)
        #expect(result.success)
        #expect(result.targets?.count == 1)
        #expect(result.targets?.executables.count == 1)
        #expect(result.dependencies?.count == 0)
        #expect(result.issues.count == 0)
    }

    @Test("Parser extracts dependency information correctly")
    func parsePackageWithDependencies() throws {
        let input = """
        {
            "name": "TestPackage",
            "targets": [
                {
                    "name": "TestTarget",
                    "type": "library",
                    "dependencies": ["TCA", "SwiftUI"]
                }
            ],
            "dependencies": [
                {
                    "name": "swift-composable-architecture",
                    "url": "https://github.com/pointfreeco/swift-composable-architecture",
                    "requirement": {
                        "range": [
                            "1.0.0",
                            "2.0.0"
                        ]
                    }
                }
            ]
        }
        """

        let result = try parser.parse(input)

        #expect(result.targets?.count == 1)
        #expect(result.dependencies?.count == 1)
        #expect(result.dependencies?.external.first?.name == "swift-composable-architecture")
        #expect(result.dependencies?.external.first?.version == "1.0.0, 2.0.0")
    }

    @Test("Parser identifies test targets correctly")
    func parsePackageWithTestTargets() throws {
        let input = """
        {
            "name": "TestPackage",
            "targets": [
                {
                    "name": "TestTarget",
                    "type": "executable"
                },
                {
                    "name": "TestTargetTests",
                    "type": "test"
                }
            ]
        }
        """

        let result = try parser.parse(input)

        #expect(result.targets?.count == 2)
        #expect(result.targets?.hasTestTargets == true)
    }

    @Test("Parser gracefully handles invalid JSON input")
    func parseInvalidJSON() throws {
        let input = "invalid json"

        let result = try parser.parse(input)

        #expect(result.command == .dumpPackage)
        #expect(!result.success)
        #expect(result.issues.count > 0)
        #expect(result.issues.first?.type == .syntaxError)
        #expect(result.issues.first?.severity == .error)
    }

    @Test("Parser provides appropriate warnings for minimal packages")
    func parseEmptyPackage() throws {
        let input = """
        {
            "name": "EmptyPackage"
        }
        """

        let result = try parser.parse(input)

        #expect(result.command == .dumpPackage)
        #expect(result.success) // Empty package is still valid
        #expect(result.targets?.count == 0)
        #expect(result.dependencies?.count == 0)
        // Should have a warning about no products
        #expect(result.issues.contains { $0.type == .missingTarget })
    }
}