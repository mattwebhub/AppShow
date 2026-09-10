import Foundation

struct ZoomRegion {
  let startIndex: Int
  let count: Int
  let startTime: Double
  let zoomStartTime: Double
  let zoomEndTime: Double
  let endTime: Double
  let isAuto: Bool
  let peakZoom: Double
}

extension ZoomRegion {
  func editedKeyframes(from original: [ZoomKeyframe], drag: RegionDragType, delta: Double, bounds: ClosedRange<Double>) -> [ZoomKeyframe] {
    guard delta.isFinite, endTime > startTime else { return original }
    var start = startTime
    var end = endTime
    switch drag {
    case .move:
      let shift = max(bounds.lowerBound - startTime, min(bounds.upperBound - endTime, delta))
      return original.map { frame in
        var moved = frame
        moved.t += shift
        moved.isAuto = false
        return moved
      }
    case .resizeLeft:
      start = max(bounds.lowerBound, min(endTime - 0.05, startTime + delta))
    case .resizeRight:
      end = min(bounds.upperBound, max(startTime + 0.05, endTime + delta))
    }
    let easeIn = max(0, zoomStartTime - startTime)
    let easeOut = max(0, endTime - zoomEndTime)
    let transitionScale = min(1, max(0, end - start - 0.01) / max(0.001, easeIn + easeOut))
    let holdStart = start + easeIn * transitionScale
    let holdEnd = end - easeOut * transitionScale
    return original.map { frame in
      var edited = frame
      if frame.t <= zoomStartTime, easeIn > 0 {
        edited.t = start + (frame.t - startTime) / easeIn * (holdStart - start)
      } else if frame.t >= zoomEndTime, easeOut > 0 {
        edited.t = holdEnd + (frame.t - zoomEndTime) / easeOut * (end - holdEnd)
      } else {
        let fraction = (frame.t - zoomStartTime) / max(0.001, zoomEndTime - zoomStartTime)
        edited.t = holdStart + fraction * (holdEnd - holdStart)
      }
      edited.t = max(start, min(end, edited.t))
      edited.isAuto = false
      return edited
    }
  }
}

func groupZoomRegions(from keyframes: [ZoomKeyframe]) -> [ZoomRegion] {
  guard keyframes.count >= 2 else { return [] }

  var regions: [ZoomRegion] = []
  var i = 0

  while i < keyframes.count {
    if keyframes[i].zoomLevel <= 1.0 && i + 1 < keyframes.count && keyframes[i + 1].zoomLevel > 1.0 {
      let regionStart = i
      var j = i + 1
      var peak = keyframes[j].zoomLevel

      while j < keyframes.count && keyframes[j].zoomLevel > 1.0 {
        peak = max(peak, keyframes[j].zoomLevel)
        j += 1
      }

      let regionEnd: Int
      if j < keyframes.count && keyframes[j].zoomLevel <= 1.0 {
        regionEnd = j
      } else {
        regionEnd = j - 1
      }

      let count = regionEnd - regionStart + 1
      if count >= 2 {
        let zoomStart = keyframes[regionStart + 1].t
        let zoomEnd: Double
        if regionEnd > regionStart + 1 && keyframes[regionEnd].zoomLevel <= 1.0 {
          zoomEnd = keyframes[regionEnd - 1].t
        } else {
          zoomEnd = keyframes[regionEnd].t
        }

        regions.append(
          ZoomRegion(
            startIndex: regionStart,
            count: count,
            startTime: keyframes[regionStart].t,
            zoomStartTime: zoomStart,
            zoomEndTime: zoomEnd,
            endTime: keyframes[regionEnd].t,
            isAuto: keyframes[regionStart].isAuto,
            peakZoom: peak
          )
        )
      }

      i = regionEnd + 1
    } else if keyframes[i].zoomLevel > 1.0 {
      let regionStart = i
      var j = i
      var peak = keyframes[j].zoomLevel

      while j < keyframes.count && keyframes[j].zoomLevel > 1.0 {
        peak = max(peak, keyframes[j].zoomLevel)
        j += 1
      }

      let regionEnd: Int
      if j < keyframes.count && keyframes[j].zoomLevel <= 1.0 {
        regionEnd = j
      } else {
        regionEnd = j - 1
      }

      let count = regionEnd - regionStart + 1
      let zoomEnd: Double
      if regionEnd > regionStart && keyframes[regionEnd].zoomLevel <= 1.0 {
        zoomEnd = keyframes[regionEnd - 1].t
      } else {
        zoomEnd = keyframes[regionEnd].t
      }

      regions.append(
        ZoomRegion(
          startIndex: regionStart,
          count: count,
          startTime: keyframes[regionStart].t,
          zoomStartTime: keyframes[regionStart].t,
          zoomEndTime: zoomEnd,
          endTime: keyframes[regionEnd].t,
          isAuto: keyframes[regionStart].isAuto,
          peakZoom: peak
        )
      )

      i = regionEnd + 1
    } else {
      i += 1
    }
  }

  return regions
}

enum RegionDragType {
  case move, resizeLeft, resizeRight
}
