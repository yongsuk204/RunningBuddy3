import Foundation
import FirebaseFirestore

// Purpose: Firestore에서 사용자 데이터를 관리하는 서비스
class UserService {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = UserService()

    // MARK: - Properties

    // Purpose: Firestore 데이터베이스 참조
    private let firestore = FirebaseManager.shared.firestore

    // Purpose: SecurityService 인스턴스
    private let securityService = SecurityService.shared

    // Purpose: 사용자 컬렉션 이름
    private let usersCollection = "users"

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - User Data Management

    // Purpose: 회원가입 시 사용자 정보를 Firestore에 저장 👈
    func saveUserData(userId: String, email: String, securityQuestion: String, securityAnswer: String) async throws {
        // Step 1: 보안질문 답변 해시화
        let hashedAnswer = securityService.hashSecurityAnswer(securityAnswer)

        // Step 2: UserData 객체 생성 👈 UserData() init!!
        let userData = UserData(
            userId: userId,
            email: email,
            securityQuestion: securityQuestion,
            hashedSecurityAnswer: hashedAnswer
        )

        // Step 3: Firestore에 저장 👈 userData.toDictionary() 상태로 저장!!
        do {
            try await firestore.collection(usersCollection).document(userId).setData(userData.toDictionary())
            print("UserService: 사용자 데이터 저장 성공 - \(email)")
        } catch {
            print("UserService: 사용자 데이터 저장 실패 - \(error.localizedDescription)")
            throw UserServiceError.saveFailed(error.localizedDescription)
        }
    }

    // Purpose: 사용자 ID로 사용자 정보 조회
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

    // Purpose: 보안질문 답변 검증
    func verifySecurityAnswer(userId: String, inputAnswer: String) async throws -> Bool {
        // Step 1: 사용자 데이터 조회
        guard let userData = try await getUserData(userId: userId) else {
            throw UserServiceError.userNotFound
        }

        // Step 2: 보안질문 답변 검증
        let isValid = securityService.verifySecurityAnswer(inputAnswer, hashedAnswer: userData.hashedSecurityAnswer)

        print("UserService: 보안질문 답변 검증 결과 - \(isValid)")
        return isValid
    }

    // Purpose: 사용자 데이터 업데이트
    func updateUserData(userId: String, updates: [String: Any]) async throws {
        do {
            try await firestore.collection(usersCollection).document(userId).updateData(updates)
            print("UserService: 사용자 데이터 업데이트 성공 - \(userId)")
        } catch {
            print("UserService: 사용자 데이터 업데이트 실패 - \(error.localizedDescription)")
            throw UserServiceError.updateFailed(error.localizedDescription)
        }
    }

    // Purpose: 사용자 데이터 삭제
    func deleteUserData(userId: String) async throws {
        do {
            try await firestore.collection(usersCollection).document(userId).delete()
            print("UserService: 사용자 데이터 삭제 성공 - \(userId)")
        } catch {
            print("UserService: 사용자 데이터 삭제 실패 - \(error.localizedDescription)")
            throw UserServiceError.deleteFailed(error.localizedDescription)
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
        }
    }
}
