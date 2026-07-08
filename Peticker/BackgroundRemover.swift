import UIKit
import Vision
import CoreImage

// 2단계 — 사진에서 피사체만 남기고 배경을 투명하게 (누끼)
// iOS 17+ Vision 프레임워크의 전경 피사체 마스크 기능 사용
enum BackgroundRemover {

    /// 원본 이미지에서 배경을 제거한 이미지를 반환. 실패 시 nil.
    static func removeBackground(from image: UIImage) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return nil }

            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: cgOrientation(image.imageOrientation),
                options: [:]
            )

            do {
                try handler.perform([request])
                guard let result = request.results?.first else { return nil }

                // 인식된 모든 피사체를 합쳐 배경 투명 이미지 생성
                // croppedToInstancesExtent: true → 피사체 바운딩박스에 딱 맞게 잘라냄.
                // 원본 캔버스 크기를 유지하면 피사체가 사진 속 위치·크기 그대로 남아
                // 원 안에서 치우치고 작게 보이므로, 여기서 타이트하게 크롭해 중앙·꽉참을 보장.
                let maskedBuffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: true
                )

                let ciImage = CIImage(cvPixelBuffer: maskedBuffer)
                let context = CIContext()
                guard let outputCG = context.createCGImage(ciImage, from: ciImage.extent) else {
                    return nil
                }
                return UIImage(cgImage: outputCG)
            } catch {
                return nil
            }
        }.value
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
