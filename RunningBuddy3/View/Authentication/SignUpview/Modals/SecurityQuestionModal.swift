import SwiftUI
import Foundation
import Combine

// Purpose: 보안 질문 선택 및 답변 입력을 위한 모달
struct SecurityQuestionModal: View {

    // MARK: - Properties

    @ObservedObject var viewModel: SignUpViewModel
    @FocusState private var isAnswerFieldFocused: Bool

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
        VStack(spacing: 24) {
            headerSection
            securityQuestionSection
            securityAnswerSection
            securityGuideSection
            Spacer()
            navigationSection
        }
        .padding(30)
        .background(ModalBackground())
        .padding(.horizontal, 20)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("보안 질문")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("계정 보안을 위한 질문과 답변을 설정해주세요")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Security Question Section

    private var securityQuestionSection: some View {
        VStack(spacing: 12) {
            // Section title
            HStack {
                Text("보안 질문 선택")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            // Question menu
            Menu {
                ForEach(securityQuestions, id: \.self) { question in
                    Button(question) {
                        viewModel.signUpData.selectedSecurityQuestion = question
                        // 질문 선택 후 답변 필드로 포커스 이동
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isAnswerFieldFocused = true
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    Text(viewModel.signUpData.selectedSecurityQuestion.isEmpty
                         ? "질문을 선택해주세요"
                         : viewModel.signUpData.selectedSecurityQuestion)
                        .foregroundColor(viewModel.signUpData.selectedSecurityQuestion.isEmpty
                                       ? .white.opacity(0.6)
                                       : .white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
                .padding()
                .background(FieldBackground())
            }
        }
    }

    // MARK: - Security Answer Section

    private var securityAnswerSection: some View {
        VStack(spacing: 12) {
            // Section title
            HStack {
                Text("답변 입력")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            // Answer input field
            HStack {
                Image(systemName: "key")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                TextField(
                    viewModel.signUpData.selectedSecurityQuestion.isEmpty
                        ? "먼저 질문을 선택해주세요"
                        : "답변을 입력해주세요",
                    text: $viewModel.signUpData.securityAnswer
                )
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textContentType(.oneTimeCode)
                .disabled(viewModel.signUpData.selectedSecurityQuestion.isEmpty)
                .focused($isAnswerFieldFocused)

                Spacer()

                if !viewModel.signUpData.securityAnswer.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                FieldBackground(
                    strokeColor: viewModel.signUpData.selectedSecurityQuestion.isEmpty
                        ? Color.white.opacity(0.1)
                        : Color.white.opacity(0.2)
                )
            )
            .opacity(viewModel.signUpData.selectedSecurityQuestion.isEmpty ? 0.6 : 1.0)
        }
    }

    // MARK: - Security Guide Section

    @ViewBuilder
    private var securityGuideSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.white.opacity(0.6))
                Text("보안 팁")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                securityTip(text: "다른 사람이 쉽게 추측할 수 없는 답변을 입력하세요")
                securityTip(text: "답변은 정확히 기억할 수 있는 내용으로 설정하세요")
                securityTip(text: "대소문자를 구분하여 정확히 입력해주세요")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Security Tip Item

    private func securityTip(text: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "circle")
                .font(.system(size: 6))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 4)
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        NavigationButtons(
            canGoBack: true,
            canGoNext: true,
            nextButtonTitle: "다음",
            isNextDisabled: !canProceedToNext,
            onBack: {
                viewModel.goToPreviousStep()
            },
            onNext: {
                viewModel.goToNextStep()
            }
        )
    }

    // MARK: - Computed Properties

    // Purpose: 다음 단계로 진행 가능한지 확인
    private var canProceedToNext: Bool {
        return !viewModel.signUpData.selectedSecurityQuestion.isEmpty &&
               !viewModel.signUpData.securityAnswer.isEmpty &&
               viewModel.signUpData.securityAnswer.count >= 2 // 최소 2글자 이상
    }
}