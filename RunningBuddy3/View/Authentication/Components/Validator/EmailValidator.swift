import Foundation

// Purpose: 이메일 유효성 검사를 담당하는 유틸리티 클래스
// MARK: - 함수 목록
/*
 * Validation Methods
 * - validateEmail(): 이메일 검증 결과를 EmailValidationResult로 반환
 */
class EmailValidator {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = EmailValidator()

    // MARK: - Constants

    // Purpose: 이메일 검증 관련 상수
    private let minimumLocalPartLength = 5  // @ 앞부분 최소 길이 (도메인이 고정이므로 5자면 충분)

    // Purpose: 허용된 이메일 도메인 목록
    private let allowedDomains = [
        "gmail.com",
        "naver.com",
        "daum.net",
        "nate.com",
        "yahoo.com"
    ]

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Public Methods

    // Purpose: 검증 결과를 EmailValidationResult로 반환
    func validateEmail(_ email: String) -> EmailValidationResult {
        // Step 1: 빈 문자열 체크
        guard !email.isEmpty else {
            return .invalid("이메일을 입력해주세요.")
        }

        // Step 2: 공백 포함 여부 체크
        guard !email.contains(" ") else {
            return .invalid("이메일에 공백을 포함할 수 없습니다")
        }

        // Step 3: @ 기호로 분리
        let components = email.split(separator: "@")
        guard components.count == 2 else {
            return .invalid("올바른 이메일 형식이 아닙니다")
        }

        // Step 4: 로컬 파트 길이 검증
        let localPart = String(components[0])
        guard localPart.count >= minimumLocalPartLength else {
            return .invalid("이메일 아이디는 5자 이상이어야 합니다")
        }

        // Step 5: 도메인 체크
        let domain = String(components[1]).lowercased()
        guard allowedDomains.contains(domain) else {
            return .invalid("지원하지 않는 이메일 도메인입니다\n(gmail, naver, daum, nate, yahoo만 가능)")
        }

        return .valid
    }
}

// MARK: - Validation Result Enum

// Purpose: 이메일 검증 결과를 나타내는 열거형
enum EmailValidationResult {
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