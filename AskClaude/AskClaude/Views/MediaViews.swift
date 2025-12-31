import SwiftUI
import AppKit
import PDFKit

// MARK: - Image Block View

/// Displays an image from a local file or URL with loading and error states
struct ImageBlockView: View {
    let alt: String
    let url: String
    @Binding var loadedImages: [String: NSImage]
    @EnvironmentObject var textSizeManager: TextSizeManager
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var imageLoadTask: URLSessionDataTask?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = loadedImages[url] {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 500, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading...")
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "F5F5F3"))
                )
            } else if let error = loadError {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .foregroundStyle(Color(hex: "888888"))
                    Text(error)
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "F5F5F3"))
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .foregroundStyle(Color(hex: "888888"))
                    Text(alt.isEmpty ? url : alt)
                        .font(.system(size: textSizeManager.scaled(11)))
                        .foregroundStyle(Color(hex: "888888"))
                        .lineLimit(1)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "F5F5F3"))
                )
                .onAppear { loadImage() }
            }

            if !alt.isEmpty && loadedImages[url] != nil {
                Text(alt)
                    .font(.system(size: textSizeManager.scaled(10)))
                    .foregroundStyle(Color(hex: "888888"))
                    .italic()
            }
        }
        .onDisappear {
            imageLoadTask?.cancel()
        }
    }

    private func loadImage() {
        if url.hasPrefix("/") || url.hasPrefix("file://") {
            let filePath = url.hasPrefix("file://") ? String(url.dropFirst(7)) : url
            if let image = NSImage(contentsOfFile: filePath) {
                loadedImages[url] = image
            } else {
                loadError = "File not found"
            }
            return
        }

        guard let imageURL = URL(string: url) else {
            loadError = "Invalid URL"
            return
        }

        isLoading = true
        let task = URLSession.shared.dataTask(with: imageURL) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    // Don't show error if task was cancelled
                    if (error as NSError).code != NSURLErrorCancelled {
                        loadError = error.localizedDescription
                    }
                } else if let data = data, let image = NSImage(data: data) {
                    loadedImages[url] = image
                } else {
                    loadError = "Failed to load"
                }
            }
        }
        imageLoadTask = task
        task.resume()
    }
}

// MARK: - Video Player View

/// Placeholder view for video files with option to open in QuickTime
struct VideoPlayerView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "E85D04"))

            Text("Video: \(url.lastPathComponent)")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "666666"))

            Button("Open in QuickTime") {
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(hex: "E85D04"))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(hex: "F5F5F3"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - PDF Preview View

/// Displays a thumbnail of the first page of a PDF with page count
struct PDFPreviewView: View {
    let url: URL
    @State private var thumbnail: NSImage?
    @State private var pageCount: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            if let thumbnail = thumbnail {
                // Show PDF thumbnail
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(hex: "E8E8E4"), lineWidth: 1)
                    )

                HStack(spacing: 16) {
                    Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "888888"))

                    Button(action: { NSWorkspace.shared.open(url) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 10))
                            Text("Open in Preview")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "E85D04"))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Fallback
                VStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "E85D04"))

                    Text("PDF: \(url.lastPathComponent)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "666666"))

                    Button("Open in Preview") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "E85D04"))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(hex: "F5F5F3"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear { loadPDFThumbnail() }
    }

    private func loadPDFThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pdfDocument = PDFDocument(url: url),
                  let firstPage = pdfDocument.page(at: 0) else {
                return
            }

            let pageCount = pdfDocument.pageCount
            let pageRect = firstPage.bounds(for: .mediaBox)

            // Scale to reasonable size
            let scale: CGFloat = min(400 / pageRect.width, 500 / pageRect.height)
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            let image = NSImage(size: scaledSize)
            image.lockFocus()

            if let context = NSGraphicsContext.current?.cgContext {
                // White background
                context.setFillColor(NSColor.white.cgColor)
                context.fill(CGRect(origin: .zero, size: scaledSize))

                // Draw PDF page
                context.scaleBy(x: scale, y: scale)
                firstPage.draw(with: .mediaBox, to: context)
            }

            image.unlockFocus()

            DispatchQueue.main.async {
                self.thumbnail = image
                self.pageCount = pageCount
            }
        }
    }
}
