//
//  WatchCreatureView.swift
//  Fonsters Watch App
//
//  watchOS SwiftUI view: displays creature from seed using creatureImage (CGImage).
//

import SwiftUI

struct WatchCreatureView: View {
    let seed: String
    let size: CGFloat

    var body: some View {
        let effectiveSeed = seed.trimmingCharacters(in: .whitespaces).isEmpty ? " " : seed
        Group {
            if let cgImage = creatureImage(for: effectiveSeed) {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: size, height: size)
            }
        }
    }
}
