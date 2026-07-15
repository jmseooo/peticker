import UIKit
import CoreImage

// 3단계 — 누끼 딴 피사체 둘레에 컬러 스트로크(테두리)를 둘러 스티커로 만듦
enum StickerStyler {

    private static let context = CIContext()

    /// 배경 제거된 이미지(cutout)에 색 테두리를 둘러 반환. 실패 시 nil.
    /// - color: 테두리 색
    /// - widthRatio: 이미지 크기 대비 테두리 두께 비율 (기본 4.3%)
    /// - feather: 테두리 바깥 경계의 번짐(px). 0이면 펜으로 그린 듯한 하드 엣지.
    static func addStroke(
        to cutout: UIImage,
        color: UIColor,
        widthRatio: CGFloat = 0.043,
        feather: CGFloat = 0
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let input = CIImage(image: cutout) else { return nil }

            let extent = input.extent
            // 테두리 두께: 이미지 긴 변 기준 비율, 최소 18pt
            let width = max(18, max(extent.width, extent.height) * widthRatio)

            // 피사체가 이미지 경계에 붙어 잘려있어도 그 변에 테두리가 그려지도록
            // 캔버스를 테두리 두께만큼 넓힘. 넓힌 영역은 투명.
            let pad = ceil(width + feather * 3 + 2)
            let padded = extent.insetBy(dx: -pad, dy: -pad)

            // 1. 피사체 실루엣만 흰색으로 뽑아낸다 (RGB = A, 프리멀티플라이드 유지).
            //    clampedToExtent를 쓰지 않아 바깥은 투명 → 잘린 변에도 테두리가 생긴다.
            let silhouette = alphaAsWhite(input).cropped(to: padded)

            // 2. 실루엣을 테두리 두께만큼 바깥으로 팽창.
            //    CIMorphologyMaximum은 원반형 커널이라 모서리가 둥글게 확장된다.
            let dilated = silhouette
                .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: width])
                .cropped(to: padded)

            // 3. 경계를 정리한다. feather가 0이면 흐림 없이 문턱값만 적용해 하드 엣지를 만든다.
            let edged: CIImage
            if feather > 0 {
                edged = dilated
                    .clampedToExtent()
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: feather])
                    .cropped(to: padded)
            } else {
                edged = dilated
            }
            let hardened = threshold(edged)

            // 4. 다듬은 실루엣을 테두리 색으로 칠한다 (RGB = color x A → 프리멀티플라이드)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let colored = hardened.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: r),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: g),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: b),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])

            // 5. 원본 피사체를 색 테두리 위에 합성
            let output = input.composited(over: colored)

            guard let cg = context.createCGImage(output, from: padded) else { return nil }
            return UIImage(cgImage: cg)
        }.value
    }

    // 알파를 흰색 실루엣으로 (RGB = A). 프리멀티플라이드라 색 번짐이 없다.
    private static func alphaAsWhite(_ image: CIImage) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
    }

    // 알파 0.5를 기준으로 잘라 반투명 경계를 없앤다 (RGB는 알파를 따라감)
    private static func threshold(_ image: CIImage) -> CIImage {
        let gain: CGFloat = 64
        let bias = -0.5 * gain + 0.5
        return image
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: gain),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: gain),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: gain),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: gain),
                "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: bias)
            ])
            .applyingFilter("CIColorClamp")
    }
}
