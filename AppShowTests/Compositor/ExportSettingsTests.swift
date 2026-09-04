import AVFoundation
import Testing
import VideoToolbox

@testable import AppShow

struct ExportSettingsTests {
  private struct PresetExpectation {
    let format: ExportFormat
    let fps: ExportFPS
    let resolution: ExportResolution
    let codec: ExportCodec
    let audioBitrate: ExportAudioBitrate
  }

  private static func expectation(for preset: ExportPreset) -> PresetExpectation? {
    switch preset {
    case .custom: nil
    case .youtube: PresetExpectation(format: .mp4, fps: .original, resolution: .fhd1080, codec: .h265, audioBitrate: .kbps320)
    case .twitter, .tiktok, .instagram:
      PresetExpectation(format: .mp4, fps: .fps30, resolution: .fhd1080, codec: .h264, audioBitrate: .kbps256)
    case .discord: PresetExpectation(format: .mp4, fps: .fps30, resolution: .hd720, codec: .h264, audioBitrate: .kbps192)
    case .proRes:
      PresetExpectation(format: .mov, fps: .original, resolution: .original, codec: .proRes422, audioBitrate: .kbps320)
    case .gif: PresetExpectation(format: .gif, fps: .fps24, resolution: .hd720, codec: .h265, audioBitrate: .kbps320)
    }
  }

  @Test(arguments: ExportPreset.allCases) func presetSettingsMatchTable(preset: ExportPreset) throws {
    guard let expected = Self.expectation(for: preset) else {
      #expect(preset.settings == nil)
      return
    }

    let settings = try #require(preset.settings)

    #expect(settings.format == expected.format)
    #expect(settings.fps == expected.fps)
    #expect(settings.resolution == expected.resolution)
    #expect(settings.codec == expected.codec)
    #expect(settings.audioBitrate == expected.audioBitrate)
    #expect(settings.mode == .parallel)
  }

  @Test func defaultSettingsAreHEVCMP4AtOriginalSizeAndRate() {
    let settings = ExportSettings()

    #expect(settings.format == .mp4)
    #expect(settings.fps == .original)
    #expect(settings.resolution == .original)
    #expect(settings.codec == .h265)
    #expect(settings.audioBitrate == .kbps320)
    #expect(settings.mode == .parallel)
    #expect(settings.gifQuality == .high)
    #expect(settings.captionExportMode == .burnIn)
    #expect(settings.maximumWidth == nil)
    #expect(settings.frameRateOverride == nil)
  }

  @Test(arguments: [
    (ExportFPS.original, 60), (.fps24, 24), (.fps30, 30), (.fps40, 40), (.fps50, 50), (.fps60, 60),
  ])
  func fpsValueUsesFallbackOnlyForOriginal(fps: ExportFPS, expected: Int) {
    #expect(fps.value(fallback: 60) == expected)
    #expect(fps.numericValue == (fps == .original ? nil : expected))
  }

  @Test func fpsCasesAreAllTabulated() {
    #expect(ExportFPS.allCases.count == 6)
  }

  @Test(arguments: [
    (ExportResolution.original, nil), (.uhd4k, 3840), (.fhd1080, 1920), (.hd720, 1280),
  ])
  func resolutionPixelWidth(resolution: ExportResolution, expected: CGFloat?) {
    #expect(resolution.pixelWidth == expected)
  }

  @Test(arguments: [
    (ExportAudioBitrate.kbps128, 128_000), (.kbps192, 192_000), (.kbps256, 256_000), (.kbps320, 320_000),
  ])
  func audioBitrateValue(bitrate: ExportAudioBitrate, expected: Int) {
    #expect(bitrate.value == expected)
  }

  @Test func gifFormatWritesMP4IntermediateWithGIFExtension() {
    #expect(ExportFormat.gif.fileType == .mp4)
    #expect(ExportFormat.gif.fileExtension == "gif")
    #expect(ExportFormat.gif.isGIF)
    #expect(ExportFormat.mov.fileType == .mov)
    #expect(!ExportFormat.mp4.isGIF)
  }

  @Test func codecTables() {
    #expect(ExportCodec.h264.videoCodecType == .h264)
    #expect(ExportCodec.h265.videoCodecType == .hevc)
    #expect(ExportCodec.proRes422.videoCodecType == .proRes422)
    #expect(ExportCodec.proRes4444.videoCodecType == .proRes4444)
    #expect(ExportCodec.allCases.filter(\.isProRes) == [.proRes422, .proRes4444])
    #expect(ExportCodec.h265.exportPreset == AVAssetExportPresetHEVCHighestQuality)
  }

  private func compression(_ settings: [String: Any]) -> [String: Any]? {
    settings[AVVideoCompressionPropertiesKey] as? [String: Any]
  }

  @Test func hevcBitrateIsFiveTimesPixels() throws {
    let settings = EncodingSettings.exportVideoSettings(codec: .hevc, width: 1920, height: 1080, fps: 30)
    let props = try #require(compression(settings))
    let bitrate = try #require(props[AVVideoAverageBitRateKey] as? Double)

    #expect(bitrate == 10_368_000)
    #expect(props[AVVideoProfileLevelKey] as? String == kVTProfileLevel_HEVC_Main10_AutoLevel as String)
    #expect(props[AVVideoMaxKeyFrameIntervalKey] as? Int == 30)
    #expect(props[AVVideoExpectedSourceFrameRateKey] as? Int == 30)
    #expect(settings[AVVideoCodecKey] as? AVVideoCodecType == .hevc)
    #expect(settings[AVVideoWidthKey] as? Int == 1920)
    #expect(settings[AVVideoHeightKey] as? Int == 1080)
  }

  @Test func hevcHDRBitrateIsSevenTimesPixelsWithoutColorProperties() throws {
    let settings = EncodingSettings.exportVideoSettings(codec: .hevc, width: 1920, height: 1080, fps: 30, isHDR: true)
    let props = try #require(compression(settings))
    let bitrate = try #require(props[AVVideoAverageBitRateKey] as? Double)

    #expect(bitrate == 14_515_200)
    #expect(settings[AVVideoColorPropertiesKey] == nil)
  }

  @Test func h264BitrateIsSevenTimesPixelsRegardlessOfHDR() throws {
    let sdr = EncodingSettings.exportVideoSettings(codec: .h264, width: 1280, height: 720, fps: 60)
    let hdr = EncodingSettings.exportVideoSettings(codec: .h264, width: 1280, height: 720, fps: 60, isHDR: true)
    let sdrProps = try #require(compression(sdr))
    let hdrProps = try #require(compression(hdr))
    let sdrBitrate = try #require(sdrProps[AVVideoAverageBitRateKey] as? Double)
    let hdrBitrate = try #require(hdrProps[AVVideoAverageBitRateKey] as? Double)

    #expect(sdrBitrate == 6_451_200)
    #expect(hdrBitrate == 6_451_200)
    #expect(sdrProps[AVVideoProfileLevelKey] as? String == AVVideoProfileLevelH264HighAutoLevel)
  }

  @Test func sdrSettingsCarryBT709ColorProperties() throws {
    let settings = EncodingSettings.exportVideoSettings(codec: .h264, width: 1280, height: 720, fps: 60)
    let color = try #require(settings[AVVideoColorPropertiesKey] as? [String: String])

    #expect(color[AVVideoColorPrimariesKey] == AVVideoColorPrimaries_ITU_R_709_2)
    #expect(color[AVVideoTransferFunctionKey] == AVVideoTransferFunction_ITU_R_709_2)
    #expect(color[AVVideoYCbCrMatrixKey] == AVVideoYCbCrMatrix_ITU_R_709_2)
  }

  @Test(arguments: [AVVideoCodecType.proRes422, .proRes4444])
  func proResHasNoCompressionProperties(codec: AVVideoCodecType) {
    let sdr = EncodingSettings.exportVideoSettings(codec: codec, width: 1920, height: 1080, fps: 30)
    let hdr = EncodingSettings.exportVideoSettings(codec: codec, width: 1920, height: 1080, fps: 30, isHDR: true)

    #expect(sdr[AVVideoCompressionPropertiesKey] == nil)
    #expect(sdr[AVVideoCodecKey] as? AVVideoCodecType == codec)
    #expect(sdr[AVVideoColorPropertiesKey] != nil)
    #expect(hdr[AVVideoColorPropertiesKey] == nil)
    #expect(Set(sdr.keys) == [AVVideoCodecKey, AVVideoWidthKey, AVVideoHeightKey, AVVideoColorPropertiesKey])
  }
}
