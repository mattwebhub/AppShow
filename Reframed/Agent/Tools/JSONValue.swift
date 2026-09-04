import Foundation

enum JSONValue: Sendable, Equatable, Hashable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  var isNull: Bool {
    if case .null = self { return true }
    return false
  }

  var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  var doubleValue: Double? {
    if case .number(let value) = self { return value }
    return nil
  }

  var intValue: Int? {
    guard case .number(let value) = self, value.rounded() == value, abs(value) < 9_007_199_254_740_992 else { return nil }
    return Int(value)
  }

  var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  var arrayValue: [JSONValue]? {
    if case .array(let value) = self { return value }
    return nil
  }

  var objectValue: [String: JSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  var typeName: String {
    switch self {
    case .null: "null"
    case .bool: "boolean"
    case .number: "number"
    case .string: "string"
    case .array: "array"
    case .object: "object"
    }
  }

  subscript(key: String) -> JSONValue? {
    objectValue?[key]
  }

  subscript(index: Int) -> JSONValue? {
    guard let array = arrayValue, index >= 0, index < array.count else { return nil }
    return array[index]
  }

  static func parse(_ data: Data) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: data)
  }

  init<T: Encodable>(encoding value: T) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    self = try JSONDecoder().decode(JSONValue.self, from: try encoder.encode(value))
  }

  func decoded<T: Decodable>(as type: T.Type) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: try data())
  }

  func data() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }

  func jsonString() throws -> String {
    String(decoding: try data(), as: UTF8.self)
  }
}

extension JSONValue: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value is not JSON")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .bool(let value):
      try container.encode(value)
    case .number(let value):
      if let integer = intValue {
        try container.encode(integer)
      } else {
        try container.encode(value)
      }
    case .string(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    }
  }
}

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
  ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
  init(nilLiteral: ()) {
    self = .null
  }

  init(booleanLiteral value: Bool) {
    self = .bool(value)
  }

  init(integerLiteral value: Int) {
    self = .number(Double(value))
  }

  init(floatLiteral value: Double) {
    self = .number(value)
  }

  init(stringLiteral value: String) {
    self = .string(value)
  }

  init(arrayLiteral elements: JSONValue...) {
    self = .array(elements)
  }

  init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
  }
}

extension JSONValue {
  init(_ value: Int) {
    self = .number(Double(value))
  }

  init(_ value: Double) {
    self = .number(value)
  }

  init(_ value: String) {
    self = .string(value)
  }

  init(_ value: Bool) {
    self = .bool(value)
  }

  init(_ values: [JSONValue]) {
    self = .array(values)
  }

  init(_ values: [String: JSONValue]) {
    self = .object(values)
  }
}
