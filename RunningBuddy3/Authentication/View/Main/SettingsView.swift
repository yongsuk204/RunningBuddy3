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

    // Calibration Properties
    @State private var calibrationData: CalibrationData? = nil
    @State private var showingCalibrationView = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            Color.clear
                .appGradientBackground()

            VStack(spacing: 24) {
                // 다리 길이 섹션
                legLengthSection

                // 캘리브레이션 섹션
                calibrationSection

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
            loadCalibrationData()
        }
        .sheet(isPresented: $showingCalibrationView) {
            CalibrationView(calibrationData: $calibrationData, onSave: saveCalibrationData)
        }
        .alert("다리 길이 입력", isPresented: $showingLegLengthInput) {
            TextField("다리 길이 (cm)", text: $legLengthInput)
                .keyboardType(.decimalPad)
            Button("취소", role: .cancel) {}
            Button("확인") {
                handleLegLengthInput()
            }
        } message: {
            Text("일반적인 다리길이는 키 × 0.53 입니다.")
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
                            Text("다리 길이 입력")
                                .font(.headline)

                            Text("다리 길이를 직접 입력하세요")
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

    // MARK: - Calibration Section
    // ═══════════════════════════════════════
    // PURPOSE: 100m 캘리브레이션 섹션
    // ═══════════════════════════════════════
    private var calibrationSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Image(systemName: "ruler")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("100m 보폭 측정")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            if let calibration = calibrationData {
                // 캘리브레이션 데이터 표시
                VStack(spacing: 12) {
                    // 평균 보폭
                    HStack {
                        Text("평균 보폭")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text(String(format: "%.2f m", calibration.averageStepLength))
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Divider()
                        .background(Color.white.opacity(0.3))

                    // 걸음 수
                    HStack {
                        Text("걸음 수")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text("\(calibration.totalSteps) 걸음")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Divider()
                        .background(Color.white.opacity(0.3))

                    // 평균 케이던스
                    HStack {
                        Text("평균 케이던스")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text(String(format: "%.0f SPM", calibration.averageCadence))
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    // 재측정 버튼
                    Button {
                        showingCalibrationView = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("재측정")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            } else {
                // 캘리브레이션 측정 안내
                Button {
                    showingCalibrationView = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("100m 측정하기")
                                .font(.headline)

                            Text("실제로 100m를 달려서 정확한 보폭을 측정하세요")
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
    // PURPOSE: 다리 길이 직접 입력 및 저장
    // ═══════════════════════════════════════
    private func handleLegLengthInput() {
        guard let inputLegLength = Double(legLengthInput), inputLegLength > 0 else {
            return
        }

        guard let userId = authManager.currentUser?.uid else {
            return
        }

        Task {
            isLoading = true

            do {
                // UserService에서 다리 길이 저장 + 캐시 업데이트
                try await UserService.shared.updateLegLength(
                    userId: userId,
                    legLength: inputLegLength,
                    authManager: authManager
                )

                await MainActor.run {
                    legLength = inputLegLength
                    isLoading = false
                }

            } catch {
                print("⚠️ 다리 길이 저장 실패: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 슬라이더 조정 후 다리 길이 저장
    // ═══════════════════════════════════════
    private func saveLegLength() {
        guard let userId = authManager.currentUser?.uid else {
            return
        }

        Task {
            do {
                // UserService에서 비즈니스 로직 처리 (저장 + 캐시 업데이트)
                try await UserService.shared.updateLegLength(
                    userId: userId,
                    legLength: legLength,
                    authManager: authManager
                )
            } catch {
                print("⚠️ 다리 길이 저장 실패: \(error.localizedDescription)")
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 데이터 불러오기
    // ═══════════════════════════════════════
    private func loadCalibrationData() {
        guard let userId = authManager.currentUser?.uid else {
            return
        }

        Task {
            do {
                calibrationData = try await UserService.shared.getCalibrationData(userId: userId)
            } catch {
                print("캘리브레이션 데이터 조회 실패: \(error.localizedDescription)")
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 데이터 저장
    // ═══════════════════════════════════════
    private func saveCalibrationData() {
        guard let userId = authManager.currentUser?.uid,
              let data = calibrationData else {
            return
        }

        Task {
            do {
                try await UserService.shared.saveCalibrationData(userId: userId, calibrationData: data)

                // AuthenticationManager 캐시에도 업데이트
                await MainActor.run {
                    if let userData = authManager.currentUserData {
                        authManager.currentUserData = UserData(
                            userId: userData.userId,
                            username: userData.username,
                            email: userData.email,
                            phoneNumber: userData.phoneNumber,
                            securityQuestion: userData.securityQuestion,
                            securityAnswer: userData.securityAnswer,
                            legLength: userData.legLength,
                            calibrationData: data,
                            createdAt: userData.createdAt
                        )
                    }
                }

                // DistanceCalculator에 캘리브레이션 데이터 적용
                DistanceCalculator.shared.updateCalibrationData(data)

                print("✅ 캘리브레이션 데이터 저장 및 적용 완료")
            } catch {
                print("⚠️ 캘리브레이션 데이터 저장 실패: \(error.localizedDescription)")
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
