public enum LineEndingDetector {
    public static func normalize(_ text: String) -> NormalizedText {
        var result = String()
        result.reserveCapacity(text.utf8.count)
        var profile = LineEndingProfile()

        let scalars = text.unicodeScalars
        var index = scalars.startIndex
        while index < scalars.endIndex {
            let scalar = scalars[index]
            if scalar.value == 0x0D {
                let next = scalars.index(after: index)
                if next < scalars.endIndex, scalars[next].value == 0x0A {
                    profile.crlfCount += 1
                    result.append("\n")
                    index = scalars.index(after: next)
                } else {
                    profile.crCount += 1
                    result.append("\n")
                    index = next
                }
            } else {
                if scalar.value == 0x0A {
                    profile.lfCount += 1
                }
                result.unicodeScalars.append(scalar)
                index = scalars.index(after: index)
            }
        }

        return NormalizedText(text: result, profile: profile)
    }
}
