import SwiftUI
import FirebaseAuth

// Purpose: 이메일 찾기 및 비밀번호 재설정을 위한 뷰
// TODO: 이메일 찾기 기능 구현 필요
struct FindEmailView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    // Purpose: 검색 단계 관리
    enum SearchStep {
        case searching      // 이메일 검색 중
        case completed      // 완료
        case notFound       // 검색 결과 없음
    }

    // 상태 관리
    @State private var currentStep: SearchStep = .searching
    @State private var email = ""
    @State private var foundEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션 효과
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // 제목
                Text(titleText)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // 단계별 내용 표시
                switch currentStep {
                case .searching:
                    searchingView
                case .completed:
                    completedView
                case .notFound:
                    notFoundView
                }

                // 취소 버튼
                if currentStep != .completed && currentStep != .notFound {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .font(.caption)
                    .padding(.top)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("알림", isPresented: $showingAlert) {
            Button("확인") {
                if currentStep == .completed {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }

    // MARK: - Step Views

    // Purpose: 이메일 검색 단계 뷰
    private var searchingView: some View {
        VStack(spacing: 15) {
            Text("가입하신 이메일 주소를 입력해주세요")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)
                TextField("", text: $email)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.oneTimeCode)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )

            Button {
                Task {
                    await searchEmails()
                }
            } label: {
                Text("검색")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .disabled(email.isEmpty || isLoading)
        }
        .padding(.horizontal)
    }

    // Purpose: 완료 단계 뷰
    private var completedView: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("가입된 계정이 확인되었습니다")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("확인")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal)
    }

    // Purpose: 검색 결과 없음 단계 뷰
    private var notFoundView: some View {
        VStack(spacing: 15) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.pink.opacity(0.7))

            Text("검색된 계정이 없습니다")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("입력하신 이메일로 가입된 계정을 찾을 수 없습니다")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button {
                    currentStep = .searching
                    email = ""
                } label: {
                    Text("다시 검색")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }

                NavigationLink {
                    SignUpView()
                } label: {
                    Text("회원가입")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helper Properties

    private var titleText: String {
        switch currentStep {
        case .searching:
            return "아이디 찾기"
        case .completed:
            return "완료"
        case .notFound:
            return "검색 결과"
        }
    }

    // MARK: - Actions

    // Purpose: 이메일 검색 (현재 비활성화)
    private func searchEmails() async {
        isLoading = true

        // 이메일 찾기 기능은 현재 사용할 수 없습니다
        alertMessage = "이메일 찾기 기능은 현재 사용할 수 없습니다"
        showingAlert = true

        isLoading = false
    }
}
