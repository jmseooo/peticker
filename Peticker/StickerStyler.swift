import UIKit
import CoreImage

// 3단계 — 누끼 딴 피사체 둘레에 컬러 스트로크(테두리)를 둘러 스티커로 만듦
enum StickerStyler {

    /// 배경 제거된 이미지(cutout)에 색 테두리를 둘러 반환. 실패 시 nil.
    /// - color: 테두리 색
    /// - widthRatio: 이미지 크기 대비 테두리 두께 비율 (기본 1.5%)
    static func addStroke(
        to cutout: UIImage,
        color: UIColor,
        widthRatio: CGFloat = 0.015
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let input = CIImage(image: cutout) else { return nil }

            let extent = input.extent
            // 테두리 두께: 이미지 긴 변 기준 비율, 최소 6pt
            let radius = max(6, max(extent.width, extent.height) * widthRatio)
            let blurRadius = radius * 0.35

            // 피사체가 이미지 경계에 붙어 잘려있어도 그 변에 테두리가 그려지도록
            // 캔버스를 테두리 두께(+블러 여유)만큼 넓힘. 넓힌 영역은 투명.
            let pad = ceil(radius + blurRadius * 3)
            let paddedExtent = extent.insetBy(dx: -pad, dy: -pad)

            // 1. 피사체 실루엣을 바깥으로 팽창 (테두리 두께만큼)
            //    clampedToExtent를 쓰지 않아 경계 바깥을 투명으로 둠 → 잘린 변에서도
            //    경계의 불투명 픽셀이 바깥(투명 여백)으로 번져 테두리가 생김.
            let dilated = input
                .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])
                .cropped(to: paddedExtent)

            // 1-2. 팽창된 실루엣의 가장자리를 매끄럽게 다듬음
            //      살짝 블러로 계단(각짐)을 없앤 뒤, alpha를 적당히 증폭해
            //      선명함은 유지하되 곡선은 부드럽게
            let hardened = dilated
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
                .cropped(to: paddedExtent)
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 4)
                ])
                .applyingFilter("CIColorClamp")

            // 2. 다듬은 실루엣을 단색(테두리 색)으로 칠함 — alpha는 유지
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let colored = hardened.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: r, y: g, z: b, w: 0)
            ])

            // 3. 원본 피사체를 색 테두리 위에 합성
            let output = input.composited(over: colored)

            let context = CIContext()
            guard let cg = context.createCGImage(output, from: paddedExtent) else { return nil }
            return UIImage(cgImage: cg)
        }.value
    }
}
