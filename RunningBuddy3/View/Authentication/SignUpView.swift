import SwiftUI
import FirebaseAuth

// 사용자 회원가입을 위한 Glass UI 디자인의 화면
struct SignUpView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    // 사용자 입력 필드들
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedSecurityQuestion = ""
    @State private var securityAnswer = ""

    // 상태 관리
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // 보안질문 목록
    private let securityQuestions = [
        "당신의 첫 번째 애완동물의 이름은?",
        "당신이 태어난 도시는?",
        "당신이 다닌 초등학교의 이름은?",
        "당신이 가장 좋아하는 음식은?",
        "당신의 첫 번째 자동차 모델은?"
    ]

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
                Text("회원가입")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20)
                        TextField("", text: $email)
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.emailAddress)
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

                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20)
                        SecureField("", text: $password)
                            .foregroundColor(.white)
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

                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20)
                        SecureField("", text: $confirmPassword)
                            .foregroundColor(.white)
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

                    // 보안질문 선택
                    Menu {
                        ForEach(securityQuestions, id: \.self) { question in
                            Button(question) {
                                selectedSecurityQuestion = question
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 20)
                            Text(selectedSecurityQuestion.isEmpty ? "" : selectedSecurityQuestion)
                                .foregroundColor(selectedSecurityQuestion.isEmpty ? .white.opacity(0.6) : .white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.caption)
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
                    }

                    // 보안질문 답변
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20)
                        TextField("", text: $securityAnswer)
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
                }
                .padding(.horizontal)

                if !authManager.errorMessage.isEmpty {
                    Text(authManager.errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Button {
                    if password != confirmPassword {
                        authManager.errorMessage = "비밀번호가 일치하지 않습니다."
                        return
                    }

                    if selectedSecurityQuestion.isEmpty {
                        authManager.errorMessage = "보안질문을 선택해주세요."
                        return
                    }

                    if securityAnswer.isEmpty {
                        authManager.errorMessage = "보안질문 답변을 입력해주세요."
                        return
                    }

                    Task {
                        await authManager.signUp(email: email, password: password, securityQuestion: selectedSecurityQuestion, securityAnswer: securityAnswer)
                    }
                } label: {
                    Text("회원가입")
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
                .padding(.horizontal)
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || selectedSecurityQuestion.isEmpty || securityAnswer.isEmpty)

                Button("이미 계정이 있으신가요?") {
                    dismiss()
                }
                .foregroundColor(.white.opacity(0.9))
                .font(.caption)
                .padding(.top)
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
                if authManager.isAuthenticated {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                alertMessage = "회원가입이 완료되었습니다!"
                showingAlert = true
            }
        }
        .overlay {
            if authManager.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
}
