import Foundation
import FirebaseFirestore
import FirebaseAuth

// Purpose: Firestore에서 사용자 데이터를 관리하는 서비스
// MARK: - 함수 목록
/*
 * User Data Management
 * - saveUserData(): 회원가입 시 사용자 정보를 Firestore users 컬렉션에 저장
 * - getUserData(): 사용자 ID로 사용자 정보 조회
 * - getUserDataWithCalibration(): 사용자 정보 + 캘리브레이션 + 선형 모델기록 한 번에 조회
 * - verifySecurityAnswer(): 보안질문 답변 검증 👈 추후 사용예정
 * - updateUserData(): 사용자 데이터 업데이트 👈 추후 사용예정
 * - deleteUserData(): 사용자 데이터 삭제 👈 추후 사용예정
 *
 * Calibration History Management
 * - saveCalibrationRecord(): 새 캘리브레이션 기록 추가 (subcollection)
 * - loadCalibrationRecords(): 모든 캘리브레이션 기록 로드 👈 추후 사용예정
 * - deleteCalibrationRecord(): 캘리브레이션 기록 삭제
 * - saveStrideModel(): 선형 회귀 모델 저장
 * - loadStrideModel(): 선형 회귀 모델 로드 👈 추후 사용예정
 * - deleteStrideModel(): 선형 회귀 모델 삭제
 *
 * Data Migration
 * - migrateUserData(): 로그인 시 사용자 데이터 마이그레이션 (필드명 변경 등) 👈 배포전까지는 아마 필요없을거임
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
    func saveUserData(userId: String, email: String, securityQuestion: String, securityAnswer: String) async throws {
        // Step 1: 보안질문 답변만 해시화
        let hashedAnswer = securityService.hash(securityAnswer)

        // Step 2: UserData 객체 생성
        let userData = UserData(
            userId: userId,
            email: email,
            securityQuestion: securityQuestion,
            securityAnswer: hashedAnswer
        )

        // Step 4: Firestore에 저장 👈 userData.toDictionary() 상태로 저장!!
        do {
            try await firestore.collection(usersCollection).document(userId).setData(userData.toDictionary())
        } catch {
            throw UserServiceError.saveFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 ID로 사용자 정보 조회
    // ═══════════════════════════════════════
    func getUserData(userId: String) async throws -> UserData? {
        do {
            let document = try await firestore.collection(usersCollection).document(userId).getDocument()

            guard document.exists, let data = document.data() else {
                return nil
            }

            guard let userData = UserData.fromDictionary(data) else {
                throw UserServiceError.dataConversionFailed
            }

            return userData

        } catch {
            throw UserServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 정보 + 캘리브레이션 기록 + 선형 모델 한 번에 조회
    // RETURNS: (UserData, [CalibrationData], StrideData?)
    // FUNCTIONALITY:
    //   - Firestore 읽기 1회로 모든 데이터 로드
    //   - 로그인 시 사용
    // ═══════════════════════════════════════
    func getUserDataWithCalibration(userId: String) async throws -> (UserData, [CalibrationData], StrideData?) {
        do {
            let document = try await firestore.collection(usersCollection).document(userId).getDocument()

            guard document.exists, let data = document.data() else {
                throw UserServiceError.userNotFound
            }

            guard let userData = UserData.fromDictionary(data) else {
                throw UserServiceError.dataConversionFailed
            }

            // 👈Firestore 저장 형식: JSON-like 딕셔너리 [String: Any]
            // Swift 사용 형식: 타입 안전한 CalibrationData 구조체
            // recordsArray: [[String: Any]] - Firestore 원본 형식
            // records: [CalibrationData] - Swift에서 사용할 수 있는 타입 안전한 배열
            let recordsArray = data["calibrationRecords"] as? [[String: Any]] ?? []
            let records = recordsArray.compactMap { dict -> CalibrationData? in
                CalibrationData.fromDictionary(dict)
            }

            var strideModel: StrideData?
            if let modelData = data["strideModel"] as? [String: Any] {
                strideModel = StrideData.fromDictionary(modelData)
            }

            return (userData, records, strideModel)

        } catch {
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
        return isValid
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 데이터 업데이트
    // STATUS: 준비 완료 (미사용) - 프로필 수정, 보안질문 변경 등에서 사용 예정
    // ═══════════════════════════════════════
    func updateUserData(userId: String, updates: [String: Any]) async throws {
        do {
            try await firestore.collection(usersCollection).document(userId).updateData(updates)
        } catch {
            throw UserServiceError.updateFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 데이터 삭제 (users 컬렉션)
    // STATUS: 준비 완료 (미사용) - 회원 탈퇴, 계정 삭제 기능에서 사용 예정
    // ═══════════════════════════════════════
    func deleteUserData(userId: String) async throws {
        do {
            try await firestore.collection(usersCollection).document(userId).delete()
        } catch {
            throw UserServiceError.deleteFailed(error.localizedDescription)
        }
    }


    // MARK: - Calibration History Management

    // ═══════════════════════════════════════
    // PURPOSE: 새 캘리브레이션 기록 추가 (배열에 추가)
    // PARAMETERS:
    //   - record: 새 캘리브레이션 데이터
    // FUNCTIONALITY:
    //   - users/{userId}/calibrationRecords 배열에 새 기록 추가
    //   - averageStepLength를 명시적으로 저장 (선형회귀 모델용)
    // ═══════════════════════════════════════
    func saveCalibrationRecord(_ record: CalibrationData) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw UserServiceError.notLoggedIn
        }

        let documentRef = firestore
            .collection(usersCollection)
            .document(userId)

        try await documentRef.updateData([
            "calibrationRecords": FieldValue.arrayUnion([record.toDictionary(userId: userId)])
        ])
    }

    // ═══════════════════════════════════════
    // PURPOSE: 모든 캘리브레이션 기록 로드
    // RETURNS: 캘리브레이션 기록 배열 (시간순)
    // FUNCTIONALITY:
    //   - users/{userId}/calibrationRecords 배열에서 로드
    // ═══════════════════════════════════════
    func loadCalibrationRecords() async throws -> [CalibrationData] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw UserServiceError.notLoggedIn
        }

        let document = try await firestore
            .collection(usersCollection)
            .document(userId)
            .getDocument()

        // 👈 전체 데이터에서 캘리브레이션있는 부분만 찾음
        guard let data = document.data(),
              let recordsArray = data["calibrationRecords"] as? [[String: Any]] else {
            return []
        }

        // 👈 캘리브레이션 전체 내용을 (딕셔너리) 를 CalibrationData 기준으로 나눠서 배열에 담음
        let records = recordsArray.compactMap { dict -> CalibrationData? in
            CalibrationData.fromDictionary(dict)
        }

        return records
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 기록 삭제
    // PARAMETERS:
    //   - record: 삭제할 캘리브레이션 데이터 👈 인덱스 번호가 아니라 데이너 내용일치여부로 삭제함
    // FUNCTIONALITY:
    //   - users/{userId}/calibrationRecords 배열에서 해당 기록 제거
    // ═══════════════════════════════════════
    func deleteCalibrationRecord(_ record: CalibrationData) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw UserServiceError.notLoggedIn
        }

        let documentRef = firestore
            .collection(usersCollection)
            .document(userId)

        // FieldValue.arrayRemove를 사용하여 배열에서 제거
        try await documentRef.updateData([
            "calibrationRecords": FieldValue.arrayRemove([record.toDictionary(userId: userId)])
        ])
    }

    // ═══════════════════════════════════════
    // PURPOSE: 선형 회귀 모델 저장
    // PARAMETERS:
    //   - model: 계산된 선형 회귀 모델
    // FUNCTIONALITY:
    //   - users/{userId}/strideModel 필드에 저장
    // ═══════════════════════════════════════
    func saveStrideModel(_ model: StrideData) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw UserServiceError.notLoggedIn
        }

        try await firestore
            .collection(usersCollection)
            .document(userId)
            .updateData(["strideModel": model.toDictionary()])
    }

    // ═══════════════════════════════════════
    // PURPOSE: 선형 회귀 모델 로드
    // RETURNS: 저장된 선형 회귀 모델 (없으면 nil)
    // ═══════════════════════════════════════
    func loadStrideModel() async throws -> StrideData? {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw UserServiceError.notLoggedIn
        }

        let document = try await firestore
            .collection(usersCollection)
            .document(userId)
            .getDocument()

        guard let data = document.data(),
              let modelData = data["strideModel"] as? [String: Any] else {
            return nil
        }

        return StrideData.fromDictionary(modelData)
    }

    // ═══════════════════════════════════════
    // PURPOSE: 선형 회귀 모델 삭제
    // FUNCTIONALITY:
    //   - users/{userId}/strideModel 필드 삭제
    // ═══════════════════════════════════════
    func deleteStrideModel() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw UserServiceError.notLoggedIn
        }

        try await firestore
            .collection(usersCollection)
            .document(userId)
            .updateData(["strideModel": FieldValue.delete()])
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
            return
        }

        // Step 3: 기존 필드가 있는지 확인
        if let oldValue = document.data()?["hashedSecurityAnswer"] as? String {
            // Step 4: 신규 필드명으로 변경
            try await documentRef.updateData([
                "securityAnswer": oldValue,
                "hashedSecurityAnswer": FieldValue.delete()
            ])
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
    case dataConversionFailed
    case userNotFound
    case notLoggedIn

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
        case .dataConversionFailed:
            return "데이터 변환 실패"
        case .userNotFound:
            return "사용자를 찾을 수 없습니다"
        case .notLoggedIn:
            return "로그인이 필요합니다"
        }
    }
}
