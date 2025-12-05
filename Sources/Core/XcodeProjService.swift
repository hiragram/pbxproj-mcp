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

        guard let rootGroup = try pbxproj.rootGroup() else {
            throw XcodeProjServiceError.projectNotFound
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
        let file = Path(filePath)
        let sourceRoot = projPath.parent()
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

    // MARK: - Helpers

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
        }
    }
}
