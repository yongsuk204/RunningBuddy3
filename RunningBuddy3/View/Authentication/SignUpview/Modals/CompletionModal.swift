import SwiftUI
import Foundation
import Combine

// Purpose: 회원가입 정보 확인 및 최종 제출을 위한 모달
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
            confirmationSection
            Spacer()
            navigationSection
        }
        .padding(30)
        .background(ModalBackground())
        .padding(.horizontal, 20)
        .alert("알림", isPresented: $showingAlert) {
            Button("확인") {
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
                icon: "phone",
                title: "전화번호",
                value: viewModel.signUpData.phoneNumber,
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
            .padding()
            .background(FieldBackground())
        }
    }
    
    // MARK: - Confirmation Section
    
    private var confirmationSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.green)
                Text("개인정보 처리방침 및 이용약관에 동의합니다")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.white.opacity(0.6))
                Text("입력하신 정보는 안전하게 암호화되어 저장됩니다")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        VStack(spacing: 12) {
            // Error message
            if !authManager.errorMessage.isEmpty {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(authManager.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            
            // Navigation buttons
            NavigationButtons(
                canGoBack: true,
                canGoNext: true,
                nextButtonTitle: "회원가입 완료",
                isNextDisabled: authManager.isLoading,
                onBack: {
                    viewModel.goToPreviousStep()
                },
                onNext: {
                    performSignUp()
                }
            )
        }
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
                phoneNumber: viewModel.signUpData.phoneNumber,
                securityQuestion: viewModel.signUpData.selectedSecurityQuestion,
                securityAnswer: viewModel.signUpData.securityAnswer
            )
        }
    }
}

// MARK: - Previews

#Preview("회원가입 완료 화면") {
    // Purpose: 회원가입 정보가 모두 입력된 상태의 미리보기
    CompletionModal(viewModel: {
        let vm = SignUpViewModel()
        vm.signUpData.email = "user@example.com"
        vm.signUpData.password = "Password123!"
        vm.signUpData.phoneNumber = "010-1234-5678"
        vm.signUpData.selectedSecurityQuestion = "가장 좋아하는 음식은?"
        vm.signUpData.securityAnswer = "피자"
        return vm
    }())
    .environmentObject(AuthenticationManager())
}

#Preview("로딩 상태") {
    // Purpose: 회원가입 중 로딩 상태 미리보기
    CompletionModal(viewModel: {
        let vm = SignUpViewModel()
        vm.signUpData.email = "user@example.com"
        vm.signUpData.password = "Password123!"
        vm.signUpData.phoneNumber = "010-1234-5678"
        vm.signUpData.selectedSecurityQuestion = "가장 좋아하는 음식은?"
        vm.signUpData.securityAnswer = "피자"
        return vm
    }())
    .environmentObject(AuthenticationManager())
    // Note: Preview에서는 실제 로딩 상태를 시뮬레이션할 수 없음
}

#Preview("긴 이메일 주소") {
    // Purpose: 긴 이메일 주소에서 레이아웃 테스트
    CompletionModal(viewModel: {
        let vm = SignUpViewModel()
        vm.signUpData.email = "very.long.email.address@example-domain.com"
        vm.signUpData.password = "Password123!"
        vm.signUpData.phoneNumber = "010-9876-5432"
        vm.signUpData.selectedSecurityQuestion = "어린 시절 가장 좋아했던 선생님의 성함은?"
        vm.signUpData.securityAnswer = "김철수"
        return vm
    }())
    .environmentObject(AuthenticationManager())
}

#Preview("다크모드") {
    CompletionModal(viewModel: {
        let vm = SignUpViewModel()
        vm.signUpData.email = "user@example.com"
        vm.signUpData.password = "Password123!"
        vm.signUpData.phoneNumber = "010-1234-5678"
        vm.signUpData.selectedSecurityQuestion = "가장 좋아하는 음식은?"
        vm.signUpData.securityAnswer = "피자"
        return vm
    }())
    .environmentObject(AuthenticationManager())
    .preferredColorScheme(.dark)
}
