import Foundation
import XcodeProj
import PathKit

/// XcodeProjライブラリを使用してプロジェクト操作を行うサービス
public actor XcodeProjService {

    public init() {}

    // MARK: - Read Operations

    /// プロジェクト情報を取得
    public func getProjectInfo(projectPath: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let project = try pbxproj.rootProject() else {
            throw XcodeProjServiceError.projectNotFound
        }

        var info: [String: Any] = [
            "name": project.name,
            "path": projectPath
        ]

        if let compatibilityVersion = project.compatibilityVersion {
            info["compatibilityVersion"] = compatibilityVersion
        }
        if let developmentRegion = project.developmentRegion {
            info["developmentRegion"] = developmentRegion
        }
        info["knownRegions"] = project.knownRegions
        info["targetCount"] = project.targets.count
        info["targets"] = project.targets.map { $0.name }

        if let configList = project.buildConfigurationList {
            let configurations = configList.buildConfigurations.map { $0.name }
            info["configurations"] = configurations
        }

        if let schemes = xcodeproj.sharedData?.schemes {
            info["schemes"] = schemes.map { $0.name }
        }

        return formatAsJSON(info)
    }

    /// ターゲット一覧を取得
    public func listTargets(projectPath: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        var targets: [[String: Any]] = []

        for target in pbxproj.nativeTargets {
            var targetInfo: [String: Any] = [
                "name": target.name,
                "type": "native"
            ]
            if let productType = target.productType {
                targetInfo["productType"] = productType.rawValue
            }
            if let productName = target.productName {
                targetInfo["productName"] = productName
            }
            targets.append(targetInfo)
        }

        for target in pbxproj.aggregateTargets {
            targets.append([
                "name": target.name,
                "type": "aggregate"
            ])
        }

        for target in pbxproj.legacyTargets {
            targets.append([
                "name": target.name,
                "type": "legacy"
            ])
        }

        return formatAsJSON(["targets": targets])
    }

    /// 特定ターゲットの詳細情報を取得
    public func getTargetInfo(projectPath: String, targetName: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        var info: [String: Any] = [
            "name": target.name
        ]

        if let productType = target.productType {
            info["productType"] = productType.rawValue
        }
        if let productName = target.productName {
            info["productName"] = productName
        }

        // Build phases
        var phases: [[String: Any]] = []
        for phase in target.buildPhases {
            var phaseInfo: [String: Any] = [
                "type": phase.name() ?? "Unknown"
            ]
            if let files = phase.files {
                phaseInfo["fileCount"] = files.count
            }
            phases.append(phaseInfo)
        }
        info["buildPhases"] = phases

        // Dependencies
        let dependencies = target.dependencies.compactMap { dep -> String? in
            dep.name ?? dep.target?.name
        }
        info["dependencies"] = dependencies

        // Build configurations
        if let configList = target.buildConfigurationList {
            info["configurations"] = configList.buildConfigurations.map { $0.name }
        }

        // Package dependencies
        if let packageDeps = target.packageProductDependencies {
            info["packageDependencies"] = packageDeps.map { $0.productName }
        }

        return formatAsJSON(info)
    }

    /// ファイル一覧を取得
    public func listFiles(projectPath: String, groupPath: String?) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        var files: [[String: Any]] = []

        if let groupPath = groupPath {
            // 特定グループ内のファイルを取得
            guard let rootGroup = try pbxproj.rootGroup() else {
                throw XcodeProjServiceError.groupNotFound(groupPath)
            }

            let pathComponents = groupPath.split(separator: "/").map(String.init)
            var currentGroup: PBXGroup? = rootGroup

            for component in pathComponents {
                currentGroup = currentGroup?.group(named: component)
            }

            guard let targetGroup = currentGroup else {
                throw XcodeProjServiceError.groupNotFound(groupPath)
            }

            for child in targetGroup.children {
                if let fileRef = child as? PBXFileReference {
                    var fileInfo: [String: Any] = [
                        "name": fileRef.name ?? fileRef.path ?? "Unknown"
                    ]
                    if let filePath = fileRef.path {
                        fileInfo["path"] = filePath
                    }
                    if let fileType = fileRef.lastKnownFileType {
                        fileInfo["fileType"] = fileType
                    }
                    files.append(fileInfo)
                } else if let group = child as? PBXGroup {
                    files.append([
                        "name": group.name ?? group.path ?? "Unknown",
                        "type": "group"
                    ])
                }
            }
        } else {
            // 全ファイル参照を取得
            for fileRef in pbxproj.fileReferences {
                var fileInfo: [String: Any] = [:]
                if let name = fileRef.name {
                    fileInfo["name"] = name
                }
                if let filePath = fileRef.path {
                    fileInfo["path"] = filePath
                }
                if let fileType = fileRef.lastKnownFileType {
                    fileInfo["fileType"] = fileType
                }
                if !fileInfo.isEmpty {
                    files.append(fileInfo)
                }
            }
        }

        return formatAsJSON(["files": files])
    }

    /// Configuration一覧を取得
    public func listConfigurations(projectPath: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let project = try pbxproj.rootProject() else {
            throw XcodeProjServiceError.projectNotFound
        }

        guard let configList = project.buildConfigurationList else {
            throw XcodeProjServiceError.configurationNotFound("No build configuration list for project")
        }
        var configurations: [[String: Any]] = []

        for config in configList.buildConfigurations {
            var configInfo: [String: Any] = [
                "name": config.name
            ]
            if let baseConfig = config.baseConfiguration {
                configInfo["baseConfigurationFile"] = baseConfig.path ?? baseConfig.name ?? "Unknown"
            }
            configurations.append(configInfo)
        }

        var result: [String: Any] = [
            "configurations": configurations
        ]
        if let defaultConfig = configList.defaultConfigurationName {
            result["defaultConfiguration"] = defaultConfig
        }

        return formatAsJSON(result)
    }

    /// ビルド設定を取得
    public func getBuildSettings(projectPath: String, targetName: String?, configurationName: String?) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        let configList: XCConfigurationList

        if let targetName = targetName {
            guard let target = pbxproj.targets(named: targetName).first else {
                throw XcodeProjServiceError.targetNotFound(targetName)
            }
            guard let list = target.buildConfigurationList else {
                throw XcodeProjServiceError.configurationNotFound("No configuration list for target")
            }
            configList = list
        } else {
            guard let project = try pbxproj.rootProject() else {
                throw XcodeProjServiceError.projectNotFound
            }
            guard let list = project.buildConfigurationList else {
                throw XcodeProjServiceError.configurationNotFound("No configuration list for project")
            }
            configList = list
        }

        var result: [String: Any] = [:]

        for config in configList.buildConfigurations {
            if let configName = configurationName, config.name != configName {
                continue
            }

            var settings: [String: Any] = [:]
            for (key, value) in config.buildSettings {
                settings[key] = value
            }
            result[config.name] = settings
        }

        return formatAsJSON(result)
    }

    /// ビルドフェーズ一覧を取得
    public func listBuildPhases(projectPath: String, targetName: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        var phases: [[String: Any]] = []

        for phase in target.buildPhases {
            var phaseInfo: [String: Any] = [
                "type": phase.name() ?? "Unknown"
            ]

            if let files = phase.files {
                phaseInfo["fileCount"] = files.count
                let fileNames = files.compactMap { buildFile -> String? in
                    if let fileRef = buildFile.file {
                        return fileRef.name ?? fileRef.path
                    }
                    return nil
                }
                if !fileNames.isEmpty {
                    phaseInfo["files"] = fileNames
                }
            }

            // Run Script specific info
            if let scriptPhase = phase as? PBXShellScriptBuildPhase {
                if let name = scriptPhase.name {
                    phaseInfo["name"] = name
                }
                if let shellPath = scriptPhase.shellPath {
                    phaseInfo["shellPath"] = shellPath
                }
                if let script = scriptPhase.shellScript {
                    phaseInfo["script"] = script
                }
            }

            // Copy Files specific info
            if let copyPhase = phase as? PBXCopyFilesBuildPhase {
                if let name = copyPhase.name {
                    phaseInfo["name"] = name
                }
                if let dstPath = copyPhase.dstPath {
                    phaseInfo["destinationPath"] = dstPath
                }
            }

            phases.append(phaseInfo)
        }

        return formatAsJSON(["buildPhases": phases])
    }

    /// Swift Package一覧を取得
    public func listPackages(projectPath: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let project = try pbxproj.rootProject() else {
            throw XcodeProjServiceError.projectNotFound
        }

        var packages: [[String: Any]] = []

        // Remote packages
        for package in project.remotePackages {
            var pkgInfo: [String: Any] = [
                "type": "remote"
            ]
            if let url = package.repositoryURL {
                pkgInfo["repositoryURL"] = url
            }
            if let name = package.name {
                pkgInfo["name"] = name
            }
            if let requirement = package.versionRequirement {
                pkgInfo["versionRequirement"] = formatVersionRequirement(requirement)
            }
            packages.append(pkgInfo)
        }

        // Local packages
        for package in project.localPackages {
            var pkgInfo: [String: Any] = [
                "type": "local",
                "relativePath": package.relativePath
            ]
            if let name = package.name {
                pkgInfo["name"] = name
            }
            packages.append(pkgInfo)
        }

        return formatAsJSON(["packages": packages])
    }

    /// スキーム一覧を取得
    public func listSchemes(projectPath: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        var schemes: [[String: Any]] = []

        if let sharedData = xcodeproj.sharedData {
            for scheme in sharedData.schemes {
                var schemeInfo: [String: Any] = [
                    "name": scheme.name,
                    "shared": true
                ]
                if let buildAction = scheme.buildAction {
                    schemeInfo["buildActionEntries"] = buildAction.buildActionEntries.count
                }
                if scheme.testAction != nil {
                    schemeInfo["hasTestAction"] = true
                }
                if scheme.launchAction != nil {
                    schemeInfo["hasLaunchAction"] = true
                }
                schemes.append(schemeInfo)
            }
        }

        // User schemes
        for userData in xcodeproj.userData {
            for scheme in userData.schemes {
                schemes.append([
                    "name": scheme.name,
                    "shared": false,
                    "user": userData.userName
                ])
            }
        }

        return formatAsJSON(["schemes": schemes])
    }

    // MARK: - Write Operations

    /// ビルド設定を更新
    public func updateBuildSetting(
        projectPath: String,
        settingName: String,
        value: String,
        targetName: String?,
        configurationName: String?
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        let configList: XCConfigurationList

        if let targetName = targetName {
            guard let target = pbxproj.targets(named: targetName).first else {
                throw XcodeProjServiceError.targetNotFound(targetName)
            }
            guard let list = target.buildConfigurationList else {
                throw XcodeProjServiceError.configurationNotFound("No configuration list for target")
            }
            configList = list
        } else {
            guard let project = try pbxproj.rootProject() else {
                throw XcodeProjServiceError.projectNotFound
            }
            guard let list = project.buildConfigurationList else {
                throw XcodeProjServiceError.configurationNotFound("No configuration list for project")
            }
            configList = list
        }

        var updatedConfigs: [String] = []

        for config in configList.buildConfigurations {
            if let configName = configurationName, config.name != configName {
                continue
            }
            config.buildSettings[settingName] = value
            updatedConfigs.append(config.name)
        }

        try xcodeproj.write(path: path)

        return formatAsJSON([
            "success": true,
            "settingName": settingName,
            "value": value,
            "updatedConfigurations": updatedConfigs
        ])
    }

    /// ファイルを追加
    public func addFile(
        projectPath: String,
        filePath: String,
        groupPath: String?,
        targetName: String?
    ) throws -> String {
        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj
        let sourceRoot = projPath.parent()

        // Check if path is a directory
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory), isDirectory.boolValue {
            throw XcodeProjServiceError.pathIsDirectory(filePath)
        }

        guard let rootGroup = try pbxproj.rootGroup() else {
            throw XcodeProjServiceError.projectNotFound
        }

        // Check if file is already covered by a folder reference
        let file = Path(filePath)
        let fileAbsolutePath = file.isAbsolute ? file : sourceRoot + file
        let syncGroups = findSynchronizedRootGroups(in: rootGroup)
        for syncGroup in syncGroups {
            if let syncPath = syncGroup.path {
                let syncAbsolutePath = sourceRoot + Path(syncPath)
                if fileAbsolutePath.string.hasPrefix(syncAbsolutePath.string + "/") {
                    throw XcodeProjServiceError.fileAlreadyCoveredByFolderReference(
                        filePath: filePath,
                        folderReference: syncPath
                    )
                }
            }
        }

        // Find or create target group
        var targetGroup: PBXGroup = rootGroup
        if let groupPath = groupPath {
            let pathComponents = groupPath.split(separator: "/").map(String.init)
            for component in pathComponents {
                if let existingGroup = targetGroup.group(named: component) {
                    targetGroup = existingGroup
                } else {
                    let newGroups = try targetGroup.addGroup(named: component)
                    targetGroup = newGroups.last ?? targetGroup
                }
            }
        }

        // Add file to group
        let fileRef = try targetGroup.addFile(
            at: file,
            sourceTree: .group,
            sourceRoot: sourceRoot,
            validatePresence: false
        )

        // Add to target's source build phase if specified
        if let targetName = targetName {
            guard let target = pbxproj.targets(named: targetName).first else {
                throw XcodeProjServiceError.targetNotFound(targetName)
            }

            // Determine which build phase to add to based on file extension
            let fileExtension = file.extension ?? ""

            if ["swift", "m", "mm", "c", "cpp", "cc"].contains(fileExtension) {
                if let sourcesPhase = try target.sourcesBuildPhase() {
                    _ = try sourcesPhase.add(file: fileRef)
                }
            } else if ["xib", "storyboard", "xcassets", "json", "plist"].contains(fileExtension) {
                if let resourcesPhase = try target.resourcesBuildPhase() {
                    _ = try resourcesPhase.add(file: fileRef)
                }
            }
        }

        try xcodeproj.write(path: projPath)

        return formatAsJSON([
            "success": true,
            "addedFile": filePath,
            "toGroup": groupPath ?? "root",
            "addedToTarget": targetName as Any
        ])
    }

    /// Run Scriptフェーズを追加
    public func addRunScript(
        projectPath: String,
        targetName: String,
        scriptName: String,
        script: String,
        shellPath: String
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        let scriptPhase = PBXShellScriptBuildPhase(
            name: scriptName,
            shellPath: shellPath,
            shellScript: script
        )

        pbxproj.add(object: scriptPhase)
        target.buildPhases.append(scriptPhase)

        try xcodeproj.write(path: path)

        return formatAsJSON([
            "success": true,
            "scriptName": scriptName,
            "addedToTarget": targetName
        ])
    }

    /// Swift Packageを追加
    public func addSwiftPackage(
        projectPath: String,
        repositoryURL: String,
        productName: String,
        targetName: String,
        version: String,
        versionRule: String
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let project = try pbxproj.rootProject() else {
            throw XcodeProjServiceError.projectNotFound
        }

        let versionRequirement: XCRemoteSwiftPackageReference.VersionRequirement
        switch versionRule.lowercased() {
        case "uptonextmajor":
            versionRequirement = .upToNextMajorVersion(version)
        case "uptonextminor":
            versionRequirement = .upToNextMinorVersion(version)
        case "exact":
            versionRequirement = .exact(version)
        case "branch":
            versionRequirement = .branch(version)
        case "revision":
            versionRequirement = .revision(version)
        default:
            versionRequirement = .upToNextMajorVersion(version)
        }

        _ = try project.addSwiftPackage(
            repositoryURL: repositoryURL,
            productName: productName,
            versionRequirement: versionRequirement,
            targetName: targetName
        )

        try xcodeproj.write(path: path)

        return formatAsJSON([
            "success": true,
            "package": repositoryURL,
            "product": productName,
            "addedToTarget": targetName,
            "version": version,
            "versionRule": versionRule
        ])
    }

    /// ターゲットを追加
    public func addTarget(
        projectPath: String,
        targetName: String,
        productType: String,
        bundleId: String?
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let project = try pbxproj.rootProject() else {
            throw XcodeProjServiceError.projectNotFound
        }

        // Determine PBXProductType from string
        let type: PBXProductType
        switch productType.lowercased() {
        case "application", "app":
            type = .application
        case "framework":
            type = .framework
        case "staticlibrary", "static_library":
            type = .staticLibrary
        case "dynamiclibrary", "dynamic_library":
            type = .dynamicLibrary
        case "unittestbundle", "unit_test", "unittest":
            type = .unitTestBundle
        case "uitestbundle", "ui_test", "uitest":
            type = .uiTestBundle
        case "appextension", "app_extension":
            type = .appExtension
        case "commandlinetool", "command_line_tool":
            type = .commandLineTool
        case "bundle":
            type = .bundle
        case "xcframework":
            type = .xcFramework
        default:
            type = .application
        }

        // Create build configuration list for the target
        let debugConfig = XCBuildConfiguration(name: "Debug")
        let releaseConfig = XCBuildConfiguration(name: "Release")

        if let bundleId = bundleId {
            debugConfig.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = bundleId
            releaseConfig.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = bundleId
        }
        debugConfig.buildSettings["PRODUCT_NAME"] = "$(TARGET_NAME)"
        releaseConfig.buildSettings["PRODUCT_NAME"] = "$(TARGET_NAME)"

        pbxproj.add(object: debugConfig)
        pbxproj.add(object: releaseConfig)

        let configList = XCConfigurationList(
            buildConfigurations: [debugConfig, releaseConfig],
            defaultConfigurationName: "Release"
        )
        pbxproj.add(object: configList)

        // Create build phases
        let sourcesPhase = PBXSourcesBuildPhase()
        let frameworksPhase = PBXFrameworksBuildPhase()
        let resourcesPhase = PBXResourcesBuildPhase()

        pbxproj.add(object: sourcesPhase)
        pbxproj.add(object: frameworksPhase)
        pbxproj.add(object: resourcesPhase)

        // Create the target
        let target = PBXNativeTarget(
            name: targetName,
            buildConfigurationList: configList,
            buildPhases: [sourcesPhase, frameworksPhase, resourcesPhase],
            productType: type
        )

        pbxproj.add(object: target)
        project.targets.append(target)

        try xcodeproj.write(path: path)

        return formatAsJSON([
            "success": true,
            "targetName": targetName,
            "productType": productType
        ])
    }

    /// ターゲット依存関係を追加
    public func addTargetDependency(
        projectPath: String,
        targetName: String,
        dependencyName: String
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        guard let dependencyTarget = pbxproj.targets(named: dependencyName).first else {
            throw XcodeProjServiceError.targetNotFound(dependencyName)
        }

        // Create container item proxy
        guard let project = try pbxproj.rootProject() else {
            throw XcodeProjServiceError.projectNotFound
        }

        let containerProxy = PBXContainerItemProxy(
            containerPortal: .project(project),
            remoteGlobalID: .object(dependencyTarget),
            proxyType: .nativeTarget,
            remoteInfo: dependencyName
        )
        pbxproj.add(object: containerProxy)

        // Create target dependency
        let dependency = PBXTargetDependency(
            name: dependencyName,
            target: dependencyTarget,
            targetProxy: containerProxy
        )
        pbxproj.add(object: dependency)

        target.dependencies.append(dependency)

        try xcodeproj.write(path: path)

        return formatAsJSON([
            "success": true,
            "target": targetName,
            "dependsOn": dependencyName
        ])
    }

    /// グループ一覧を取得
    public func listGroups(projectPath: String, parentPath: String?) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let rootGroup = try pbxproj.rootGroup() else {
            throw XcodeProjServiceError.projectNotFound
        }

        var startGroup: PBXGroup = rootGroup
        if let parentPath = parentPath {
            let pathComponents = parentPath.split(separator: "/").map(String.init)
            for component in pathComponents {
                guard let nextGroup = startGroup.group(named: component) else {
                    throw XcodeProjServiceError.groupNotFound(parentPath)
                }
                startGroup = nextGroup
            }
        }

        var groups: [[String: Any]] = []
        collectGroups(from: startGroup, parentPath: parentPath ?? "", into: &groups)

        return formatAsJSON(["groups": groups])
    }

    private func collectGroups(from group: PBXGroup, parentPath: String, into groups: inout [[String: Any]]) {
        for child in group.children {
            if let childGroup = child as? PBXGroup {
                let groupName = childGroup.name ?? childGroup.path ?? "Unknown"
                let fullPath = parentPath.isEmpty ? groupName : "\(parentPath)/\(groupName)"

                var groupInfo: [String: Any] = [
                    "name": groupName,
                    "path": fullPath
                ]

                if let sourcePath = childGroup.path {
                    groupInfo["sourceTreePath"] = sourcePath
                }

                let childCount = childGroup.children.count
                groupInfo["childCount"] = childCount

                groups.append(groupInfo)

                // Recursively collect subgroups
                collectGroups(from: childGroup, parentPath: fullPath, into: &groups)
            }
        }
    }

    /// グループを追加
    public func addGroup(
        projectPath: String,
        groupName: String,
        parentPath: String?
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let rootGroup = try pbxproj.rootGroup() else {
            throw XcodeProjServiceError.projectNotFound
        }

        var targetGroup: PBXGroup = rootGroup
        if let parentPath = parentPath {
            let pathComponents = parentPath.split(separator: "/").map(String.init)
            for component in pathComponents {
                guard let nextGroup = targetGroup.group(named: component) else {
                    throw XcodeProjServiceError.groupNotFound(parentPath)
                }
                targetGroup = nextGroup
            }
        }

        let newGroups = try targetGroup.addGroup(named: groupName)

        try xcodeproj.write(path: path)

        let fullPath = parentPath.map { "\($0)/\(groupName)" } ?? groupName

        return formatAsJSON([
            "success": true,
            "groupName": groupName,
            "path": fullPath,
            "groupsCreated": newGroups.count
        ])
    }

    /// ファイルを削除
    public func removeFile(
        projectPath: String,
        filePath: String,
        removeFromDisk: Bool
    ) throws -> String {
        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        // Find the file reference
        guard let fileRef = pbxproj.fileReferences.first(where: {
            $0.path == filePath || $0.name == filePath
        }) else {
            throw XcodeProjServiceError.fileNotFound(filePath)
        }

        // Remove from build phases
        for buildFile in pbxproj.buildFiles {
            if buildFile.file == fileRef {
                pbxproj.delete(object: buildFile)
            }
        }

        // Remove from parent group
        for group in pbxproj.groups {
            if let index = group.children.firstIndex(where: { $0 === fileRef }) {
                group.children.remove(at: index)
            }
        }

        // Remove the file reference
        pbxproj.delete(object: fileRef)

        // Optionally remove from disk
        if removeFromDisk {
            let sourceRoot = projPath.parent()
            let fullPath = sourceRoot + Path(filePath)
            if fullPath.exists {
                try fullPath.delete()
            }
        }

        try xcodeproj.write(path: projPath)

        return formatAsJSON([
            "success": true,
            "removedFile": filePath,
            "removedFromDisk": removeFromDisk
        ])
    }

    /// ビルドフェーズ内のファイル一覧を取得
    public func getBuildPhaseFiles(
        projectPath: String,
        targetName: String,
        phaseType: String
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        var phase: PBXBuildPhase?

        switch phaseType.lowercased() {
        case "sources", "compile":
            phase = try target.sourcesBuildPhase()
        case "resources":
            phase = try target.resourcesBuildPhase()
        case "frameworks", "link":
            phase = try target.frameworksBuildPhase()
        case "headers":
            phase = target.buildPhases.first { $0 is PBXHeadersBuildPhase }
        case "copybundles", "embedframeworks":
            phase = target.buildPhases.first { $0 is PBXCopyFilesBuildPhase }
        default:
            // Try to find by name for script phases
            phase = target.buildPhases.first {
                if let scriptPhase = $0 as? PBXShellScriptBuildPhase {
                    return scriptPhase.name == phaseType
                }
                return $0.name() == phaseType
            }
        }

        guard let buildPhase = phase else {
            throw XcodeProjServiceError.configurationNotFound("Build phase not found: \(phaseType)")
        }

        var files: [[String: Any]] = []

        if let buildFiles = buildPhase.files {
            for buildFile in buildFiles {
                var fileInfo: [String: Any] = [:]

                if let fileRef = buildFile.file {
                    if let name = fileRef.name {
                        fileInfo["name"] = name
                    }
                    if let filePath = fileRef.path {
                        fileInfo["path"] = filePath
                    }
                    // Check if it's a PBXFileReference to get file type
                    if let actualFileRef = fileRef as? PBXFileReference,
                       let fileType = actualFileRef.lastKnownFileType {
                        fileInfo["fileType"] = fileType
                    }
                }

                if let settings = buildFile.settings {
                    fileInfo["settings"] = settings
                }

                if !fileInfo.isEmpty {
                    files.append(fileInfo)
                }
            }
        }

        return formatAsJSON([
            "phaseType": phaseType,
            "fileCount": files.count,
            "files": files
        ])
    }

    /// ファイルをビルドフェーズに追加
    public func addFileToBuildPhase(
        projectPath: String,
        targetName: String,
        filePath: String,
        phaseType: String
    ) throws -> String {
        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        // Find the file reference
        guard let fileRef = pbxproj.fileReferences.first(where: {
            $0.path == filePath || $0.name == filePath
        }) else {
            throw XcodeProjServiceError.fileNotFound(filePath)
        }

        var phase: PBXBuildPhase?

        switch phaseType.lowercased() {
        case "sources", "compile":
            phase = try target.sourcesBuildPhase()
        case "resources":
            phase = try target.resourcesBuildPhase()
        case "frameworks", "link":
            phase = try target.frameworksBuildPhase()
        case "headers":
            phase = target.buildPhases.first { $0 is PBXHeadersBuildPhase }
        case "copybundles", "embedframeworks":
            phase = target.buildPhases.first { $0 is PBXCopyFilesBuildPhase }
        default:
            throw XcodeProjServiceError.configurationNotFound("Unknown phase type: \(phaseType)")
        }

        guard let buildPhase = phase else {
            throw XcodeProjServiceError.configurationNotFound("Build phase not found: \(phaseType)")
        }

        _ = try buildPhase.add(file: fileRef)

        try xcodeproj.write(path: projPath)

        return formatAsJSON([
            "success": true,
            "file": filePath,
            "addedToPhase": phaseType,
            "target": targetName
        ])
    }

    /// Run Scriptを更新
    public func updateRunScript(
        projectPath: String,
        targetName: String,
        scriptName: String,
        newScript: String?,
        newShellPath: String?,
        newName: String?
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        guard let scriptPhase = target.buildPhases.compactMap({ $0 as? PBXShellScriptBuildPhase }).first(where: { $0.name == scriptName }) else {
            throw XcodeProjServiceError.configurationNotFound("Run script not found: \(scriptName)")
        }

        var updated: [String] = []

        if let newScript = newScript {
            scriptPhase.shellScript = newScript
            updated.append("script")
        }

        if let newShellPath = newShellPath {
            scriptPhase.shellPath = newShellPath
            updated.append("shellPath")
        }

        if let newName = newName {
            scriptPhase.name = newName
            updated.append("name")
        }

        try xcodeproj.write(path: path)

        return formatAsJSON([
            "success": true,
            "scriptName": scriptName,
            "target": targetName,
            "updatedFields": updated
        ])
    }

    /// ローカルSwift Packageを追加
    public func addLocalPackage(
        projectPath: String,
        packagePath: String,
        productName: String,
        targetName: String
    ) throws -> String {
        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let project = try pbxproj.rootProject() else {
            throw XcodeProjServiceError.projectNotFound
        }

        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        // Create local package reference
        let localPackageRef = XCLocalSwiftPackageReference(relativePath: packagePath)
        pbxproj.add(object: localPackageRef)
        project.localPackages.append(localPackageRef)

        // Create product dependency for local package
        let productDep = XCSwiftPackageProductDependency(productName: productName)
        pbxproj.add(object: productDep)

        // Add to target
        if target.packageProductDependencies == nil {
            target.packageProductDependencies = []
        }
        target.packageProductDependencies?.append(productDep)

        try xcodeproj.write(path: projPath)

        return formatAsJSON([
            "success": true,
            "packagePath": packagePath,
            "product": productName,
            "addedToTarget": targetName
        ])
    }

    /// スキーム詳細情報を取得
    public func getSchemeInfo(projectPath: String, schemeName: String) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        var scheme: XCScheme?

        // Check shared schemes
        if let sharedData = xcodeproj.sharedData {
            scheme = sharedData.schemes.first { $0.name == schemeName }
        }

        // Check user schemes if not found
        if scheme == nil {
            for userData in xcodeproj.userData {
                if let found = userData.schemes.first(where: { $0.name == schemeName }) {
                    scheme = found
                    break
                }
            }
        }

        guard let foundScheme = scheme else {
            throw XcodeProjServiceError.configurationNotFound("Scheme not found: \(schemeName)")
        }

        var info: [String: Any] = [
            "name": foundScheme.name
        ]

        // Build action
        if let buildAction = foundScheme.buildAction {
            var buildInfo: [String: Any] = [:]

            var entries: [[String: Any]] = []
            for entry in buildAction.buildActionEntries {
                var entryInfo: [String: Any] = [
                    "buildForTesting": entry.buildFor.contains(.testing),
                    "buildForRunning": entry.buildFor.contains(.running),
                    "buildForProfiling": entry.buildFor.contains(.profiling),
                    "buildForArchiving": entry.buildFor.contains(.archiving),
                    "buildForAnalyzing": entry.buildFor.contains(.analyzing)
                ]
                let buildableRef = entry.buildableReference
                entryInfo["blueprintName"] = buildableRef.blueprintName
                entryInfo["buildableName"] = buildableRef.buildableName
                entries.append(entryInfo)
            }
            buildInfo["entries"] = entries
            info["buildAction"] = buildInfo
        }

        // Test action
        if let testAction = foundScheme.testAction {
            var testInfo: [String: Any] = [
                "buildConfiguration": testAction.buildConfiguration
            ]

            var testables: [[String: Any]] = []
            for testable in testAction.testables {
                var testableInfo: [String: Any] = [
                    "skipped": testable.skipped
                ]
                let buildableRef = testable.buildableReference
                testableInfo["blueprintName"] = buildableRef.blueprintName
                testableInfo["buildableName"] = buildableRef.buildableName
                testables.append(testableInfo)
            }
            testInfo["testables"] = testables
            info["testAction"] = testInfo
        }

        // Launch action
        if let launchAction = foundScheme.launchAction {
            var launchInfo: [String: Any] = [
                "buildConfiguration": launchAction.buildConfiguration
            ]
            if let productRunnable = launchAction.runnable?.buildableReference {
                launchInfo["runnableProductName"] = productRunnable.buildableName
            }
            if let args = launchAction.commandlineArguments {
                launchInfo["argumentCount"] = args.arguments.count
            }
            if let envVars = launchAction.environmentVariables {
                launchInfo["environmentVariableCount"] = envVars.count
            }
            info["launchAction"] = launchInfo
        }

        // Profile action
        if let profileAction = foundScheme.profileAction {
            var profileInfo: [String: Any] = [
                "buildConfiguration": profileAction.buildConfiguration
            ]
            if let productRunnable = profileAction.runnable?.buildableReference {
                profileInfo["runnableProductName"] = productRunnable.buildableName
            }
            info["profileAction"] = profileInfo
        }

        // Analyze action
        if let analyzeAction = foundScheme.analyzeAction {
            info["analyzeAction"] = [
                "buildConfiguration": analyzeAction.buildConfiguration
            ]
        }

        // Archive action
        if let archiveAction = foundScheme.archiveAction {
            var archiveInfo: [String: Any] = [
                "buildConfiguration": archiveAction.buildConfiguration,
                "revealArchiveInOrganizer": archiveAction.revealArchiveInOrganizer
            ]
            if let archiveName = archiveAction.customArchiveName {
                archiveInfo["customArchiveName"] = archiveName
            }
            info["archiveAction"] = archiveInfo
        }

        return formatAsJSON(info)
    }

    // MARK: - Scheme Operations

    /// スキームを新規作成
    public func createScheme(
        projectPath: String,
        schemeName: String,
        targetName: String,
        testTargetName: String?,
        buildConfiguration: String,
        shared: Bool
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        // Check if scheme already exists
        if let sharedData = xcodeproj.sharedData {
            if sharedData.schemes.contains(where: { $0.name == schemeName }) {
                throw XcodeProjServiceError.schemeAlreadyExists(schemeName)
            }
        }

        // Find the main target
        guard let target = pbxproj.targets(named: targetName).first else {
            throw XcodeProjServiceError.targetNotFound(targetName)
        }

        // Create BuildableReference for main target
        let buildableRef = createBuildableReference(
            for: target,
            projectPath: projectPath
        )

        // Create BuildAction
        let buildActionEntry = XCScheme.BuildAction.Entry(
            buildableReference: buildableRef,
            buildFor: [.running, .testing, .profiling, .archiving, .analyzing]
        )

        let buildAction = XCScheme.BuildAction(
            buildActionEntries: [buildActionEntry],
            preActions: [],
            postActions: [],
            parallelizeBuild: true,
            buildImplicitDependencies: true
        )

        // Create LaunchAction
        let runnable = XCScheme.BuildableProductRunnable(buildableReference: buildableRef)
        let launchAction = XCScheme.LaunchAction(
            runnable: runnable,
            buildConfiguration: buildConfiguration
        )

        // Create TestAction
        var testables: [XCScheme.TestableReference] = []
        if let testTargetName = testTargetName,
           let testTarget = pbxproj.targets(named: testTargetName).first {
            let testBuildableRef = createBuildableReference(
                for: testTarget,
                projectPath: projectPath
            )
            let testableRef = XCScheme.TestableReference(
                skipped: false,
                parallelization: .none,
                randomExecutionOrdering: false,
                buildableReference: testBuildableRef
            )
            testables.append(testableRef)
        }

        let testAction = XCScheme.TestAction(
            buildConfiguration: buildConfiguration,
            macroExpansion: buildableRef,
            testables: testables
        )

        // Create ProfileAction
        let profileRunnable = XCScheme.BuildableProductRunnable(buildableReference: buildableRef)
        let profileAction = XCScheme.ProfileAction(
            buildableProductRunnable: profileRunnable,
            buildConfiguration: "Release"
        )

        // Create AnalyzeAction
        let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: buildConfiguration)

        // Create ArchiveAction
        let archiveAction = XCScheme.ArchiveAction(
            buildConfiguration: "Release",
            revealArchiveInOrganizer: true
        )

        // Create the scheme
        let scheme = XCScheme(
            name: schemeName,
            lastUpgradeVersion: nil,
            version: "1.7",
            buildAction: buildAction,
            testAction: testAction,
            launchAction: launchAction,
            profileAction: profileAction,
            analyzeAction: analyzeAction,
            archiveAction: archiveAction
        )

        // Save the scheme
        try saveScheme(scheme, to: xcodeproj, shared: shared)

        return formatAsJSON([
            "success": true,
            "schemeName": schemeName,
            "targetName": targetName,
            "testTargetName": testTargetName as Any,
            "shared": shared
        ])
    }

    /// スキームを更新
    public func updateScheme(
        projectPath: String,
        schemeName: String,
        newName: String?,
        buildConfiguration: String?,
        codeCoverageEnabled: Bool?
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        // Find the scheme
        guard let (scheme, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        var updated: [String] = []

        // Update build configuration
        if let buildConfiguration = buildConfiguration {
            scheme.launchAction?.buildConfiguration = buildConfiguration
            scheme.testAction?.buildConfiguration = buildConfiguration
            scheme.analyzeAction?.buildConfiguration = buildConfiguration
            updated.append("buildConfiguration")
        }

        // Update code coverage
        if let codeCoverageEnabled = codeCoverageEnabled {
            scheme.testAction?.codeCoverageEnabled = codeCoverageEnabled
            updated.append("codeCoverageEnabled")
        }

        // Handle rename
        let finalSchemeName: String
        if let newName = newName, newName != schemeName {
            // Delete old scheme file
            let oldSchemePath = getSchemePath(for: xcodeproj, schemeName: schemeName, shared: isShared)
            if oldSchemePath.exists {
                try oldSchemePath.delete()
            }

            scheme.name = newName
            finalSchemeName = newName
            updated.append("name")
        } else {
            finalSchemeName = schemeName
        }

        // Save the scheme
        try saveScheme(scheme, to: xcodeproj, shared: isShared)

        return formatAsJSON([
            "success": true,
            "schemeName": finalSchemeName,
            "updatedFields": updated
        ])
    }

    /// スキームを削除
    public func deleteScheme(
        projectPath: String,
        schemeName: String
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        // Find the scheme
        guard let (_, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        // Delete scheme file
        let schemePath = getSchemePath(for: xcodeproj, schemeName: schemeName, shared: isShared)
        if schemePath.exists {
            try schemePath.delete()
        }

        return formatAsJSON([
            "success": true,
            "deletedScheme": schemeName,
            "wasShared": isShared
        ])
    }

    /// Pre Actionを追加
    public func addSchemePreAction(
        projectPath: String,
        schemeName: String,
        actionType: String,
        script: String,
        title: String,
        shellPath: String
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        guard let (scheme, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        let executionAction = XCScheme.ExecutionAction(
            scriptText: script,
            title: title,
            shellToInvoke: shellPath
        )

        switch actionType.lowercased() {
        case "build":
            if scheme.buildAction == nil {
                scheme.buildAction = XCScheme.BuildAction(buildActionEntries: [])
            }
            scheme.buildAction?.preActions.append(executionAction)
        case "test":
            scheme.testAction?.preActions.append(executionAction)
        case "launch":
            scheme.launchAction?.preActions.append(executionAction)
        case "profile":
            scheme.profileAction?.preActions.append(executionAction)
        case "archive":
            scheme.archiveAction?.preActions.append(executionAction)
        default:
            throw XcodeProjServiceError.invalidActionType(actionType)
        }

        try saveScheme(scheme, to: xcodeproj, shared: isShared)

        return formatAsJSON([
            "success": true,
            "schemeName": schemeName,
            "actionType": actionType,
            "preActionTitle": title
        ])
    }

    /// Post Actionを追加
    public func addSchemePostAction(
        projectPath: String,
        schemeName: String,
        actionType: String,
        script: String,
        title: String,
        shellPath: String
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        guard let (scheme, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        let executionAction = XCScheme.ExecutionAction(
            scriptText: script,
            title: title,
            shellToInvoke: shellPath
        )

        switch actionType.lowercased() {
        case "build":
            if scheme.buildAction == nil {
                scheme.buildAction = XCScheme.BuildAction(buildActionEntries: [])
            }
            scheme.buildAction?.postActions.append(executionAction)
        case "test":
            scheme.testAction?.postActions.append(executionAction)
        case "launch":
            scheme.launchAction?.postActions.append(executionAction)
        case "profile":
            scheme.profileAction?.postActions.append(executionAction)
        case "archive":
            scheme.archiveAction?.postActions.append(executionAction)
        default:
            throw XcodeProjServiceError.invalidActionType(actionType)
        }

        try saveScheme(scheme, to: xcodeproj, shared: isShared)

        return formatAsJSON([
            "success": true,
            "schemeName": schemeName,
            "actionType": actionType,
            "postActionTitle": title
        ])
    }

    /// 環境変数を設定
    public func setSchemeEnvironmentVariables(
        projectPath: String,
        schemeName: String,
        actionType: String,
        variables: [[String: Any]]
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        guard let (scheme, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        let envVars = variables.compactMap { dict -> XCScheme.EnvironmentVariable? in
            guard let key = dict["key"] as? String,
                  let value = dict["value"] as? String else {
                return nil
            }
            let enabled = dict["enabled"] as? Bool ?? true
            return XCScheme.EnvironmentVariable(variable: key, value: value, enabled: enabled)
        }

        switch actionType.lowercased() {
        case "launch":
            scheme.launchAction?.environmentVariables = envVars
        case "test":
            scheme.testAction?.environmentVariables = envVars
        default:
            throw XcodeProjServiceError.invalidActionType("\(actionType). Environment variables can only be set for 'launch' or 'test' actions")
        }

        try saveScheme(scheme, to: xcodeproj, shared: isShared)

        return formatAsJSON([
            "success": true,
            "schemeName": schemeName,
            "actionType": actionType,
            "variableCount": envVars.count
        ])
    }

    /// コマンドライン引数を設定
    public func setSchemeCommandLineArguments(
        projectPath: String,
        schemeName: String,
        actionType: String,
        arguments: [[String: Any]]
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        guard let (scheme, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        let cmdArgs = arguments.compactMap { dict -> XCScheme.CommandLineArguments.CommandLineArgument? in
            guard let name = dict["name"] as? String else {
                return nil
            }
            let enabled = dict["enabled"] as? Bool ?? true
            return XCScheme.CommandLineArguments.CommandLineArgument(name: name, enabled: enabled)
        }

        let commandLineArgs = XCScheme.CommandLineArguments(arguments: cmdArgs)

        switch actionType.lowercased() {
        case "launch":
            scheme.launchAction?.commandlineArguments = commandLineArgs
        case "test":
            scheme.testAction?.commandlineArguments = commandLineArgs
        default:
            throw XcodeProjServiceError.invalidActionType("\(actionType). Command line arguments can only be set for 'launch' or 'test' actions")
        }

        try saveScheme(scheme, to: xcodeproj, shared: isShared)

        return formatAsJSON([
            "success": true,
            "schemeName": schemeName,
            "actionType": actionType,
            "argumentCount": cmdArgs.count
        ])
    }

    /// テストカバレッジ設定
    public func setSchemeTestCoverage(
        projectPath: String,
        schemeName: String,
        enabled: Bool,
        targetNames: [String]?
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let (scheme, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        scheme.testAction?.codeCoverageEnabled = enabled

        if let targetNames = targetNames, !targetNames.isEmpty {
            var coverageTargets: [XCScheme.BuildableReference] = []
            for targetName in targetNames {
                guard let target = pbxproj.targets(named: targetName).first else {
                    throw XcodeProjServiceError.targetNotFound(targetName)
                }
                let buildableRef = createBuildableReference(for: target, projectPath: projectPath)
                coverageTargets.append(buildableRef)
            }
            scheme.testAction?.codeCoverageTargets = coverageTargets
            scheme.testAction?.onlyGenerateCoverageForSpecifiedTargets = true
        } else {
            scheme.testAction?.onlyGenerateCoverageForSpecifiedTargets = false
        }

        try saveScheme(scheme, to: xcodeproj, shared: isShared)

        return formatAsJSON([
            "success": true,
            "schemeName": schemeName,
            "codeCoverageEnabled": enabled,
            "targetNames": targetNames as Any
        ])
    }

    /// テストターゲットを追加
    public func addSchemeTestable(
        projectPath: String,
        schemeName: String,
        testTargetName: String,
        skipped: Bool
    ) throws -> String {
        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let pbxproj = xcodeproj.pbxproj

        guard let (scheme, isShared) = findScheme(in: xcodeproj, named: schemeName) else {
            throw XcodeProjServiceError.schemeNotFound(schemeName)
        }

        guard let testTarget = pbxproj.targets(named: testTargetName).first else {
            throw XcodeProjServiceError.targetNotFound(testTargetName)
        }

        let testBuildableRef = createBuildableReference(for: testTarget, projectPath: projectPath)

        let testableRef = XCScheme.TestableReference(
            skipped: skipped,
            parallelization: .none,
            randomExecutionOrdering: false,
            buildableReference: testBuildableRef
        )

        scheme.testAction?.testables.append(testableRef)

        try saveScheme(scheme, to: xcodeproj, shared: isShared)

        return formatAsJSON([
            "success": true,
            "schemeName": schemeName,
            "addedTestable": testTargetName,
            "skipped": skipped
        ])
    }

    // MARK: - Scheme Helper Methods

    /// スキームを探す
    private func findScheme(in xcodeproj: XcodeProj, named schemeName: String) -> (XCScheme, Bool)? {
        // Check shared schemes
        if let sharedData = xcodeproj.sharedData {
            if let scheme = sharedData.schemes.first(where: { $0.name == schemeName }) {
                return (scheme, true)
            }
        }

        // Check user schemes
        for userData in xcodeproj.userData {
            if let scheme = userData.schemes.first(where: { $0.name == schemeName }) {
                return (scheme, false)
            }
        }

        return nil
    }

    /// ターゲットからBuildableReferenceを作成
    private func createBuildableReference(for target: PBXTarget, projectPath: String) -> XCScheme.BuildableReference {
        let projectName = Path(projectPath).lastComponent

        // Determine buildable name based on product type
        var buildableName = target.productName ?? target.name
        if let nativeTarget = target as? PBXNativeTarget,
           let productType = nativeTarget.productType {
            switch productType {
            case .application:
                buildableName = "\(target.name).app"
            case .framework:
                buildableName = "\(target.name).framework"
            case .staticLibrary:
                buildableName = "lib\(target.name).a"
            case .dynamicLibrary:
                buildableName = "\(target.name).dylib"
            case .unitTestBundle, .uiTestBundle:
                buildableName = "\(target.name).xctest"
            case .appExtension:
                buildableName = "\(target.name).appex"
            case .bundle:
                buildableName = "\(target.name).bundle"
            default:
                buildableName = target.productName ?? target.name
            }
        }

        return XCScheme.BuildableReference(
            referencedContainer: "container:\(projectName)",
            blueprint: target,
            buildableName: buildableName,
            blueprintName: target.name
        )
    }

    /// スキームファイルのパスを取得
    private func getSchemePath(for xcodeproj: XcodeProj, schemeName: String, shared: Bool) -> Path {
        guard let projectPath = xcodeproj.path else {
            return Path("")
        }

        if shared {
            return projectPath + "xcshareddata" + "xcschemes" + "\(schemeName).xcscheme"
        } else {
            // User scheme path would be in xcuserdata/<username>.xcuserdatad/xcschemes
            return projectPath + "xcshareddata" + "xcschemes" + "\(schemeName).xcscheme"
        }
    }

    /// スキームを保存
    private func saveScheme(_ scheme: XCScheme, to xcodeproj: XcodeProj, shared: Bool) throws {
        guard let projectPath = xcodeproj.path else {
            throw XcodeProjServiceError.projectNotFound
        }

        let schemesDir: Path
        if shared {
            schemesDir = projectPath + "xcshareddata" + "xcschemes"
        } else {
            // For user schemes, we'd need the username
            // For simplicity, we'll save to shared for now
            schemesDir = projectPath + "xcshareddata" + "xcschemes"
        }

        // Create directory if it doesn't exist
        if !schemesDir.exists {
            try schemesDir.mkpath()
        }

        let schemePath = schemesDir + "\(scheme.name).xcscheme"
        try scheme.write(path: schemePath, override: true)
    }

    /// フォルダをFolder Reference（PBXFileSystemSynchronizedRootGroup）として追加
    public func addFolderReference(
        projectPath: String,
        folderPath: String,
        parentGroupPath: String?,
        targetName: String?
    ) throws -> String {
        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj
        let sourceRoot = projPath.parent()

        // Check if path is a directory
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw XcodeProjServiceError.pathIsNotDirectory(folderPath)
        }

        guard let rootGroup = try pbxproj.rootGroup() else {
            throw XcodeProjServiceError.projectNotFound
        }

        // Find parent group
        var parentGroup: PBXGroup = rootGroup
        if let parentGroupPath = parentGroupPath {
            let pathComponents = parentGroupPath.split(separator: "/").map(String.init)
            for component in pathComponents {
                if let existingGroup = parentGroup.group(named: component) {
                    parentGroup = existingGroup
                } else {
                    throw XcodeProjServiceError.groupNotFound(parentGroupPath)
                }
            }
        }

        // Calculate relative path from source root
        let folder = Path(folderPath)
        let folderAbsolutePath = folder.isAbsolute ? folder : sourceRoot + folder
        let relativePath: String
        if folderAbsolutePath.string.hasPrefix(sourceRoot.string) {
            relativePath = String(folderAbsolutePath.string.dropFirst(sourceRoot.string.count + 1))
        } else {
            relativePath = folderPath
        }

        // Check if folder reference already exists
        let existingSyncGroups = findSynchronizedRootGroups(in: rootGroup)
        for syncGroup in existingSyncGroups {
            if syncGroup.path == relativePath {
                throw XcodeProjServiceError.folderReferenceAlreadyExists(relativePath)
            }
        }

        // Create PBXFileSystemSynchronizedRootGroup
        let folderName = folderAbsolutePath.lastComponent
        let syncRootGroup = PBXFileSystemSynchronizedRootGroup(
            sourceTree: .group,
            path: relativePath,
            name: folderName
        )
        pbxproj.add(object: syncRootGroup)
        parentGroup.children.append(syncRootGroup)

        // Add to target if specified
        if let targetName = targetName {
            guard let target = pbxproj.targets(named: targetName).first as? PBXNativeTarget else {
                throw XcodeProjServiceError.targetNotFound(targetName)
            }

            // Add to fileSystemSynchronizedGroups
            if target.fileSystemSynchronizedGroups == nil {
                target.fileSystemSynchronizedGroups = []
            }
            target.fileSystemSynchronizedGroups?.append(syncRootGroup)
        }

        try xcodeproj.write(path: projPath)

        return formatAsJSON([
            "success": true,
            "folderReference": relativePath,
            "name": folderName,
            "parentGroup": parentGroupPath ?? "root",
            "addedToTarget": targetName as Any
        ])
    }

    // MARK: - Helpers

    /// Recursively finds all PBXFileSystemSynchronizedRootGroup elements in the project
    private func findSynchronizedRootGroups(in group: PBXGroup) -> [PBXFileSystemSynchronizedRootGroup] {
        var result: [PBXFileSystemSynchronizedRootGroup] = []
        for child in group.children {
            if let syncGroup = child as? PBXFileSystemSynchronizedRootGroup {
                result.append(syncGroup)
            } else if let subGroup = child as? PBXGroup {
                result.append(contentsOf: findSynchronizedRootGroups(in: subGroup))
            }
        }
        return result
    }

    private func formatAsJSON(_ dict: [String: Any]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize response\"}"
        }
    }

    private func formatVersionRequirement(_ requirement: XCRemoteSwiftPackageReference.VersionRequirement) -> String {
        switch requirement {
        case .upToNextMajorVersion(let version):
            return "upToNextMajor(\(version))"
        case .upToNextMinorVersion(let version):
            return "upToNextMinor(\(version))"
        case .range(let from, let to):
            return "range(\(from)..<\(to))"
        case .exact(let version):
            return "exact(\(version))"
        case .branch(let branch):
            return "branch(\(branch))"
        case .revision(let revision):
            return "revision(\(revision))"
        }
    }
}

// MARK: - Errors

public enum XcodeProjServiceError: Error, LocalizedError {
    case projectNotFound
    case targetNotFound(String)
    case groupNotFound(String)
    case configurationNotFound(String)
    case fileNotFound(String)
    case pathIsDirectory(String)
    case pathIsNotDirectory(String)
    case fileAlreadyCoveredByFolderReference(filePath: String, folderReference: String)
    case folderReferenceAlreadyExists(String)
    case schemeNotFound(String)
    case schemeAlreadyExists(String)
    case invalidActionType(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "Project not found"
        case .targetNotFound(let name):
            return "Target not found: \(name)"
        case .groupNotFound(let path):
            return "Group not found: \(path)"
        case .configurationNotFound(let msg):
            return "Configuration not found: \(msg)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .pathIsDirectory(let path):
            return "Path is a directory, not a file: \(path). Use add_folder_reference to add directories."
        case .pathIsNotDirectory(let path):
            return "Path is not a directory: \(path). Use add_file to add files."
        case .fileAlreadyCoveredByFolderReference(let filePath, let folderReference):
            return "File '\(filePath)' is already covered by folder reference '\(folderReference)'"
        case .folderReferenceAlreadyExists(let path):
            return "Folder reference already exists: \(path)"
        case .schemeNotFound(let name):
            return "Scheme not found: \(name)"
        case .schemeAlreadyExists(let name):
            return "Scheme already exists: \(name)"
        case .invalidActionType(let actionType):
            return "Invalid action type: \(actionType). Valid types are: build, test, launch, profile, archive"
        }
    }
}
