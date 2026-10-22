import AppKit

// The play-room scenes, one per supported series plus the UN hall for politics. Drawn in view coordinates
// (y up) and clipped to the room's rounded outline; members stand on the floor strip at the bottom.
extension RoomView {
    // MARK: Kimetsu no Yaiba

    /// A wisteria trellis on a moonlit night, over a wooden veranda.
    func drawWisteriaNight(wall: CGRect, floorH: CGFloat) {
        let w = bounds.width, h = wall.height
        gradient(wall, color(84, 60, 128), color(22, 24, 60))
        for i in 0..<45 {
            let star = CGPoint(x: noise(i) * w, y: wall.minY + h * (0.3 + 0.7 * noise(i, 1)))
            circle(star, 0.6 + noise(i, 2) * 1.1, color(255, 250, 230, 0.5 + 0.5 * noise(i, 3)))
        }
        let r = min(24, h * 0.16)
        let moon = CGPoint(x: w * 0.78, y: wall.minY + h * 0.56)
        circle(moon, r * 1.7, color(255, 240, 200, 0.12))
        circle(moon, r, color(255, 246, 214))
        shape([(0, 0), (0, 0.22), (0.18, 0.38), (0.36, 0.2), (0.55, 0.34), (0.78, 0.16), (1, 0.3), (1, 0)]
            .map { CGPoint(x: $0.0 * w, y: wall.minY + $0.1 * h) }, color(48, 36, 82))

        // Trellis beam with blossoms hanging from it, tapering toward the tips.
        let top = bounds.height - 8
        fill(CGRect(x: 0, y: top - 2, width: w, height: 10), color(92, 62, 44))
        let shades = [color(206, 170, 236), color(176, 128, 218), color(150, 100, 200)]
        for (i, x) in stride(from: CGFloat(8), to: w, by: 22).enumerated() {
            let length = min(h * 0.45, 30 + noise(i, 4) * 50)
            for j in 0..<Int(length / 5) {
                let t = CGFloat(j) * 5
                let spread = 6 * (1 - t / length)
                circle(CGPoint(x: x + (noise(i * 31 + j, 5) - 0.5) * spread * 2, y: top - t), 2.4 + spread * 0.35, shades[(i + j) % 3])
            }
            oval(CGRect(x: x - 8, y: top - 7, width: 11, height: 5), color(96, 150, 90))
        }

        planks(floorH, base: color(122, 82, 56), seam: color(86, 56, 38), edge: color(70, 46, 32))
    }

    // MARK: One Piece

    /// The Thousand Sunny's lawn deck at sea, under the Straw Hat jolly roger.
    func drawSunnyDeck(wall: CGRect, floorH: CGFloat) {
        let w = bounds.width, h = wall.height
        gradient(wall, color(196, 232, 250), color(96, 176, 236))
        let sun = CGPoint(x: w * 0.12, y: wall.maxY - 34)
        circle(sun, 30, color(255, 236, 150, 0.35))
        circle(sun, 18, color(255, 226, 120))
        cloud(CGPoint(x: w * 0.36, y: wall.maxY - 38), 1)
        cloud(CGPoint(x: w * 0.88, y: wall.maxY - 64), 0.8)

        let sea = CGRect(x: 0, y: wall.minY, width: w, height: h * 0.3)
        gradient(sea, color(30, 100, 170), color(70, 150, 210))
        waves(in: sea, salt: 6)

        // Mast and flag.
        let mastX = w * 0.68
        fill(CGRect(x: mastX - 5, y: wall.minY, width: 10, height: h), color(150, 100, 60))
        let flagH = min(58, h * 0.36), flagW = min(84, flagH * 1.45)
        let flag = CGRect(x: mastX + 5, y: wall.maxY - flagH - 12, width: flagW, height: flagH)
        fill(flag, color(30, 30, 34))
        jollyRoger(in: flag)

        // Railing between the deck and the sea.
        let wood = color(164, 112, 70)
        fill(CGRect(x: 0, y: wall.minY + 16, width: w, height: 6), wood)
        for x in stride(from: CGFloat(10), to: w, by: 34) {
            fill(CGRect(x: x, y: wall.minY, width: 5, height: 18), wood)
        }

        fill(CGRect(x: 0, y: 0, width: w, height: floorH), color(126, 196, 92))
        for x in stride(from: CGFloat(0), to: w, by: 40) {
            fill(CGRect(x: x, y: 0, width: 20, height: floorH), color(116, 184, 84))
        }
        fill(CGRect(x: 0, y: floorH - 4, width: w, height: 8), wood)
    }

    private func jollyRoger(in f: CGRect) {
        let r = f.height * 0.2
        let c = CGPoint(x: f.midX, y: f.midY - r * 0.4)
        let bone = color(245, 245, 240)
        for d: CGFloat in [-1, 1] {
            line(CGPoint(x: c.x - r * 1.7, y: c.y - r * 1.3 * d), CGPoint(x: c.x + r * 1.7, y: c.y + r * 1.3 * d), bone, r * 0.35)
        }
        circle(c, r, bone)
        fill(CGRect(x: c.x - r * 0.55, y: c.y - r * 1.15, width: r * 1.1, height: r * 0.7), bone)
        for dx: CGFloat in [-0.38, 0.38] { circle(CGPoint(x: c.x + r * dx, y: c.y - r * 0.05), r * 0.24, color(30, 30, 34)) }
        // The straw hat, with its red band.
        let straw = color(240, 200, 90)
        oval(CGRect(x: c.x - r * 0.85, y: c.y + r * 0.6, width: r * 1.7, height: r * 1.1), straw)
        fill(CGRect(x: c.x - r * 0.84, y: c.y + r * 0.72, width: r * 1.68, height: r * 0.24), color(214, 52, 48))
        oval(CGRect(x: c.x - r * 1.55, y: c.y + r * 0.5, width: r * 3.1, height: r * 0.5), straw)
    }

    // MARK: Attack on Titan

    /// Wall Maria, with the Colossal Titan peeking over it, above a cobblestone street.
    func drawWallMaria(wall: CGRect, floorH: CGFloat) {
        let w = bounds.width, h = wall.height
        gradient(wall, color(250, 214, 168), color(150, 190, 225))
        let top = wall.minY + h * 0.62

        let r = min(h * 0.3, 56)
        let face = CGPoint(x: w * 0.3, y: top + r * 0.45)
        for i in 0..<7 {
            let puff = CGPoint(x: face.x + (noise(i, 6) - 0.5) * r * 3, y: face.y + r * 0.5 + noise(i, 7) * r * 0.9)
            circle(puff, r * (0.3 + 0.3 * noise(i, 8)), color(255, 255, 255, 0.45))
        }
        oval(CGRect(x: face.x - r * 0.85, y: face.y - r, width: r * 1.7, height: r * 2), color(196, 78, 66))
        for k in -2...2 {   // bare muscle
            let x = face.x + CGFloat(k) * r * 0.15
            line(CGPoint(x: x, y: face.y + r * 0.88), CGPoint(x: x * 1 + CGFloat(k) * r * 0.05, y: face.y + r * 0.3), color(160, 52, 46), 1.5)
        }
        oval(CGRect(x: face.x - r * 0.62, y: face.y + r * 0.18, width: r * 1.24, height: r * 0.2), color(150, 48, 42))
        for dx: CGFloat in [-0.32, 0.32] {
            let eye = CGPoint(x: face.x + r * dx, y: face.y + r * 0.02)
            circle(eye, r * 0.16, color(250, 246, 236))
            circle(eye, r * 0.06, color(40, 30, 30))
        }

        // The wall itself.
        fill(CGRect(x: 0, y: wall.minY, width: w, height: top - wall.minY), color(196, 182, 156))
        let seam = color(170, 154, 128)
        for (row, y) in stride(from: wall.minY, to: top, by: 14).enumerated() {
            fill(CGRect(x: 0, y: y, width: w, height: 1.5), seam)
            for x in stride(from: row % 2 == 0 ? CGFloat(0) : 22, to: w, by: 44) {
                fill(CGRect(x: x, y: y, width: 1.5, height: 14), seam)
            }
        }
        fill(CGRect(x: 0, y: top - 2, width: w, height: 8), color(150, 136, 112))

        // Survey Corps banner hanging from the parapet.
        let bannerH = min(64, (top - wall.minY) * 0.8), bannerW = bannerH * 0.65
        let banner = CGRect(x: w * 0.7, y: top - 2 - bannerH, width: bannerW, height: bannerH)
        fill(banner, color(46, 84, 60))
        shape([CGPoint(x: banner.minX, y: banner.minY), CGPoint(x: banner.midX, y: banner.minY - 8), CGPoint(x: banner.maxX, y: banner.minY)],
              color(46, 84, 60))
        wingsOfFreedom(CGPoint(x: banner.midX, y: banner.midY), bannerW * 0.42)

        fill(CGRect(x: 0, y: 0, width: w, height: floorH), color(140, 130, 120))
        for (row, y) in stride(from: CGFloat(3), to: floorH - 4, by: 13).enumerated() {
            for (col, x) in stride(from: row % 2 == 0 ? CGFloat(-6) : 8, to: w, by: 28).enumerated() {
                let stone = noise(row * 97 + col, 9) > 0.5 ? color(174, 164, 152) : color(160, 150, 138)
                stone.setFill()
                NSBezierPath(roundedRect: CGRect(x: x, y: y, width: 24, height: 10), xRadius: 4, yRadius: 4).fill()
            }
        }
        fill(CGRect(x: 0, y: floorH - 2, width: w, height: 6), color(110, 100, 92))
    }

    /// Two overlapping wings, white over blue.
    private func wingsOfFreedom(_ c: CGPoint, _ s: CGFloat) {
        for (dx, wing) in [(s * 0.25, color(70, 110, 196)), (-s * 0.25, color(245, 245, 245))] {
            shape([CGPoint(x: c.x + dx + s * 0.5, y: c.y - s * 0.9), CGPoint(x: c.x + dx - s * 0.7, y: c.y + s * 0.9),
                   CGPoint(x: c.x + dx - s * 0.35, y: c.y + s * 0.1), CGPoint(x: c.x + dx - s * 0.75, y: c.y + s * 0.05),
                   CGPoint(x: c.x + dx - s * 0.3, y: c.y - s * 0.35), CGPoint(x: c.x + dx - s * 0.6, y: c.y - s * 0.45)], wing)
        }
    }

    // MARK: Jujutsu Kaisen

    /// Tokyo Jujutsu High at dusk: a torii gate, a temple hall and a stone path.
    func drawJujutsuHigh(wall: CGRect, floorH: CGFloat) {
        let w = bounds.width, h = wall.height, base = wall.minY
        gradient(wall, color(250, 176, 128), color(104, 82, 150))
        let forest = color(52, 70, 70)
        for i in 0...Int(w / 22) {
            circle(CGPoint(x: CGFloat(i) * 22 + noise(i, 9) * 8, y: base + h * 0.18 + noise(i, 10) * h * 0.1), 16 + noise(i, 11) * 8, forest)
        }
        fill(CGRect(x: 0, y: base, width: w, height: h * 0.18), forest)
        for i in 0..<6 {   // cursed energy drifting about
            circle(CGPoint(x: noise(i, 12) * w, y: base + h * (0.35 + 0.6 * noise(i, 13))), 3 + noise(i, 14) * 6,
                   color(160, 100, 230, 0.3))
        }

        let red = color(184, 50, 42)
        // Temple hall.
        let hallW = min(w * 0.36, 200), hallX = w - hallW - w * 0.06, hallH = h * 0.3, roofH = h * 0.18
        fill(CGRect(x: hallX, y: base, width: hallW, height: hallH), color(236, 226, 206))
        for k in 0...4 {
            fill(CGRect(x: hallX + hallW * CGFloat(k) / 4 - 3, y: base, width: 6, height: hallH), red)
        }
        shape([CGPoint(x: hallX - hallW * 0.14, y: base + hallH + 4), CGPoint(x: hallX + hallW * 1.14, y: base + hallH + 4),
               CGPoint(x: hallX + hallW * 0.86, y: base + hallH + roofH), CGPoint(x: hallX + hallW * 0.14, y: base + hallH + roofH)],
              color(58, 58, 66))
        fill(CGRect(x: hallX + hallW * 0.1, y: base + hallH + roofH - 3, width: hallW * 0.8, height: 6), color(40, 40, 46))

        // Torii gate.
        let gx = w * 0.26, gw = min(w * 0.3, 150), gh = min(h * 0.68, 130)
        for side: CGFloat in [-1, 1] {
            fill(CGRect(x: gx + side * gw * 0.36 - 4.5, y: base, width: 9, height: gh), red)
        }
        fill(CGRect(x: gx - gw * 0.46, y: base + gh * 0.72, width: gw * 0.92, height: 7), red)
        fill(CGRect(x: gx - 3, y: base + gh * 0.72, width: 6, height: gh * 0.28), red)
        shape([CGPoint(x: gx - gw * 0.55, y: base + gh - 4), CGPoint(x: gx + gw * 0.55, y: base + gh - 4),
               CGPoint(x: gx + gw * 0.62, y: base + gh + 6), CGPoint(x: gx - gw * 0.62, y: base + gh + 6)], red)
        shape([CGPoint(x: gx - gw * 0.62, y: base + gh + 6), CGPoint(x: gx + gw * 0.62, y: base + gh + 6),
               CGPoint(x: gx + gw * 0.66, y: base + gh + 12), CGPoint(x: gx - gw * 0.66, y: base + gh + 12)], color(40, 30, 30))

        // Gravel yard with a stone path up to the gate.
        fill(CGRect(x: 0, y: 0, width: w, height: floorH), color(176, 170, 160))
        for i in 0..<Int(w * floorH / 160) {
            circle(CGPoint(x: noise(i, 15) * w, y: noise(i, 16) * floorH), 1, color(146, 140, 130))
        }
        color(204, 198, 188).setFill()
        for y in stride(from: CGFloat(4), to: floorH - 8, by: 18) {
            NSBezierPath(roundedRect: CGRect(x: gx - 30, y: y, width: 60, height: 13), xRadius: 3, yRadius: 3).fill()
        }
        fill(CGRect(x: 0, y: floorH - 2, width: w, height: 6), color(120, 116, 108))
    }

    // MARK: Hunter x Hunter

    /// Gon's Whale Island: green hills by the sea, a big tree and a whale spouting offshore.
    func drawWhaleIsland(wall: CGRect, floorH: CGFloat) {
        let w = bounds.width, h = wall.height, base = wall.minY
        gradient(wall, color(214, 240, 252), color(110, 190, 240))
        cloud(CGPoint(x: w * 0.2, y: wall.maxY - 36), 0.9)
        cloud(CGPoint(x: w * 0.62, y: wall.maxY - 56), 1.1)

        let sea = CGRect(x: 0, y: base, width: w, height: h * 0.36)
        gradient(sea, color(40, 120, 190), color(80, 160, 215))
        waves(in: sea, salt: 17)
        if w >= 360 {
            let whale = CGPoint(x: w * 0.55, y: sea.minY + sea.height * 0.7)
            let blue = color(54, 84, 140)
            oval(CGRect(x: whale.x - 22, y: whale.y - 6, width: 44, height: 14), blue)
            shape([CGPoint(x: whale.x + 18, y: whale.y), CGPoint(x: whale.x + 32, y: whale.y + 9), CGPoint(x: whale.x + 30, y: whale.y - 4)], blue)
            for (dx, dy, r): (CGFloat, CGFloat, CGFloat) in [(-12, 12, 2.5), (-16, 17, 2.2), (-8, 17, 2.2), (-12, 20, 2)] {
                circle(CGPoint(x: whale.x + dx, y: whale.y + dy), r, color(255, 255, 255, 0.9))
            }
        }

        oval(CGRect(x: -w * 0.1, y: base - h * 0.3, width: w * 0.6, height: h * 0.54), color(104, 174, 82))
        oval(CGRect(x: w * 0.62, y: base - h * 0.36, width: w * 0.6, height: h * 0.6), color(86, 158, 70))

        let tree = CGPoint(x: w * 0.82, y: base)
        fill(CGRect(x: tree.x - 6, y: base, width: 12, height: h * 0.42), color(120, 82, 52))
        for (dx, dy, r): (CGFloat, CGFloat, CGFloat) in [(-18, 0.42, 20), (16, 0.44, 20), (0, 0.55, 24), (-4, 0.4, 18)] {
            circle(CGPoint(x: tree.x + dx, y: base + h * dy), min(r, h * 0.16), dy > 0.5 ? color(90, 165, 72) : color(70, 140, 60))
        }

        fill(CGRect(x: 0, y: 0, width: w, height: floorH), color(120, 186, 86))
        oval(CGRect(x: w * 0.2, y: floorH * 0.15, width: w * 0.6, height: floorH * 0.55), color(206, 170, 120))
        for i in 0..<Int(w / 14) {   // grass tufts
            let p = CGPoint(x: noise(i, 18) * w, y: noise(i, 19) * (floorH - 12))
            line(p, CGPoint(x: p.x - 2, y: p.y + 5), color(84, 150, 60), 1.2)
            line(p, CGPoint(x: p.x + 2, y: p.y + 6), color(84, 150, 60), 1.2)
        }
        fill(CGRect(x: 0, y: floorH - 3, width: w, height: 6), color(96, 160, 70))
    }

    // MARK: Politics

    /// The UN General Assembly hall: gold wall, the emblem, a row of flags, the green rostrum and blue carpet.
    func drawAssemblyHall(wall: CGRect, floorH: CGFloat) {
        let w = bounds.width, h = wall.height, base = wall.minY
        gradient(wall, color(214, 170, 92), color(238, 206, 140))
        for x in stride(from: CGFloat(20), to: w, by: 36) {
            fill(CGRect(x: x, y: base, width: 2, height: h), color(196, 152, 78, 0.6))
        }

        // Big screens on both sides.
        if w >= 420 {
            let sw = min(w * 0.16, 90), sh = sw * 0.6
            for x in [w * 0.06, w * 0.94 - sw] {
                let screen = CGRect(x: x, y: base + h * 0.5, width: sw, height: sh)
                fill(screen, color(40, 40, 50))
                gradient(screen.insetBy(dx: 3, dy: 3), color(30, 60, 120), color(70, 120, 200))
            }
        }

        // Emblem: a globe in an olive wreath.
        let r = min(h * 0.24, 42), c = CGPoint(x: w / 2, y: base + h * 0.6)
        circle(c, r * 1.4, color(250, 228, 170, 0.55))
        circle(c, r, color(78, 148, 216))
        let globe = color(255, 255, 255, 0.95)
        globe.setStroke()
        for k: CGFloat in [0.33, 0.66] {
            let ring = NSBezierPath(ovalIn: CGRect(x: c.x - r * k, y: c.y - r * k, width: r * 2 * k, height: r * 2 * k))
            ring.lineWidth = 1.2
            ring.stroke()
        }
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * 2 * .pi
            line(c, CGPoint(x: c.x + cos(a) * r * 0.9, y: c.y + sin(a) * r * 0.9), globe, 1)
        }
        for side: CGFloat in [-1, 1] {
            for k in 0..<9 {
                let a = -CGFloat.pi / 2 + side * (0.12 + CGFloat(k) / 8 * 0.8) * .pi
                let leaf = CGPoint(x: c.x + cos(a) * r * 1.2, y: c.y + sin(a) * r * 1.2)
                oval(CGRect(x: leaf.x - r * 0.08, y: leaf.y - r * 0.08, width: r * 0.16, height: r * 0.16), globe)
            }
        }

        // Flags on poles either side of the rostrum (plain stripes, no particular country).
        let deskW = min(w * 0.5, 260)
        let stripes: [(NSColor, NSColor)] = [
            (color(214, 52, 48), color(250, 250, 250)), (color(40, 90, 180), color(250, 210, 60)),
            (color(40, 140, 80), color(250, 250, 250)), (color(250, 210, 60), color(214, 52, 48)),
            (color(250, 250, 250), color(40, 90, 180)), (color(30, 30, 34), color(214, 52, 48)),
        ]
        let poleH = min(60, h * 0.4)
        var i = 0
        for x in stride(from: CGFloat(18), to: w / 2 - deskW / 2 - 10, by: 26) {
            for px in [x, w - x] {
                line(CGPoint(x: px, y: base), CGPoint(x: px, y: base + poleH), color(120, 100, 70), 1.5)
                let (a, b) = stripes[i % stripes.count]
                fill(CGRect(x: px + 1, y: base + poleH - 6, width: 15, height: 6), a)
                fill(CGRect(x: px + 1, y: base + poleH - 12, width: 15, height: 6), b)
                i += 1
            }
        }

        // Blue carpet with rows of delegate desks.
        fill(CGRect(x: 0, y: 0, width: w, height: floorH), color(52, 82, 140))
        for k in 0..<2 {
            fill(CGRect(x: 0, y: floorH * (0.2 + CGFloat(k) * 0.35), width: w, height: 5), color(176, 136, 84, 0.85))
        }
        fill(CGRect(x: 0, y: floorH - 2, width: w, height: 6), color(150, 112, 60))

        // The green marble rostrum and lectern at the back.
        let rostrum = CGRect(x: w / 2 - deskW / 2, y: floorH - 4, width: deskW, height: min(26, h * 0.16))
        fill(rostrum, color(46, 96, 76))
        fill(CGRect(x: rostrum.minX, y: rostrum.maxY - 3, width: deskW, height: 3), color(214, 176, 96))
        fill(CGRect(x: w / 2 - 14, y: floorH - 4, width: 28, height: min(38, h * 0.24)), color(36, 80, 62))
    }

    // MARK: Helpers

    private func gradient(_ rect: CGRect, _ bottom: NSColor, _ top: NSColor) {
        NSGradient(starting: bottom, ending: top)!.draw(in: rect, angle: 90)
    }

    private func oval(_ rect: CGRect, _ c: NSColor) {
        c.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat, _ c: NSColor) {
        oval(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), c)
    }

    private func shape(_ points: [CGPoint], _ c: NSColor) {
        let path = NSBezierPath()
        path.move(to: points[0])
        for p in points.dropFirst() { path.line(to: p) }
        path.close()
        c.setFill()
        path.fill()
    }

    private func line(_ from: CGPoint, _ to: CGPoint, _ c: NSColor, _ width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: from)
        path.line(to: to)
        path.lineWidth = width
        path.lineCapStyle = .round
        c.setStroke()
        path.stroke()
    }

    private func cloud(_ c: CGPoint, _ scale: CGFloat) {
        for (dx, dy, r): (CGFloat, CGFloat, CGFloat) in [(-14, 0, 10), (0, 5, 13), (15, 0, 10)] {
            circle(CGPoint(x: c.x + dx * scale, y: c.y + dy * scale), r * scale, color(255, 255, 255, 0.95))
        }
    }

    private func waves(in sea: CGRect, salt: Double) {
        for i in 0..<Int(sea.width / 30) {
            let p = CGPoint(x: noise(i, salt) * sea.width, y: sea.minY + 4 + noise(i, salt + 1) * (sea.height - 8))
            line(p, CGPoint(x: p.x + 10, y: p.y), color(255, 255, 255, 0.6), 1.5)
        }
    }

    private func planks(_ floorH: CGFloat, base: NSColor, seam: NSColor, edge: NSColor) {
        fill(CGRect(x: 0, y: 0, width: bounds.width, height: floorH), base)
        for (row, y) in stride(from: CGFloat(0), to: floorH, by: 16).enumerated() {
            fill(CGRect(x: 0, y: y, width: bounds.width, height: 1.5), seam)
            for x in stride(from: row % 2 == 0 ? CGFloat(30) : 75, to: bounds.width, by: 90) {
                fill(CGRect(x: x, y: y, width: 1.5, height: 16), seam)
            }
        }
        fill(CGRect(x: 0, y: floorH - 2, width: bounds.width, height: 9), edge)
    }

    /// The same value in 0..<1 on every redraw for the same inputs, so stars and stones don't jump around.
    private func noise(_ i: Int, _ salt: Double = 0) -> CGFloat {
        let v = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
        return CGFloat(v - v.rounded(.down))
    }
}
