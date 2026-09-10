import Foundation
import Testing

@testable import Reframed

struct JSONValueTests {
  @Test func literalsBuildTheExpectedCases() {
    let value: JSONValue = [
      "name": "reframed",
      "count": 3,
      "ratio": 0.5,
      "ok": true,
      "nothing": nil,
      "list": [1, "two"],
    ]
    #expect(value["name"] == .string("reframed"))
    #expect(value["count"] == .number(3))
    #expect(value["ratio"] == .number(0.5))
    #expect(value["ok"] == .bool(true))
    #expect(value["nothing"] == .null)
    #expect(value["list"] == .array([.number(1), .string("two")]))
    #expect(value["missing"] == nil)
  }

  @Test func typedAccessorsReturnNilForOtherCases() {
    #expect(JSONValue.string("x").stringValue == "x")
    #expect(JSONValue.string("x").doubleValue == nil)
    #expect(JSONValue.number(2).intValue == 2)
    #expect(JSONValue.number(2.5).intValue == nil)
    #expect(JSONValue.number(2.5).doubleValue == 2.5)
    #expect(JSONValue.bool(false).boolValue == false)
    #expect(JSONValue.bool(false).intValue == nil)
    #expect(JSONValue.array([.null]).arrayValue == [.null])
    #expect(JSONValue.object(["a": .null]).objectValue == ["a": .null])
    #expect(JSONValue.null.isNull)
    #expect(JSONValue.object([:]).isNull == false)
    #expect(JSONValue.array([.number(7), .number(8)])[1] == .number(8))
    #expect(JSONValue.array([.number(7)])[3] == nil)
    #expect(JSONValue.string("x")[0] == nil)
  }

  @Test func decodesEveryJSONTypeAndPreservesIntegers() throws {
    let data = Data(#"{"a":1,"b":1.5,"c":"s","d":true,"e":null,"f":[1,{"g":[]}],"h":{}}"#.utf8)
    let value = try JSONValue.parse(data)
    #expect(value["a"] == .number(1))
    #expect(value["b"] == .number(1.5))
    #expect(value["c"] == .string("s"))
    #expect(value["d"] == .bool(true))
    #expect(value["e"] == .null)
    #expect(value["f"]?[1]?["g"] == .array([]))
    #expect(value["h"] == .object([:]))
    #expect(value["a"]?.intValue == 1)
  }

  @Test func encodesWithSortedKeysAndIntegralNumbersWithoutFraction() throws {
    let value: JSONValue = ["z": 1, "a": ["y": 2.5, "x": false], "m": nil]
    let text = try value.jsonString()
    #expect(text == #"{"a":{"x":false,"y":2.5},"m":null,"z":1}"#)
  }

  @Test func roundTripsThroughCodable() throws {
    let original: JSONValue = ["nested": [["deep": [1, 2, 3]]], "flag": true, "text": "héllo \"quoted\""]
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
    #expect(decoded == original)
  }

  @Test func bridgesEncodableAndDecodableTypes() throws {
    struct Payload: Codable, Equatable {
      var id: Int
      var tags: [String]
      var note: String?
    }
    let payload = Payload(id: 4, tags: ["a", "b"], note: nil)
    let value = try JSONValue(encoding: payload)
    #expect(value == ["id": 4, "tags": ["a", "b"]])
    let decoded = try value.decoded(as: Payload.self)
    #expect(decoded == payload)
  }

  @Test func parseRejectsInvalidJSON() {
    #expect(throws: (any Error).self) {
      try JSONValue.parse(Data("{not json".utf8))
    }
  }

  @Test func typeNamesMatchJSONSchemaVocabulary() {
    #expect(JSONValue.null.typeName == "null")
    #expect(JSONValue.bool(true).typeName == "boolean")
    #expect(JSONValue.number(1).typeName == "number")
    #expect(JSONValue.string("").typeName == "string")
    #expect(JSONValue.array([]).typeName == "array")
    #expect(JSONValue.object([:]).typeName == "object")
  }
}
