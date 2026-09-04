import Foundation

enum AgentError: LocalizedError, Equatable, Sendable {
  case launchFailed(String)
  case processFailed(status: Int32, stderrTail: String)
  case lineTooLong
  case cancelled
  case alreadyRunning
  case executableNotFound(AgentProviderKind)

  var errorDescription: String? {
    switch self {
    case .launchFailed(let reason):
      "The agent process could not be started: \(reason)"
    case .processFailed(let status, let stderrTail):
      stderrTail.isEmpty
        ? "The agent process exited with status \(status)" : "The agent process exited with status \(status): \(stderrTail)"
    case .lineTooLong:
      "The agent process produced a line longer than the allowed limit"
    case .cancelled:
      "The turn was cancelled"
    case .alreadyRunning:
      "A turn is already running"
    case .executableNotFound(let kind):
      "\(kind.displayName) was not found on this Mac"
    }
  }
}
