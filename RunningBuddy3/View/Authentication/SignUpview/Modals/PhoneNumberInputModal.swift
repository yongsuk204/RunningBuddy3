import SwiftUI
import Foundation
import Combine

// Purpose: 전화번호 입력 및 유효성 검사를 위한 모달
// MARK: - 함수 목록
/*
 * UI Components
 * - headerSection: 헤더 영역 (제목 및 정보 버튼)
 * - phoneNumberInputSection: 전화번호 입력 필드
 * - navigationSection: 이전/다음 버튼
 *
 * Validation Methods
 * - handlePhoneNumberChange(): 전화번호 변경 시 실시간 포맷팅, 검증 및 중복 체크
 */
struct PhoneNumberInputModal: View {

    // MARK: - Properties

    // Purpose: 회원가입 전체 상태 및 데이터 관리 (전화번호 입력값, 검증 상태 등)
    @ObservedObject var viewModel: SignUpViewModel

    // Purpose: Firebase 인증 관리자 (회원가입 처리용)
    @EnvironmentObject var authManager: AuthenticationManager

    // Purpose: 전화번호 중복 체크를 위한 Firestore 사용자 서비스 (모달 내부에서만 사용)
    private let userService = UserService.shared

    // Purpose: 전화번호 형식 검증 및 포맷팅 서비스 (모달 내부에서만 사용)
    private let phoneNumberValidator = PhoneNumberValidator.shared

    // Purpose: 전화번호 정보 도움말 알림창 표시 여부 (내부 UI 상태)
    @State private var showingPhoneInfo = false

    // Purpose: 전화번호 입력 디바운싱을 위한 타이머 (0.5초 지연 후 검증 실행, 내부 제어용)
    @State private var phoneCheckTimer: Timer?

    // Purpose: 전화번호 입력 필드의 포커스 상태 관리 (내부 UI 제어, 키보드 표시/숨김)
    @FocusState private var focusedField: Field?

    // MARK: - Focus Field Enum

    private enum Field: Hashable {
        case phoneNumber
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            phoneNumberInputSection
            Spacer()
            navigationSection
        }
        .padding(30)
        .background(ModalBackground())
        .padding(.horizontal, 20)
        .onAppear {
            focusedField = .phoneNumber
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Text("전화번호")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showingPhoneInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Text("본인 확인을 위한 전화번호를 입력해 주세요")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 10)
        }
        .alert("전화번호 입력", isPresented: $showingPhoneInfo) {
            Button("확인") { }
        } message: {
            Text("\n• 전화번호는 본인 확인 및 보안을 위해 사용됩니다\n• 010, 011, 016, 017, 018, 019로 시작하는 번호만 가능합니다\n• 자동으로 하이픈(-)이 추가됩니다\n• 예시) 010-1234-5678")
        }
    }

    // MARK: - Phone Number Input Section

    private var phoneNumberInputSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                TextField("", text: $viewModel.signUpData.phoneNumber)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focusedField, equals: .phoneNumber)
                    .onChange(of: viewModel.signUpData.phoneNumber) { _, newValue in
                        handlePhoneNumberChange(newValue)
                    }

                Spacer()

                ValidationFeedbackIcon(status: viewModel.validationStates.phoneNumberStatus)
            }
            .padding()
            .background(FieldBackground())
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
        return viewModel.validationStates.phoneNumberStatus == .valid &&
               !viewModel.signUpData.phoneNumber.isEmpty
    }

    // MARK: - Helper Methods

    // Purpose: 전화번호 변경 시 포맷팅, 유효성 검사 및 중복 체크 (디바운싱 포함)
    private func handlePhoneNumberChange(_ newNumber: String) {
        // 이전 타이머 취소
        phoneCheckTimer?.invalidate()

        // Step 1: 자동 포맷팅 적용
        let formattedNumber = phoneNumberValidator.formatPhoneNumber(newNumber)
        if formattedNumber != newNumber {
            viewModel.signUpData.phoneNumber = formattedNumber
            return // onChange가 다시 호출되므로 여기서 종료
        }

        // Step 2: 기본 형식 체크 (실시간 입력용)
        guard phoneNumberValidator.isBasicValidFormat(formattedNumber) else {
            viewModel.validationStates.phoneNumberStatus = .none
            return
        }

        // 체크 중 상태로 변경
        viewModel.validationStates.phoneNumberStatus = .checking

        // 0.5초 디바운싱 후 상세 검증 및 중복 체크 실행
        phoneCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                // Step 3: 전화번호 형식 상세 검증
                let validationResult = phoneNumberValidator.validatePhoneNumber(formattedNumber)

                if !validationResult.isValid {
                    viewModel.validationStates.phoneNumberStatus = .invalid
                    return
                }

                // Step 4: 중복 체크 (publicdata 컬렉션 조회)
                do {
                    let exists = try await userService.checkPhoneNumberInPublicData(formattedNumber)
                    viewModel.validationStates.phoneNumberStatus = exists ? .invalid : .valid
                } catch {
                    viewModel.validationStates.phoneNumberStatus = .none
                }
            }
        }
    }
}