import XCTest
import Foundation
@testable import Core

final class XcodeProjServiceWriteTests: XCTestCase {

    var service: XcodeProjService!
    var tempProjectPath: String!
    var tempDirectory: URL!

    override func setUp() async throws {
        service = XcodeProjService()

        // Create temp directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Copy fixture project to temp directory
        let bundle = Bundle.module
        guard let fixturePath = bundle.path(forResource: "TestProject", ofType: "xcodeproj", inDirectory: "Fixtures") else {
            XCTFail("Fixture project not found")
            return
        }

        let sourceURL = URL(fileURLWithPath: fixturePath)
        let destURL = tempDirectory.appendingPathComponent("TestProject.xcodeproj")
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        tempProjectPath = destURL.path
    }

    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - updateBuildSetting Tests

    func testUpdateBuildSettingAllConfigurations() async throws {
        // Update SWIFT_VERSION for all configurations
        let result = try await service.updateBuildSetting(
            projectPath: tempProjectPath,
            settingName: "SWIFT_VERSION",
            value: "6.0",
            targetName: "TestApp",
            configurationName: nil
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["settingName"] as? String, "SWIFT_VERSION")
        XCTAssertEqual(json["value"] as? String, "6.0")

        let updatedConfigs = json["updatedConfigurations"] as? [String] ?? []
        XCTAssertTrue(updatedConfigs.contains("Debug"))
        XCTAssertTrue(updatedConfigs.contains("Release"))

        // Verify the change was persisted
        let settingsResult = try await service.getBuildSettings(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            configurationName: nil
        )
        let settingsData = settingsResult.data(using: .utf8)!
        let settingsJson = try JSONSerialization.jsonObject(with: settingsData) as! [String: Any]

        let debugSettings = settingsJson["Debug"] as? [String: Any]
        XCTAssertEqual(debugSettings?["SWIFT_VERSION"] as? String, "6.0")

        let releaseSettings = settingsJson["Release"] as? [String: Any]
        XCTAssertEqual(releaseSettings?["SWIFT_VERSION"] as? String, "6.0")
    }

    func testUpdateBuildSettingSingleConfiguration() async throws {
        // Update only Debug configuration
        let result = try await service.updateBuildSetting(
            projectPath: tempProjectPath,
            settingName: "CUSTOM_SETTING",
            value: "debug_only_value",
            targetName: "TestApp",
            configurationName: "Debug"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        let updatedConfigs = json["updatedConfigurations"] as? [String] ?? []
        XCTAssertEqual(updatedConfigs, ["Debug"])

        // Verify Debug has the setting but Release doesn't
        let settingsResult = try await service.getBuildSettings(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            configurationName: nil
        )
        let settingsData = settingsResult.data(using: .utf8)!
        let settingsJson = try JSONSerialization.jsonObject(with: settingsData) as! [String: Any]

        let debugSettings = settingsJson["Debug"] as? [String: Any]
        XCTAssertEqual(debugSettings?["CUSTOM_SETTING"] as? String, "debug_only_value")

        let releaseSettings = settingsJson["Release"] as? [String: Any]
        XCTAssertNil(releaseSettings?["CUSTOM_SETTING"])
    }

    func testUpdateBuildSettingProjectLevel() async throws {
        // Update project-level setting (no target specified)
        let result = try await service.updateBuildSetting(
            projectPath: tempProjectPath,
            settingName: "PROJECT_SETTING",
            value: "project_value",
            targetName: nil,
            configurationName: nil
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)

        // Verify at project level
        let settingsResult = try await service.getBuildSettings(
            projectPath: tempProjectPath,
            targetName: nil,
            configurationName: nil
        )
        let settingsData = settingsResult.data(using: .utf8)!
        let settingsJson = try JSONSerialization.jsonObject(with: settingsData) as! [String: Any]

        let debugSettings = settingsJson["Debug"] as? [String: Any]
        XCTAssertEqual(debugSettings?["PROJECT_SETTING"] as? String, "project_value")
    }

    // MARK: - addGroup Tests

    func testAddGroup() async throws {
        let result = try await service.addGroup(
            projectPath: tempProjectPath,
            groupName: "NewGroup",
            parentPath: nil
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["groupName"] as? String, "NewGroup")
        XCTAssertEqual(json["path"] as? String, "NewGroup")

        // Verify the group was created
        let groupsResult = try await service.listGroups(projectPath: tempProjectPath, parentPath: nil)
        let groupsData = groupsResult.data(using: .utf8)!
        let groupsJson = try JSONSerialization.jsonObject(with: groupsData) as! [String: Any]

        let groups = groupsJson["groups"] as? [[String: Any]] ?? []
        let groupNames = groups.compactMap { $0["name"] as? String }
        XCTAssertTrue(groupNames.contains("NewGroup"))
    }

    func testAddNestedGroup() async throws {
        // First create parent group
        _ = try await service.addGroup(
            projectPath: tempProjectPath,
            groupName: "ParentGroup",
            parentPath: nil
        )

        // Then create nested group
        let result = try await service.addGroup(
            projectPath: tempProjectPath,
            groupName: "ChildGroup",
            parentPath: "ParentGroup"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["path"] as? String, "ParentGroup/ChildGroup")
    }

    // MARK: - addTarget Tests

    func testAddTarget() async throws {
        let result = try await service.addTarget(
            projectPath: tempProjectPath,
            targetName: "NewFramework",
            productType: "framework",
            bundleId: "com.example.NewFramework"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["targetName"] as? String, "NewFramework")
        XCTAssertEqual(json["productType"] as? String, "framework")

        // Verify target was created
        let targetsResult = try await service.listTargets(projectPath: tempProjectPath)
        let targetsData = targetsResult.data(using: .utf8)!
        let targetsJson = try JSONSerialization.jsonObject(with: targetsData) as! [String: Any]

        let targets = targetsJson["targets"] as? [[String: Any]] ?? []
        let targetNames = targets.compactMap { $0["name"] as? String }
        XCTAssertTrue(targetNames.contains("NewFramework"))

        // Verify target info
        let targetInfoResult = try await service.getTargetInfo(projectPath: tempProjectPath, targetName: "NewFramework")
        let targetInfoData = targetInfoResult.data(using: .utf8)!
        let targetInfoJson = try JSONSerialization.jsonObject(with: targetInfoData) as! [String: Any]

        XCTAssertEqual(targetInfoJson["name"] as? String, "NewFramework")
        XCTAssertEqual(targetInfoJson["productType"] as? String, "com.apple.product-type.framework")
    }

    func testAddTargetWithDifferentTypes() async throws {
        // Test various product types
        let productTypes = [
            ("TestLib", "staticLibrary"),
            ("TestTool", "commandLineTool"),
            ("TestBundle", "bundle")
        ]

        for (name, type) in productTypes {
            let result = try await service.addTarget(
                projectPath: tempProjectPath,
                targetName: name,
                productType: type,
                bundleId: nil
            )

            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            XCTAssertEqual(json["success"] as? Bool, true, "Failed for type: \(type)")
        }

        // Verify all targets exist
        let targetsResult = try await service.listTargets(projectPath: tempProjectPath)
        let targetsData = targetsResult.data(using: .utf8)!
        let targetsJson = try JSONSerialization.jsonObject(with: targetsData) as! [String: Any]

        let targets = targetsJson["targets"] as? [[String: Any]] ?? []
        XCTAssertEqual(targets.count, 4) // Original TestApp + 3 new ones
    }

    // MARK: - addTargetDependency Tests

    func testAddTargetDependency() async throws {
        // First create a new target to depend on
        _ = try await service.addTarget(
            projectPath: tempProjectPath,
            targetName: "CoreLib",
            productType: "framework",
            bundleId: nil
        )

        // Add dependency from TestApp to CoreLib
        let result = try await service.addTargetDependency(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            dependencyName: "CoreLib"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["target"] as? String, "TestApp")
        XCTAssertEqual(json["dependsOn"] as? String, "CoreLib")

        // Verify dependency was added
        let targetInfoResult = try await service.getTargetInfo(projectPath: tempProjectPath, targetName: "TestApp")
        let targetInfoData = targetInfoResult.data(using: .utf8)!
        let targetInfoJson = try JSONSerialization.jsonObject(with: targetInfoData) as! [String: Any]

        let dependencies = targetInfoJson["dependencies"] as? [String] ?? []
        XCTAssertTrue(dependencies.contains("CoreLib"))
    }

    // MARK: - addRunScript Tests

    func testAddRunScript() async throws {
        let scriptContent = "echo \"Hello from build script\"\nexit 0"

        let result = try await service.addRunScript(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            scriptName: "My Custom Script",
            script: scriptContent,
            shellPath: "/bin/bash"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["scriptName"] as? String, "My Custom Script")
        XCTAssertEqual(json["addedToTarget"] as? String, "TestApp")

        // Verify script phase was added
        let phasesResult = try await service.listBuildPhases(projectPath: tempProjectPath, targetName: "TestApp")
        let phasesData = phasesResult.data(using: .utf8)!
        let phasesJson = try JSONSerialization.jsonObject(with: phasesData) as! [String: Any]

        let phases = phasesJson["buildPhases"] as? [[String: Any]] ?? []
        // Script phase has "type" = "Run Script" and "name" = "My Custom Script"
        let scriptPhase = phases.first { ($0["name"] as? String) == "My Custom Script" }

        XCTAssertNotNil(scriptPhase, "Script phase should exist")
        // The "type" field comes from phase.name() which returns the build phase type
        XCTAssertEqual(scriptPhase?["shellPath"] as? String, "/bin/bash")
        XCTAssertEqual(scriptPhase?["script"] as? String, scriptContent)
    }

    // MARK: - updateRunScript Tests

    func testUpdateRunScript() async throws {
        // First add a script
        _ = try await service.addRunScript(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            scriptName: "Original Script",
            script: "echo original",
            shellPath: "/bin/sh"
        )

        // Update the script
        let result = try await service.updateRunScript(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            scriptName: "Original Script",
            newScript: "echo updated",
            newShellPath: "/bin/zsh",
            newName: "Updated Script"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        let updatedFields = json["updatedFields"] as? [String] ?? []
        XCTAssertTrue(updatedFields.contains("script"))
        XCTAssertTrue(updatedFields.contains("shellPath"))
        XCTAssertTrue(updatedFields.contains("name"))

        // Verify updates
        let phasesResult = try await service.listBuildPhases(projectPath: tempProjectPath, targetName: "TestApp")
        let phasesData = phasesResult.data(using: .utf8)!
        let phasesJson = try JSONSerialization.jsonObject(with: phasesData) as! [String: Any]

        let phases = phasesJson["buildPhases"] as? [[String: Any]] ?? []
        let scriptPhase = phases.first { ($0["name"] as? String) == "Updated Script" }

        XCTAssertNotNil(scriptPhase)
        XCTAssertEqual(scriptPhase?["script"] as? String, "echo updated")
        XCTAssertEqual(scriptPhase?["shellPath"] as? String, "/bin/zsh")
    }

    func testUpdateRunScriptPartial() async throws {
        // First add a script
        _ = try await service.addRunScript(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            scriptName: "Partial Update Script",
            script: "echo original",
            shellPath: "/bin/sh"
        )

        // Update only the script content
        let result = try await service.updateRunScript(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            scriptName: "Partial Update Script",
            newScript: "echo partial update",
            newShellPath: nil,
            newName: nil
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        let updatedFields = json["updatedFields"] as? [String] ?? []
        XCTAssertEqual(updatedFields, ["script"])
    }

    // MARK: - addFile Tests

    func testAddFile() async throws {
        // Create a temp file to add
        let tempFile = tempDirectory.appendingPathComponent("NewFile.swift")
        try "// New Swift file".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try await service.addFile(
            projectPath: tempProjectPath,
            filePath: tempFile.path,
            groupPath: nil,
            targetName: "TestApp"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["toGroup"] as? String, "root")

        // Verify file was added to project
        let filesResult = try await service.listFiles(projectPath: tempProjectPath, groupPath: nil)
        let filesData = filesResult.data(using: .utf8)!
        let filesJson = try JSONSerialization.jsonObject(with: filesData) as! [String: Any]

        let files = filesJson["files"] as? [[String: Any]] ?? []
        let filePaths = files.compactMap { $0["path"] as? String }
        XCTAssertTrue(filePaths.contains { $0.contains("NewFile.swift") })
    }

    func testAddFileToGroup() async throws {
        // Create a group first
        _ = try await service.addGroup(
            projectPath: tempProjectPath,
            groupName: "Sources",
            parentPath: nil
        )

        // Create a temp file
        let tempFile = tempDirectory.appendingPathComponent("GroupedFile.swift")
        try "// Grouped file".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = try await service.addFile(
            projectPath: tempProjectPath,
            filePath: tempFile.path,
            groupPath: "Sources",
            targetName: nil
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["toGroup"] as? String, "Sources")
    }

    // MARK: - removeFile Tests

    func testRemoveFile() async throws {
        // First add a file
        let tempFile = tempDirectory.appendingPathComponent("ToBeRemoved.swift")
        try "// Will be removed".write(to: tempFile, atomically: true, encoding: .utf8)

        _ = try await service.addFile(
            projectPath: tempProjectPath,
            filePath: tempFile.path,
            groupPath: nil,
            targetName: nil
        )

        // Get the relative path as it appears in the project
        let filesResult = try await service.listFiles(projectPath: tempProjectPath, groupPath: nil)
        let filesData = filesResult.data(using: .utf8)!
        let filesJson = try JSONSerialization.jsonObject(with: filesData) as! [String: Any]
        let files = filesJson["files"] as? [[String: Any]] ?? []
        let addedFile = files.first { ($0["path"] as? String)?.contains("ToBeRemoved.swift") == true }
        let filePath = addedFile?["path"] as? String ?? "ToBeRemoved.swift"

        // Now remove the file
        let result = try await service.removeFile(
            projectPath: tempProjectPath,
            filePath: filePath,
            removeFromDisk: false
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["removedFromDisk"] as? Bool, false)

        // Verify file was removed from project
        let filesResultAfter = try await service.listFiles(projectPath: tempProjectPath, groupPath: nil)
        let filesDataAfter = filesResultAfter.data(using: .utf8)!
        let filesJsonAfter = try JSONSerialization.jsonObject(with: filesDataAfter) as! [String: Any]

        let filesAfter = filesJsonAfter["files"] as? [[String: Any]] ?? []
        let filePathsAfter = filesAfter.compactMap { $0["path"] as? String }
        XCTAssertFalse(filePathsAfter.contains { $0.contains("ToBeRemoved.swift") })

        // File should still exist on disk
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path))
    }

    // MARK: - addFileToBuildPhase Tests

    func testAddFileToBuildPhase() async throws {
        // Create and add a resource file (not automatically added to build phase)
        let tempFile = tempDirectory.appendingPathComponent("data.json")
        try "{}".write(to: tempFile, atomically: true, encoding: .utf8)

        // First add file to project without target
        _ = try await service.addFile(
            projectPath: tempProjectPath,
            filePath: tempFile.path,
            groupPath: nil,
            targetName: nil
        )

        // Get the file path as stored in project
        let filesResult = try await service.listFiles(projectPath: tempProjectPath, groupPath: nil)
        let filesData = filesResult.data(using: .utf8)!
        let filesJson = try JSONSerialization.jsonObject(with: filesData) as! [String: Any]
        let files = filesJson["files"] as? [[String: Any]] ?? []
        let addedFile = files.first { ($0["path"] as? String)?.contains("data.json") == true }
        let filePath = addedFile?["path"] as? String ?? "data.json"

        // Now add to resources build phase
        let result = try await service.addFileToBuildPhase(
            projectPath: tempProjectPath,
            targetName: "TestApp",
            filePath: filePath,
            phaseType: "resources"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["addedToPhase"] as? String, "resources")
        XCTAssertEqual(json["target"] as? String, "TestApp")
    }

    // MARK: - addSwiftPackage Tests

    func testAddSwiftPackage() async throws {
        let result = try await service.addSwiftPackage(
            projectPath: tempProjectPath,
            repositoryURL: "https://github.com/apple/swift-collections.git",
            productName: "Collections",
            targetName: "TestApp",
            version: "1.0.0",
            versionRule: "upToNextMajor"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["package"] as? String, "https://github.com/apple/swift-collections.git")
        XCTAssertEqual(json["product"] as? String, "Collections")
        XCTAssertEqual(json["addedToTarget"] as? String, "TestApp")

        // Verify package was added
        let packagesResult = try await service.listPackages(projectPath: tempProjectPath)
        let packagesData = packagesResult.data(using: .utf8)!
        let packagesJson = try JSONSerialization.jsonObject(with: packagesData) as! [String: Any]

        let packages = packagesJson["packages"] as? [[String: Any]] ?? []
        XCTAssertEqual(packages.count, 1)

        let package = packages.first
        XCTAssertEqual(package?["type"] as? String, "remote")
        XCTAssertEqual(package?["repositoryURL"] as? String, "https://github.com/apple/swift-collections.git")
    }

    func testAddSwiftPackageWithDifferentVersionRules() async throws {
        // Test exact version
        let exactResult = try await service.addSwiftPackage(
            projectPath: tempProjectPath,
            repositoryURL: "https://github.com/example/exact-package.git",
            productName: "ExactPackage",
            targetName: "TestApp",
            version: "2.0.0",
            versionRule: "exact"
        )

        let exactData = exactResult.data(using: .utf8)!
        let exactJson = try JSONSerialization.jsonObject(with: exactData) as! [String: Any]
        XCTAssertEqual(exactJson["success"] as? Bool, true)
        XCTAssertEqual(exactJson["versionRule"] as? String, "exact")
    }

    // MARK: - addLocalPackage Tests

    func testAddLocalPackage() async throws {
        let result = try await service.addLocalPackage(
            projectPath: tempProjectPath,
            packagePath: "../LocalPackage",
            productName: "LocalLib",
            targetName: "TestApp"
        )

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertEqual(json["packagePath"] as? String, "../LocalPackage")
        XCTAssertEqual(json["product"] as? String, "LocalLib")
        XCTAssertEqual(json["addedToTarget"] as? String, "TestApp")

        // Verify local package was added
        let packagesResult = try await service.listPackages(projectPath: tempProjectPath)
        let packagesData = packagesResult.data(using: .utf8)!
        let packagesJson = try JSONSerialization.jsonObject(with: packagesData) as! [String: Any]

        let packages = packagesJson["packages"] as? [[String: Any]] ?? []
        let localPackage = packages.first { ($0["type"] as? String) == "local" }

        XCTAssertNotNil(localPackage)
        XCTAssertEqual(localPackage?["relativePath"] as? String, "../LocalPackage")
    }

    // MARK: - Error Handling Tests

    func testUpdateBuildSettingTargetNotFound() async throws {
        do {
            _ = try await service.updateBuildSetting(
                projectPath: tempProjectPath,
                settingName: "TEST",
                value: "value",
                targetName: "NonExistent",
                configurationName: nil
            )
            XCTFail("Should throw error")
        } catch let error as XcodeProjServiceError {
            if case .targetNotFound(let name) = error {
                XCTAssertEqual(name, "NonExistent")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testAddRunScriptTargetNotFound() async throws {
        do {
            _ = try await service.addRunScript(
                projectPath: tempProjectPath,
                targetName: "NonExistent",
                scriptName: "Script",
                script: "echo",
                shellPath: "/bin/sh"
            )
            XCTFail("Should throw error")
        } catch let error as XcodeProjServiceError {
            if case .targetNotFound(let name) = error {
                XCTAssertEqual(name, "NonExistent")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testUpdateRunScriptNotFound() async throws {
        do {
            _ = try await service.updateRunScript(
                projectPath: tempProjectPath,
                targetName: "TestApp",
                scriptName: "NonExistentScript",
                newScript: "echo",
                newShellPath: nil,
                newName: nil
            )
            XCTFail("Should throw error")
        } catch let error as XcodeProjServiceError {
            if case .configurationNotFound(let msg) = error {
                XCTAssertTrue(msg.contains("NonExistentScript"))
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testRemoveFileNotFound() async throws {
        do {
            _ = try await service.removeFile(
                projectPath: tempProjectPath,
                filePath: "NonExistentFile.swift",
                removeFromDisk: false
            )
            XCTFail("Should throw error")
        } catch let error as XcodeProjServiceError {
            if case .fileNotFound(let path) = error {
                XCTAssertEqual(path, "NonExistentFile.swift")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testAddFileToBuildPhaseFileNotFound() async throws {
        do {
            _ = try await service.addFileToBuildPhase(
                projectPath: tempProjectPath,
                targetName: "TestApp",
                filePath: "NonExistent.swift",
                phaseType: "sources"
            )
            XCTFail("Should throw error")
        } catch let error as XcodeProjServiceError {
            if case .fileNotFound(let path) = error {
                XCTAssertEqual(path, "NonExistent.swift")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testAddTargetDependencyTargetNotFound() async throws {
        do {
            _ = try await service.addTargetDependency(
                projectPath: tempProjectPath,
                targetName: "TestApp",
                dependencyName: "NonExistentTarget"
            )
            XCTFail("Should throw error")
        } catch let error as XcodeProjServiceError {
            if case .targetNotFound(let name) = error {
                XCTAssertEqual(name, "NonExistentTarget")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testAddGroupParentNotFound() async throws {
        do {
            _ = try await service.addGroup(
                projectPath: tempProjectPath,
                groupName: "Child",
                parentPath: "NonExistentParent"
            )
            XCTFail("Should throw error")
        } catch let error as XcodeProjServiceError {
            if case .groupNotFound(let path) = error {
                XCTAssertEqual(path, "NonExistentParent")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
}
