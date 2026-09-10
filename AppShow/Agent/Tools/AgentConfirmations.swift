import Foundation

struct AgentConfirmationOperation: Sendable, Equatable, Hashable {
  var kind: String
  var arguments: JSONValue

  static func externalFile(kind: String, url: URL) -> AgentConfirmationOperation {
    AgentConfirmationOperation(
      kind: kind,
      arguments: ["path": .string(url.standardizedFileURL.path)]
    )
  }
}

struct AgentConfirmationRequest: Sendable, Equatable, Identifiable {
  var id: UUID
  var operation: AgentConfirmationOperation
  var title: String
  var detail: String
  var createdAt: Date
  var expiresAt: Date
}

@MainActor
@Observable
final class AgentConfirmations {
  private enum Status {
    case pending
    case approved
    case denied
  }

  private struct Record {
    var request: AgentConfirmationRequest
    var status: Status
  }

  private var records: [UUID: Record] = [:]
  private let expirationInterval: TimeInterval
  private let now: () -> Date

  init(expirationInterval: TimeInterval = 300, now: @escaping () -> Date = Date.init) {
    self.expirationInterval = expirationInterval
    self.now = now
  }

  var pending: [AgentConfirmationRequest] {
    let current = now()
    return records.values
      .filter { $0.status == .pending && $0.request.expiresAt > current }
      .map(\.request)
      .sorted { $0.createdAt < $1.createdAt }
  }

  func authorize(
    operation: AgentConfirmationOperation,
    confirmationID: UUID?,
    title: String,
    detail: String
  ) throws {
    removeExpired()
    guard let confirmationID else {
      let createdAt = now()
      let request = AgentConfirmationRequest(
        id: UUID(),
        operation: operation,
        title: title,
        detail: detail,
        createdAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(expirationInterval)
      )
      records[request.id] = Record(request: request, status: .pending)
      throw AgentToolError.confirmationRequired(id: request.id, title: title, detail: detail)
    }
    guard let record = records[confirmationID] else {
      throw AgentToolError.confirmationExpired(confirmationID)
    }
    guard record.request.operation == operation else {
      records[confirmationID] = nil
      throw AgentToolError.confirmationMismatch(confirmationID)
    }
    switch record.status {
    case .pending:
      throw AgentToolError.confirmationPending(confirmationID)
    case .approved:
      records[confirmationID] = nil
    case .denied:
      records[confirmationID] = nil
      throw AgentToolError.confirmationDenied(confirmationID)
    }
  }

  @discardableResult
  func approve(_ id: UUID) -> Bool {
    removeExpired()
    guard var record = records[id], record.status == .pending else { return false }
    record.status = .approved
    records[id] = record
    return true
  }

  @discardableResult
  func deny(_ id: UUID) -> Bool {
    removeExpired()
    guard var record = records[id], record.status == .pending else { return false }
    record.status = .denied
    records[id] = record
    return true
  }

  func clear() {
    records.removeAll()
  }

  private func removeExpired() {
    let current = now()
    records = records.filter { $0.value.request.expiresAt > current }
  }
}
