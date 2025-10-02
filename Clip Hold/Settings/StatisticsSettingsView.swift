import SwiftUI

struct StatisticsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("統計")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("ここに統計情報が表示されます。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("統計")
    }
}

#Preview {
    StatisticsSettingsView()
}