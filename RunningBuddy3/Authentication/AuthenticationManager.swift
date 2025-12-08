import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// Purpose: Firebase Authentication 관리 및 사용자 인증 상태 처리
// MARK: - 함수 목록
/*
 * Authentication State
 * - setupAuthStateListener(): Firebase 인증 상태 변경 감지 설정 및 자동 UserData 로드
 *
 * Authentication Methods
 * - signUp(): 아이디/비밀번호 회원가입
 * - signIn(): 아이디/비밀번호 로그인 (마이그레이션 포함)
 * - signOut(): 로그아웃 처리
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

    // Purpose: 현재 사용자의 Firestore 데이터 캐싱 👈 어디서나 이 데이터를 사용가능
    @Published var currentUserData: UserData?

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
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Authentication State

    // ═══════════════════════════════════════
    // PURPOSE: Firebase 인증 상태 변경 감지 설정
    // ═══════════════════════════════════════
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user

                if let user = user {
                    // 👈 인증상태가 있으면 userID로 로드된 데이터를 ui로 업데이트 userData, records, strideModel 3가지
                    do {
                        let (userData, records, strideModel) = try await self?.userService.getUserDataWithCalibration(userId: user.uid) ?? (nil, [], nil)
                        self?.currentUserData = userData

                        // 👈 StrideCalibratorService.shared 싱글톤 인스턴스의 두 변수에 데이터저장
                        // 👈 @Published 변수는 반드시 메인 스레드에서 업데이트해야 함
                        await MainActor.run {
                            StrideCalibratorService.shared.calibrationRecords = records.sorted { $0.measuredAt > $1.measuredAt }
                            StrideCalibratorService.shared.strideModel = strideModel
                        }

                        if let model = strideModel {
                            DistanceCalculator.shared.setStrideModel(model)
                        } else {
                            await StrideCalibratorService.shared.recalculateStrideModel()
                        }
                    } catch {
                        await MainActor.run {
                            self?.errorMessage = "사용자 데이터 로드 실패: \(error.localizedDescription)"
                        }
                    }
                } else {
                    self?.currentUserData = nil
                }
            }
        }
    }

    // MARK: - Authentication Methods

    // ═══════════════════════════════════════
    // PURPOSE: 이메일/비밀번호 회원가입
    // ═══════════════════════════════════════
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
                return
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
    // PURPOSE: 이메일/비밀번호로 로그인 (개인 마이그레이션 포함)
    // ═══════════════════════════════════════
    func signIn(email: String, password: String) async {
        // Step 1: 로딩 상태 시작
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            // Step 2: Firebase 로그인 시도 (이메일 사용)
            let result = try await Auth.auth().signIn(withEmail: email, password: password)

            // Step 3: 사용자 데이터 마이그레이션 (필드명 변경 등)
            do {
                try await userService.migrateUserData(userId: result.user.uid)
            } catch {
                // 👈 마이그레이션 실패는 무시 (로그인 차단하지 않음)
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

        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "이미 사용 중인 이메일입니다."
        
        case AuthErrorCode.weakPassword.rawValue:
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
