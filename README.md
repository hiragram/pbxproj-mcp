# pbxproj-mcp

An MCP (Model Context Protocol) server for manipulating Xcode project files (.xcodeproj).

## Overview

pbxproj-mcp is an MCP server that provides read and write operations for Xcode project files using the [XcodeProj](https://github.com/tuist/XcodeProj) library. It enables AI assistants like Claude to directly manipulate Xcode projects.

## Features

### Read Operations

| Tool | Description |
|------|-------------|
| `get_project_info` | Get basic project information |
| `list_targets` | List all targets |
| `get_target_info` | Get detailed information for a specific target |
| `list_files` | List files in the project |
| `list_groups` | List groups in the project |
| `list_configurations` | List build configurations |
| `get_build_settings` | Get build settings |
| `list_build_phases` | List build phases |
| `get_build_phase_files` | List files in a build phase |
| `list_packages` | List Swift Package dependencies |
| `list_schemes` | List schemes |
| `get_scheme_info` | Get detailed scheme information |

### Write Operations

| Tool | Description |
|------|-------------|
| `update_build_setting` | Update a build setting |
| `add_file` | Add a file to the project |
| `remove_file` | Remove a file from the project |
| `add_group` | Add a group |
| `add_file_to_build_phase` | Add a file to a build phase |
| `add_run_script` | Add a Run Script phase |
| `update_run_script` | Update a Run Script phase |
| `add_target` | Add a target |
| `add_target_dependency` | Add a dependency between targets |
| `add_swift_package` | Add a remote Swift Package |
| `add_local_package` | Add a local Swift Package |

## Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Build

```bash
swift build -c release
```

The executable will be generated at `.build/release/pbxproj-mcp`.

### Claude Desktop Configuration

Add the following to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "pbxproj": {
      "command": "swx",
      "args": ["hiragram/pbxproj-mcp"]
    }
  }
}
```

## Usage Examples

### Get Project Information

```
Use get_project_info to check the project overview
```

### Add a File

```
Add NewFeature.swift to the Sources group
```

### Update Build Settings

```
Update SWIFT_VERSION to 5.9
```

## Development

### Project Structure

```
pbxproj/
├── Package.swift
├── Sources/
│   ├── Core/                    # Core library
│   │   └── XcodeProjService.swift
│   └── pbxproj-mcp/             # MCP server executable
│       ├── main.swift
│       └── ToolHandler.swift
└── Tests/
    └── CoreTests/               # Unit tests
        ├── XcodeProjServiceTests.swift
        ├── XcodeProjServiceWriteTests.swift
        └── Fixtures/            # Test fixtures
```

### Running Tests

```bash
swift test
```

### Dependencies

- [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) - MCP Swift SDK
- [XcodeProj](https://github.com/tuist/XcodeProj) - Xcode project manipulation library

## License

MIT
