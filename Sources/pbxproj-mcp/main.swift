import Foundation
import MCP

@main
struct PbxprojMCPServer {
    static func main() async throws {
        let server = Server(
            name: "pbxproj-mcp",
            version: "0.1.0",
            capabilities: .init(tools: .init())
        )

        // ツールハンドラの登録
        let toolHandler = ToolHandler()
        await toolHandler.register(to: server)

        // サーバー起動
        let transport = StdioTransport()
        try await server.start(transport: transport)

        // 終了を待機
        await server.waitUntilCompleted()
    }
}
