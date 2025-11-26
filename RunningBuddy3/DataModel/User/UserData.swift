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

    // Purpose: 사용자 다리 길이 (cm 단위, 옵셔널 - 수동 입력 또는 수정된 값)
    let legLength: Double?

    // MARK: - Initialization

    // Purpose: 사용자 데이터 생성 (회원가입 시에는 현재 시간, Firestore에서 읽을 때는 원본 시간 사용)
    init(userId: String, username: String, email: String, phoneNumber: String, securityQuestion: String, securityAnswer: String, legLength: Double? = nil, createdAt: Date = Date()) {
        self.userId = userId
        self.username = username
        self.email = email
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.securityQuestion = securityQuestion
        self.securityAnswer = securityAnswer
        self.legLength = legLength
    }


    // MARK: - Firestore Conversion / Firestore와 Swift 객체 간의 직렬화/역직렬화를 담당하는 핵심

    // Purpose: Firestore 저장을 위한 딕셔너리 변환
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "email": email,
            "phoneNumber": phoneNumber,
            "createdAt": Timestamp(date: createdAt),
            "securityQuestion": securityQuestion,
            "securityAnswer": securityAnswer
        ]

        // 다리 길이가 있으면 추가
        if let legLength = legLength {
            dict["legLength"] = legLength
        }

        return dict
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

        // Purpose: 다리 길이는 옵셔널 (없을 수 있음)
        let legLength = data["legLength"] as? Double

        let userData = UserData(
            userId: userId,
            username: username,
            email: email,
            phoneNumber: phoneNumber,
            securityQuestion: securityQuestion,
            securityAnswer: securityAnswer,
            legLength: legLength,
            createdAt: originalCreatedAt
        )

        return userData
    }
}
