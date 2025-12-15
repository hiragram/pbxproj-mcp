# pbxproj MCP Tool Architecture

## 概要

Xcodeプロジェクトファイル（.pbxproj）を読み書きするMCPツールのアーキテクチャ設計。

## 使用ライブラリ

| ライブラリ | 用途 | バージョン |
|-----------|------|-----------|
| modelcontextprotocol/swift-sdk | MCPサーバー実装 | 0.10.0+ |
| tuist/XcodeProj | pbxproj操作 | 8.12.0+ |
| hiragram/swx | 配布・実行 | - |

## システム構成

```
┌─────────────────────────────────────────────────────────┐
│                    MCP Client (Claude等)                 │
└─────────────────────┬───────────────────────────────────┘
                      │ stdio (JSON-RPC)
                      ▼
┌─────────────────────────────────────────────────────────┐
│                 pbxproj-mcp-server                       │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Server (swift-sdk)                    │  │
│  │  - StdioTransport                                 │  │
│  │  - Tool handlers                                  │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │           XcodeProjService                        │  │
│  │  - XcodeProj (tuist/XcodeProj)                   │  │
│  │  - プロジェクト操作ロジック                        │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 実行方法

```bash
# swxを使用した実行
swx hiragram/pbxproj-mcp
```

### MCP設定例

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

## ディレクトリ構成

```
pbxproj-mcp/
├── Package.swift
├── Sources/
│   └── pbxproj-mcp/
│       ├── main.swift              # エントリーポイント
│       ├── Server/
│       │   └── PbxprojServer.swift # MCPサーバー設定
│       ├── Tools/
│       │   ├── Project/
│       │   │   └── GetProjectInfoTool.swift
│       │   ├── Targets/
│       │   │   ├── ListTargetsTool.swift
│       │   │   ├── GetTargetInfoTool.swift
│       │   │   └── AddTargetTool.swift
│       │   ├── Files/
│       │   │   ├── ListFilesTool.swift
│       │   │   ├── AddFileTool.swift
│       │   │   └── RemoveFileTool.swift
│       │   ├── BuildSettings/
│       │   │   ├── GetBuildSettingsTool.swift
│       │   │   └── UpdateBuildSettingTool.swift
│       │   ├── BuildPhases/
│       │   │   ├── ListBuildPhasesTool.swift
│       │   │   └── AddRunScriptTool.swift
│       │   ├── Packages/
│       │   │   ├── ListPackagesTool.swift
│       │   │   └── AddPackageTool.swift
│       │   └── Schemes/
│       │       └── ListSchemesTool.swift
│       └── Services/
│           └── XcodeProjService.swift
├── Tests/
└── docs/
    ├── architecture.md
    └── xcodeproj-api-reference.md
```

## Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pbxproj-mcp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "pbxproj-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
    ]
)
```

## 提案ツール一覧

### プロジェクト情報

| ツール名 | 説明 | Read/Write |
|---------|------|------------|
| `get_project_info` | プロジェクト全体の概要 | Read |

### ターゲット操作

| ツール名 | 説明 | Read/Write |
|---------|------|------------|
| `list_targets` | ターゲット一覧 | Read |
| `get_target_info` | ターゲット詳細 | Read |
| `add_target` | ターゲット追加 | Write |
| `add_target_dependency` | ターゲット依存追加 | Write |

### ファイル・グループ操作

| ツール名 | 説明 | Read/Write |
|---------|------|------------|
| `list_files` | ファイル一覧 | Read |
| `list_groups` | グループ一覧 | Read |
| `add_file` | ファイル追加 | Write |
| `add_group` | グループ追加 | Write |
| `remove_file` | ファイル削除 | Write |

### ビルド設定

| ツール名 | 説明 | Read/Write |
|---------|------|------------|
| `list_configurations` | Configuration一覧 | Read |
| `get_build_settings` | ビルド設定取得 | Read |
| `update_build_setting` | ビルド設定更新 | Write |

### ビルドフェーズ

| ツール名 | 説明 | Read/Write |
|---------|------|------------|
| `list_build_phases` | ビルドフェーズ一覧 | Read |
| `get_build_phase_files` | フェーズ内ファイル | Read |
| `add_file_to_build_phase` | ファイルをフェーズに追加 | Write |
| `add_run_script` | Run Scriptフェーズ追加 | Write |
| `update_run_script` | Run Script更新 | Write |

### Swift Package

| ツール名 | 説明 | Read/Write |
|---------|------|------------|
| `list_packages` | パッケージ一覧 | Read |
| `add_remote_package` | リモートパッケージ追加 | Write |
| `add_local_package` | ローカルパッケージ追加 | Write |

### スキーム

| ツール名 | 説明 | Read/Write |
|---------|------|------------|
| `list_schemes` | スキーム一覧 | Read |
| `get_scheme_info` | スキーム詳細 | Read |

## ツール引数設計

全てのツールで `project_path` 引数を必須とする。

```typescript
// 例: list_targets
{
  "project_path": "/path/to/Project.xcodeproj"
}

// 例: get_build_settings
{
  "project_path": "/path/to/Project.xcodeproj",
  "target_name": "MyApp",           // optional
  "configuration_name": "Debug"     // optional
}

// 例: add_file
{
  "project_path": "/path/to/Project.xcodeproj",
  "file_path": "/path/to/NewFile.swift",
  "group_path": "Sources/Models",   // optional, default: root
  "target_name": "MyApp"            // optional
}
```

## 実装上の考慮事項

### エラーハンドリング

| エラー種別 | 対応 |
|-----------|------|
| プロジェクトが存在しない | `XCodeProjError.notFound` |
| pbxprojが見つからない | `XCodeProjError.pbxprojNotFound` |
| ターゲットが見つからない | `PBXProjError.targetNotFound` |
| ファイルが存在しない | `XcodeprojEditingError.unexistingFile` |

### 書き込み操作の安全性

- `destructiveHint: true` をWriteツールに設定
- 変更前のバックアップ作成を検討（将来）

### 並行アクセス

- XcodeProjServiceをActorとして実装
- 同一プロジェクトへの同時書き込みを防止

## 次のステップ

1. プロジェクトの初期セットアップ
2. MCPサーバー基盤実装
3. 読み取り系ツールの実装（`get_project_info`, `list_targets`）
4. テスト作成
5. 書き込み系ツールの実装
6. swxでの配布テスト
