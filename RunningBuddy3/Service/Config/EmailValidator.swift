import Foundation

// Purpose: 이메일 유효성 검사를 담당하는 유틸리티 클래스
// MARK: - 함수 목록
/*
 * Validation Methods
 * - isValidEmail(): 이메일 형식 유효성 검사
 * - isValidEmailFormat(): 정규식을 사용한 상세한 이메일 형식 검증
 * - checkEmailLength(): 이메일 길이 검증
 * - checkDomainValidity(): 도메인 유효성 검증
 * - getEmailValidationError(): 유효하지 않은 이메일에 대한 구체적인 에러 메시지 반환
 */
class EmailValidator {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = EmailValidator()

    // MARK: - Constants

    // Purpose: 이메일 검증 관련 상수
    private let minimumEmailLength = 5  // a@b.c 최소 형식
    private let maximumEmailLength = 254  // RFC 5321 표준
    private let minimumLocalPartLength = 1
    private let maximumLocalPartLength = 64
    private let minimumDomainLength = 3  // a.b 최소 형식
    private let maximumDomainLength = 253

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Public Methods

    // Purpose: 이메일 유효성 종합 검사
    func isValidEmail(_ email: String) -> Bool {
        // Step 1: 빈 문자열 체크
        guard !email.isEmpty else {
            return false
        }

        // Step 2: 전체 길이 검증
        guard checkEmailLength(email) else {
            return false
        }

        // Step 3: 이메일 형식 검증
        guard isValidEmailFormat(email) else {
            return false
        }

        return true
    }

    // Purpose: 정규식을 사용한 이메일 형식 검증
    func isValidEmailFormat(_ email: String) -> Bool {
        // Step 1: @ 기호 존재 확인
        guard email.contains("@") else {
            return false
        }

        // Step 2: @ 기호로 분리
        let components = email.split(separator: "@")
        guard components.count == 2 else {
            return false  // @ 기호가 여러 개이거나 없는 경우
        }

        let localPart = String(components[0])
        let domain = String(components[1])

        // Step 3: 로컬 파트 검증 (@ 앞부분)
        guard isValidLocalPart(localPart) else {
            return false
        }

        // Step 4: 도메인 검증 (@ 뒷부분)
        guard isValidDomain(domain) else {
            return false
        }

        // Step 5: 정규식 패턴 매칭
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        return emailPredicate.evaluate(with: email)
    }

    // Purpose: 이메일 길이 검증
    func checkEmailLength(_ email: String) -> Bool {
        return email.count >= minimumEmailLength && email.count <= maximumEmailLength
    }

    // Purpose: 이메일 검증 실패 시 구체적인 에러 메시지 반환
    func getEmailValidationError(_ email: String) -> String? {
        // Step 1: 빈 문자열 체크
        if email.isEmpty {
            return "이메일을 입력해주세요."
        }

        // Step 2: @ 기호 체크
        if !email.contains("@") {
            return "올바른 이메일 형식이 아닙니다. '@'가 필요합니다."
        }

        // Step 3: 길이 체크
        if email.count < minimumEmailLength {
            return "이메일이 너무 짧습니다."
        }

        if email.count > maximumEmailLength {
            return "이메일이 너무 깁니다."
        }

        // Step 4: @ 기호 개수 체크
        let atCount = email.filter { $0 == "@" }.count
        if atCount > 1 {
            return "이메일에 '@'가 여러 개 있습니다."
        }

        // Step 5: 로컬 파트와 도메인 분리
        let components = email.split(separator: "@")
        if components.count != 2 {
            return "올바른 이메일 형식이 아닙니다."
        }

        let localPart = String(components[0])
        let domain = String(components[1])

        // Step 6: 로컬 파트 검증
        if localPart.isEmpty {
            return "'@' 앞에 이메일 주소가 필요합니다."
        }

        if localPart.count > maximumLocalPartLength {
            return "'@' 앞 부분이 너무 깁니다."
        }

        if localPart.first == "." || localPart.last == "." {
            return "이메일 주소는 '.'로 시작하거나 끝날 수 없습니다."
        }

        if localPart.contains("..") {
            return "이메일 주소에 '..'를 사용할 수 없습니다."
        }

        // Step 7: 도메인 검증
        if domain.isEmpty {
            return "'@' 뒤에 도메인이 필요합니다."
        }

        if !domain.contains(".") {
            return "도메인 형식이 올바르지 않습니다."
        }

        if domain.first == "." || domain.last == "." {
            return "도메인은 '.'로 시작하거나 끝날 수 없습니다."
        }

        if domain.contains("..") {
            return "도메인에 '..'를 사용할 수 없습니다."
        }

        // Step 8: 정규식 검증
        if !isValidEmailFormat(email) {
            return "올바른 이메일 형식이 아닙니다."
        }

        return nil  // 모든 검증 통과
    }

    // MARK: - Private Methods

    // Purpose: 이메일 로컬 파트 검증 (@ 앞부분)
    private func isValidLocalPart(_ localPart: String) -> Bool {
        // Step 1: 길이 검증
        guard localPart.count >= minimumLocalPartLength &&
              localPart.count <= maximumLocalPartLength else {
            return false
        }

        // Step 2: 시작과 끝 문자 검증
        if localPart.first == "." || localPart.last == "." {
            return false
        }

        // Step 3: 연속된 점 검증
        if localPart.contains("..") {
            return false
        }

        // Step 4: 허용된 문자 검증
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._%+-")
        let localPartCharacterSet = CharacterSet(charactersIn: localPart)

        return allowedCharacters.isSuperset(of: localPartCharacterSet)
    }

    // Purpose: 도메인 검증 (@ 뒷부분)
    private func isValidDomain(_ domain: String) -> Bool {
        // Step 1: 길이 검증
        guard domain.count >= minimumDomainLength &&
              domain.count <= maximumDomainLength else {
            return false
        }

        // Step 2: 점 존재 확인 (최소한 하나의 점이 있어야 함)
        guard domain.contains(".") else {
            return false
        }

        // Step 3: 시작과 끝 문자 검증
        if domain.first == "." || domain.last == "." ||
           domain.first == "-" || domain.last == "-" {
            return false
        }

        // Step 4: 연속된 점 검증
        if domain.contains("..") {
            return false
        }

        // Step 5: 도메인 라벨 검증
        let labels = domain.split(separator: ".")
        for label in labels {
            if label.isEmpty || label.count > 63 {
                return false
            }

            // 라벨은 하이픈으로 시작하거나 끝날 수 없음
            if label.first == "-" || label.last == "-" {
                return false
            }
        }

        // Step 6: TLD 검증 (최소 2자 이상)
        if let lastLabel = labels.last {
            if lastLabel.count < 2 {
                return false
            }

            // TLD는 숫자로만 구성될 수 없음
            if lastLabel.allSatisfy({ $0.isNumber }) {
                return false
            }
        }

        return true
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

// MARK: - Extension for Convenience

extension EmailValidator {

    // Purpose: 검증 결과를 EmailValidationResult로 반환
    func validateEmail(_ email: String) -> EmailValidationResult {
        if let error = getEmailValidationError(email) {
            return .invalid(error)
        }
        return .valid
    }

    // Purpose: 간단한 형식 체크 (실시간 입력 검증용)
    func isBasicValidFormat(_ email: String) -> Bool {
        // 최소한 @ 기호가 있고, 앞뒤에 문자가 있는지만 체크
        guard email.contains("@") else { return false }

        let components = email.split(separator: "@")
        guard components.count == 2 else { return false }

        return !components[0].isEmpty && !components[1].isEmpty
    }
}