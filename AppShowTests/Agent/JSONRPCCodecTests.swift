import Foundation
import Testing

@testable import AppShow

struct JSONRPCCodecTests {
  private func line(_ text: String) -> Data {
    Data(text.utf8)
  }

  @Test func decodesRequestWithIntegerId() throws {
    let message = try JSONRPCCodec.decode(line(#"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#))
    guard case .request(let request) = message else {
      Issue.record("expected a request")
      return
    }
    #expect(request.id == .number(1))
    #expect(request.method == "tools/list")
    #expect(request.params == nil)
    #expect(request.isNotification == false)
  }

  @Test func decodesRequestWithStringIdAndObjectParams() throws {
    let message = try JSONRPCCodec.decode(
      line(#"{"jsonrpc":"2.0","id":"abc","method":"tools/call","params":{"name":"get_timeline","arguments":{}}}"#)
    )
    guard case .request(let request) = message else {
      Issue.record("expected a request")
      return
    }
    #expect(request.id == .string("abc"))
    #expect(request.params?["name"] == .string("get_timeline"))
    #expect(request.params?["arguments"] == .object([:]))
  }

  @Test func decodesNotificationWithoutIdAndToleratesMissingVersion() throws {
    let message = try JSONRPCCodec.decode(line(#"{"method":"notifications/initialized"}"#))
    guard case .request(let request) = message else {
      Issue.record("expected a request")
      return
    }
    #expect(request.id == nil)
    #expect(request.isNotification)
    #expect(request.method == "notifications/initialized")
  }

  @Test func decodesNullIdAsNotificationAndFloatIdAsInteger() throws {
    let nullId = try JSONRPCCodec.decode(line(#"{"jsonrpc":"2.0","id":null,"method":"ping"}"#))
    guard case .request(let first) = nullId else {
      Issue.record("expected a request")
      return
    }
    #expect(first.id == nil)
    let floatId = try JSONRPCCodec.decode(line(#"{"jsonrpc":"2.0","id":7.0,"method":"ping"}"#))
    guard case .request(let second) = floatId else {
      Issue.record("expected a request")
      return
    }
    #expect(second.id == .number(7))
  }

  @Test func decodesResponsesWithResultOrError() throws {
    let ok = try JSONRPCCodec.decode(line(#"{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}"#))
    guard case .response(let success) = ok else {
      Issue.record("expected a response")
      return
    }
    #expect(success.id == .number(2))
    #expect(success.result?["tools"] == .array([]))
    #expect(success.error == nil)
    let failed = try JSONRPCCodec.decode(
      line(#"{"jsonrpc":"2.0","id":3,"error":{"code":-32601,"message":"nope","data":{"code":"UNKNOWN_TOOL"}}}"#)
    )
    guard case .response(let failure) = failed else {
      Issue.record("expected a response")
      return
    }
    #expect(failure.error == JSONRPCError(code: -32601, message: "nope", data: ["code": "UNKNOWN_TOOL"]))
    #expect(failure.result == nil)
  }

  @Test func invalidJSONIsAParseErrorAndMissingMethodIsInvalidRequest() {
    #expect(throws: JSONRPCError.self) {
      try JSONRPCCodec.decode(line("{oops"))
    }
    do {
      _ = try JSONRPCCodec.decode(line("{oops"))
    } catch let error as JSONRPCError {
      #expect(error.code == JSONRPCError.parseErrorCode)
    } catch {
      Issue.record("unexpected error \(error)")
    }
    do {
      _ = try JSONRPCCodec.decode(line(#"{"jsonrpc":"2.0","id":1}"#))
    } catch let error as JSONRPCError {
      #expect(error.code == JSONRPCError.invalidRequestCode)
    } catch {
      Issue.record("unexpected error \(error)")
    }
  }

  @Test func encodesResponsesAsOneSortedLineWithTrailingNewline() throws {
    let success = JSONRPCResponse(id: .number(1), result: ["tools": []])
    let successLine = try JSONRPCCodec.encode(success)
    #expect(String(decoding: successLine, as: UTF8.self) == #"{"id":1,"jsonrpc":"2.0","result":{"tools":[]}}"# + "\n")
    let failure = JSONRPCResponse(
      id: .string("x"),
      error: JSONRPCError(code: -32601, message: "Unknown tool", data: ["code": "UNKNOWN_TOOL"])
    )
    let failureLine = try JSONRPCCodec.encode(failure)
    #expect(
      String(decoding: failureLine, as: UTF8.self)
        == #"{"error":{"code":-32601,"data":{"code":"UNKNOWN_TOOL"},"message":"Unknown tool"},"id":"x","jsonrpc":"2.0"}"# + "\n"
    )
    let request = JSONRPCRequest(id: .number(9), method: "initialize", params: ["token": "t"])
    let requestLine = try JSONRPCCodec.encode(request)
    #expect(
      String(decoding: requestLine, as: UTF8.self) == #"{"id":9,"jsonrpc":"2.0","method":"initialize","params":{"token":"t"}}"# + "\n"
    )
    let notification = JSONRPCRequest(id: nil, method: "notifications/initialized", params: nil)
    #expect(
      String(decoding: try JSONRPCCodec.encode(notification), as: UTF8.self) == #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#
        + "\n"
    )
  }

  @Test func responseRoundTripsThroughDecode() throws {
    let response = JSONRPCResponse(id: .number(5), result: ["a": [1, 2]])
    let decoded = try JSONRPCCodec.decode(try JSONRPCCodec.encode(response))
    #expect(decoded == .response(response))
  }

  @Test func lineBufferSplitsFramesAndKeepsPartialTail() {
    var buffer = JSONRPCLineBuffer()
    #expect(buffer.append(Data(#"{"id":1,"method":"a"}"#.utf8)).isEmpty)
    #expect(buffer.pendingByteCount > 0)
    let lines = buffer.append(Data("}\n\r\n{\"id\":2,\"method\":\"b\"}\n{\"id\":3".utf8))
    #expect(lines.map { String(decoding: $0, as: UTF8.self) } == [#"{"id":1,"method":"a"}}"#, #"{"id":2,"method":"b"}"#])
    #expect(String(decoding: buffer.flush(), as: UTF8.self) == #"{"id":3"#)
    #expect(buffer.pendingByteCount == 0)
  }

  @Test func lineBufferStripsCarriageReturnsAndSkipsBlankLines() {
    var buffer = JSONRPCLineBuffer()
    let lines = buffer.append(Data("\n\n{\"a\":1}\r\n\n".utf8))
    #expect(lines.map { String(decoding: $0, as: UTF8.self) } == [#"{"a":1}"#])
  }

  @Test func standardErrorsCarryTheirCodes() {
    #expect(JSONRPCError.parseError("x").code == -32700)
    #expect(JSONRPCError.invalidRequest("x").code == -32600)
    #expect(JSONRPCError.methodNotFound("m").code == -32601)
    #expect(JSONRPCError.methodNotFound("m").message.contains("m"))
    #expect(JSONRPCError.invalidParams("x").code == -32602)
    #expect(JSONRPCError.internalError("x").code == -32603)
  }
}
