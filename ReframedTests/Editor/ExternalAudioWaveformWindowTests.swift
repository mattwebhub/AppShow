import Testing

@testable import Reframed

struct ExternalAudioWaveformWindowTests {
  private let samples: [Float] = (0..<200).map { Float($0) / 199 }

  @Test func externalWaveformWindowMapsFileRangeOntoRegionWidth() {
    let slice = ExternalAudioWaveformWindow.slice(samples: samples, fileIn: 1, fileOut: 2, sourceDuration: 4)
    #expect(slice.count == 50)
    #expect(slice.first == samples[50])
    #expect(slice.last == samples[99])
  }

  @Test func fullFileRangeReturnsEverySample() {
    let slice = ExternalAudioWaveformWindow.slice(samples: samples, fileIn: 0, fileOut: 4, sourceDuration: 4)
    #expect(slice == samples)
  }

  @Test func tinyWindowStillReturnsTwoSamplesForDrawing() {
    let slice = ExternalAudioWaveformWindow.slice(samples: samples, fileIn: 1, fileOut: 1.001, sourceDuration: 4)
    #expect(slice.count == 2)
    #expect(slice.first == samples[50])
  }

  @Test func emptyOrInvalidInputReturnsNothing() {
    #expect(ExternalAudioWaveformWindow.slice(samples: [], fileIn: 0, fileOut: 1, sourceDuration: 4).isEmpty)
    #expect(ExternalAudioWaveformWindow.slice(samples: samples, fileIn: 0, fileOut: 1, sourceDuration: 0).isEmpty)
    #expect(ExternalAudioWaveformWindow.slice(samples: samples, fileIn: 3, fileOut: 1, sourceDuration: 4).isEmpty)
  }
}
