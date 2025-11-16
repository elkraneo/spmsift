import Testing
@testable import spmsift

@Suite("Show Dependencies Parser Tests")
struct ShowDependenciesParserTests {
    let parser = ShowDependenciesParser()

    @Test("Parser correctly extracts simple dependency tree")
    func parseSimpleDependencies() throws {
        let input = """
        Dependencies:
        ├─ SomeDependency (1.2.3)
        └─ AnotherDependency (4.5.6)
        """

        let result = try parser.parse(input)

        #expect(result.command == .showDependencies)
        #expect(result.success)
        #expect(result.dependencies?.count == 2)
        #expect(result.dependencies?.external.map { $0.name }.sorted() == ["AnotherDependency", "SomeDependency"])
    }

    @Test("Parser handles various version and dependency formats")
    func parseVersionFormats() throws {
        let input = """
        Dependencies:
        ├─ SwiftComposableArchitecture@1.23.1
        ├─ SQLiteData [local]
        └─ Foundation (built-in)
        """

        let result = try parser.parse(input)

        #expect(result.dependencies?.count == 3)

        let tcaDep = result.dependencies?.external.first { $0.name == "SwiftComposableArchitecture" }
        #expect(tcaDep?.version == "1.23.1")
        #expect(tcaDep?.type == .registry)

        // SQLiteData might be parsed as external with [local] in version
        let sqliteDep = result.dependencies?.external.first { $0.name.contains("SQLiteData") }
        #expect(sqliteDep != nil)

        // Check for Foundation dependency
        let foundationDep = result.dependencies?.external.first { $0.name.contains("Foundation") }
        #expect(foundationDep != nil)
    }

    @Test("Parser correctly handles nested dependency trees")
    func parseComplexTree() throws {
        let input = """
        Dependencies:
        ├─ MainDependency (1.0.0)
        │  ├─ SubDependency1 (2.0.0)
        │  └─ SubDependency2 (3.0.0)
        └─ AnotherMain (4.0.0)
        """

        let result = try parser.parse(input)

        #expect(result.dependencies?.count == 4)
        let names = result.dependencies?.external.map { $0.name }.sorted()
        #expect(names == ["AnotherMain", "MainDependency", "SubDependency1", "SubDependency2"])
    }

    @Test("Parser detects and reports errors while continuing processing")
    func parseWithErrors() throws {
        let input = """
        Dependencies:
        error: Failed to resolve dependency ConflictingDep
        ├─ ValidDep (1.0.0)
        warning: Some dependency has version conflicts
        """

        let result = try parser.parse(input)

        // Should have issues detected
        #expect(result.issues.count > 0)
        #expect(result.issues.contains { $0.type == .dependencyError })

        // Should still parse the valid dependency
        #expect(result.dependencies?.count == 1)

        // Success should be false due to errors
        #expect(result.success == false)
    }

    @Test("Parser correctly handles packages with no dependencies")
    func parseNoDependencies() throws {
        let input = """
        Dependencies:
        No dependencies
        """

        let result = try parser.parse(input)

        #expect(result.dependencies?.count == 0)
        #expect(result.success)
    }

    @Test("Parser identifies version conflicts in dependencies")
    func detectVersionConflicts() throws {
        let input = """
        Dependencies:
        ├─ ConflictingDep (1.0.0)
        └─ ConflictingDep (2.0.0)
        """

        let result = try parser.parse(input)

        #expect(result.dependencies?.count == 2)
        let versionConflicts = result.issues.filter { $0.type == .versionConflict }
        #expect(versionConflicts.count > 0)
        #expect(versionConflicts.first?.message.contains("Multiple versions") == true)
    }
}