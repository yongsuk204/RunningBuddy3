import SwiftUI
import CoreLocation

// MARK: - GPS Signal Quality

// Purpose: GPS 신호 품질 정보 (텍스트, 색상, 아이콘)
struct SignalQuality {
    let text: String
    let color: Color  // DesignSystem 색상 사용
    let icon: String

    // ═══════════════════════════════════════
    // PURPOSE: GPS 신호 강도 평가
    // PARAMETERS:
    //   - location: 평가할 GPS 위치 (nil 가능)
    // RETURNS: SignalQuality (신호 품질 정보)
    // LOGIC:
    //   - horizontalAccuracy 기반 신호 강도 판단
    //   - < 0: 신호 없음 (회색)
    //   - < 10m: 매우 좋음 (녹색)
    //   - < 20m: 좋음 (녹색)
    //   - < 50m: 보통 (주황색)
    //   - >= 50m: 약함 (빨간색)
    // ═══════════════════════════════════════
    static func evaluate(_ location: CLLocation?) -> SignalQuality {
        let accuracy = location?.horizontalAccuracy ?? -1

        if accuracy < 0 {
            return SignalQuality(text: "GPS 신호 없음", color: DesignSystem.Colors.neutral, icon: "location.slash")
        } else if accuracy < 10 {
            return SignalQuality(text: "GPS 신호 매우 좋음", color: DesignSystem.Colors.success, icon: "location.fill")
        } else if accuracy < 20 {
            return SignalQuality(text: "GPS 신호 좋음", color: DesignSystem.Colors.success, icon: "location.fill")
        } else if accuracy < 50 {
            return SignalQuality(text: "GPS 신호 보통", color: DesignSystem.Colors.warning, icon: "location.fill")
        } else {
            return SignalQuality(text: "GPS 신호 약함", color: DesignSystem.Colors.error, icon: "location.fill")
        }
    }
}

// MARK: - Compact Status Indicator

// Purpose: 컴팩트한 상태 표시 카드 (워치 연결, GPS 등)
struct CompactStatusCard: View {

    // MARK: - Properties

    let icon: String
    let text: String
    let isActive: Bool
    let activeColor: Color

    // MARK: - Factory Methods

    // ═══════════════════════════════════════
    // PURPOSE: 워치 연결 상태 카드 생성
    // PARAMETERS:
    //   - isReachable: 워치 연결 여부
    // RETURNS: CompactStatusCard (워치 상태 카드)
    // LOGIC:
    //   - 연결됨: 녹색 "연결됨"
    //   - 연결 안 됨: 회색 "연결 안 됨"
    // ═══════════════════════════════════════
    static func watchStatus(isReachable: Bool) -> CompactStatusCard {
        return CompactStatusCard(
            icon: "applewatch",
            text: isReachable ? "연결됨" : "연결 안 됨",
            isActive: isReachable,
            activeColor: DesignSystem.Colors.success
        )
    }

    // ═══════════════════════════════════════
    // PURPOSE: GPS 신호 상태 카드 생성
    // PARAMETERS:
    //   - location: GPS 위치 정보 (nil 가능)
    //   - isActive: GPS 활성 상태 (정확도 임계값 이내)
    // RETURNS: CompactStatusCard (GPS 상태 카드)
    // LOGIC:
    //   - SignalQuality로 신호 품질 평가
    //   - 아이콘과 색상을 신호 강도에 따라 자동 설정
    // ═══════════════════════════════════════
    static func gpsStatus(location: CLLocation?, isActive: Bool) -> CompactStatusCard {
        let signalQuality = SignalQuality.evaluate(location)

        return CompactStatusCard(
            icon: signalQuality.icon,
            text: "GPS",
            isActive: isActive,
            activeColor: signalQuality.color
        )
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs + 2) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(isActive ? activeColor : .gray)

            Text(text)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Circle()
                .fill(isActive ? activeColor : .gray)
                .frame(
                    width: DesignSystem.Layout.statusIndicatorSize,
                    height: DesignSystem.Layout.statusIndicatorSize
                )
        }
        .padding(.horizontal, DesignSystem.Spacing.sm + 2)
        .padding(.vertical, DesignSystem.Spacing.xs + 2)
        .overlayCardStyle(
            cornerRadius: DesignSystem.CornerRadius.small,
            shadow: DesignSystem.Shadow.subtle
        )
    }
}

// MARK: - Previews

#Preview("CompactStatusCard - 연결됨") {
    VStack(spacing: 20) {
        CompactStatusCard(
            icon: "applewatch",
            text: "연결됨",
            isActive: true,
            activeColor: .green
        )

        CompactStatusCard(
            icon: "applewatch",
            text: "연결 안 됨",
            isActive: false,
            activeColor: .green
        )
    }
    .padding()
    .background(Color.blue.opacity(0.3))
}

#Preview("CompactStatusCard - GPS") {
    VStack(spacing: 20) {
        CompactStatusCard(
            icon: "antenna.radiowaves.left.and.right",
            text: "GPS",
            isActive: true,
            activeColor: .green
        )

        CompactStatusCard(
            icon: "antenna.radiowaves.left.and.right",
            text: "GPS",
            isActive: true,
            activeColor: .orange
        )

        CompactStatusCard(
            icon: "antenna.radiowaves.left.and.right.slash",
            text: "GPS",
            isActive: false,
            activeColor: .gray
        )
    }
    .padding()
    .background(Color.blue.opacity(0.3))
}

#Preview("상태 카드 조합") {
    HStack(spacing: 12) {
        CompactStatusCard(
            icon: "applewatch",
            text: "연결됨",
            isActive: true,
            activeColor: .green
        )

        CompactStatusCard(
            icon: "antenna.radiowaves.left.and.right",
            text: "GPS",
            isActive: true,
            activeColor: .green
        )
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
