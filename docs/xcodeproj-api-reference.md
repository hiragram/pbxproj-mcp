# XcodeProj API Reference

tuist/XcodeProj ライブラリの主要APIをまとめたリファレンス。

## 主要クラス階層

```
XcodeProj (エントリーポイント)
├── workspace: XCWorkspace
├── pbxproj: PBXProj
├── sharedData: XCSharedData?
└── userData: [XCUserData]

PBXProj
├── rootObject: PBXProject?
├── archiveVersion: UInt
├── objectVersion: UInt
└── objects: PBXObjects (内部)

PBXProject
├── name: String
├── buildConfigurationList: XCConfigurationList
├── mainGroup: PBXGroup
├── productsGroup: PBXGroup?
├── targets: [PBXTarget]
├── remotePackages: [XCRemoteSwiftPackageReference]
├── localPackages: [XCLocalSwiftPackageReference]
└── attributes: [String: ProjectAttribute]
```

---

## 1. プロジェクト情報

### XcodeProj

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `init(path:)` | `throws` | プロジェクトを読み込む |
| `write(path:override:)` | `throws` | プロジェクトを保存 |
| `pbxproj` | `PBXProj` | PBXProjオブジェクト |
| `workspace` | `XCWorkspace` | ワークスペース |
| `sharedData` | `XCSharedData?` | 共有データ（スキーム等） |
| `userData` | `[XCUserData]` | ユーザーデータ |
| `path` | `Path?` | プロジェクトパス |

### PBXProj

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `rootProject()` | `PBXProject? throws` | ルートプロジェクト取得 |
| `rootGroup()` | `PBXGroup? throws` | ルートグループ取得 |
| `archiveVersion` | `UInt` | アーカイブバージョン |
| `objectVersion` | `UInt` | オブジェクトバージョン |
| `add(object:)` | `void` | オブジェクト追加 |
| `delete(object:)` | `void` | オブジェクト削除 |
| `targets(named:)` | `[PBXTarget]` | 名前でターゲット検索 |
| `forEach(_:)` | `void` | 全オブジェクトを走査 |
| `batchUpdate(sourceRoot:closure:)` | `throws` | 大量更新の最適化 |

### PBXProject

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `name` | `String` | プロジェクト名 |
| `compatibilityVersion` | `String?` | 互換性バージョン |
| `developmentRegion` | `String?` | 開発リージョン |
| `knownRegions` | `[String]` | 既知のリージョン一覧 |
| `mainGroup` | `PBXGroup!` | メイングループ |
| `productsGroup` | `PBXGroup?` | Productsグループ |
| `buildConfigurationList` | `XCConfigurationList!` | ビルド設定リスト |
| `targets` | `[PBXTarget]` | ターゲット一覧 |
| `attributes` | `[String: ProjectAttribute]` | プロジェクト属性 |
| `targetAttributes` | `[PBXTarget: [String: ProjectAttribute]]` | ターゲット属性 |

---

## 2. ターゲット操作

### PBXProj - ターゲット取得

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `nativeTargets` | `[PBXNativeTarget]` | ネイティブターゲット一覧 |
| `aggregateTargets` | `[PBXAggregateTarget]` | アグリゲートターゲット一覧 |
| `legacyTargets` | `[PBXLegacyTarget]` | レガシーターゲット一覧 |
| `targetDependencies` | `[PBXTargetDependency]` | ターゲット依存一覧 |

### PBXTarget (基底クラス)

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `name` | `String` | ターゲット名 |
| `productName` | `String?` | 製品名 |
| `productType` | `PBXProductType?` | 製品タイプ |
| `product` | `PBXFileReference?` | 製品ファイル参照 |
| `buildPhases` | `[PBXBuildPhase]` | ビルドフェーズ一覧 |
| `buildRules` | `[PBXBuildRule]` | ビルドルール一覧 |
| `dependencies` | `[PBXTargetDependency]` | ターゲット依存関係 |
| `buildConfigurationList` | `XCConfigurationList?` | ビルド設定リスト |
| `packageProductDependencies` | `[XCSwiftPackageProductDependency]?` | パッケージ依存 |
| `productNameWithExtension()` | `String?` | 拡張子付き製品名 |
| `frameworksBuildPhase()` | `PBXFrameworksBuildPhase? throws` | フレームワークフェーズ |
| `sourcesBuildPhase()` | `PBXSourcesBuildPhase? throws` | ソースフェーズ |
| `resourcesBuildPhase()` | `PBXResourcesBuildPhase? throws` | リソースフェーズ |
| `sourceFiles()` | `[PBXFileElement] throws` | ソースファイル一覧 |
| `embedFrameworksBuildPhases()` | `[PBXCopyFilesBuildPhase]` | 埋め込みフレームワークフェーズ |
| `runScriptBuildPhases()` | `[PBXShellScriptBuildPhase]` | スクリプトフェーズ |

### PBXNativeTarget

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `productInstallPath` | `String?` | 製品インストールパス |
| `addDependency(target:)` | `PBXTargetDependency? throws` | ターゲット依存を追加 |

### PBXProductType (enum)

```swift
case none = ""
case application = "com.apple.product-type.application"
case framework = "com.apple.product-type.framework"
case staticFramework = "com.apple.product-type.framework.static"
case xcFramework = "com.apple.product-type.xcframework"
case dynamicLibrary = "com.apple.product-type.library.dynamic"
case staticLibrary = "com.apple.product-type.library.static"
case bundle = "com.apple.product-type.bundle"
case unitTestBundle = "com.apple.product-type.bundle.unit-test"
case uiTestBundle = "com.apple.product-type.bundle.ui-testing"
case appExtension = "com.apple.product-type.app-extension"
case extensionKitExtension = "com.apple.product-type.extensionkit-extension"
case commandLineTool = "com.apple.product-type.tool"
case watchApp = "com.apple.product-type.application.watchapp"
case watch2App = "com.apple.product-type.application.watchapp2"
case watch2AppContainer = "com.apple.product-type.application.watchapp2-container"
case watchExtension = "com.apple.product-type.watchkit-extension"
case watch2Extension = "com.apple.product-type.watchkit2-extension"
case tvExtension = "com.apple.product-type.tv-app-extension"
case messagesApplication = "com.apple.product-type.application.messages"
case messagesExtension = "com.apple.product-type.app-extension.messages"
case stickerPack = "com.apple.product-type.app-extension.messages-sticker-pack"
case xpcService = "com.apple.product-type.xpc-service"
case ocUnitTestBundle = "com.apple.product-type.bundle.ocunit-test"
case xcodeExtension = "com.apple.product-type.xcode-extension"
case instrumentsPackage = "com.apple.product-type.instruments-package"
case intentsServiceExtension = "com.apple.product-type.app-extension.intents-service"
case onDemandInstallCapableApplication = "com.apple.product-type.application.on-demand-install-capable"
case metalLibrary = "com.apple.product-type.metal-library"
case driverExtension = "com.apple.product-type.driver-extension"
case systemExtension = "com.apple.product-type.system-extension"
```

`fileExtension` プロパティで対応するファイル拡張子を取得可能。

---

## 3. ファイル・グループ操作

### PBXProj - ファイル/グループ取得

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `fileReferences` | `[PBXFileReference]` | 全ファイル参照 |
| `groups` | `[PBXGroup]` | 全グループ |
| `variantGroups` | `[PBXVariantGroup]` | バリアントグループ |
| `versionGroups` | `[XCVersionGroup]` | バージョングループ |
| `referenceProxies` | `[PBXReferenceProxy]` | 参照プロキシ |

### PBXGroup

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `children` | `[PBXFileElement]` | 子要素一覧 |
| `group(named:)` | `PBXGroup?` | 名前でグループ検索 |
| `group(with:)` | `PBXGroup?` | パスでグループ検索 |
| `file(named:)` | `PBXFileReference?` | 名前でファイル検索 |
| `addGroup(named:options:)` | `[PBXGroup] throws` | グループ作成 |
| `addVariantGroup(named:)` | `[PBXVariantGroup] throws` | バリアントグループ作成 |
| `addFile(at:sourceTree:sourceRoot:override:validatePresence:)` | `PBXFileReference throws` | ファイル追加 |

### GroupAddingOptions (OptionSet)

```swift
static let withoutFolder  // フォルダ参照なしでグループ作成
```

### PBXFileReference

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `path` | `String?` | ファイルパス |
| `name` | `String?` | ファイル名 |
| `fileEncoding` | `UInt?` | ファイルエンコーディング |
| `explicitFileType` | `String?` | 明示的ファイルタイプ |
| `lastKnownFileType` | `String?` | 推測ファイルタイプ |
| `lineEnding` | `UInt?` | 改行タイプ |
| `expectedSignature` | `String?` | XCFramework署名 |

### PBXFileElement (基底クラス)

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `sourceTree` | `PBXSourceTree?` | ソースツリー |
| `path` | `String?` | パス |
| `name` | `String?` | 名前 |
| `includeInIndex` | `Bool?` | インデックスに含める |
| `usesTabs` | `Bool?` | タブ使用 |
| `indentWidth` | `UInt?` | インデント幅 |
| `tabWidth` | `UInt?` | タブ幅 |
| `wrapsLines` | `Bool?` | 行折り返し |

### PBXSourceTree (enum)

```swift
case none = ""
case absolute = "<absolute>"
case group = "<group>"
case sourceRoot = "SOURCE_ROOT"
case buildProductsDir = "BUILT_PRODUCTS_DIR"
case sdkRoot = "SDKROOT"
case developerDir = "DEVELOPER_DIR"
```

---

## 4. ビルド設定

### PBXProj - 設定取得

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `buildConfigurations` | `[XCBuildConfiguration]` | 全ビルド設定 |
| `configurationLists` | `[XCConfigurationList]` | 全設定リスト |

### XCConfigurationList

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `buildConfigurations` | `[XCBuildConfiguration]` | ビルド設定一覧 |
| `defaultConfigurationName` | `String?` | デフォルト設定名 |
| `defaultConfigurationIsVisible` | `Bool` | デフォルト設定の可視性 |
| `configuration(name:)` | `XCBuildConfiguration?` | 名前で設定取得 |
| `addDefaultConfigurations()` | `[XCBuildConfiguration] throws` | Debug/Release追加 |
| `objectWithConfigurationList()` | `PBXObject? throws` | 親オブジェクト取得 |

### XCBuildConfiguration

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `name` | `String` | 設定名 (Debug/Release等) |
| `buildSettings` | `BuildSettings` | ビルド設定辞書 |
| `baseConfiguration` | `PBXFileReference?` | ベースxcconfig |
| `append(setting:value:)` | `void` | 設定に値を追加 |

### BuildSettings

`[String: BuildSetting]` 型のエイリアス。

```swift
enum BuildSetting {
    case string(String)
    case array([String])
}
```

---

## 5. ビルドフェーズ

### PBXProj - フェーズ取得

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `buildPhases` | `[PBXBuildPhase]` | 全ビルドフェーズ |
| `sourcesBuildPhases` | `[PBXSourcesBuildPhase]` | ソースフェーズ |
| `resourcesBuildPhases` | `[PBXResourcesBuildPhase]` | リソースフェーズ |
| `frameworksBuildPhases` | `[PBXFrameworksBuildPhase]` | フレームワークフェーズ |
| `headersBuildPhases` | `[PBXHeadersBuildPhase]` | ヘッダーフェーズ |
| `copyFilesBuildPhases` | `[PBXCopyFilesBuildPhase]` | コピーファイルフェーズ |
| `shellScriptBuildPhases` | `[PBXShellScriptBuildPhase]` | シェルスクリプトフェーズ |
| `carbonResourcesBuildPhases` | `[PBXRezBuildPhase]` | Rezフェーズ |
| `buildFiles` | `[PBXBuildFile]` | 全ビルドファイル |

### PBXBuildPhase (基底クラス)

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `files` | `[PBXBuildFile]?` | ビルドファイル一覧 |
| `buildActionMask` | `UInt` | ビルドアクションマスク |
| `runOnlyForDeploymentPostprocessing` | `Bool` | デプロイ時のみ実行 |
| `inputFileListPaths` | `[String]?` | 入力ファイルリスト |
| `outputFileListPaths` | `[String]?` | 出力ファイルリスト |
| `buildPhase` | `BuildPhase` | フェーズタイプ (abstract) |
| `add(file:)` | `PBXBuildFile throws` | ファイルを追加 |
| `name()` | `String?` | フェーズ名 |

### PBXShellScriptBuildPhase

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `name` | `String?` | スクリプト名 |
| `shellPath` | `String?` | シェルパス (デフォルト: /bin/sh) |
| `shellScript` | `String?` | スクリプト内容 |
| `inputPaths` | `[String]` | 入力パス |
| `outputPaths` | `[String]` | 出力パス |
| `showEnvVarsInLog` | `Bool` | ログに環境変数表示 |
| `alwaysOutOfDate` | `Bool` | 常に実行 |
| `dependencyFile` | `String?` | 依存ファイル |

### PBXCopyFilesBuildPhase

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `name` | `String?` | フェーズ名 |
| `dstPath` | `String?` | コピー先パス |
| `dstSubfolderSpec` | `SubFolder?` | コピー先フォルダ種別 |

### SubFolder (enum)

```swift
case absolutePath = 0
case productsDirectory = 16
case wrapper = 1
case executables = 6
case resources = 7
case javaResources = 15
case frameworks = 10
case sharedFrameworks = 11
case sharedSupport = 12
case plugins = 13
case other
```

### BuildPhase (enum)

```swift
case sources
case frameworks
case resources
case copyFiles
case runScript
case headers
case carbonResources
```

---

## 6. 依存関係

### PBXTargetDependency

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `name` | `String?` | 依存名 |
| `target` | `PBXTarget?` | 依存先ターゲット |
| `targetProxy` | `PBXContainerItemProxy?` | ターゲットプロキシ |

### XCRemoteSwiftPackageReference

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `repositoryURL` | `String?` | リポジトリURL |
| `versionRequirement` | `VersionRequirement?` | バージョン要件 |
| `name` | `String?` | パッケージ名 (計算) |

### VersionRequirement (enum)

```swift
case upToNextMajorVersion(String)
case upToNextMinorVersion(String)
case range(from: String, to: String)
case exact(String)
case branch(String)
case revision(String)
```

### XCLocalSwiftPackageReference

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `relativePath` | `String?` | 相対パス |
| `name` | `String?` | パッケージ名 |

### PBXProject - パッケージ操作

| メソッド | 説明 |
|---------|------|
| `addSwiftPackage(repositoryURL:productName:versionRequirement:targetName:)` | リモートパッケージ追加 |
| `addLocalSwiftPackage(path:productName:targetName:addFileReference:)` | ローカルパッケージ追加 |

---

## 7. スキーム操作

### XCSharedData

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `schemes` | `[XCScheme]` | 共有スキーム一覧 |
| `breakpoints` | `XCBreakpointList?` | ブレークポイント |
| `workspaceSettings` | `WorkspaceSettings?` | ワークスペース設定 |
| `init(path:)` | `throws` | 読み込み |
| `write(path:override:)` | `throws` | 保存 |

### XCScheme

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `name` | `String` | スキーム名 |
| `lastUpgradeVersion` | `String?` | 最終アップグレードバージョン |
| `version` | `String?` | バージョン |
| `buildAction` | `BuildAction?` | ビルドアクション |
| `testAction` | `TestAction?` | テストアクション |
| `launchAction` | `LaunchAction?` | 起動アクション |
| `profileAction` | `ProfileAction?` | プロファイルアクション |
| `analyzeAction` | `AnalyzeAction?` | 解析アクション |
| `archiveAction` | `ArchiveAction?` | アーカイブアクション |
| `wasCreatedForAppExtension` | `Bool?` | App Extension用か |
| `init(path:)` | `throws` | 読み込み |
| `write(path:override:)` | `throws` | 保存 |

---

## 8. ワークスペース操作

### XCWorkspace

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `data` | `XCWorkspaceData` | ワークスペースデータ |
| `init(path:)` | `throws` | 読み込み |
| `write(path:override:)` | `throws` | 保存 |

### XCWorkspaceData

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `children` | `[XCWorkspaceDataElement]` | 子要素 |

---

## 9. ユーティリティ

### Xcode (定数)

```swift
Xcode.LastKnown.archiveVersion   // 最新アーカイブバージョン
Xcode.LastKnown.objectVersion    // 最新オブジェクトバージョン
Xcode.LastKnown.swiftVersion     // 最新Swiftバージョン
Xcode.Default.compatibilityVersion  // デフォルト互換性バージョン
Xcode.Default.developmentRegion     // デフォルト開発リージョン
Xcode.filetype(extension:)          // 拡張子からファイルタイプ取得
```

### XCConfig

| プロパティ/メソッド | 型 | 説明 |
|-------------------|---|------|
| `init(path:)` | `throws` | xcconfig読み込み |
| `buildSettings` | `BuildSettings` | ビルド設定 |
| `includes` | `[XCConfig]` | インクルード設定 |

---

## 使用例

### プロジェクト読み込みと保存

```swift
import XcodeProj
import PathKit

let path = Path("/path/to/Project.xcodeproj")
let xcodeproj = try XcodeProj(path: path)

// 変更...

try xcodeproj.write(path: path)
```

### ターゲット一覧取得

```swift
let targets = xcodeproj.pbxproj.nativeTargets
for target in targets {
    print("Target: \(target.name)")
    print("  Product Type: \(target.productType?.rawValue ?? "none")")
}
```

### ビルド設定の変更

```swift
for target in xcodeproj.pbxproj.nativeTargets {
    for config in target.buildConfigurationList?.buildConfigurations ?? [] {
        config.buildSettings["SWIFT_VERSION"] = "5.0"
    }
}
```

### ファイル追加

```swift
let mainGroup = try xcodeproj.pbxproj.rootGroup()!
let sourceRoot = Path("/path/to/project")
let filePath = Path("/path/to/project/NewFile.swift")

let fileRef = try mainGroup.addFile(
    at: filePath,
    sourceTree: .group,
    sourceRoot: sourceRoot
)

// ソースビルドフェーズに追加
if let target = xcodeproj.pbxproj.nativeTargets.first,
   let sourcesPhase = try target.sourcesBuildPhase() {
    _ = try sourcesPhase.add(file: fileRef)
}
```

### Swift Package追加

```swift
let project = try xcodeproj.pbxproj.rootProject()!
let package = try project.addSwiftPackage(
    repositoryURL: "https://github.com/Alamofire/Alamofire.git",
    productName: "Alamofire",
    versionRequirement: .upToNextMajorVersion("5.0.0"),
    targetName: "MyApp"
)
```

### Run Scriptフェーズ追加

```swift
let scriptPhase = PBXShellScriptBuildPhase(
    name: "SwiftLint",
    shellPath: "/bin/sh",
    shellScript: "swiftlint"
)
xcodeproj.pbxproj.add(object: scriptPhase)
target.buildPhases.append(scriptPhase)
```
