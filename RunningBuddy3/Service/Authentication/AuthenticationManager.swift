import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// Purpose: Firebase Authentication 관리 및 사용자 인증 상태 처리
class AuthenticationManager: ObservableObject {

    // MARK: - Published Properties

    // Purpose: 현재 로그인된 사용자 정보
    @Published var currentUser: User?

    // Purpose: 사용자 인증 여부 확인
    @Published var isAuthenticated: Bool = false

    // Purpose: 로딩 상태 표시
    @Published var isLoading: Bool = false

    // Purpose: 에러 메시지 저장
    @Published var errorMessage: String = ""

    // MARK: - Private Properties

    // Purpose: Firebase Auth 상태 리스너 핸들
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // Purpose: Combine cancellables 저장
    private var cancellables = Set<AnyCancellable>()

    // Purpose: 사용자 데이터 관리 서비스
    private let userService = UserService.shared

    // MARK: - Initialization

    init() {
        setupAuthStateListener()
    }

    deinit {
        // Purpose: 메모리 누수 방지를 위한 리스너 정리
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Authentication State

    // Purpose: Firebase 인증 상태 변경 감지 설정
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                // Step 1: 사용자 정보 업데이트
                self?.currentUser = user
                // Step 2: 인증 상태 업데이트
                self?.isAuthenticated = user != nil
            }
        }
    }

    // MARK: - Authentication Methods

    // Purpose: 이메일/비밀번호와 보안질문으로 회원가입
    func signUp(email: String, password: String, securityQuestion: String?, securityAnswer: String?) async {
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
                    securityQuestion: securityQuestion!,
                    securityAnswer: securityAnswer!
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = "사용자 정보 저장 실패: \(error.localizedDescription)"
                }
                print("사용자 정보 저장 실패: \(error.localizedDescription)")
                return
            }

            // Step 4: 성공 로그
            print("회원가입 성공: \(result.user.email ?? "")")

        } catch {
            // Step 5: 에러 처리
            await MainActor.run {
                self.errorMessage = self.handleAuthError(error)
            }
            print("회원가입 실패: \(error.localizedDescription)")
        }

        // Step 6: 로딩 상태 종료
        await MainActor.run {
            isLoading = false
        }
    }


    // Purpose: 이메일/비밀번호로 로그인
    func signIn(email: String, password: String) async {
        // Step 1: 로딩 상태 시작
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            // Step 2: Firebase 로그인 시도
            let result = try await Auth.auth().signIn(withEmail: email, password: password)

            // Step 3: 성공 로그
            print("로그인 성공: \(result.user.email ?? "")")

        } catch {
            // Step 4: 에러 처리
            await MainActor.run {
                self.errorMessage = self.handleAuthError(error)
            }
            print("로그인 실패: \(error.localizedDescription)")
        }

        // Step 5: 로딩 상태 종료
        await MainActor.run {
            isLoading = false
        }
    }

    // Purpose: 로그아웃 처리
    func signOut() {
        do {
            // Step 1: Firebase 로그아웃 실행
            try Auth.auth().signOut()
            print("로그아웃 성공")

        } catch {
            // Step 2: 에러 처리
            errorMessage = handleAuthError(error)
            print("로그아웃 실패: \(error.localizedDescription)")
        }
    }

    // Purpose: 비밀번호 재설정 이메일 발송
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
            print("비밀번호 재설정 이메일 발송 성공")

        } catch {
            // Step 4: 에러 처리
            await MainActor.run {
                self.errorMessage = self.handleAuthError(error)
            }
            print("비밀번호 재설정 실패: \(error.localizedDescription)")
        }

        // Step 5: 로딩 상태 종료
        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: - Error Handling

    // Purpose: Firebase 에러를 간소화된 메시지로 변환
    private func handleAuthError(_ error: Error) -> String {
        let nsError = error as NSError

        // 보안상 간소화된 에러 메시지
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