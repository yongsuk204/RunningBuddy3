import SwiftUI

// Purpose: 회원가입 정보 확인 및 최종 제출을 위한 모달
// MARK: - 함수 목록
/*
 * UI Components
 * - headerSection: 헤더 영역 (제목 및 설명)
 * - summarySection: 입력 정보 요약 표시
 * - navigationSection: 이전/회원가입 완료 버튼
 * - loadingOverlay: 회원가입 처리 중 로딩 화면
 *
 * Helper Methods
 * - summaryItem(): 요약 정보 항목 생성
 * - performSignUp(): 회원가입 수행
 */
struct CompletionModal: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: SignUpViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            summarySection
            Spacer()
            navigationSection
        }
        .padding(30)
        .modalBackgroundStyle()
        .padding(.horizontal, 20)
        .alert("알림", isPresented: $showingAlert) {
            Button("확인", role: .cancel) {
                if authManager.currentUser != nil {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: authManager.currentUser) { _, currentUser in
            if currentUser != nil {
                alertMessage = "회원가입이 완료되었습니다!"
                showingAlert = true
            }
        }
        .overlay(loadingOverlay)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("가입 정보 확인")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("입력하신 정보를 확인하고 회원가입을 완료해주세요")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 16) {
            summaryItem(
                icon: "envelope",
                title: "이메일",
                value: viewModel.signUpData.email,
                status: .valid
            )

            summaryItem(
                icon: "questionmark.circle",
                title: "보안 질문",
                value: viewModel.signUpData.selectedSecurityQuestion,
                status: .valid
            )

        }
    }
    
    // MARK: - Summary Item
    
    private func summaryItem(
        icon: String,
        title: String,
        value: String,
        status: ValidationFeedbackIcon.ValidationStatus
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                
                Spacer()
                
                ValidationFeedbackIcon(status: status)
            }
            .inputFieldStyle()
        }
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        NavigationButtons(
            canGoBack: true,
            canGoNext: true,
            nextButtonTitle: "회원가입 완료",
            isNextDisabled: authManager.isLoading,
            onBack: {
                viewModel.currentStep = .security
            },
            onNext: {
                performSignUp()
            }
        )
    }
    
    // MARK: - Loading Overlay
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if authManager.isLoading {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("회원가입 중...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                )
        }
    }
    
    // MARK: - Helper Methods
    
    // Purpose: 회원가입 수행
    private func performSignUp() {
        Task {
            await authManager.signUp(
                email: viewModel.signUpData.email,
                password: viewModel.signUpData.password,
                securityQuestion: viewModel.signUpData.selectedSecurityQuestion,
                securityAnswer: viewModel.signUpData.securityAnswer
            )
        }
    }
}
