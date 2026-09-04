import Foundation
import Testing

@testable import Reframed

struct AgentToolCatalogTests {
  private static let expectedNames: Set<String> = [
    "get_project_summary", "get_timeline", "get_transcript", "get_cursor_activity", "get_history", "render_preview_frame",
  ]

  @Test func everyToolHasUniqueSnakeCaseNameAndObjectSchema() throws {
    let names = AgentToolCatalog.all.map(\.name)
    #expect(Set(names).count == names.count)
    let pattern = try Regex("^[a-z][a-z0-9_]*$")
    for tool in AgentToolCatalog.all {
      #expect(tool.name.wholeMatch(of: pattern) != nil, "\(tool.name) is not snake_case")
      #expect(!tool.description.isEmpty, "\(tool.name) has no description")
      #expect(tool.inputSchema["type"] == "object", "\(tool.name) schema is not an object")
      #expect(tool.inputSchema["additionalProperties"] == false, "\(tool.name) allows unknown keys")
      #expect(tool.inputSchema["properties"]?.objectValue != nil, "\(tool.name) schema has no properties")
      for (key, property) in tool.inputSchema["properties"]?.objectValue ?? [:] {
        #expect(property["type"]?.stringValue != nil, "\(tool.name).\(key) has no type")
        #expect(property["description"]?.stringValue?.isEmpty == false, "\(tool.name).\(key) has no description")
      }
      let required = tool.inputSchema["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
      for key in required {
        #expect(tool.inputSchema["properties"]?[key] != nil, "\(tool.name) requires unknown key \(key)")
      }
    }
  }

  @Test func noToolIsMutatingInThisMilestone() {
    #expect(AgentToolCatalog.all.allSatisfy { !$0.mutating })
    #expect(AgentToolCatalog.all.filter { $0.name.hasPrefix("get_") }.allSatisfy { !$0.mutating && !$0.slow })
    #expect(AgentToolCatalog.definition(named: "render_preview_frame")?.slow == true)
  }

  @Test func toolsListAdvertisesOnlyAvailableToolsInMCPShape() throws {
    let list = AgentToolCatalog.toolsListResult
    let tools = try #require(list["tools"]?.arrayValue)
    #expect(Set(tools.compactMap { $0["name"]?.stringValue }) == Self.expectedNames)
    for tool in tools {
      #expect(tool["description"]?.stringValue?.isEmpty == false)
      #expect(tool["inputSchema"]?["type"] == "object")
      #expect(tool["annotations"]?["readOnlyHint"] == true)
      #expect(tool["annotations"]?["destructiveHint"] == false)
    }
    let timeline = try #require(tools.first { $0["name"] == "get_timeline" })
    #expect(timeline["inputSchema"]?["properties"]?["detail"]?["enum"] == ["summary", "full"])
    let roundTrip = try JSONValue.parse(try list.data())
    #expect(roundTrip == list)
  }

  @Test func pendingMergeToolIsListedInAllButNotAvailable() throws {
    let silences = try #require(AgentToolCatalog.definition(named: "get_silences"))
    #expect(silences.availability == .pendingMerge(branch: "milestone-07-primitives"))
    #expect(silences.isAvailable == false)
    #expect(AgentToolCatalog.available.contains { $0.name == "get_silences" } == false)
    #expect(AgentToolCatalog.all.contains { $0.name == "get_silences" })
    #expect(Set(AgentToolCatalog.available.map(\.name)) == Self.expectedNames)
  }

  @Test func schemaValidationRejectsBadArgumentsBeforeAnyToolRuns() throws {
    let preview = try #require(AgentToolCatalog.definition(named: "render_preview_frame")).inputSchema
    let timeline = try #require(AgentToolCatalog.definition(named: "get_timeline")).inputSchema

    #expect(try AgentToolSchema.validate(["atSeconds": 1], against: preview) == ["atSeconds": 1])
    #expect(try AgentToolSchema.validate(nil, against: timeline) == [:])
    #expect(try AgentToolSchema.validate(.null, against: timeline) == [:])
    #expect(try AgentToolSchema.validate(["detail": "full"], against: timeline) == ["detail": "full"])

    func failure(_ arguments: JSONValue?, _ schema: JSONValue) -> String? {
      do {
        _ = try AgentToolSchema.validate(arguments, against: schema)
        return nil
      } catch let error as AgentToolError {
        guard case .invalidArguments(let message) = error else { return "wrong case \(error)" }
        return message
      } catch {
        return "unexpected \(error)"
      }
    }
    #expect(failure([:], preview)?.contains("atSeconds") == true)
    #expect(failure(["atSeconds": "one"], preview)?.contains("number") == true)
    #expect(failure(["atSeconds": -1], preview)?.contains("minimum") == true)
    #expect(failure(["atSeconds": 1, "width": 8], preview)?.contains("minimum") == true)
    #expect(failure(["atSeconds": 1, "width": 4000], preview)?.contains("maximum") == true)
    #expect(failure(["atSeconds": 1, "width": 1.5], preview)?.contains("integer") == true)
    #expect(failure(["atSeconds": 1, "extra": true], preview)?.contains("extra") == true)
    #expect(failure(["detail": "nope"], timeline)?.contains("summary") == true)
    #expect(failure([1, 2], timeline)?.contains("object") == true)
  }

  @Test func schemaValidationRecursesIntoArrayItems() throws {
    let schema = AgentToolSchema.object(
      [
        "slices": AgentToolSchema.array(
          "Kept source-time slices",
          items: AgentToolSchema.object(
            [
              "start": AgentToolSchema.number("Start", minimum: 0),
              "end": AgentToolSchema.number("End", minimum: 0),
            ],
            required: ["start", "end"]
          ),
          minimumItems: 1
        )
      ],
      required: ["slices"]
    )

    #expect(throws: AgentToolError.invalidArguments("slices must contain at least 1 item")) {
      try AgentToolSchema.validate(["slices": []], against: schema)
    }
    #expect(throws: AgentToolError.invalidArguments("slices[0].end is below the minimum 0.0")) {
      try AgentToolSchema.validate(["slices": [["start": 0, "end": -1]]], against: schema)
    }
    #expect(throws: AgentToolError.invalidArguments("slices[0] missing required key end")) {
      try AgentToolSchema.validate(["slices": [["start": 0]]], against: schema)
    }
  }

  @Test func toolErrorsMapToJSONRPCCodes() {
    #expect(AgentToolError.unknownTool("x").jsonRPCError.code == JSONRPCError.methodNotFoundCode)
    #expect(AgentToolError.unknownTool("x").jsonRPCError.data?["code"] == "UNKNOWN_TOOL")
    #expect(AgentToolError.invalidArguments("x").jsonRPCError.code == JSONRPCError.invalidParamsCode)
    #expect(AgentToolError.invalidArguments("x").code == "TOOL_ARGUMENTS_INVALID")
    #expect(AgentToolError.mutationNotAllowed("x").jsonRPCError.code == -32003)
    #expect(AgentToolError.unavailable(name: "x", reason: "r").jsonRPCError.code == -32004)
    #expect(AgentToolError.unavailable(name: "x", reason: "r").code == "TOOL_UNAVAILABLE")
    #expect(AgentToolError.timedOut("x").code == "TOOL_TIMEOUT")
    #expect(AgentToolError.batchTimedOut.jsonRPCError.data?["code"] == "BATCH_TIMEOUT")
    #expect(AgentToolError.userUndo.jsonRPCError.data?["code"] == "USER_UNDO")
    #expect(AgentToolError.failed("x").jsonRPCError.code == -32000)
    #expect(AgentToolError.failed("boom").message == "boom")
  }
}
