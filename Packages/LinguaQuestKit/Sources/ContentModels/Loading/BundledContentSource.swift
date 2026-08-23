import Foundation

/// Источник контента Фазы 1: JSON-файлы, вшитые в бандл пакета ContentModels.
/// Сеть не используется — приложение полностью работает офлайн.
public struct BundledContentSource: ContentSource {

    private let bundle: Bundle
    private let subdirectory: String

    /// - Parameter bundle: nil означает бандл ресурсов самого пакета.
    ///   `Bundle.module` нельзя поставить значением по умолчанию у public-инициализатора:
    ///   SwiftPM генерирует это свойство как internal.
    public init(bundle: Bundle? = nil, subdirectory: String = "Content") {
        self.bundle = bundle ?? .module
        self.subdirectory = subdirectory
    }

    public func loadCatalog() throws -> ContentCatalog.Payload {
        let decoder = JSONDecoder()

        let manifest: ContentManifest = try decode(
            ContentManifest.self,
            fileName: "manifest",
            decoder: decoder,
            missingError: .manifestNotFound
        )

        let skills = try manifest.skillFiles.map { file in
            try decode(SkillContent.self, fileName: file, decoder: decoder, missingError: .fileNotFound(file))
        }

        let vocabulary = try decode(
            [VocabularyItem].self,
            fileName: manifest.vocabularyFile,
            decoder: decoder,
            missingError: .fileNotFound(manifest.vocabularyFile)
        )

        return ContentCatalog.Payload(manifest: manifest, skills: skills, vocabulary: vocabulary)
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        fileName: String,
        decoder: JSONDecoder,
        missingError: ContentError
    ) throws -> T {
        let name = fileName.hasSuffix(".json") ? String(fileName.dropLast(5)) : fileName
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
                ?? bundle.url(forResource: name, withExtension: "json") else {
            throw missingError
        }
        let data = try Data(contentsOf: url)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ContentError.decodingFailed(file: name, reason: String(describing: error))
        }
    }
}

/// Источник для тестов и превью: контент задаётся прямо в коде.
public struct InMemoryContentSource: ContentSource {
    private let payload: ContentCatalog.Payload

    public init(skills: [SkillContent], vocabulary: [VocabularyItem] = [], contentVersion: Int = 1) {
        self.payload = ContentCatalog.Payload(
            manifest: ContentManifest(contentVersion: contentVersion, skillFiles: [], vocabularyFile: ""),
            skills: skills,
            vocabulary: vocabulary
        )
    }

    public func loadCatalog() throws -> ContentCatalog.Payload { payload }
}
