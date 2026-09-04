import Foundation

enum AgentEvent: Sendable, Equatable {
  case sessionStarted(id: String)
  case textDelta(String)
  case toolCallStarted(id: String, name: String, input: String)
  case toolCallFinished(id: String, output: String, isError: Bool)
  case turnCompleted(AgentTurnResult)
  case error(message: String)
  case unknown(type: String)
}

struct AgentTurnResult: Sendable, Equatable {
  var isError: Bool
  var text: String?
  var costUSD: Double?
  var durationMs: Int?

  init(isError: Bool = false, text: String? = nil, costUSD: Double? = nil, durationMs: Int? = nil) {
    self.isError = isError
    self.text = text
    self.costUSD = costUSD
    self.durationMs = durationMs
  }
}
