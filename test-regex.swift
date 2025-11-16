import Foundation

let testLine = "├── swift-argument-parser<https://github.com/apple/swift-argument-parser@1.6.2>"

print("Original: \(testLine)")

// Test tree removal
let cleanLine = testLine.replacingOccurrences(of: "^[├│└─ ]+", with: "", options: .regularExpression)
print("After tree removal: \(cleanLine)")

let trimmed = cleanLine.trimmingCharacters(in: .whitespaces)
print("After trimming: \(trimmed)")

// Test URL range detection
if let urlRange = trimmed.range(of: #"<[^>]+>"#, options: .regularExpression) {
    print("Found URL range: \(trimmed[urlRange])")
    let name = String(trimmed[..<urlRange.lowerBound]).trimmingCharacters(in: .whitespaces)
    let urlWithVersion = String(trimmed[urlRange].dropFirst().dropLast())
    print("Name: '\(name)'")
    print("URL+Version: '\(urlWithVersion)'")

    let components = urlWithVersion.components(separatedBy: "@")
    let url = components.first ?? urlWithVersion
    let version = components.count > 1 ? components[1] : "unspecified"
    print("URL: '\(url)'")
    print("Version: '\(version)'")
} else {
    print("No URL range found")
}