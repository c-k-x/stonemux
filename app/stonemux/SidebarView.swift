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
            // P9：在线 peers
            Divider()
            Text(NSLocalizedString("Online", comment: ""))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            if store.onlinePeers.isEmpty {
                Text(NSLocalizedString("No peers online", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.onlinePeers) { peer in
                            PeerRow(store: store, peer: peer)
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct PeerRow: View {
    let store: SessionStore
    let peer: Peer

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.green).frame(width: 7, height: 7)
            Text(peer.name).lineLimit(1)
            Text(peer.agentId)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { store.onPeerClicked?(peer.agentId) }
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
