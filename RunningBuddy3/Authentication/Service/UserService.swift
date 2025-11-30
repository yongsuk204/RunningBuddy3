import Foundation
import FirebaseFirestore
import FirebaseAuth

// Purpose: Firestore에서 사용자 데이터를 관리하는 서비스
// MARK: - 함수 목록
/*
 * User Data Management
 * - saveUserData(): 회원가입 시 사용자 정보를 Firestore users 컬렉션에 저장
 * - getUserData(): 사용자 ID로 사용자 정보 조회
 * - verifySecurityAnswer(): 보안질문 답변 검증 👈 추후 사용예정
 * - updateUserData(): 사용자 데이터 업데이트 👈 추후 사용예정
 * - deleteUserData(): 사용자 데이터 삭제 👈 추후 사용예정
 *
 * Leg Length Management
 * - updateLegLength(): 다리 길이 저장
 *
 * Calibration Data Management
 * - saveCalibrationData(): 캘리브레이션 데이터 저장
 * - getCalibrationData(): 캘리브레이션 데이터 조회
 *
 * Username Methods
 * - checkUsernameExists(): 아이디 중복 체크
 * - getEmailByUsername(): 아이디로 이메일 조회 (로그인용)
 *
 * Data Migration
 * - migrateUserData(): 로그인 시 사용자 데이터 마이그레이션 (필드명 변경 등) 👈 배포전까지는 아마 필요없을거임
 *
 * Duplicate Check Methods
 * - checkPhoneNumberExists(): 전화번호 중복 체크 (회원가입용)
 *
 * ID Recovery Methods
 * - findEmailByPhoneNumber(): 전화번호로 사용자 아이디 찾기 (단일 계정)
 */
class UserService {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = UserService()

    // MARK: - Properties

    // Purpose: Firestore 데이터베이스 참조
    private let firestore = FirebaseManager.shared.firestore

    // Purpose: SecurityService 인스턴스
    private let securityService = SecurityService.shared

    // Purpose: 컬렉션 이름
    private let usersCollection = "users"

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - User Data Management

    // ═══════════════════════════════════════
    // PURPOSE: 회원가입 시 사용자 정보를 Firestore에 저장
    // ═══════════════════════════════════════
    func saveUserData(userId: String, username: String, email: String, phoneNumber: String, securityQuestion: String, securityAnswer: String) async throws {
        // Step 1: 보안질문 답변만 해시화
        let hashedAnswer = securityService.hash(securityAnswer)

        // Step 2: UserData 객체 생성
        let userData = UserData(
            userId: userId,
            username: username,
            email: email,
            phoneNumber: phoneNumber,
            securityQuestion: securityQuestion,
            securityAnswer: hashedAnswer
        )

        // Step 4: Firestore에 저장 👈 userData.toDictionary() 상태로 저장!!
        do {
            try await firestore.collection(usersCollection).document(userId).setData(userData.toDictionary())
            print("UserService: 사용자 데이터 저장 성공 - \(email)")
        } catch {
            print("UserService: 사용자 데이터 저장 실패 - \(error.localizedDescription)")
            throw UserServiceError.saveFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 ID로 사용자 정보 조회
    // ═══════════════════════════════════════
    func getUserData(userId: String) async throws -> UserData? {
        do {
            // Step 1: Firestore에서 문서 조회
            let document = try await firestore.collection(usersCollection).document(userId).getDocument()

            // Step 2: 문서 존재 여부 확인 let data = document.data() 👈 firestore에 저장된 원본
            guard document.exists, let data = document.data() else {
                print("UserService: 사용자 데이터 없음 - \(userId)")
                return nil
            }

            // Step 3: UserData 객체로 변환 👈 UserData.fromDictionary(data) 상태로 가져옴!!
            guard let userData = UserData.fromDictionary(data) else {
                print("UserService: 데이터 변환 실패 - \(userId)")
                throw UserServiceError.dataConversionFailed
            }

            print("UserService: 사용자 데이터 조회 성공 - \(userData.email)")
            return userData

        } catch {
            print("UserService: 사용자 데이터 조회 실패 - \(error.localizedDescription)")
            throw UserServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 보안질문 답변 검증
    // STATUS: 준비 완료 (미사용) - 비밀번호 재설정, 계정 복구 등에서 사용 예정
    // ═══════════════════════════════════════
    func verifySecurityAnswer(userId: String, inputAnswer: String) async throws -> Bool {
        // Step 1: 사용자 데이터 조회
        guard let userData = try await getUserData(userId: userId) else {
            throw UserServiceError.userNotFound
        }

        // Step 2: 보안질문 답변 검증
        let isValid = securityService.verify(inputAnswer, hashedValue: userData.securityAnswer)

        print("UserService: 보안질문 답변 검증 결과 - \(isValid)")
        return isValid
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 데이터 업데이트
    // STATUS: 준비 완료 (미사용) - 프로필 수정, 보안질문 변경 등에서 사용 예정
    // ═══════════════════════════════════════
    func updateUserData(userId: String, updates: [String: Any]) async throws {
        do {
            try await firestore.collection(usersCollection).document(userId).updateData(updates)
            print("UserService: 사용자 데이터 업데이트 성공 - \(userId)")
        } catch {
            print("UserService: 사용자 데이터 업데이트 실패 - \(error.localizedDescription)")
            throw UserServiceError.updateFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 데이터 삭제 (users 컬렉션)
    // STATUS: 준비 완료 (미사용) - 회원 탈퇴, 계정 삭제 기능에서 사용 예정
    // ═══════════════════════════════════════
    func deleteUserData(userId: String) async throws {
        do {
            // users 컬렉션에서 사용자 문서 삭제
            try await firestore.collection(usersCollection).document(userId).delete()
            print("UserService: 사용자 데이터 삭제 성공 - \(userId)")

        } catch {
            print("UserService: 사용자 데이터 삭제 실패 - \(error.localizedDescription)")
            throw UserServiceError.deleteFailed(error.localizedDescription)
        }
    }


    // MARK: - Username Methods

    // ═══════════════════════════════════════
    // PURPOSE: 아이디 중복 체크
    // ═══════════════════════════════════════
    func checkUsernameExists(_ username: String) async throws -> Bool {
        do {
            let querySnapshot = try await firestore
                .collection(usersCollection)
                .whereField("username", isEqualTo: username)
                .getDocuments()

            let exists = !querySnapshot.documents.isEmpty
            print("UserService: 아이디 중복 체크 - \(exists ? "이미 존재" : "사용 가능")")
            return exists

        } catch {
            print("UserService: 아이디 중복 체크 실패 - \(error.localizedDescription)")
            throw UserServiceError.searchFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 아이디로 이메일 조회 (로그인용)
    // ═══════════════════════════════════════
    func getEmailByUsername(_ username: String) async throws -> String? {
        do {
            let querySnapshot = try await firestore
                .collection(usersCollection)
                .whereField("username", isEqualTo: username)
                .getDocuments()

            guard let document = querySnapshot.documents.first else {
                print("UserService: 아이디를 찾을 수 없음 - \(username)")
                return nil
            }

            guard let userData = UserData.fromDictionary(document.data()) else {
                print("UserService: 데이터 변환 실패 - \(username)")
                return nil
            }

            print("UserService: 아이디로 이메일 조회 성공 - \(username)")
            return userData.email

        } catch {
            print("UserService: 아이디로 이메일 조회 실패 - \(error.localizedDescription)")
            throw UserServiceError.searchFailed(error.localizedDescription)
        }
    }

    // MARK: - Leg Length Management

    // ═══════════════════════════════════════
    // PURPOSE: 다리 길이 저장
    // PARAMETERS:
    //   - userId: 사용자 ID
    //   - legLength: 다리 길이 (cm)
    //   - authManager: AuthenticationManager (캐시 업데이트용)
    // FUNCTIONALITY:
    //   - Firestore 저장
    //   - AuthenticationManager 캐시 업데이트
    // ═══════════════════════════════════════
    @MainActor
    func updateLegLength(userId: String, legLength: Double, authManager: AuthenticationManager) async throws {
        // Step 1: Firestore 저장
        try await updateUserData(userId: userId, updates: [
            "legLength": legLength
        ])

        // Step 2: AuthenticationManager 캐시 업데이트
        if let userData = authManager.currentUserData {
            authManager.currentUserData = UserData(
                userId: userData.userId,
                username: userData.username,
                email: userData.email,
                phoneNumber: userData.phoneNumber,
                securityQuestion: userData.securityQuestion,
                securityAnswer: userData.securityAnswer,
                legLength: legLength,
                calibrationData: userData.calibrationData,
                createdAt: userData.createdAt
            )
        }

        print("✅ 다리 길이 저장 완료: \(String(format: "%.1f", legLength)) cm")
    }

    // MARK: - Calibration Data Management

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 데이터 저장
    // ═══════════════════════════════════════
    func saveCalibrationData(userId: String, calibrationData: CalibrationData) async throws {
        do {
            try await firestore.collection(usersCollection).document(userId).updateData([
                "calibrationData": calibrationData.toDictionary()
            ])
            print("UserService: 캘리브레이션 데이터 저장 성공")
            print("   - 걸음 수: \(calibrationData.totalSteps)걸음")
            print("   - 평균 케이던스: \(String(format: "%.1f", calibrationData.averageCadence)) SPM")
            print("   - 평균 보폭: \(String(format: "%.2f", calibrationData.averageStepLength))m")
        } catch {
            print("UserService: 캘리브레이션 데이터 저장 실패 - \(error.localizedDescription)")
            throw UserServiceError.updateFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 데이터 조회
    // ═══════════════════════════════════════
    func getCalibrationData(userId: String) async throws -> CalibrationData? {
        do {
            let document = try await firestore.collection(usersCollection).document(userId).getDocument()

            guard document.exists, let data = document.data() else {
                print("UserService: 사용자 데이터 없음")
                return nil
            }

            if let calibrationDict = data["calibrationData"] as? [String: Any] {
                let calibrationData = CalibrationData.fromDictionary(calibrationDict)
                print("UserService: 캘리브레이션 데이터 조회 성공")
                return calibrationData
            } else {
                print("UserService: 캘리브레이션 데이터 없음 (측정 필요)")
                return nil
            }

        } catch {
            print("UserService: 캘리브레이션 데이터 조회 실패 - \(error.localizedDescription)")
            throw UserServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Data Migration

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 데이터 마이그레이션 (필드명 변경 등)
    // NOTE: 로그인 시 자동 실행 (개인별 점진적 적용)
    // CURRENT: hashedSecurityAnswer → securityAnswer 필드명 변경
    // ═══════════════════════════════════════
    func migrateUserData(userId: String) async throws {
        // Step 1: 해당 사용자 문서만 가져오기
        let documentRef = firestore.collection(usersCollection).document(userId)
        let document = try await documentRef.getDocument()

        // Step 2: 문서가 없으면 종료
        guard document.exists else {
            print("⚠️ 사용자 문서 없음 (마이그레이션 불필요)")
            return
        }

        // Step 3: 기존 필드가 있는지 확인
        if let oldValue = document.data()?["hashedSecurityAnswer"] as? String {
            // Step 4: 신규 필드명으로 변경
            try await documentRef.updateData([
                "securityAnswer": oldValue,
                "hashedSecurityAnswer": FieldValue.delete()
            ])
            print("✅ 개인 마이그레이션 완료: \(userId)")
        } else {
            print("⏭️ 마이그레이션 불필요 (이미 완료되었거나 신규 가입자)")
        }
    }

    // MARK: - Duplicate Check Methods

    // ═══════════════════════════════════════
    // PURPOSE: 전화번호 중복 체크
    // NOTE: 회원가입 시 사용, 한 전화번호당 하나의 계정만 허용
    // ═══════════════════════════════════════
    func checkPhoneNumberExists(_ phoneNumber: String) async throws -> Bool {
        do {
            let querySnapshot = try await firestore
                .collection(usersCollection)
                .whereField("phoneNumber", isEqualTo: phoneNumber)
                .limit(to: 1)
                .getDocuments()

            let exists = !querySnapshot.documents.isEmpty
            print("UserService: 전화번호 중복 체크 - \(exists ? "이미 존재" : "사용 가능")")
            return exists

        } catch {
            print("UserService: 전화번호 중복 체크 실패 - \(error.localizedDescription)")
            throw UserServiceError.searchFailed(error.localizedDescription)
        }
    }

    // MARK: - ID Recovery Methods

    // ═══════════════════════════════════════
    // PURPOSE: 전화번호로 사용자 아이디 찾기 (단일 계정)
    // NOTE: 전화번호는 원본으로 저장되어 Firestore 쿼리 가능
    // NOTE: 한 전화번호당 하나의 계정만 가능하므로 단일 아이디 반환
    // ═══════════════════════════════════════
    func findEmailByPhoneNumber(_ phoneNumber: String) async throws -> String? {
        do {
            // Step 1: Firestore 쿼리로 전화번호 일치하는 사용자 찾기
            let querySnapshot = try await firestore
                .collection(usersCollection)
                .whereField("phoneNumber", isEqualTo: phoneNumber)
                .limit(to: 1)  // 한 전화번호당 하나의 계정만 가능
                .getDocuments()

            // Step 2: 첫 번째 문서에서 아이디 추출
            guard let document = querySnapshot.documents.first,
                  let userData = UserData.fromDictionary(document.data()) else {
                print("UserService: 해당 전화번호로 가입된 계정 없음")
                return nil
            }

            print("UserService: 전화번호로 아이디 찾기 완료 - \(userData.email)")
            return userData.email

        } catch {
            print("UserService: 전화번호로 아이디 찾기 실패 - \(error.localizedDescription)")
            throw UserServiceError.searchFailed(error.localizedDescription)
        }
    }

}

// MARK: - Error Types

// Purpose: UserService에서 발생할 수 있는 에러 타입 정의
enum UserServiceError: LocalizedError {
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case searchFailed(String)
    case dataConversionFailed
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "사용자 데이터 저장 실패: \(message)"
        case .fetchFailed(let message):
            return "사용자 데이터 조회 실패: \(message)"
        case .updateFailed(let message):
            return "사용자 데이터 업데이트 실패: \(message)"
        case .deleteFailed(let message):
            return "사용자 데이터 삭제 실패: \(message)"
        case .searchFailed(let message):
            return "사용자 검색 실패: \(message)"
        case .dataConversionFailed:
            return "데이터 변환 실패"
        case .userNotFound:
            return "사용자를 찾을 수 없습니다"
        }
    }
}
