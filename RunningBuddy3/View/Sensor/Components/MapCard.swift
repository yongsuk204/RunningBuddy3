import SwiftUI
import MapKit

// Purpose: 러닝 경로 실시간 표시 카드 UI 컴포넌트
struct MapCard: View {

    // MARK: - Properties

    // Purpose: GPS 좌표 배열 (경로 표시용)
    let locations: [CLLocationCoordinate2D]

    // Purpose: 지도 카메라 위치 (자동 조정)
    @State private var cameraPosition: MapCameraPosition = .automatic

    // MARK: - Computed Properties

    // Purpose: 시작 위치 (첫 번째 좌표)
    private var startLocation: CLLocationCoordinate2D? {
        locations.first
    }

    // Purpose: 현재 위치 (마지막 좌표)
    private var currentLocation: CLLocationCoordinate2D? {
        locations.last
    }

    // Purpose: 지도 영역 계산 (모든 좌표가 보이도록)
    private var mapRegion: MKCoordinateRegion? {
        guard !locations.isEmpty else { return nil }

        // 위도/경도의 최소/최대값 계산
        let latitudes = locations.map { $0.latitude }
        let longitudes = locations.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else {
            return nil
        }

        // 중심 좌표 계산
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        // 스팬 계산 (약간의 여백 추가)
        let latDelta = (maxLat - minLat) * 1.5
        let lonDelta = (maxLon - minLon) * 1.5

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lonDelta, 0.01))
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // 제목 헤더
            HStack {
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundColor(.green)

                Text("러닝 경로")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                if !locations.isEmpty {
                    Text("\(locations.count)개 지점")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // 지도 뷰
            if locations.isEmpty {
                // 데이터 없을 때 플레이스홀더
                emptyMapPlaceholder
            } else {
                // 실시간 경로 지도
                routeMapView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .onChange(of: locations.count) { oldValue, newValue in
            // 좌표 개수가 변경되면 카메라 위치 자동 조정
            updateCameraPosition()
        }
    }

    // MARK: - Empty Placeholder

    private var emptyMapPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            Text("GPS 데이터 수집 중...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            Text("운동을 시작하면 경로가 표시됩니다")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Route Map View

    private var routeMapView: some View {
        Map(position: $cameraPosition) {
            // 경로 폴리라인 (파란색)
            if locations.count > 1 {
                MapPolyline(coordinates: locations)
                    .stroke(.blue, lineWidth: 4)
            }

            // 시작 위치 마커 (녹색)
            if let start = startLocation {
                Annotation("시작", coordinate: start) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 30, height: 30)

                        Image(systemName: "figure.run")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }

            // 현재 위치 마커 (빨간색) - 시작 위치와 다른 경우에만
            if let current = currentLocation,
               let start = startLocation,
               current.latitude != start.latitude || current.longitude != start.longitude {
                Annotation("현재", coordinate: current) {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )

                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 카메라 위치 자동 조정
    // FUNCTIONALITY:
    //   - 모든 좌표가 보이도록 지도 영역 계산
    //   - 카메라 위치 업데이트
    // ═══════════════════════════════════════
    private func updateCameraPosition() {
        if let region = mapRegion {
            cameraPosition = .region(region)
        }
    }
}
