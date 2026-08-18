import SwiftUI

/// 侧边栏宽度模型：只被 SidebarContainer 观察，
/// 拖宽度时不触发主区 body 重算。
@Observable
final class SidebarWidthModel {
    var width: CGFloat = 200
}

struct SidebarView: View {
    let store: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("Sessions", comment: ""))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.sessions) { session in
                        SessionRow(store: store, session: session)
                    }
                }
                .padding(.horizontal, 6)
            }
            Spacer(minLength: 0)
        }
    }
}

struct SessionRow: View {
    let store: SessionStore
    let session: Session

    private var isSelected: Bool { store.selectedSessionId == session.id }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal.fill")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text(session.displayName)
                .lineLimit(1)
            Spacer()
            if session.unread > 0 {
                Text("\(session.unread)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { store.select(session) }
    }
}
