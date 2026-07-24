import SwiftUI

struct SharedEmptyListView: View {
    let message: LocalizedStringKey
    
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .foregroundStyle(.secondary)
                .font(.title2)
                .padding(.bottom, 20)
            Spacer()
        }
    }
}
