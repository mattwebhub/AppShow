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

  func importExternalAudio(from sourceURL: URL) async throws {
    guard let project else {
      throw CaptureError.recordingFailed("Audio files can only be added to a saved project")
    }
    let imported = try await ExternalAudioImporter.import(sourceURL: sourceURL, into: project.bundleURL)
    let track = ExternalAudioTrackData(
      fileName: imported.fileName,
      displayName: imported.displayName,
      sourceDurationSeconds: imported.durationSeconds,
      timelineStartSeconds: CMTimeGetSeconds(currentTime),
      fileOutSeconds: imported.durationSeconds
    )
    externalAudioTracks.append(ExternalAudioTrackMath.clamped(track, to: CMTimeGetSeconds(duration)))
    syncExternalAudioToPlayer()
    scheduleSave()
    history.pushSnapshot(createSnapshot())
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

  func syncExternalAudioToPlayer() {
  }

  private func updateExternalAudioTrack(id: UUID, _ transform: (ExternalAudioTrackData) -> ExternalAudioTrackData) {
    guard let index = externalAudioTracks.firstIndex(where: { $0.id == id }) else { return }
    externalAudioTracks[index] = transform(externalAudioTracks[index])
    syncExternalAudioToPlayer()
  }
}
