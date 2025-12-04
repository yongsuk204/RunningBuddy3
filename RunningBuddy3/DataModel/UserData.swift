import Foundation
import FirebaseFirestore

// Purpose: 사용자 회원가입 정보를 저장하기 위한 데이터 모델
// MARK: - 함수 목록
/*
 * Firestore Conversion
 * - toDictionary(): UserData 객체를 Firestore 저장용 딕셔너리로 변환
 * - fromDictionary(_:): Firestore 문서 데이터에서 UserData 객체 생성
 */

struct UserData: Codable {

    // MARK: - Properties

    // Purpose: Firebase Auth에서 생성된 고유 사용자 ID
    let userId: String

    // Purpose: 사용자 아이디 (로그인용, 중복 불가)
    let username: String

    // Purpose: 이메일 (Firebase Auth용, 원본 저장)
    let email: String

    // Purpose: 전화번호 (원본 저장, 이메일 찾기용)
    let phoneNumber: String

    // Purpose: 계정 생성 날짜
    let createdAt: Date

    // Purpose: 선택한 보안질문
    let securityQuestion: String

    // Purpose: 보안질문 답변 (pepper + salt로 해시화되어 저장)
    let securityAnswer: String

    // MARK: - Initialization

    // Purpose: 사용자 데이터 생성 (회원가입 시에는 현재 시간, Firestore에서 읽을 때는 원본 시간 사용)
    // NOTE: 캘리브레이션 데이터는 서브컬렉션(calibrationRecords)으로 관리됨
    init(userId: String, username: String, email: String, phoneNumber: String, securityQuestion: String, securityAnswer: String, createdAt: Date = Date()) {
        self.userId = userId
        self.username = username
        self.email = email
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.securityQuestion = securityQuestion
        self.securityAnswer = securityAnswer
    }


    // MARK: - Firestore Conversion / Firestore와 Swift 객체 간의 직렬화/역직렬화를 담당하는 핵심

    // Purpose: Firestore 저장을 위한 딕셔너리 변환
    func toDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "username": username,
            "email": email,
            "phoneNumber": phoneNumber,
            "createdAt": Timestamp(date: createdAt),
            "securityQuestion": securityQuestion,
            "securityAnswer": securityAnswer
        ]
    }

    // Purpose: Firestore 문서에서 UserData 객체 생성
    static func fromDictionary(_ data: [String: Any]) -> UserData? {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let email = data["email"] as? String,
              let phoneNumber = data["phoneNumber"] as? String,
              let timestamp = data["createdAt"] as? Timestamp,
              let securityQuestion = data["securityQuestion"] as? String,
              let securityAnswer = data["securityAnswer"] as? String else {
            return nil
        }

        // Purpose: Firestore timestamp를 Date로 변환하여 원본 생성일시 보존
        let originalCreatedAt = timestamp.dateValue()

        let userData = UserData(
            userId: userId,
            username: username,
            email: email,
            phoneNumber: phoneNumber,
            securityQuestion: securityQuestion,
            securityAnswer: securityAnswer,
            createdAt: originalCreatedAt
        )

        return userData
    }
}
