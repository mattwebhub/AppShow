import Foundation

enum AgentToolPresentation {
  static func editorArea(for name: String) -> String {
    switch name {
    case "set_trim", "set_kept_slices", "remove_time_range", "get_silences", "remove_silences": "Cuts"
    case "set_camera", "add_camera_region", "update_camera_region", "remove_camera_region": "Webcam"
    case "get_transcript", "generate_transcript", "generate_captions", "set_captions", "replace_captions": "Captions"
    case "set_audio", "add_music", "set_music", "remove_music": "Audio"
    case "get_cursor_activity", "set_cursor": "Cursor"
    case "add_zoom": "Zoom"
    case "add_speed", "update_speed", "remove_speed": "Speed"
    case "add_spotlight": "Spotlight"
    case "set_canvas": "Canvas"
    case "add_text", "update_text", "remove_text": "Text"
    case "add_image", "update_image", "remove_image": "Images"
    case "add_blur", "update_blur", "remove_blur": "Blur"
    case "set_transition": "Transitions"
    case "render_preview_frame", "export_draft", "export_video": "Preview and export"
    default: "Project"
    }
  }

  static func displayName(for name: String) -> String {
    let words = name.split(separator: "_").map(String.init)
    guard let first = words.first else { return name }
    return ([first.capitalized] + words.dropFirst()).joined(separator: " ")
  }
}

extension AgentToolDefinition {
  var editorArea: String {
    AgentToolPresentation.editorArea(for: name)
  }

  var displayTitle: String {
    "\(editorArea) · \(name.replacingOccurrences(of: "_", with: " ").capitalized)"
  }
}
