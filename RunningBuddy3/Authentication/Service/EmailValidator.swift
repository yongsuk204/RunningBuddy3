import Foundation

// Purpose: 이메일 유효성 검사를 담당하는 유틸리티 클래스
// MARK: - 함수 목록
/*
 * Validation Methods
 * - validateEmail(): 전체 이메일 검증 결과를 EmailValidationResult로 반환
 * - validateLocalPart(): 로컬파트(@ 앞부분)만 검증
 */
class EmailValidator {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = EmailValidator()

    // MARK: - Constants

    // Purpose: 이메일 검증 관련 상수
    private let minimumLocalPartLength = 3  // @ 앞부분 최소 길이
    private let maximumLocalPartLength = 64  // RFC 5321 표준

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Public Methods

    // ═══════════════════════════════════════
    // PURPOSE: 로컬파트(@ 앞부분)만 검증
    // ═══════════════════════════════════════
    func validateLocalPart(_ localPart: String) -> EmailValidationResult {
        // Step 1: 빈 문자열 체크
        guard !localPart.isEmpty else {
            return .invalid("이메일 주소를 입력해주세요.")
        }

        // Step 2: 공백 포함 여부 체크
        guard !localPart.contains(" ") else {
            return .invalid("이메일에 공백을 포함할 수 없습니다")
        }

        // Step 3: 길이 검증
        guard localPart.count >= minimumLocalPartLength else {
            return .invalid("이메일 주소는 \(minimumLocalPartLength)자 이상이어야 합니다")
        }

        guard localPart.count <= maximumLocalPartLength else {
            return .invalid("이메일 주소는 \(maximumLocalPartLength)자 이하여야 합니다")
        }

        // Step 4: 영문자/숫자/특수문자(._-) 허용
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard localPart.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return .invalid("이메일 주소는 영문, 숫자, ._- 만 사용 가능합니다")
        }

        // Step 5: 시작/끝 문자 검증 (., -, _ 로 시작/끝 불가)
        let invalidStartEndChars = CharacterSet(charactersIn: "._-")
        if let firstChar = localPart.first?.unicodeScalars.first,
           invalidStartEndChars.contains(firstChar) {
            return .invalid("이메일 주소는 특수문자로 시작할 수 없습니다")
        }

        if let lastChar = localPart.last?.unicodeScalars.first,
           invalidStartEndChars.contains(lastChar) {
            return .invalid("이메일 주소는 특수문자로 끝날 수 없습니다")
        }

        return .valid
    }

    // ═══════════════════════════════════════
    // PURPOSE: 전체 이메일 검증 (로컬파트만 검증, 도메인은 Picker에서 선택되므로 항상 유효)
    // ═══════════════════════════════════════
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

        // Step 4: 로컬 파트만 검증 (도메인은 선택 방식이므로 항상 유효)
        let localPart = String(components[0])
        return validateLocalPart(localPart)
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