import Testing

@testable import AppShow

@MainActor
struct PermissionStoreTests {
  @Test func initializationChecksWithoutRequestingAccess() {
    var requests = 0
    let store = PermissionStore(
      screenRecordingCheck: { true },
      accessibilityCheck: { false },
      screenRecordingRequest: { requests += 1 },
      accessibilityRequest: { requests += 1 }
    )
    #expect(store.screenRecordingGranted)
    #expect(!store.accessibilityGranted)
    #expect(!store.allGranted)
    #expect(requests == 0)
  }

  @Test func refreshReportsGrantsAndRevocationsOnce() {
    var screen = false
    var accessibility = false
    var changes: [Bool] = []
    let store = PermissionStore(
      screenRecordingCheck: { screen },
      accessibilityCheck: { accessibility },
      screenRecordingRequest: {},
      accessibilityRequest: {}
    )
    store.onAccessibilityChanged = { changes.append($0) }
    screen = true
    accessibility = true
    store.refresh()
    store.refresh()
    #expect(store.allGranted)
    #expect(changes == [true])
    accessibility = false
    store.refresh()
    #expect(store.screenRecordingGranted)
    #expect(!store.accessibilityGranted)
    #expect(changes == [true, false])
  }

  @Test func explicitRequestsRefreshOnlyAfterCallingTheRequestedBoundary() {
    var screen = false
    var accessibility = false
    let store = PermissionStore(
      screenRecordingCheck: { screen },
      accessibilityCheck: { accessibility },
      screenRecordingRequest: { screen = true },
      accessibilityRequest: { accessibility = true }
    )
    store.request(.screenRecording)
    #expect(store.screenRecordingGranted)
    #expect(!store.accessibilityGranted)
    store.request(.accessibility)
    #expect(store.allGranted)
  }

  @Test func ignoredRequestDoesNotPretendPermissionWasGranted() {
    let store = PermissionStore(
      screenRecordingCheck: { false },
      accessibilityCheck: { false },
      screenRecordingRequest: {},
      accessibilityRequest: {}
    )
    store.request(.screenRecording)
    store.request(.accessibility)
    #expect(!store.screenRecordingGranted)
    #expect(!store.accessibilityGranted)
  }
}
