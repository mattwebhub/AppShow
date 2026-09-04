import Foundation

struct AgentSessionConfig: Sendable, Equatable {
  static let serverName = "appshow"
  static let claudeConfigFileName = "mcp.json"

  var workspace: AgentWorkspace
  var helperURL: URL

  var claudeConfigURL: URL {
    workspace.directory.appendingPathComponent(Self.claudeConfigFileName)
  }

  var processEnvironment: [String: String] {
    [
      "REFRAMED_AGENT_SOCKET": workspace.socketURL.path,
      "REFRAMED_AGENT_TOKEN": workspace.token,
    ]
  }

  var claudeArguments: [String] {
    [
      "--mcp-config", claudeConfigURL.path,
      "--strict-mcp-config",
      "--allowedTools", "mcp__\(Self.serverName)__*",
    ]
  }

  var codexArguments: [String] {
    let command = Self.tomlString(helperURL.path)
    let socket = Self.tomlString(workspace.socketURL.path)
    let token = Self.tomlString(workspace.token)
    return [
      "-c", "mcp_servers={}",
      "-c", "mcp_servers.\(Self.serverName).command=\(command)",
      "-c",
      "mcp_servers.\(Self.serverName).env={REFRAMED_AGENT_SOCKET=\(socket),REFRAMED_AGENT_TOKEN=\(token)}",
      "-c", "mcp_servers.\(Self.serverName).env_vars=[\"REFRAMED_AGENT_SOCKET\",\"REFRAMED_AGENT_TOKEN\"]",
      "-c", "mcp_servers.\(Self.serverName).tool_timeout_sec=600",
      "-c", "mcp_servers.\(Self.serverName).default_tools_approval_mode=\"approve\"",
    ]
  }

  func claudeMCPConfigJSON() throws -> JSONValue {
    [
      "mcpServers": [
        Self.serverName: [
          "type": "stdio",
          "command": .string(helperURL.path),
          "env": .object(processEnvironment.mapValues(JSONValue.string)),
        ]
      ]
    ]
  }

  @discardableResult
  func writeClaudeMCPConfig() throws -> URL {
    let data = try claudeMCPConfigJSON().data()
    try data.write(to: claudeConfigURL, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: claudeConfigURL.path)
    return claudeConfigURL
  }

  private static func tomlString(_ value: String) -> String {
    (try? JSONValue.string(value).jsonString()) ?? "\"\""
  }
}
