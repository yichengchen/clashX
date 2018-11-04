import Foundation

class SectionConfig {
    var dict = [String: String]()
    var dictArray = [(String,String)]()
    var array = [String]()
}

typealias Config = [String: SectionConfig]




func stripComment(_ line: String) -> String {
    let parts = line.split(
        separator: "#",
        maxSplits: 1,
        omittingEmptySubsequences: false)
    if parts.count > 0 {
        return String(parts[0])
    }
    return ""
}


func parseSectionHeader(_ line: String) -> String {
    let from = line.index(after: line.startIndex)
    let to = line.index(before: line.endIndex)
    return String(line[from..<to])
}


func parseLine(_ line: String) -> (String, String)? {
    let parts = stripComment(line).split(separator: "=", maxSplits: 1)
    if parts.count == 2 {
        let k = String(parts[0]).trimed()
        let v = String(parts[1]).trimed()
        return (k, v)
    }
    return nil
}


func parseConfig(_ filename : String) -> Config? {
    guard let f = try? String(contentsOfFile: filename) else {return nil}
    var config = Config()
    var currentSectionName = "main"
    for line in f.components(separatedBy: "\n") {
        let line = line.trimed()
        if line.hasPrefix("[") && line.hasSuffix("]") {
            currentSectionName = parseSectionHeader(line)
            if (config[currentSectionName] == nil) {config[currentSectionName] = SectionConfig()}
        } else if let (k, v) = parseLine(line) {
            config[currentSectionName]?.dict[k] = v
            config[currentSectionName]?.dictArray.append((k,v))
        } else if line.hasPrefix("//") || line.hasPrefix("#") || line.count < 1 {
            continue
        } else {
            if (line.split(separator: ",").count > 1) {
                config[currentSectionName]?.array.append(line)
            }
        }
    }
    return config
}
