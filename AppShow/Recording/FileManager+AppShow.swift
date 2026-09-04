import Foundation

extension FileManager {
  private func reframedTempDir() -> URL {
    let tempDir = AppShowPaths.temp
    try? createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  private func timestamp() -> String {
    formatTimestamp()
  }

  func tempRecordingURL() -> URL {
    reframedTempDir().appendingPathComponent("reframed-\(timestamp()).mp4")
  }

  func tempVideoURL(captureQuality: CaptureQuality = .standard) -> URL {
    let ext = captureQuality.isProRes ? "mov" : "mp4"
    return reframedTempDir().appendingPathComponent("video-\(timestamp()).\(ext)")
  }

  func tempWebcamURL() -> URL {
    reframedTempDir().appendingPathComponent("webcam-\(timestamp()).mp4")
  }

  func tempAudioURL(label: String) -> URL {
    reframedTempDir().appendingPathComponent("\(label)-\(timestamp()).m4a")
  }

  func tempGIFURL() -> URL {
    reframedTempDir().appendingPathComponent("reframed-\(timestamp()).gif")
  }

  @MainActor
  func projectSaveDirectory() -> URL {
    let folderPath = ConfigService.shared.projectFolder
    let expanded = NSString(string: folderPath).expandingTildeInPath
    let url = URL(fileURLWithPath: expanded, isDirectory: true)
    try? createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @MainActor
  func defaultSaveDirectory() -> URL {
    let folderPath = ConfigService.shared.outputFolder
    let expanded = NSString(string: folderPath).expandingTildeInPath
    let url = URL(fileURLWithPath: expanded, isDirectory: true)
    try? createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @MainActor
  func defaultSaveURL(for tempURL: URL, extension ext: String? = nil) -> URL {
    saveURL(for: tempURL, extension: ext, in: defaultSaveDirectory())
  }

  nonisolated func saveURL(for tempURL: URL, extension ext: String?, in directory: URL) -> URL {
    if let ext {
      let baseName = tempURL.deletingPathExtension().lastPathComponent
      return directory.appendingPathComponent("\(baseName).\(ext)")
    }
    return directory.appendingPathComponent(tempURL.lastPathComponent)
  }

  func moveToFinal(from source: URL, to destination: URL) throws {
    if fileExists(atPath: destination.path) {
      try removeItem(at: destination)
    }
    try moveItem(at: source, to: destination)
  }

  func cleanupTempDir() {
    let tempDir = AppShowPaths.temp
    guard let contents = try? contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else { return }
    for file in contents {
      try? removeItem(at: file)
    }
  }
}
