import SwiftUI
import Combine

// Purpose: 앱 전체의 디자인 시스템 통일 관리 (색상, 여백, 타이포그래피, 그림자 등)
// MARK: - 디자인 토큰 목록
/*
 * Colors
 * - gradient: 배경 그라데이션
 * - text: 텍스트 색상 계층
 * - status: 상태별 색상
 * - card: 카드 배경
 *
 * Spacing
 * - xs ~ xxl: 일관된 여백 값
 *
 * CornerRadius
 * - small, medium, large: 모서리 반경
 *
 * Shadow
 * - card, subtle, strong: 그림자 스타일
 *
 * Typography
 * - largeValue, headline, body 등: 폰트 스타일
 *
 * Opacity
 * - subtle ~ veryStrong: 투명도 단계
 *
 * Layout
 * - 카드/버튼 크기, 터치 영역
 */

enum DesignSystem {

    // MARK: - Colors

    // Purpose: 앱 전체 색상 시스템
    enum Colors {
        // MARK: Background
        // Purpose: 배경 그라데이션 (중립톤 다크 그레이)
        static let gradientStart = Color(red: 0.17, green: 0.17, blue: 0.18) // #2C2C2E
        static let gradientEnd = Color(red: 0.28, green: 0.28, blue: 0.29)   // #48484A

        // MARK: Card
        // Purpose: 카드 배경 재질
        static let cardBackground = Material.ultraThinMaterial

        // Purpose: 반투명 오버레이 카드 배경 (지도 위에 사용)
        static let overlayCardBackground = Color.black.opacity(0.3)

        // MARK: Text
        // Purpose: 텍스트 색상 계층 구조
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(Opacity.strong)
        static let textTertiary = Color.white.opacity(Opacity.semiMedium)
        static let textDisabled = Color.white.opacity(Opacity.medium)

        // MARK: Status
        // Purpose: 상태별 의미 색상
        static let success = Color.green
        static let error = Color.red
        static let warning = Color.orange
        static let info = Color.blue
        static let neutral = Color.gray  // 중립/비활성 상태

        // MARK: Metric Icons
        // Purpose: 센서 메트릭별 아이콘 색상
        static let heartRate = Color.red
        static let cadence = Color.orange
        static let distance = Color.blue
    }

    // MARK: - Spacing

    // Purpose: 일관된 여백 값 (4의 배수 기준)
    enum Spacing {
        static let xs: CGFloat = 4      // 최소 간격
        static let sm: CGFloat = 8      // 작은 간격
        static let md: CGFloat = 16     // 중간 간격 (기본)
        static let lg: CGFloat = 20     // 큰 간격
        static let xl: CGFloat = 40     // 매우 큰 간격
        static let xxl: CGFloat = 60    // 최대 간격 (노치 회피)
    }

    // MARK: - Corner Radius

    // Purpose: 모서리 반경 통일
    enum CornerRadius {
        static let small: CGFloat = 12   // 작은 카드, 버튼
        static let medium: CGFloat = 16  // 메트릭 카드
        static let large: CGFloat = 20   // 큰 카드
    }

    // MARK: - Shadow

    // Purpose: 그림자 스타일 정의
    enum Shadow {
        // Step 1: 그림자 파라미터 구조체
        struct Style {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        // Step 2: 사전 정의된 그림자 스타일
        static let card = Style(
            color: .black.opacity(Opacity.light),
            radius: 8,
            x: 0,
            y: 4
        )

        static let subtle = Style(
            color: .black.opacity(Opacity.subtle),
            radius: 4,
            x: 0,
            y: 2
        )

        static let strong = Style(
            color: .black.opacity(Opacity.medium),
            radius: 10,
            x: 0,
            y: 5
        )
    }

    // MARK: - Typography

    // Purpose: 폰트 스타일 통일
    enum Typography {
        // MARK: Values (수치 표시용)
        static let largeValue = Font.system(size: 32, weight: .bold, design: .rounded)
        static let mediumValue = Font.system(size: 24, weight: .semibold, design: .rounded)

        // MARK: Text Styles
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let body = Font.body
        static let caption = Font.caption
        static let caption2 = Font.caption2

        // MARK: Icons
        static let iconLarge = Font.system(size: 60)
        static let iconMedium = Font.title2
        static let iconSmall = Font.title3
    }

    // MARK: - Opacity

    // Purpose: 투명도 단계 정의 (0.0 ~ 1.0)
    enum Opacity {
        static let subtle: Double = 0.1      // 매우 약한 (배경 테두리)
        static let light: Double = 0.2       // 약한 (그림자)
        static let medium: Double = 0.3      // 중간 (강조 그림자)
        static let semiMedium: Double = 0.6  // 중간 강조 (배경)
        static let strong: Double = 0.8      // 강한 (텍스트)
        static let veryStrong: Double = 0.9  // 매우 강한 (중요 텍스트)
    }

    // MARK: - Layout

    // Purpose: 레이아웃 상수
    enum Layout {
        // MARK: Cards
        static let compactCardHeight: CGFloat = 140
        static let statusCardHeight: CGFloat = 30

        // MARK: Icons & Markers
        static let markerSize: CGFloat = 30
        static let statusIndicatorSize: CGFloat = 6

        // MARK: Buttons
        static let buttonHeight: CGFloat = 50
        static let minimumTouchTarget: CGFloat = 44
    }
}

// MARK: - Theme Manager

// Purpose: 앱 전체에서 디자인 시스템에 접근할 수 있도록 하는 싱글톤
class ThemeManager: ObservableObject {

    // Purpose: Singleton 인스턴스
    static let shared = ThemeManager()

    private init() {}

    // MARK: - Convenience Accessors

    // Purpose: 빠른 접근을 위한 computed properties
    var gradientStart: Color { DesignSystem.Colors.gradientStart }
    var gradientEnd: Color { DesignSystem.Colors.gradientEnd }
}

// MARK: - View Extensions

// Purpose: SwiftUI View에서 쉽게 사용할 수 있는 extension
extension View {

    // Purpose: 배경 그라데이션 적용
    func appGradientBackground(opacity: Double = 0.6) -> some View {
        self.background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.gradientStart.opacity(opacity),
                    DesignSystem.Colors.gradientEnd.opacity(opacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    // Purpose: 카드 스타일 적용
    func cardStyle(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.medium,
        shadow: DesignSystem.Shadow.Style = DesignSystem.Shadow.card
    ) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(
                    color: shadow.color,
                    radius: shadow.radius,
                    x: shadow.x,
                    y: shadow.y
                )
        )
    }

    // Purpose: 반투명 오버레이 카드 스타일 (지도 위에 사용)
    func overlayCardStyle(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.medium,
        shadow: DesignSystem.Shadow.Style = DesignSystem.Shadow.card
    ) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DesignSystem.Colors.overlayCardBackground)
                .shadow(
                    color: shadow.color,
                    radius: shadow.radius,
                    x: shadow.x,
                    y: shadow.y
                )
        )
    }
}
