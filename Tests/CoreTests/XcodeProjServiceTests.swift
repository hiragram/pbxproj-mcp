import XCTest
@testable import Core

final class XcodeProjServiceTests: XCTestCase {

    var service: XcodeProjService!
    var fixtureProjectPath: String!

    override func setUp() async throws {
        service = XcodeProjService()
        // Get path to fixture project
        let bundle = Bundle.module
        guard let fixturePath = bundle.path(forResource: "TestProject", ofType: "xcodeproj", inDirectory: "Fixtures") else {
            XCTFail("Fixture project not found")
            return
        }
        fixtureProjectPath = fixturePath
    }

    // MARK: - Read Operations Tests

    func testGetProjectInfo() async throws {
        let result = try await service.getProjectInfo(projectPath: fixtureProjectPath)

        // Parse JSON result
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["name"] as? String, "TestProject")
        XCTAssertEqual(json["targetCount"] as? Int, 1)

        let targets = json["targets"] as? [String]
        XCTAssertEqual(targets, ["TestApp"])

        let configurations = json["configurations"] as? [String]
        XCTAssertEqual(Set(configurations ?? []), Set(["Debug", "Release"]))
    }

    func testListTargets() async throws {
        let result = try await service.listTargets(projectPath: fixtureProjectPath)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let targets = json["targets"] as? [[String: Any]]
        XCTAssertEqual(targets?.count, 1)

        let firstTarget = targets?.first
        XCTAssertEqual(firstTarget?["name"] as? String, "TestApp")
        XCTAssertEqual(firstTarget?["type"] as? String, "native")
        XCTAssertEqual(firstTarget?["productType"] as? String, "com.apple.product-type.application")
    }

    func testGetTargetInfo() async throws {
        let result = try await service.getTargetInfo(projectPath: fixtureProjectPath, targetName: "TestApp")

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["name"] as? String, "TestApp")
        XCTAssertEqual(json["productType"] as? String, "com.apple.product-type.application")

        let buildPhases = json["buildPhases"] as? [[String: Any]]
        XCTAssertNotNil(buildPhases)
        XCTAssertGreaterThanOrEqual(buildPhases?.count ?? 0, 3) // Sources, Frameworks, Resources

        let configurations = json["configurations"] as? [String]
        XCTAssertEqual(Set(configurations ?? []), Set(["Debug", "Release"]))
    }

    func testGetTargetInfoNotFound() async throws {
        do {
            _ = try await service.getTargetInfo(projectPath: fixtureProjectPath, targetName: "NonExistentTarget")
            XCTFail("Should throw error for non-existent target")
        } catch let error as XcodeProjServiceError {
            if case .targetNotFound(let name) = error {
                XCTAssertEqual(name, "NonExistentTarget")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testListFiles() async throws {
        let result = try await service.listFiles(projectPath: fixtureProjectPath, groupPath: nil)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let files = json["files"] as? [[String: Any]]
        XCTAssertNotNil(files)
        XCTAssertGreaterThan(files?.count ?? 0, 0)

        // Check that expected files exist
        let fileNames = files?.compactMap { $0["path"] as? String } ?? []
        XCTAssertTrue(fileNames.contains("AppDelegate.swift"))
        XCTAssertTrue(fileNames.contains("ContentView.swift"))
    }

    func testListFilesInGroupNotFound() async throws {
        // Test that querying a non-existent group throws appropriate error
        do {
            _ = try await service.listFiles(projectPath: fixtureProjectPath, groupPath: "NonExistentGroup")
            XCTFail("Should throw error for non-existent group")
        } catch let error as XcodeProjServiceError {
            if case .groupNotFound(let path) = error {
                XCTAssertEqual(path, "NonExistentGroup")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testListConfigurations() async throws {
        let result = try await service.listConfigurations(projectPath: fixtureProjectPath)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let configurations = json["configurations"] as? [[String: Any]]
        XCTAssertEqual(configurations?.count, 2)

        let configNames = configurations?.compactMap { $0["name"] as? String } ?? []
        XCTAssertTrue(configNames.contains("Debug"))
        XCTAssertTrue(configNames.contains("Release"))

        XCTAssertEqual(json["defaultConfiguration"] as? String, "Release")
    }

    func testGetBuildSettings() async throws {
        // Get project-level settings
        let projectResult = try await service.getBuildSettings(projectPath: fixtureProjectPath, targetName: nil, configurationName: "Debug")

        let projectData = projectResult.data(using: .utf8)!
        let projectJson = try JSONSerialization.jsonObject(with: projectData) as! [String: Any]

        let debugSettings = projectJson["Debug"] as? [String: Any]
        XCTAssertNotNil(debugSettings)
        XCTAssertEqual(debugSettings?["SWIFT_VERSION"] as? String, "5.0")

        // Get target-level settings
        let targetResult = try await service.getBuildSettings(projectPath: fixtureProjectPath, targetName: "TestApp", configurationName: nil)

        let targetData = targetResult.data(using: .utf8)!
        let targetJson = try JSONSerialization.jsonObject(with: targetData) as! [String: Any]

        XCTAssertNotNil(targetJson["Debug"])
        XCTAssertNotNil(targetJson["Release"])

        let targetDebugSettings = targetJson["Debug"] as? [String: Any]
        XCTAssertEqual(targetDebugSettings?["PRODUCT_BUNDLE_IDENTIFIER"] as? String, "com.example.TestApp")
    }

    func testListBuildPhases() async throws {
        let result = try await service.listBuildPhases(projectPath: fixtureProjectPath, targetName: "TestApp")

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let phases = json["buildPhases"] as? [[String: Any]]
        XCTAssertNotNil(phases)
        XCTAssertGreaterThanOrEqual(phases?.count ?? 0, 3)

        // Check for expected phase types
        let phaseTypes = phases?.compactMap { $0["type"] as? String } ?? []
        XCTAssertTrue(phaseTypes.contains("Sources"))
        XCTAssertTrue(phaseTypes.contains("Frameworks"))
        XCTAssertTrue(phaseTypes.contains("Resources"))
    }

    func testListPackages() async throws {
        let result = try await service.listPackages(projectPath: fixtureProjectPath)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let packages = json["packages"] as? [[String: Any]]
        XCTAssertNotNil(packages)
        // Our fixture has no packages, so count should be 0
        XCTAssertEqual(packages?.count, 0)
    }

    func testListSchemes() async throws {
        let result = try await service.listSchemes(projectPath: fixtureProjectPath)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let schemes = json["schemes"] as? [[String: Any]]
        XCTAssertNotNil(schemes)
        // Our fixture may not have shared schemes, just checking structure
    }

    func testListGroups() async throws {
        let result = try await service.listGroups(projectPath: fixtureProjectPath, parentPath: nil)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let groups = json["groups"] as? [[String: Any]]
        XCTAssertNotNil(groups)
        XCTAssertGreaterThan(groups?.count ?? 0, 0)

        // Check that TestApp group exists
        let groupNames = groups?.compactMap { $0["name"] as? String } ?? []
        XCTAssertTrue(groupNames.contains("TestApp"))
    }

    func testGetBuildPhaseFiles() async throws {
        let result = try await service.getBuildPhaseFiles(projectPath: fixtureProjectPath, targetName: "TestApp", phaseType: "sources")

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["phaseType"] as? String, "sources")
        XCTAssertEqual(json["fileCount"] as? Int, 2)

        let files = json["files"] as? [[String: Any]]
        let filePaths = files?.compactMap { $0["path"] as? String } ?? []
        XCTAssertTrue(filePaths.contains("AppDelegate.swift"))
        XCTAssertTrue(filePaths.contains("ContentView.swift"))
    }

    // MARK: - Error Handling Tests

    func testProjectNotFound() async throws {
        do {
            _ = try await service.getProjectInfo(projectPath: "/nonexistent/path/Project.xcodeproj")
            XCTFail("Should throw error for non-existent project")
        } catch {
            // Expected - XcodeProj throws its own error for non-existent path
            XCTAssertNotNil(error)
        }
    }

    func testGroupNotFound() async throws {
        do {
            _ = try await service.listFiles(projectPath: fixtureProjectPath, groupPath: "NonExistentGroup")
            XCTFail("Should throw error for non-existent group")
        } catch let error as XcodeProjServiceError {
            if case .groupNotFound(let path) = error {
                XCTAssertEqual(path, "NonExistentGroup")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - getSchemeInfo Tests

    func testGetSchemeInfoNotFound() async throws {
        // Our fixture doesn't have shared schemes, so this tests error handling
        do {
            _ = try await service.getSchemeInfo(projectPath: fixtureProjectPath, schemeName: "NonExistentScheme")
            XCTFail("Should throw error for non-existent scheme")
        } catch let error as XcodeProjServiceError {
            if case .configurationNotFound(let msg) = error {
                XCTAssertTrue(msg.contains("NonExistentScheme"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
