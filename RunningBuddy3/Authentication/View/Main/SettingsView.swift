import SwiftUI
import FirebaseAuth

// Purpose: 앱 설정 화면 - 로그아웃, 다리 길이 설정 기능
struct SettingsView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    // State Properties
    @State private var legLength: Double = 0
    @State private var legLengthInput: String = ""
    @State private var showingLegLengthInput = false
    @State private var isLoading = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            Color.clear
                .appGradientBackground()

            VStack(spacing: 24) {
                // 다리 길이 섹션
                legLengthSection

                // 계정 섹션
                accountSection

                Spacer()
            }
            .padding()
            .padding(.top, 8)
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            loadLegLength()
        }
        .alert("키 입력", isPresented: $showingLegLengthInput) {
            TextField("키 (cm)", text: $legLengthInput)
                .keyboardType(.decimalPad)
            Button("취소", role: .cancel) {}
            Button("확인") {
                handleLegLengthInput()
            }
        } message: {
            Text("키를 입력하면 다리 길이가 자동 계산됩니다.")
        }
    }

    // MARK: - Leg Length Section
    // ═══════════════════════════════════════
    // PURPOSE: 다리 길이 섹션
    // ═══════════════════════════════════════
    private var legLengthSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("다리 길이")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            if legLength > 0 {
                // 다리 길이 표시 및 조정
                VStack(spacing: 16) {
                    // 다리 길이 조정
                    VStack(spacing: 12) {

                        // 숫자 표시
                        Text(String(format: "%.1f cm", legLength))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        // 슬라이더로 조정
                        Slider(
                            value: $legLength,
                            in: 30...150,
                            step: 0.1,
                            onEditingChanged: { editing in
                                // 슬라이더 조정이 끝났을 때 저장
                                if !editing {
                                    saveLegLength()
                                }
                            }
                        )
                        .tint(.white)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            } else {
                // 다리 길이 입력 안내
                Button {
                    showingLegLengthInput = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "ruler")
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("키 입력")
                                .font(.headline)

                            Text("키를 입력하여 다리 길이를 계산하세요")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }
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
                handleLogout()
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

    // ═══════════════════════════════════════
    // PURPOSE: 저장된 다리 길이 불러오기
    // ═══════════════════════════════════════
    private func loadLegLength() {
        guard let userId = authManager.currentUser?.uid else {
            return
        }

        Task {
            do {
                let userData = try await UserService.shared.getUserData(userId: userId)

                await MainActor.run {
                    if let savedLegLength = userData?.legLength {
                        legLength = savedLegLength
                    }
                }
            } catch {
                print("데이터 조회 실패: \(error.localizedDescription)")
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 키 입력 후 다리 길이 계산 및 저장
    // ═══════════════════════════════════════
    private func handleLegLengthInput() {
        guard let inputHeight = Double(legLengthInput), inputHeight > 0 else {
            return
        }

        guard let userId = authManager.currentUser?.uid else {
            return
        }

        Task {
            isLoading = true

            do {
                // 다리 길이 계산 (키 × 0.53)
                let calculatedLegLength = inputHeight * 0.53

                // 다리 길이만 저장 (키는 저장하지 않음)
                try await UserService.shared.updateUserData(userId: userId, updates: [
                    "legLength": calculatedLegLength
                ])

                await MainActor.run {
                    legLength = calculatedLegLength
                    isLoading = false
                }

                print("키: \(String(format: "%.1f", inputHeight)) cm")
                print("다리 길이 계산 및 저장: \(String(format: "%.1f", calculatedLegLength)) cm")
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                print("저장 실패: \(error.localizedDescription)")
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 다리 길이 저장
    // ═══════════════════════════════════════
    private func saveLegLength() {
        guard let userId = authManager.currentUser?.uid else {
            return
        }

        Task {
            do {
                try await UserService.shared.updateUserData(userId: userId, updates: [
                    "legLength": legLength
                ])

                print("다리 길이 저장 완료: \(String(format: "%.1f", legLength)) cm")
            } catch {
                print("다리 길이 저장 실패: \(error.localizedDescription)")
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 안전한 로그아웃 처리
    // ═══════════════════════════════════════
    private func handleLogout() {
        // Step 1: 화면 닫기
        dismiss()

        // Step 2: 뷰가 완전히 사라진 후 로그아웃
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            authManager.signOut()
        }
    }
}
