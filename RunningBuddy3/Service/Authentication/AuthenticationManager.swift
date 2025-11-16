import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// Purpose: Firebase Authentication 관리 및 사용자 인증 상태 처리
// MARK: - 함수 목록
/*
 * Authentication State
 * - setupAuthStateListener(): Firebase 인증 상태 변경 감지 설정
 * - disableListener(): 리스너 일시 비활성화 (이메일 찾기 SMS 인증용)
 * - enableListener(): 리스너 다시 활성화
 *
 * Authentication Methods
 * - signUp(): 이메일/비밀번호 회원가입
 * - signIn(): 이메일/비밀번호 로그인 (마이그레이션 포함)
 * - signOut(): 로그아웃 처리
 * - deleteCurrentAccount(): 현재 계정 삭제
 * - sendPasswordReset(): 비밀번호 재설정 이메일 발송
 *
 * Error Handling
 * - handleAuthError(): Firebase Auth 에러를 한글 메시지로 변환
 */
class AuthenticationManager: ObservableObject {

    // MARK: - Published Properties

    // Purpose: 현재 로그인된 사용자 정보 (nil = 로그아웃, User 객체 = 로그인)
    @Published var currentUser: User?

    // Purpose: 로딩 상태 표시
    @Published var isLoading: Bool = false

    // Purpose: 에러 메시지 저장
    @Published var errorMessage: String = ""

    // MARK: - Private Properties

    // Purpose: Firebase Auth 상태 리스너 핸들
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // Purpose: 리스너 활성화 플래그 👈 리스너는 Auth의 변화가 있을때만 자동감지함
    private var isListenerEnabled: Bool = true

    // Purpose: Combine cancellables 저장
    private var cancellables = Set<AnyCancellable>()

    // Purpose: 사용자 데이터 관리 서비스
    private let userService = UserService.shared

    // MARK: - Initialization

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Authentication State

    // ═══════════════════════════════════════
    // PURPOSE: Firebase 인증 상태 변경 감지 설정 👈 !!!리스너!!!
    // Firebase Auth 서버에서 로그인유무를 확인해서 user 파라미터로 콜백해줌 👈 리스너는 이 콜백을 감지해서 값을 확인
    // ═══════════════════════════════════════
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard self?.isListenerEnabled == true else { return }
                self?.currentUser = user
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 리스너 일시 비활성화 (이메일 찾기 SMS 인증용)
    // ═══════════════════════════════════════
    func disableListener() {
        isListenerEnabled = false
    }

    // ═══════════════════════════════════════
    // PURPOSE: 리스너 다시 활성화
    // ═══════════════════════════════════════
    func enableListener() {
        isListenerEnabled = true
    }

    // ═══════════════════════════════════════
    // PURPOSE: 현재 로그인된 계정 삭제 (임시 전화번호 인증 계정 정리용)
    // ═══════════════════════════════════════
    func deleteCurrentAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthenticationManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "로그인된 사용자가 없습니다."]
            )
        }

        try await user.delete()
    }

    // MARK: - Authentication Methods

    // ═══════════════════════════════════════
    // PURPOSE: 이메일/비밀번호 회원가입
    // ═══════════════════════════════════════
    func signUp(email: String, password: String, phoneNumber: String, securityQuestion: String?, securityAnswer: String?) async {
        // Step 1: 로딩 상태 시작
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            // Step 2: Firebase 회원가입 시도
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Step 3: 사용자 정보를 Firestore에 저장
            do {
                try await userService.saveUserData(
                    userId: result.user.uid,
                    email: email,
                    phoneNumber: phoneNumber,
                    securityQuestion: securityQuestion!,
                    securityAnswer: securityAnswer!
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = "사용자 정보 저장 실패: \(error.localizedDescription)"
                }
                return
            }

            // Step 4: publicdata 컬렉션에 이메일 저장 (중복 가입 방지용)
            do {
                try await userService.saveEmailToPublicData(email)
            } catch {
                // publicdata 저장 실패는 치명적이지 않으므로 로그만 남기고 진행
                print("PublicData 이메일 저장 실패: \(error.localizedDescription)")
            }

        } catch {
            // Step 5: 에러 처리
            await MainActor.run {
                self.errorMessage = self.handleAuthError(error)
            }
        }

        // Step 6: 로딩 상태 종료
        await MainActor.run {
            isLoading = false
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 이메일/비밀번호로 로그인 (개인 마이그레이션 포함)
    // 마이그레이션은
    // ═══════════════════════════════════════
    func signIn(email: String, password: String) async {
        // Step 1: 로딩 상태 시작
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            // Step 2: Firebase 로그인 시도
            let result = try await Auth.auth().signIn(withEmail: email, password: password)

            // Step 3: 사용자 데이터 마이그레이션 (필드명 변경 등)
            do {
                try await userService.migrateUserData(userId: result.user.uid)
            } catch {
                print("⚠️ 데이터 마이그레이션 실패 (무시 가능): \(error.localizedDescription)")
            }

        } catch {
            // Step 4: 에러 처리
            await MainActor.run {
                self.errorMessage = self.handleAuthError(error)
            }
        }

        // Step 5: 로딩 상태 종료
        await MainActor.run {
            isLoading = false
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 로그아웃 처리
    // ═══════════════════════════════════════
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = handleAuthError(error)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 비밀번호 재설정 이메일 발송
    // ═══════════════════════════════════════
    func sendPasswordReset(email: String) async {
        // Step 1: 로딩 상태 시작
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            // Step 2: 비밀번호 재설정 이메일 발송
            try await Auth.auth().sendPasswordReset(withEmail: email)

            // Step 3: 성공 메시지
            await MainActor.run {
                self.errorMessage = "비밀번호 재설정 이메일이 발송되었습니다."
            }

        } catch {
            // Step 4: 에러 처리
            await MainActor.run {
                self.errorMessage = self.handleAuthError(error)
            }
        }

        // Step 5: 로딩 상태 종료
        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: - Error Handling

    // ═══════════════════════════════════════
    // PURPOSE: Firebase Auth 에러를 한글 메시지로 변환
    // NOTE: 보안상 간소화된 에러 메시지 제공
    // ═══════════════════════════════════════
    private func handleAuthError(_ error: Error) -> String {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return "올바른 이메일을 입력해주세요."

        case AuthErrorCode.emailAlreadyInUse.rawValue,
             AuthErrorCode.weakPassword.rawValue:
            return "입력한 정보를 다시 확인해주세요."

        case AuthErrorCode.wrongPassword.rawValue,
             AuthErrorCode.userNotFound.rawValue:
            return "이메일 또는 비밀번호를 확인해주세요."

        case AuthErrorCode.networkError.rawValue:
            return "네트워크 연결을 확인해주세요."

        case AuthErrorCode.tooManyRequests.rawValue:
            return "잠시 후 다시 시도해주세요."

        default:
            return "요청을 처리할 수 없습니다. 다시 시도해주세요."
        }
    }
}
