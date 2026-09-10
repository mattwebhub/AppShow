import AppKit

enum CaptionFont {
  static func resolve(family: String, size: CGFloat, weight: CaptionFontWeight) -> NSFont {
    guard family != "System" else { return NSFont.systemFont(ofSize: size, weight: weight.nsWeight) }
    let descriptor = NSFontDescriptor(fontAttributes: [
      .family: family,
      .traits: [NSFontDescriptor.TraitKey.weight: weight.nsWeight.rawValue],
    ])
    guard let font = NSFont(descriptor: descriptor, size: size),
      font.familyName?.caseInsensitiveCompare(family) == .orderedSame
    else { return NSFont.systemFont(ofSize: size, weight: weight.nsWeight) }
    return font
  }
}
