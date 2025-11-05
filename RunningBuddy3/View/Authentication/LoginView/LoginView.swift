import SwiftUI
import FirebaseAuth

// 사용자 로그인을 위한 Glass UI 디자인의 로그인 화면
struct LoginView: View {
    
    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    // 사용자 입력 필드들
    @State private var email = ""
    @State private var password = ""
    // 화면 전환 상태 관리
    @State private var showingSignUp = false
    @State private var showingFindEmail = false
    // Alert 관리
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 배경 그라데이션
                Color.clear
                    .appGradientBackground()
                
                VStack(spacing: 20) {
                        // 앱 제목
                        Text("Running Buddy")
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
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                                    .textContentType(.oneTimeCode)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
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
                            )
                        }
                        .padding(.horizontal)

                        Button {
                            Task {
                                await signIn()
                            }
                        } label: {
                            Text("로그인")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        .padding(.horizontal)
                        .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                        
                        HStack(spacing: 20) {
                            Button("회원가입") {
                                showingSignUp = true
                            }
                            .foregroundColor(.white.opacity(0.9))
                            
                            Text("|")
                                .foregroundColor(.white.opacity(0.5))
                            
                            Button("아이디 찾기") {
                                showingFindEmail = true
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                        .font(.caption)
                        .padding(.bottom)
                }
                .padding(.top)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 20)
            }
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $showingFindEmail) {
                FindEmailView()
            }
            .alert("알림", isPresented: $showingAlert) {
                Button("확인") { }
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .onAppear {
                // LoginView 진입 시 이전 에러 메시지 초기화 👈 FindEmailView에서도 재설정전송 완료후 초기화 하는 부분이 있음
                authManager.errorMessage = ""
            }
        }
    }

    // MARK: - Methods

    // Purpose: 로그인 처리 및 에러 메시지를 alert로 표시
    private func signIn() async {
        await authManager.signIn(email: email, password: password)

        // 로그인 실패 시 에러 메시지를 alert로 표시
        if !authManager.errorMessage.isEmpty {
            alertMessage = authManager.errorMessage
            showingAlert = true

            // errorMessage 초기화
            await MainActor.run {
                authManager.errorMessage = ""
            }
        }
    }
}

