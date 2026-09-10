import Foundation

enum JSONRPCID: Sendable, Equatable, Hashable {
  case number(Int)
  case string(String)

  var jsonValue: JSONValue {
    switch self {
    case .number(let value): .number(Double(value))
    case .string(let value): .string(value)
    }
  }

  init?(_ value: JSONValue?) {
    switch value {
    case .some(.string(let text)): self = .string(text)
    case .some(.number(let number)):
      guard let integer = JSONValue.number(number).intValue else { return nil }
      self = .number(integer)
    default: return nil
    }
  }
}

struct JSONRPCRequest: Sendable, Equatable {
  var id: JSONRPCID?
  var method: String
  var params: JSONValue?

  var isNotification: Bool { id == nil }

  var jsonValue: JSONValue {
    var object: [String: JSONValue] = ["jsonrpc": "2.0", "method": .string(method)]
    if let id { object["id"] = id.jsonValue }
    if let params { object["params"] = params }
    return .object(object)
  }
}

struct JSONRPCError: Error, Sendable, Equatable {
  static let parseErrorCode = -32700
  static let invalidRequestCode = -32600
  static let methodNotFoundCode = -32601
  static let invalidParamsCode = -32602
  static let internalErrorCode = -32603

  var code: Int
  var message: String
  var data: JSONValue?

  init(code: Int, message: String, data: JSONValue? = nil) {
    self.code = code
    self.message = message
    self.data = data
  }

  static func parseError(_ detail: String) -> JSONRPCError {
    JSONRPCError(code: parseErrorCode, message: "Parse error: \(detail)")
  }

  static func invalidRequest(_ detail: String) -> JSONRPCError {
    JSONRPCError(code: invalidRequestCode, message: "Invalid request: \(detail)")
  }

  static func methodNotFound(_ method: String) -> JSONRPCError {
    JSONRPCError(code: methodNotFoundCode, message: "Method not found: \(method)")
  }

  static func invalidParams(_ detail: String) -> JSONRPCError {
    JSONRPCError(code: invalidParamsCode, message: "Invalid params: \(detail)")
  }

  static func internalError(_ detail: String) -> JSONRPCError {
    JSONRPCError(code: internalErrorCode, message: "Internal error: \(detail)")
  }

  var jsonValue: JSONValue {
    var object: [String: JSONValue] = ["code": .number(Double(code)), "message": .string(message)]
    if let data { object["data"] = data }
    return .object(object)
  }

  init?(_ value: JSONValue?) {
    guard let value, let code = value["code"]?.intValue, let message = value["message"]?.stringValue else { return nil }
    self.init(code: code, message: message, data: value["data"])
  }
}

struct JSONRPCResponse: Sendable, Equatable {
  var id: JSONRPCID?
  var result: JSONValue?
  var error: JSONRPCError?

  init(id: JSONRPCID?, result: JSONValue) {
    self.id = id
    self.result = result
    self.error = nil
  }

  init(id: JSONRPCID?, error: JSONRPCError) {
    self.id = id
    self.result = nil
    self.error = error
  }

  var jsonValue: JSONValue {
    var object: [String: JSONValue] = ["jsonrpc": "2.0", "id": id?.jsonValue ?? .null]
    if let error {
      object["error"] = error.jsonValue
    } else {
      object["result"] = result ?? .null
    }
    return .object(object)
  }
}

enum JSONRPCMessage: Sendable, Equatable {
  case request(JSONRPCRequest)
  case response(JSONRPCResponse)
}

enum JSONRPCCodec {
  static func decode(_ line: Data) throws -> JSONRPCMessage {
    let value: JSONValue
    do {
      value = try JSONValue.parse(line)
    } catch {
      throw JSONRPCError.parseError(error.localizedDescription)
    }
    guard case .object(let object) = value else {
      throw JSONRPCError.invalidRequest("message is not an object")
    }
    let id = JSONRPCID(object["id"])
    if let method = object["method"]?.stringValue {
      return .request(JSONRPCRequest(id: id, method: method, params: object["params"]))
    }
    if let error = JSONRPCError(object["error"]) {
      return .response(JSONRPCResponse(id: id, error: error))
    }
    if let result = object["result"] {
      return .response(JSONRPCResponse(id: id, result: result))
    }
    throw JSONRPCError.invalidRequest("missing method, result, or error")
  }

  static func encode(_ request: JSONRPCRequest) throws -> Data {
    try line(request.jsonValue)
  }

  static func encode(_ response: JSONRPCResponse) throws -> Data {
    try line(response.jsonValue)
  }

  private static func line(_ value: JSONValue) throws -> Data {
    var data = try value.data()
    data.append(0x0A)
    return data
  }
}

struct JSONRPCLineBuffer: Sendable {
  private var pending = Data()

  var pendingByteCount: Int { pending.count }

  mutating func append(_ data: Data) -> [Data] {
    pending.append(data)
    var lines: [Data] = []
    while let newline = pending.firstIndex(of: 0x0A) {
      let line = Self.trimmed(pending.subdata(in: pending.startIndex..<newline))
      pending.removeSubrange(pending.startIndex...newline)
      if !line.isEmpty {
        lines.append(line)
      }
    }
    return lines
  }

  mutating func flush() -> Data {
    let remainder = Self.trimmed(pending)
    pending = Data()
    return remainder
  }

  private static func trimmed(_ line: Data) -> Data {
    var line = line
    while line.last == 0x0D {
      line.removeLast()
    }
    return line
  }
}
