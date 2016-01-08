
module.exports.splitVersion = splitVersion = (s) ->
            parts = s.match /(\d+)\.(\d+)\.(\d+)/
            # Keep only useful data (first elem is full string)
            parts = parts.slice 1, 4
            parts = parts.map (s) -> parseInt s
            return major: parts[0], minor: parts[1], patch: parts[2]


module.exports.compareVersions = (version1, version2) ->
    v1 = splitVersion version1
    v2 = splitVersion version2

    if v1.major < v2.major or v1.minor < v2.minor or v1.patch < v2.patch
        return -1
    else if v1.major > v2.major or v1.minor > v2.minor or v1.patch > v2.patch
        return 1
    else return 0
