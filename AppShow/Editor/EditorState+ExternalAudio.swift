import CoreMedia
import Foundation

extension EditorState {
  func externalAudioURL(for track: ExternalAudioTrackData) -> URL? {
    project?.externalAudioURL(fileName: track.fileName)
  }

  func restoreExternalAudioTracks(_ saved: [ExternalAudioTrackData]) {
    let recordingDuration = CMTimeGetSeconds(duration)
    externalAudioTracks = saved.compactMap { track in
      guard let url = externalAudioURL(for: track), FileManager.default.fileExists(atPath: url.path) else {
        logger.warning("Dropping audio track \(track.displayName): \(track.fileName) is missing from the project bundle")
        return nil
      }
      return ExternalAudioTrackMath.clamped(track, to: recordingDuration)
    }
    syncExternalAudioToPlayer()
  }

  @discardableResult
  func importExternalAudio(
    from sourceURL: URL,
    atTime: Double? = nil,
    recordsHistory: Bool = true
  ) async throws -> ExternalAudioTrackData {
    guard let project else {
      throw CaptureError.recordingFailed("Audio files can only be added to a saved project")
    }
    let imported = try await ExternalAudioImporter.import(sourceURL: sourceURL, into: project.bundleURL)
    let track = ExternalAudioTrackData(
      fileName: imported.fileName,
      displayName: imported.displayName,
      sourceDurationSeconds: imported.durationSeconds,
      timelineStartSeconds: atTime ?? CMTimeGetSeconds(currentTime),
      fileOutSeconds: imported.durationSeconds
    )
    let added = ExternalAudioTrackMath.clamped(track, to: CMTimeGetSeconds(duration))
    externalAudioTracks.append(added)
    syncExternalAudioToPlayer()
    scheduleSave()
    if recordsHistory {
      history.pushSnapshot(createSnapshot())
    }
    return added
  }

  func importExternalAudioFiles(_ urls: [URL]) {
    guard !urls.isEmpty else { return }
    Task { @MainActor [weak self] in
      for url in urls {
        guard let self else { return }
        do {
          try await self.importExternalAudio(from: url)
        } catch {
          self.logger.error("Failed to add audio file \(url.lastPathComponent): \(error)")
        }
      }
    }
  }

  func removeExternalAudioTrack(id: UUID) {
    externalAudioTracks.removeAll { $0.id == id }
    syncExternalAudioToPlayer()
  }

  func moveExternalAudioTrack(id: UUID, newStart: Double) {
    let recordingDuration = CMTimeGetSeconds(duration)
    updateExternalAudioTrack(id: id) {
      ExternalAudioTrackMath.move($0, to: newStart, recordingDuration: recordingDuration)
    }
  }

  func trimExternalAudioTrackStart(id: UUID, newStart: Double) {
    updateExternalAudioTrack(id: id) {
      ExternalAudioTrackMath.trimStart($0, to: newStart)
    }
  }

  func trimExternalAudioTrackEnd(id: UUID, newEnd: Double) {
    let recordingDuration = CMTimeGetSeconds(duration)
    updateExternalAudioTrack(id: id) {
      ExternalAudioTrackMath.trimEnd($0, to: newEnd, recordingDuration: recordingDuration)
    }
  }

  func setExternalAudioTrackVolume(id: UUID, volume: Float) {
    updateExternalAudioTrack(id: id) { track in
      var updated = track
      updated.volume = min(max(0, volume), 2)
      return updated
    }
  }

  func setExternalAudioTrackMuted(id: UUID, muted: Bool) {
    updateExternalAudioTrack(id: id) { track in
      var updated = track
      updated.muted = muted
      return updated
    }
  }

  func setExternalAudioTrackFadeIn(id: UUID, seconds: Double) {
    updateExternalAudioTrack(id: id) { track in
      var updated = track
      updated.fadeInSeconds = max(0, seconds)
      return updated
    }
  }

  func setExternalAudioTrackFadeOut(id: UUID, seconds: Double) {
    updateExternalAudioTrack(id: id) { track in
      var updated = track
      updated.fadeOutSeconds = max(0, seconds)
      return updated
    }
  }

  nonisolated static func exportExternalAudioTracks(
    from tracks: [ExternalAudioTrackData],
    bundleURL: URL?
  ) -> [ExternalAudioExportTrack] {
    guard let bundleURL else { return [] }
    return tracks.compactMap { track in
      guard track.effectiveVolume > 0, track.lengthSeconds > 0 else { return nil }
      return ExternalAudioExportTrack(
        url: bundleURL.appendingPathComponent(track.fileName),
        timelineRange: CMTimeRange(
          start: CMTime(seconds: track.timelineStartSeconds, preferredTimescale: 600),
          end: CMTime(seconds: track.timelineEndSeconds, preferredTimescale: 600)
        ),
        fileStart: CMTime(seconds: track.fileInSeconds, preferredTimescale: 600),
        volume: track.effectiveVolume,
        fadeIn: CMTime(seconds: track.fadeInSeconds, preferredTimescale: 600),
        fadeOut: CMTime(seconds: track.fadeOutSeconds, preferredTimescale: 600)
      )
    }
  }

  func syncExternalAudioToPlayer() {
    var urls: [UUID: URL] = [:]
    for track in externalAudioTracks {
      urls[track.id] = externalAudioURL(for: track)
    }
    playerController.setExternalAudioTracks(externalAudioTracks, urls: urls)
  }

  private func updateExternalAudioTrack(id: UUID, _ transform: (ExternalAudioTrackData) -> ExternalAudioTrackData) {
    guard let index = externalAudioTracks.firstIndex(where: { $0.id == id }) else { return }
    externalAudioTracks[index] = transform(externalAudioTracks[index])
    syncExternalAudioToPlayer()
  }
}
