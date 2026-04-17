//
//  SpotifyHelpers.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/16/26.
//

import Foundation

struct SpotifyHelpers {
    
    static func extractTrackID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Case 1: spotify:track:ID
        if trimmed.hasPrefix("spotify:track:") {
            return trimmed.replacingOccurrences(of: "spotify:track:", with: "")
        }

        // Case 2: https://open.spotify.com/track/ID
        if let url = URL(string: trimmed),
           url.host?.contains("spotify.com") == true {

            let components = url.pathComponents
            if let trackIndex = components.firstIndex(of: "track"),
               components.count > trackIndex + 1 {
                return components[trackIndex + 1]
            }
        }

        return nil
    }

    static func displayText(from input: String) -> String {
        if let id = extractTrackID(from: input) {
            return "Track ID: \(id.prefix(8))..."
        } else {
            return "Invalid Spotify Link"
        }
    }
}
