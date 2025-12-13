import Foundation
import MCP
import Core

/// MCPツールハンドラー
/// 全てのツールを登録し、呼び出しをディスパッチする
final class ToolHandler: Sendable {
    private let service = XcodeProjService()

    func register(to server: Server) async {
        // ツール一覧を登録
        _ = await server.withMethodHandler(ListTools.self) { [self] _ in
            ListTools.Result(tools: self.allTools)
        }

        // ツール呼び出しを登録
        _ = await server.withMethodHandler(CallTool.self) { [self] params in
            try await self.handleToolCall(params)
        }
    }

    // MARK: - Tool Definitions

    private var allTools: [Tool] {
        [
            // Project
            Tool(
                name: "get_project_info",
                description: "Get overview information of an Xcode project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),

            // Targets
            Tool(
                name: "list_targets",
                description: "List all targets in the project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),
            Tool(
                name: "get_target_info",
                description: "Get detailed information about a specific target",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name")])
                ])
            ),

            // Files
            Tool(
                name: "list_files",
                description: "List all files in the project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "group_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Path to a specific group to list files from")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),

            // Build Settings
            Tool(
                name: "list_configurations",
                description: "List all build configurations (Debug, Release, etc.)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),
            Tool(
                name: "get_build_settings",
                description: "Get build settings for a target and/or configuration",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Name of the target (if not specified, returns project-level settings)")
                        ]),
                        "configuration_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Name of the configuration (Debug, Release, etc.)")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),

            // Build Phases
            Tool(
                name: "list_build_phases",
                description: "List all build phases for a target",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name")])
                ])
            ),

            // Swift Packages
            Tool(
                name: "list_packages",
                description: "List all Swift Package dependencies",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),

            // Schemes
            Tool(
                name: "list_schemes",
                description: "List all shared schemes in the project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),

            // Write operations
            Tool(
                name: "update_build_setting",
                description: "Update a build setting value",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "setting_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the build setting (e.g., SWIFT_VERSION, PRODUCT_BUNDLE_IDENTIFIER)")
                        ]),
                        "value": .object([
                            "type": .string("string"),
                            "description": .string("New value for the setting")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Target name (if not specified, updates project-level settings)")
                        ]),
                        "configuration_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Configuration name (if not specified, updates all configurations)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("setting_name"), .string("value")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_file",
                description: "Add a file to the project. Directories cannot be added - only individual files are supported. Note: Xcode 16+ uses Folder References by default, so files are automatically included without explicit addition.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "file_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the file to add")
                        ]),
                        "group_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Group path to add the file to (e.g., 'Sources/Models')")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Target to add the file to (for compilation)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("file_path")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_run_script",
                description: "Add a Run Script build phase to a target",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target")
                        ]),
                        "script_name": .object([
                            "type": .string("string"),
                            "description": .string("Name for the script phase")
                        ]),
                        "script": .object([
                            "type": .string("string"),
                            "description": .string("Shell script content")
                        ]),
                        "shell_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Shell path (default: /bin/sh)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name"), .string("script_name"), .string("script")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_swift_package",
                description: "Add a Swift Package dependency to the project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "repository_url": .object([
                            "type": .string("string"),
                            "description": .string("Git repository URL of the package")
                        ]),
                        "product_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the product to use from the package")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Target to add the package dependency to")
                        ]),
                        "version": .object([
                            "type": .string("string"),
                            "description": .string("Minimum version (e.g., '5.0.0')")
                        ]),
                        "version_rule": .object([
                            "type": .string("string"),
                            "description": .string("Version rule: 'upToNextMajor', 'upToNextMinor', 'exact', 'branch', 'revision' (default: upToNextMajor)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("repository_url"), .string("product_name"), .string("target_name"), .string("version")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            // New tools
            Tool(
                name: "add_target",
                description: "Add a new target to the project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the new target")
                        ]),
                        "product_type": .object([
                            "type": .string("string"),
                            "description": .string("Product type: 'application', 'framework', 'staticLibrary', 'dynamicLibrary', 'unitTestBundle', 'uiTestBundle', 'appExtension', 'commandLineTool', 'bundle'")
                        ]),
                        "bundle_id": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Bundle identifier for the target")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name"), .string("product_type")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_target_dependency",
                description: "Add a dependency between targets",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target that will have the dependency")
                        ]),
                        "dependency_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target to depend on")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name"), .string("dependency_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "list_groups",
                description: "List all groups in the project hierarchy",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "parent_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Path to a parent group to start from")
                        ])
                    ]),
                    "required": .array([.string("project_path")])
                ])
            ),

            Tool(
                name: "add_group",
                description: "Add a new group to the project. Note: Xcode 16+ uses Folder References by default, so files and folders are automatically included without explicit addition.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "group_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the new group")
                        ]),
                        "parent_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Path to the parent group (e.g., 'Sources/Models')")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("group_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "remove_file",
                description: "Remove a file from the project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "file_path": .object([
                            "type": .string("string"),
                            "description": .string("Path or name of the file to remove")
                        ]),
                        "remove_from_disk": .object([
                            "type": .string("boolean"),
                            "description": .string("Optional: Also delete the file from disk (default: false)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("file_path")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "get_build_phase_files",
                description: "Get files in a specific build phase",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target")
                        ]),
                        "phase_type": .object([
                            "type": .string("string"),
                            "description": .string("Build phase type: 'sources', 'resources', 'frameworks', 'headers', 'embedFrameworks', or a script phase name")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name"), .string("phase_type")])
                ])
            ),

            Tool(
                name: "add_file_to_build_phase",
                description: "Add an existing file reference to a build phase",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target")
                        ]),
                        "file_path": .object([
                            "type": .string("string"),
                            "description": .string("Path or name of the file to add")
                        ]),
                        "phase_type": .object([
                            "type": .string("string"),
                            "description": .string("Build phase type: 'sources', 'resources', 'frameworks', 'headers', 'embedFrameworks'")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name"), .string("file_path"), .string("phase_type")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "update_run_script",
                description: "Update an existing Run Script build phase",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the target")
                        ]),
                        "script_name": .object([
                            "type": .string("string"),
                            "description": .string("Current name of the script phase to update")
                        ]),
                        "new_script": .object([
                            "type": .string("string"),
                            "description": .string("Optional: New shell script content")
                        ]),
                        "new_shell_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: New shell path")
                        ]),
                        "new_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: New name for the script phase")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("target_name"), .string("script_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_local_package",
                description: "Add a local Swift Package dependency",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "package_path": .object([
                            "type": .string("string"),
                            "description": .string("Relative path to the local package directory")
                        ]),
                        "product_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the product to use from the package")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Target to add the package dependency to")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("package_path"), .string("product_name"), .string("target_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "get_scheme_info",
                description: "Get detailed information about a scheme",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name")])
                ])
            ),

            Tool(
                name: "add_folder_reference",
                description: "Add a folder as a Folder Reference (PBXFileSystemSynchronizedRootGroup) to the project. This is the recommended way to add folders in Xcode 16+. Files inside the folder are automatically synchronized with the file system.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "folder_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the folder to add as a folder reference")
                        ]),
                        "parent_group_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Path to the parent group (e.g., 'Sources/Models')")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Target to add the folder reference to (files will be compiled/included automatically)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("folder_path")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            // Scheme operations
            Tool(
                name: "create_scheme",
                description: "Create a new scheme for a target",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the new scheme")
                        ]),
                        "target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the main target for the scheme")
                        ]),
                        "test_target_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Name of the test target")
                        ]),
                        "build_configuration": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Build configuration (default: Debug)")
                        ]),
                        "shared": .object([
                            "type": .string("boolean"),
                            "description": .string("Optional: Create as shared scheme (default: true)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name"), .string("target_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "update_scheme",
                description: "Update an existing scheme's settings",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme to update")
                        ]),
                        "new_name": .object([
                            "type": .string("string"),
                            "description": .string("Optional: New name for the scheme")
                        ]),
                        "build_configuration": .object([
                            "type": .string("string"),
                            "description": .string("Optional: New build configuration")
                        ]),
                        "code_coverage_enabled": .object([
                            "type": .string("boolean"),
                            "description": .string("Optional: Enable or disable code coverage")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "delete_scheme",
                description: "Delete a scheme from the project",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme to delete")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_scheme_pre_action",
                description: "Add a pre-action script to a scheme action (build, test, launch, profile, archive)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme")
                        ]),
                        "action_type": .object([
                            "type": .string("string"),
                            "description": .string("Action type: build, test, launch, profile, archive")
                        ]),
                        "script": .object([
                            "type": .string("string"),
                            "description": .string("Shell script content")
                        ]),
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Title for the action (default: Run Script)")
                        ]),
                        "shell_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Shell path (default: /bin/sh)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name"), .string("action_type"), .string("script")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_scheme_post_action",
                description: "Add a post-action script to a scheme action (build, test, launch, profile, archive)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme")
                        ]),
                        "action_type": .object([
                            "type": .string("string"),
                            "description": .string("Action type: build, test, launch, profile, archive")
                        ]),
                        "script": .object([
                            "type": .string("string"),
                            "description": .string("Shell script content")
                        ]),
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Title for the action (default: Run Script)")
                        ]),
                        "shell_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional: Shell path (default: /bin/sh)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name"), .string("action_type"), .string("script")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "set_scheme_environment_variables",
                description: "Set environment variables for a scheme's launch or test action",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme")
                        ]),
                        "action_type": .object([
                            "type": .string("string"),
                            "description": .string("Action type: launch or test")
                        ]),
                        "variables": .object([
                            "type": .string("array"),
                            "description": .string("Array of environment variables: [{key: string, value: string, enabled: boolean}]")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name"), .string("action_type"), .string("variables")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "set_scheme_command_line_arguments",
                description: "Set command line arguments for a scheme's launch or test action",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme")
                        ]),
                        "action_type": .object([
                            "type": .string("string"),
                            "description": .string("Action type: launch or test")
                        ]),
                        "arguments": .object([
                            "type": .string("array"),
                            "description": .string("Array of arguments: [{name: string, enabled: boolean}]")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name"), .string("action_type"), .string("arguments")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "set_scheme_test_coverage",
                description: "Configure test coverage settings for a scheme",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme")
                        ]),
                        "enabled": .object([
                            "type": .string("boolean"),
                            "description": .string("Enable or disable code coverage")
                        ]),
                        "target_names": .object([
                            "type": .string("array"),
                            "description": .string("Optional: Array of target names to gather coverage for. If not specified, gathers for all targets.")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name"), .string("enabled")])
                ]),
                annotations: .init(destructiveHint: true)
            ),

            Tool(
                name: "add_scheme_testable",
                description: "Add a test target to a scheme's test action",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "project_path": .object([
                            "type": .string("string"),
                            "description": .string("Path to the .xcodeproj directory")
                        ]),
                        "scheme_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the scheme")
                        ]),
                        "test_target_name": .object([
                            "type": .string("string"),
                            "description": .string("Name of the test target to add")
                        ]),
                        "skipped": .object([
                            "type": .string("boolean"),
                            "description": .string("Optional: Whether the test target is skipped (default: false)")
                        ])
                    ]),
                    "required": .array([.string("project_path"), .string("scheme_name"), .string("test_target_name")])
                ]),
                annotations: .init(destructiveHint: true)
            ),
        ]
    }

    // MARK: - Tool Call Handler

    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments else {
            throw MCPError.invalidParams("Missing arguments")
        }

        guard let projectPath = args["project_path"]?.stringValue else {
            throw MCPError.invalidParams("Missing project_path argument")
        }

        do {
            let result: String
            switch params.name {
            // Read operations
            case "get_project_info":
                result = try await service.getProjectInfo(projectPath: projectPath)
            case "list_targets":
                result = try await service.listTargets(projectPath: projectPath)
            case "get_target_info":
                guard let targetName = args["target_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing target_name argument")
                }
                result = try await service.getTargetInfo(projectPath: projectPath, targetName: targetName)
            case "list_files":
                let groupPath = args["group_path"]?.stringValue
                result = try await service.listFiles(projectPath: projectPath, groupPath: groupPath)
            case "list_configurations":
                result = try await service.listConfigurations(projectPath: projectPath)
            case "get_build_settings":
                let targetName = args["target_name"]?.stringValue
                let configName = args["configuration_name"]?.stringValue
                result = try await service.getBuildSettings(
                    projectPath: projectPath,
                    targetName: targetName,
                    configurationName: configName
                )
            case "list_build_phases":
                guard let targetName = args["target_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing target_name argument")
                }
                result = try await service.listBuildPhases(projectPath: projectPath, targetName: targetName)
            case "list_packages":
                result = try await service.listPackages(projectPath: projectPath)
            case "list_schemes":
                result = try await service.listSchemes(projectPath: projectPath)

            // Write operations
            case "update_build_setting":
                guard let settingName = args["setting_name"]?.stringValue,
                      let value = args["value"]?.stringValue else {
                    throw MCPError.invalidParams("Missing setting_name or value argument")
                }
                let targetName = args["target_name"]?.stringValue
                let configName = args["configuration_name"]?.stringValue
                result = try await service.updateBuildSetting(
                    projectPath: projectPath,
                    settingName: settingName,
                    value: value,
                    targetName: targetName,
                    configurationName: configName
                )
            case "add_file":
                guard let filePath = args["file_path"]?.stringValue else {
                    throw MCPError.invalidParams("Missing file_path argument")
                }
                let groupPath = args["group_path"]?.stringValue
                let targetName = args["target_name"]?.stringValue
                result = try await service.addFile(
                    projectPath: projectPath,
                    filePath: filePath,
                    groupPath: groupPath,
                    targetName: targetName
                )
            case "add_run_script":
                guard let targetName = args["target_name"]?.stringValue,
                      let scriptName = args["script_name"]?.stringValue,
                      let script = args["script"]?.stringValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let shellPath = args["shell_path"]?.stringValue ?? "/bin/sh"
                result = try await service.addRunScript(
                    projectPath: projectPath,
                    targetName: targetName,
                    scriptName: scriptName,
                    script: script,
                    shellPath: shellPath
                )
            case "add_swift_package":
                guard let repoURL = args["repository_url"]?.stringValue,
                      let productName = args["product_name"]?.stringValue,
                      let targetName = args["target_name"]?.stringValue,
                      let version = args["version"]?.stringValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let versionRule = args["version_rule"]?.stringValue ?? "upToNextMajor"
                result = try await service.addSwiftPackage(
                    projectPath: projectPath,
                    repositoryURL: repoURL,
                    productName: productName,
                    targetName: targetName,
                    version: version,
                    versionRule: versionRule
                )

            // New tools
            case "add_target":
                guard let targetName = args["target_name"]?.stringValue,
                      let productType = args["product_type"]?.stringValue else {
                    throw MCPError.invalidParams("Missing target_name or product_type argument")
                }
                let bundleId = args["bundle_id"]?.stringValue
                result = try await service.addTarget(
                    projectPath: projectPath,
                    targetName: targetName,
                    productType: productType,
                    bundleId: bundleId
                )

            case "add_target_dependency":
                guard let targetName = args["target_name"]?.stringValue,
                      let dependencyName = args["dependency_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing target_name or dependency_name argument")
                }
                result = try await service.addTargetDependency(
                    projectPath: projectPath,
                    targetName: targetName,
                    dependencyName: dependencyName
                )

            case "list_groups":
                let parentPath = args["parent_path"]?.stringValue
                result = try await service.listGroups(projectPath: projectPath, parentPath: parentPath)

            case "add_group":
                guard let groupName = args["group_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing group_name argument")
                }
                let parentPath = args["parent_path"]?.stringValue
                result = try await service.addGroup(
                    projectPath: projectPath,
                    groupName: groupName,
                    parentPath: parentPath
                )

            case "remove_file":
                guard let filePath = args["file_path"]?.stringValue else {
                    throw MCPError.invalidParams("Missing file_path argument")
                }
                let removeFromDisk = args["remove_from_disk"]?.boolValue ?? false
                result = try await service.removeFile(
                    projectPath: projectPath,
                    filePath: filePath,
                    removeFromDisk: removeFromDisk
                )

            case "get_build_phase_files":
                guard let targetName = args["target_name"]?.stringValue,
                      let phaseType = args["phase_type"]?.stringValue else {
                    throw MCPError.invalidParams("Missing target_name or phase_type argument")
                }
                result = try await service.getBuildPhaseFiles(
                    projectPath: projectPath,
                    targetName: targetName,
                    phaseType: phaseType
                )

            case "add_file_to_build_phase":
                guard let targetName = args["target_name"]?.stringValue,
                      let filePath = args["file_path"]?.stringValue,
                      let phaseType = args["phase_type"]?.stringValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                result = try await service.addFileToBuildPhase(
                    projectPath: projectPath,
                    targetName: targetName,
                    filePath: filePath,
                    phaseType: phaseType
                )

            case "update_run_script":
                guard let targetName = args["target_name"]?.stringValue,
                      let scriptName = args["script_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing target_name or script_name argument")
                }
                let newScript = args["new_script"]?.stringValue
                let newShellPath = args["new_shell_path"]?.stringValue
                let newName = args["new_name"]?.stringValue
                result = try await service.updateRunScript(
                    projectPath: projectPath,
                    targetName: targetName,
                    scriptName: scriptName,
                    newScript: newScript,
                    newShellPath: newShellPath,
                    newName: newName
                )

            case "add_local_package":
                guard let packagePath = args["package_path"]?.stringValue,
                      let productName = args["product_name"]?.stringValue,
                      let targetName = args["target_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                result = try await service.addLocalPackage(
                    projectPath: projectPath,
                    packagePath: packagePath,
                    productName: productName,
                    targetName: targetName
                )

            case "get_scheme_info":
                guard let schemeName = args["scheme_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing scheme_name argument")
                }
                result = try await service.getSchemeInfo(projectPath: projectPath, schemeName: schemeName)

            case "add_folder_reference":
                guard let folderPath = args["folder_path"]?.stringValue else {
                    throw MCPError.invalidParams("Missing folder_path argument")
                }
                let parentGroupPath = args["parent_group_path"]?.stringValue
                let targetName = args["target_name"]?.stringValue
                result = try await service.addFolderReference(
                    projectPath: projectPath,
                    folderPath: folderPath,
                    parentGroupPath: parentGroupPath,
                    targetName: targetName
                )

            // Scheme operations
            case "create_scheme":
                guard let schemeName = args["scheme_name"]?.stringValue,
                      let targetName = args["target_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing scheme_name or target_name argument")
                }
                let testTargetName = args["test_target_name"]?.stringValue
                let buildConfiguration = args["build_configuration"]?.stringValue ?? "Debug"
                let shared = args["shared"]?.boolValue ?? true
                result = try await service.createScheme(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    targetName: targetName,
                    testTargetName: testTargetName,
                    buildConfiguration: buildConfiguration,
                    shared: shared
                )

            case "update_scheme":
                guard let schemeName = args["scheme_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing scheme_name argument")
                }
                let newName = args["new_name"]?.stringValue
                let buildConfiguration = args["build_configuration"]?.stringValue
                let codeCoverageEnabled = args["code_coverage_enabled"]?.boolValue
                result = try await service.updateScheme(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    newName: newName,
                    buildConfiguration: buildConfiguration,
                    codeCoverageEnabled: codeCoverageEnabled
                )

            case "delete_scheme":
                guard let schemeName = args["scheme_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing scheme_name argument")
                }
                result = try await service.deleteScheme(
                    projectPath: projectPath,
                    schemeName: schemeName
                )

            case "add_scheme_pre_action":
                guard let schemeName = args["scheme_name"]?.stringValue,
                      let actionType = args["action_type"]?.stringValue,
                      let script = args["script"]?.stringValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let title = args["title"]?.stringValue ?? "Run Script"
                let shellPath = args["shell_path"]?.stringValue ?? "/bin/sh"
                result = try await service.addSchemePreAction(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    actionType: actionType,
                    script: script,
                    title: title,
                    shellPath: shellPath
                )

            case "add_scheme_post_action":
                guard let schemeName = args["scheme_name"]?.stringValue,
                      let actionType = args["action_type"]?.stringValue,
                      let script = args["script"]?.stringValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let title = args["title"]?.stringValue ?? "Run Script"
                let shellPath = args["shell_path"]?.stringValue ?? "/bin/sh"
                result = try await service.addSchemePostAction(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    actionType: actionType,
                    script: script,
                    title: title,
                    shellPath: shellPath
                )

            case "set_scheme_environment_variables":
                guard let schemeName = args["scheme_name"]?.stringValue,
                      let actionType = args["action_type"]?.stringValue,
                      let variables = args["variables"]?.arrayValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let varsDict = variables.compactMap { value -> [String: Any]? in
                    guard case .object(let dict) = value else { return nil }
                    var result: [String: Any] = [:]
                    for (k, v) in dict {
                        if let str = v.stringValue {
                            result[k] = str
                        } else if let boolVal = v.boolValue {
                            result[k] = boolVal
                        }
                    }
                    return result
                }
                result = try await service.setSchemeEnvironmentVariables(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    actionType: actionType,
                    variables: varsDict
                )

            case "set_scheme_command_line_arguments":
                guard let schemeName = args["scheme_name"]?.stringValue,
                      let actionType = args["action_type"]?.stringValue,
                      let arguments = args["arguments"]?.arrayValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let argsDict = arguments.compactMap { value -> [String: Any]? in
                    guard case .object(let dict) = value else { return nil }
                    var result: [String: Any] = [:]
                    for (k, v) in dict {
                        if let str = v.stringValue {
                            result[k] = str
                        } else if let boolVal = v.boolValue {
                            result[k] = boolVal
                        }
                    }
                    return result
                }
                result = try await service.setSchemeCommandLineArguments(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    actionType: actionType,
                    arguments: argsDict
                )

            case "set_scheme_test_coverage":
                guard let schemeName = args["scheme_name"]?.stringValue,
                      let enabled = args["enabled"]?.boolValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let targetNames = args["target_names"]?.arrayValue?.compactMap { $0.stringValue }
                result = try await service.setSchemeTestCoverage(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    enabled: enabled,
                    targetNames: targetNames
                )

            case "add_scheme_testable":
                guard let schemeName = args["scheme_name"]?.stringValue,
                      let testTargetName = args["test_target_name"]?.stringValue else {
                    throw MCPError.invalidParams("Missing required arguments")
                }
                let skipped = args["skipped"]?.boolValue ?? false
                result = try await service.addSchemeTestable(
                    projectPath: projectPath,
                    schemeName: schemeName,
                    testTargetName: testTargetName,
                    skipped: skipped
                )

            default:
                throw MCPError.methodNotFound("Unknown tool: \(params.name)")
            }

            return CallTool.Result(content: [.text(result)])
        } catch let error as MCPError {
            throw error
        } catch {
            return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }
}
