import SwiftUI

// Purpose: 앱 설정 화면 - Apple Watch 연결 관리
struct SettingsView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var connectivityManager = PhoneConnectivityManager.shared
    @State private var showingReconnectAlert = false
    @State private var reconnectMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            Color.clear
                .appGradientBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Apple Watch 연결 섹션
                    watchConnectionSection

                    // 계정 섹션
                    accountSection

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("연결 상태", isPresented: $showingReconnectAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(reconnectMessage)
        }
    }

    // MARK: - Watch Connection Section

    private var watchConnectionSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("Apple Watch 연결")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            // 연결 상태 카드
            VStack(spacing: 12) {
                // 연결 상태
                HStack {
                    Text("연결 상태")
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    HStack(spacing: 8) {
                        Circle()
                            .fill(connectivityManager.isWatchReachable ? Color.green : Color.red)
                            .frame(width: 10, height: 10)

                        Text(connectivityManager.isWatchReachable ? "연결됨" : "연결 안 됨")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // 세션 활성화 상태
                HStack {
                    Text("세션 활성화")
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Text(connectivityManager.isSessionActivated ? "활성화됨" : "비활성화")
                        .foregroundColor(connectivityManager.isSessionActivated ? .green : .orange)
                        .fontWeight(.semibold)
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // 마지막 업데이트 시간
                HStack {
                    Text("마지막 업데이트")
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    if let lastUpdate = connectivityManager.lastUpdateTime {
                        Text(timeAgo(from: lastUpdate))
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("없음")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )

            // 재연결 버튼
            Button {
                handleReconnect()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)

                    Text("Watch 재연결")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(connectivityManager.isWatchReachable ? Color.blue.opacity(0.3) : Color.orange.opacity(0.5))
                )
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("계정")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            // 로그아웃 버튼
            Button {
                authManager.signOut()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)

                    Text("로그아웃")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    // MARK: - Helper Methods

    // Purpose: 재연결 처리
    private func handleReconnect() {
        connectivityManager.reconnect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if connectivityManager.isWatchReachable {
                reconnectMessage = "Apple Watch와 연결되었습니다!"
            } else {
                reconnectMessage = "연결을 시도했습니다.\n\nWatch에서 앱이 실행 중인지 확인하고\n잠시 후 다시 시도해주세요."
            }
            showingReconnectAlert = true
        }
    }

    // Purpose: 시간 경과 표시
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "\(seconds)초 전"
        } else if seconds < 3600 {
            return "\(seconds / 60)분 전"
        } else if seconds < 86400 {
            return "\(seconds / 3600)시간 전"
        } else {
            return "\(seconds / 86400)일 전"
        }
    }
}
