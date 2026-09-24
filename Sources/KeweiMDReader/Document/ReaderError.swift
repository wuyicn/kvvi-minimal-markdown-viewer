import Foundation

enum ReaderError: Error, Equatable {
    case unsupportedFileType
    case unreadableFile
    case unsupportedEncoding
    case fileTooLarge
    case renderFailed

    var userMessage: String {
        switch self {
        case .unsupportedFileType: return "请选择 Markdown 文件"
        case .unreadableFile: return "无法读取该文件"
        case .unsupportedEncoding: return "暂时无法识别该文件的文字编码"
        case .fileTooLarge: return "文件过大，暂时无法显示"
        case .renderFailed: return "无法显示该文件"
        }
    }
}

