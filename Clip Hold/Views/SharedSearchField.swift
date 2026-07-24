import SwiftUI

struct SharedSearchField: View {
    let placeholder: LocalizedStringKey
    @Binding var searchText: String
    var isSearchFieldFocused: FocusState<Bool>.Binding
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    var body: some View {
        TextField(
            placeholder,
            text: $searchText
        )
        .textFieldStyle(.plain)
        .font(.title3)
        .padding(.vertical, 8)
        .padding(.leading, 30)
        .padding(.trailing, 10)
        .background(Color.primary.opacity(colorSchemeContrast == .increased ? 0.05 : 0.1))
        .cornerRadius(10)
        .controlSize(.large)
        .focused(isSearchFieldFocused)
        .overlay(
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .offset(y: -1.0)
                Spacer()
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.trailing, 8)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary, lineWidth: 1)
                .opacity(colorSchemeContrast == .increased ? 1 : 0)
        )
    }
}
