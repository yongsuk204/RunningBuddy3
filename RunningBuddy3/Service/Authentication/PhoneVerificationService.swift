import Foundation
import FirebaseAuth
import FirebaseCore
import Combine
import UIKit

// Purpose: SMS 인증 코드 검증 서비스 (이메일 찾기 전용)
// MARK: - 함수 목록
/*
 * Verification Methods
 * - sendVerificationCode(): SMS 인증 코드 발송 (APNs 사일런트 푸시로 기기 검증 → SMS 발송)
 * - verifyCode(): 6자리 코드 검증 및 Firebase 로그인
 * - resendVerificationCode(): 코드 재발송
 *
 * Helper Methods
 * - formatPhoneNumber(): 한국 번호 → 국제 형식 (+821012345678)
 * - handleAuthError(): 에러 → 한국어 메시지 변환
 * - createAuthUIDelegate(): reCAPTCHA 웹뷰용 UIDelegate 생성
 */
@MainActor
class PhoneVerificationService: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = PhoneVerificationService()
    private override init() {
        super.init()
    }

    // MARK: - Properties

    @Published var verificationID: String?  // Purpose: Firebase 세션 ID (코드 검증에 필요)
    @Published var isLoading = false        // Purpose: 로딩 상태
    @Published var errorMessage: String?    // Purpose: 에러 메시지

    // MARK: - Phone Authentication Methods

    // Purpose: SMS 인증 코드 발송
    // Flow: 번호 변환 → Firebase 호출 → APNs 기기 검증 → SMS 발송 → verificationID 반환 👈 핵심과정
    func sendVerificationCode(to phoneNumber: String) async -> Result<String, Error> {
        isLoading = true
        errorMessage = nil

        // Step 1: 전화번호 형식 변환 (한국 번호 → 국제 형식)
        let formattedNumber = formatPhoneNumber(phoneNumber)

        // Step 1.5: Firebase Auth 초기화 확인 👈  FirebaseApp.configure() 초기화한거를 FirebaseApp.app() 인스턴스로 접근함
        guard FirebaseApp.app() != nil else {
            let error = NSError(domain: "PhoneVerificationService", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "Firebase가 초기화되지 않았습니다."])
            isLoading = false
            errorMessage = error.localizedDescription
            return .failure(error)
        }

        // Step 2: Phone Auth 시작
        // Note: APNs 토큰은 이미 AppDelegate에서 Firebase에 등록되어 있음
        return await withCheckedContinuation { continuation in
            print("📲 PhoneAuthProvider.verifyPhoneNumber 호출...")
            print("📱 전화번호: \(formattedNumber)")

            // Step 3: UIDelegate 생성 (reCAPTCHA 처리용)
            let uiDelegate = createAuthUIDelegate()
            if uiDelegate == nil {
                print("⚠️ uiDelegate가 nil입니다!")
            } else {
                print("✅ uiDelegate 생성 완료")
            }

            // Step 4: PhoneAuthProvider 호출
            print("🔧 PhoneAuthProvider.provider() 호출 전...")
            let provider = PhoneAuthProvider.provider()
            print("🔧 PhoneAuthProvider 생성 완료")

            provider.verifyPhoneNumber(formattedNumber, uiDelegate: uiDelegate) { verificationID, error in
                    DispatchQueue.main.async {
                        self.isLoading = false

                        if let error = error {
                            print("❌ SMS 발송 실패: \(error)")
                            self.errorMessage = self.handleAuthError(error)
                            continuation.resume(returning: .failure(error))
                        } else if let verificationID = verificationID {
                            print("✅ SMS 발송 성공!")
                            // Step 3: 세션 ID 저장
                            self.verificationID = verificationID
                            continuation.resume(returning: .success(verificationID))
                        } else {
                            print("⚠️ verificationID와 error 모두 nil")
                            let unknownError = NSError(
                                domain: "PhoneVerificationService",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "알 수 없는 오류가 발생했습니다."]
                            )
                            self.errorMessage = unknownError.localizedDescription
                            continuation.resume(returning: .failure(unknownError))
                        }
                    }
                }
        }
    }

    // Purpose: SMS 인증 코드 검증 (로그인하지만 currentUser 변경 안 됨)
    // Flow: verificationID + 코드 → Credential 생성 → 검증 완료
    // Note: 이메일 찾기 전용 (리스너 비활성화 → Firebase 로그인 → 리스너 활성화)
    func verifyCode(_ code: String, authManager: AuthenticationManager) async -> Result<Bool, Error> {
        isLoading = true
        errorMessage = nil

        guard let verificationID = verificationID else {
            let error = NSError(
                domain: "PhoneVerificationService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "인증 세션이 없습니다. 다시 시도해주세요."]
            )
            isLoading = false
            errorMessage = error.localizedDescription
            return .failure(error)
        }

        do {
            // Step 1: AuthenticationManager 리스너 비활성화 (isListenerEnabled = false)
            authManager.disableListener()

            // Step 2: 인증 코드로 자격 증명 생성
            let credential = PhoneAuthProvider.provider()
                .credential(withVerificationID: verificationID, verificationCode: code)

            // Step 3: Firebase 서버에 코드 검증 (잘못된 코드면 에러 발생)
            _ = try await Auth.auth().signIn(with: credential)
            // Note: signIn() 시 리스너 호출되지만 isListenerEnabled = false라 무시됨

            // Step 4: 리스너 다시 활성화 (isListenerEnabled = true)
            authManager.enableListener()
            // Note: 이미 인증 상태 변경 완료되어 리스너 재호출 안 됨

            // Step 5: 성공 처리
            self.verificationID = nil // 세션 초기화
            isLoading = false

            return .success(true)

        } catch {
            // 에러 발생 시 리스너 다시 활성화
            authManager.enableListener()

            isLoading = false
            errorMessage = handleAuthError(error)
            return .failure(error)
        }
    }

    // Purpose: 인증 코드 재발송 (세션 초기화 후 재호출)
    func resendVerificationCode(to phoneNumber: String) async -> Result<String, Error> {
        verificationID = nil
        return await sendVerificationCode(to: phoneNumber)
    }

    // MARK: - Helper Methods

    // Purpose: 한국 번호 → 국제 형식 (010-1234-5678 → +821012345678)
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // 하이픈, 공백 제거
        let cleaned = phoneNumber.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 이미 국제 형식인 경우
        if cleaned.hasPrefix("+82") {
            return cleaned
        }

        // 010으로 시작하는 경우 → +8210...
        if cleaned.hasPrefix("010") {
            return "+82" + String(cleaned.dropFirst(1))
        }

        // 01X로 시작하는 경우 → +821X...
        if cleaned.hasPrefix("01") {
            return "+82" + String(cleaned.dropFirst(1))
        }

        // 기본값 (변환 실패 시 원본 반환)
        return cleaned
    }

    // Purpose: Firebase 에러 → 한국어 메시지 변환
    private func handleAuthError(_ error: Error) -> String {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.invalidPhoneNumber.rawValue:
            return "유효하지 않은 전화번호입니다."
        case AuthErrorCode.invalidVerificationCode.rawValue:
            return "잘못된 인증 코드입니다."
        case AuthErrorCode.invalidVerificationID.rawValue:
            return "인증 세션이 만료되었습니다. 다시 요청해주세요."
        case AuthErrorCode.sessionExpired.rawValue:
            return "인증 시간이 초과되었습니다. 다시 요청해주세요."
        case AuthErrorCode.quotaExceeded.rawValue:
            return "SMS 전송 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "너무 많은 요청이 있었습니다. 잠시 후 다시 시도해주세요."
        case AuthErrorCode.networkError.rawValue:
            return "네트워크 연결을 확인해주세요."
        default:
            return nsError.localizedDescription
        }
    }

    // Purpose: reCAPTCHA 웹뷰 표시용 UIDelegate 생성 (APNs 실패 시 폴백)
    private func createAuthUIDelegate() -> AuthUIDelegate? {
        // 현재 윈도우 씬 가져오기
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            print("⚠️ rootViewController를 찾을 수 없습니다.")
            return nil
        }

        return ViewControllerAuthUIDelegate(viewController: viewController)
    }
}

// Purpose: AuthUIDelegate 구현 (reCAPTCHA 모달 표시)
private class ViewControllerAuthUIDelegate: NSObject, AuthUIDelegate {
    weak var viewController: UIViewController?

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        viewController?.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        viewController?.dismiss(animated: flag, completion: completion)
    }
}
