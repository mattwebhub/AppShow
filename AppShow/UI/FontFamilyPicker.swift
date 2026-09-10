import SwiftUI

struct FontFamilyPicker: View {
  @Binding var selection: String
  @State private var search = ""
  @State private var families: [String] = []
  @Environment(\.colorScheme) private var colorScheme

  private var choices: [String] {
    let all = ["System"] + families
    let available = all.contains(selection) ? all : [selection] + all
    return search.isEmpty ? available : available.filter { $0.localizedCaseInsensitiveContains(search) }
  }

  var body: some View {
    let _ = colorScheme
    SelectButton(label: selection) { dismiss in
      VStack(spacing: 8) {
        TextField("Search fonts…", text: $search)
          .textFieldStyle(.plain)
          .font(.system(size: FontSize.xs))
          .padding(8)
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(choices, id: \.self) { family in
              Button {
                selection = family
                dismiss()
              } label: {
                HStack {
                  Text(family)
                    .font(Font(CaptionFont.resolve(family: family, size: 13, weight: .regular)))
                    .lineLimit(1)
                  Spacer()
                  if family == selection { Image(systemName: "checkmark") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
            }
            if choices.isEmpty {
              Text("No matching fonts")
                .font(.system(size: FontSize.xs))
                .foregroundStyle(AppShowColors.secondaryText)
            }
          }
          .padding(4)
        }
      }
      .frame(width: 250, height: 320)
      .onAppear {
        search = ""
        families = NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") && $0 != "System" }.sorted()
      }
    }
  }
}
