import SwiftUI

// Purpose: 심박수, 케이던스, 거리를 하나의 카드에 통합 표시하는 컴포넌트
// MARK: - 함수 목록
/*
 * Main Component
 * - UnifiedMetricsCard: 세 가지 수치를 표시하는 메인 카드
 *
 * Supporting Components
 * - MetricButtonContent: 개별 수치 버튼의 컨텐츠
 * - MetricButtonStyle: 버튼 애니메이션 스타일
 */

struct UnifiedMetricsCard: View {

    // MARK: - Properties

    // Purpose: 심박수 값 (bpm)
    let heartRate: Double?

    // Purpose: 케이던스 값 (SPM - Steps Per Minute)
    let cadence: Double

    // Purpose: 거리 값 (미터 단위)
    let distance: Double

    // Purpose: 현재 지도 모드
    let mapMode: MapMode

    // Purpose: 거리 버튼 탭 액션 (지도 모드 전환)
    let onDistanceTap: () -> Void

    // Purpose: 추후 구현 알림 표시 여부
    @State private var showingComingSoonAlert = false

    // Purpose: 알림 메시지
    @State private var alertMessage = ""

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // 심박수 버튼
            Button {
                alertMessage = "심박수 상세 기능을 추가할 예정입니다"
                showingComingSoonAlert = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text(String(format: "%.0f", heartRate ?? 0))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text("bpm")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MetricButtonStyle())

            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 60)

            // 케이던스 버튼
            Button {
                alertMessage = "케이던스 상세 기능을 추가할 예정입니다"
                showingComingSoonAlert = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text(String(format: "%.0f", cadence))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text("SPM")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MetricButtonStyle())

            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 60)

            // 거리 버튼 (지도 모드 전환)
            Button {
                onDistanceTap()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: mapMode.icon)
                        .font(.title2)
                        .foregroundColor(.white)

                    Text(String(format: "%.2f", distance / 1000.0))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text("km")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MetricButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .alert("알림", isPresented: $showingComingSoonAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - MapMode Enum

// Purpose: 지도 모드 정의 (UnifiedMetricsCard에서 사용)
enum MapMode: CaseIterable {
    case automatic    // 자동 추적 모드 (경로 전체 보기)
    case manual       // 수동 모드 (사용자가 원하는 위치)
    case heading      // 방향 추적 모드 (현재 바라보는 방향)

    var icon: String {
        switch self {
        case .automatic: return "location.fill"
        case .manual: return "hand.tap.fill"
        case .heading: return "location.north.line.fill"
        }
    }

    var description: String {
        switch self {
        case .automatic: return "자동"
        case .manual: return "수동"
        case .heading: return "방향"
        }
    }

    // Purpose: 다음 모드로 전환
    var next: MapMode {
        let allCases = MapMode.allCases
        let currentIndex = allCases.firstIndex(of: self)!
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

// MARK: - Metric Button Components

// Purpose: 메트릭 버튼 컨텐츠
struct MetricButtonContent: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 4) {
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// Purpose: 메트릭 버튼 스타일
struct MetricButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}