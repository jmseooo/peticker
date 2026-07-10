import UIKit
import Vision
import CoreImage

// 2단계 — 사진에서 피사체만 남기고 배경을 투명하게 (누끼)
// iOS 17+ Vision 프레임워크의 전경 피사체 마스크 기능 사용
enum BackgroundRemover {

    private static let context = CIContext()

    /// 원본 이미지에서 배경을 제거한 이미지를 반환. 실패 시 nil.
    /// Vision 마스크를 그대로 쓰면 경계가 반투명해 뿌옇게 보이므로,
    /// 마스크를 또렷하게 다듬은 뒤 원본 색을 오려낸다.
    static func removeBackground(from image: UIImage) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return nil }
            let orientation = cgOrientation(image.imageOrientation)

            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

            do {
                try handler.perform([request])
                guard let result = request.results?.first else { return nil }

                // 원본 해상도에 맞춘 마스크를 직접 받는다.
                // generateMaskedImage는 프리멀티플라이드 결과라 경계를 세우면 검은 띠가 생긴다.
                let maskBuffer = try result.generateScaledMaskForImage(
                    forInstances: result.allInstances,
                    from: handler
                )

                let source = normalized(CIImage(cgImage: cgImage).oriented(orientation))
                let mask = normalized(CIImage(cvPixelBuffer: maskBuffer))

                // 마스크를 원본 좌표계에 정확히 겹치도록 크기 보정
                let scaled = mask.transformed(by: CGAffineTransform(
                    scaleX: source.extent.width / mask.extent.width,
                    y: source.extent.height / mask.extent.height
                ))
                let cleaned = cleanedMask(scaled)

                // 다듬은 마스크로 원본 색을 오려낸다 (색은 원본 그대로 → 경계에 어두운 띠 없음).
                // CIBlendWithMask는 마스크의 휘도를 보므로 회색조 마스크를 그대로 넘긴다.
                let cutout = source.applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: source.extent),
                    kCIInputMaskImageKey: cleaned
                ])

                // 피사체 바운딩박스에 딱 맞게 잘라낸다.
                // 원본 캔버스를 유지하면 피사체가 사진 속 위치·크기 그대로 남아
                // 원 안에서 치우치고 작게 보이므로, 여기서 타이트하게 크롭한다.
                let bounds = opaqueBounds(of: cleaned) ?? source.extent
                guard let outputCG = context.createCGImage(cutout, from: bounds) else { return nil }
                return UIImage(cgImage: outputCG)
            } catch {
                return nil
            }
        }.value
    }

    // 원점을 (0,0)으로 맞춰 두 이미지의 좌표계를 일치시킨다
    private static func normalized(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(
            translationX: -image.extent.minX,
            y: -image.extent.minY
        ))
    }

    /// Vision 마스크(회색조)를 펜으로 그린 듯 또렷한 실루엣으로 다듬는다.
    /// 반투명 경계를 없애고, 잡티·가시를 정리한 뒤, 계단만 살짝 풀어준다.
    private static func cleanedMask(_ mask: CIImage) -> CIImage {
        let extent = mask.extent
        let unit = max(extent.width, extent.height)
        let speck = max(1, (unit * 0.004).rounded())          // 지워낼 잡티·가시 크기
        let antialias = max(1, unit * 0.0015)                 // 계단만 풀 정도의 아주 약한 흐림

        // 1) 이진화 — Vision 마스크의 반투명 경계(뿌연 원인)를 잘라낸다
        let binary = contrast(mask, 24)

        // 2) 열림(침식 → 팽창) — 작은 잡티와 가시처럼 튀어나온 부분 제거
        let opened = binary
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: speck])
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: speck])

        // 3) 닫힘(팽창 → 침식) — 내부의 작은 구멍과 우묵하게 패인 곳을 메움
        let closed = opened
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: speck])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: speck])

        // 4) 살짝 흐린 뒤 다시 대비를 세운다 — 계단(각짐)만 사라지고 선은 또렷하게 남는다
        let smoothed = closed
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: antialias])
            .cropped(to: extent)

        return contrast(smoothed, 8)
    }

    // 0.5를 기준으로 대비를 세워 이진화에 가깝게 만든다 (채도는 없앰)
    private static func contrast(_ image: CIImage, _ amount: CGFloat) -> CIImage {
        image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputBrightnessKey: 0,
                kCIInputContrastKey: amount
            ])
            .applyingFilter("CIColorClamp")
    }

    /// 마스크에서 불투명한 영역의 바운딩박스를 구한다.
    /// 축소본을 훑어 계산하므로 큰 사진에서도 가볍다. 피사체가 없으면 nil.
    private static func opaqueBounds(of mask: CIImage) -> CGRect? {
        let extent = mask.extent
        let scale = min(1, 256 / max(extent.width, extent.height))
        let small = mask.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(small, from: small.extent) else { return nil }

        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let gray = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        gray.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] > 127 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        // 픽셀 좌표(위→아래)를 CoreImage 좌표(아래→위)로 뒤집고 원본 배율로 되돌린다
        let s = 1 / scale
        let rect = CGRect(
            x: CGFloat(minX) * s,
            y: CGFloat(height - 1 - maxY) * s,
            width: CGFloat(maxX - minX + 1) * s,
            height: CGFloat(maxY - minY + 1) * s
        )
        return rect.integral.intersection(extent)
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
