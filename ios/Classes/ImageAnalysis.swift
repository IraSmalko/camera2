import Foundation
import AVKit

enum C2ColorOrder {
    case rgb
    case rbg
    case grb
    case gbr
    case brg
    case bgr
}

enum C2Normalization {
    case ubyte
    case byte
    case ufloat
    case float
}

struct C2AnalysisOptions {
    let imageSize: CGSize
    let colorOrder: C2ColorOrder
    let normalization: C2Normalization
    let centerCropAspectRatio: CGFloat?
    let centerCropWidthPercent: CGFloat?
    
    init(dictionary opts: Dictionary<String, Any?>) {
        switch (opts["colorOrder"] as! String) {
        case "rgb": self.colorOrder = C2ColorOrder.rgb
        case "rbg": self.colorOrder = C2ColorOrder.rbg
        case "gbr": self.colorOrder = C2ColorOrder.gbr
        case "grb": self.colorOrder = C2ColorOrder.grb
        case "brg": self.colorOrder = C2ColorOrder.brg
        case "bgr": self.colorOrder = C2ColorOrder.bgr
        default:
            fatalError("'colorOrder' value must be one of ['rgb', 'rbg', 'gbr', 'grb', 'brg', 'bgr']")
        }
        
        switch (opts["normalization"] as! String) {
        case "ubyte" : self.normalization = C2Normalization.ubyte
        case "byte"  : self.normalization = C2Normalization.byte
        case "ufloat": self.normalization = C2Normalization.ufloat
        case "float" : self.normalization = C2Normalization.float
        default:
            fatalError("'normalization' value must be one of ['ubyte', 'byte', 'ufloat', 'float']")
        }
        
        self.imageSize = CGSize(
            width: (opts["imageWidth"] as! NSNumber).intValue,
            height: (opts["imageHeight"] as! NSNumber).intValue
        )
        
        if let centerCropAspectRatio = (opts["centerCropAspectRatio"] as? NSNumber)?.floatValue {
            self.centerCropAspectRatio = CGFloat(centerCropAspectRatio)
        }
        if let centerCropWidthPercent = (opts["centerCropWidthPercent"] as? NSNumber)?.floatValue {
            self.centerCropWidthPercent = CGFloat(centerCropWidthPercent)
        }
    }
}

class C2ImageAnalysisHelper : NSObject {
    private let opts: C2AnalysisOptions
    
    init(opts: C2AnalysisOptions) {
        self.opts = opts
        super.init()
    }
    
}