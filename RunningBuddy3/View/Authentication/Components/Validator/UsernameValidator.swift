import Foundation

// Purpose: 사용자 아이디 유효성 검사를 담당하는 유틸리티 클래스
// MARK: - 함수 목록
/*
 * Validation Methods
 * - validateUsername(): 아이디 검증 결과를 UsernameValidationResult로 반환
 * - isBasicValidFormat(): 간단한 형식 체크 (실시간 입력 검증용)
 */
class UsernameValidator {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = UsernameValidator()

    // MARK: - Constants

    // Purpose: 아이디 검증 관련 상수
    private let minimumLength = 4   // 최소 길이
    private let maximumLength = 20  // 최대 길이

    // Purpose: 허용된 문자 정규식 (영문 소문자, 숫자, 언더스코어)
    private let allowedCharacterPattern = "^[a-z0-9_]+$"

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Public Methods

    // Purpose: 검증 결과를 UsernameValidationResult로 반환
    func validateUsername(_ username: String) -> UsernameValidationResult {
        // Step 1: 빈 문자열 체크
        guard !username.isEmpty else {
            return .invalid("아이디를 입력해주세요.")
        }

        // Step 2: 공백 포함 여부 체크
        guard !username.contains(" ") else {
            return .invalid("아이디에 공백을 포함할 수 없습니다")
        }

        // Step 3: 길이 검증
        guard username.count >= minimumLength else {
            return .invalid("아이디는 \(minimumLength)자 이상이어야 합니다")
        }

        guard username.count <= maximumLength else {
            return .invalid("아이디는 \(maximumLength)자 이하여야 합니다")
        }

        // Step 4: 허용된 문자만 사용했는지 검증
        let regex = try? NSRegularExpression(pattern: allowedCharacterPattern)
        let range = NSRange(username.startIndex..., in: username)
        guard regex?.firstMatch(in: username, range: range) != nil else {
            return .invalid("영문 소문자, 숫자, 언더스코어(_)만 사용 가능합니다")
        }

        // Step 5: 첫 글자는 영문이어야 함
        guard let firstChar = username.first, firstChar.isLetter else {
            return .invalid("아이디는 영문으로 시작해야 합니다")
        }

        return .valid
    }

    // Purpose: 간단한 형식 체크 (실시간 입력 검증용)
    func isBasicValidFormat(_ username: String) -> Bool {
        // 길이와 기본 문자 규칙만 체크
        guard username.count >= minimumLength && username.count <= maximumLength else {
            return false
        }

        let regex = try? NSRegularExpression(pattern: allowedCharacterPattern)
        let range = NSRange(username.startIndex..., in: username)
        return regex?.firstMatch(in: username, range: range) != nil
    }
}

// MARK: - Validation Result Enum

// Purpose: 아이디 검증 결과를 나타내는 열거형
enum UsernameValidationResult {
    case valid
    case invalid(String)  // 에러 메시지 포함

    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        }
    }
}
