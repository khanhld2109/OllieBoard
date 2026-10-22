import AppKit

// The two special-move rows ("skill1", "skill2") hold a different move for each anime character,
// props included. Agent mascots have no special moves, so their skill rows stay empty.

/// Both rows loop at 8 fps; the app plays a move that shouldn't loop for exactly one cycle (or holds its last frame).
func skillAnimation(_ which: Int) -> Animation {
    Animation(name: "skill\(which)", fps: 8, loop: true, frames: (0..<8).map { i in
        var p = Pose()
        p.skill = (which, i)
        return p
    })
}

func drawSkill(_ ctx: CGContext, _ look: Look, _ which: Int, _ i: Int) {
    switch (look.style, which) {
    case (.anya, 1): anyaTelepathy(ctx, look, i)
    case (.anya, 2): anyaSmug(ctx, look, i)
    case (.nezuko, 1): nezukoBurst(ctx, look, i)
    case (.nezuko, 2): nezukoWindup(ctx, look, i)
    case (.frieren, 1): frierenCast(ctx, look, i)
    case (.frieren, 2): frierenMimic(ctx, look, i)
    case (.bocchi, 1): bocchiGuitar(ctx, look, i)
    case (.bocchi, 2): bocchiMelt(ctx, look, i)
    case (.rem, 1): remMorningStar(ctx, look, i)
    case (.rem, 2): remOni(ctx, look, i)
    case (.trumpSwoop, 1): trumpWall(ctx, look, i)
    case (.trumpSwoop, 2): trumpTariff(ctx, look, i)
    case (.putinShort, 1): putinJudo(ctx, look, i)
    case (.putinShort, 2): putinBear(ctx, look, i)
    case (.xiSlick, 1): xiParade(ctx, look, i)
    case (.xiSlick, 2): xiRobot(ctx, look, i)
    case (.kimSide, 1): kimApplause(ctx, look, i)
    case (.kimSide, 2): kimMissile(ctx, look, i)
    default: drawAnimeSkill(ctx, look, which, i)
    }
}

// MARK: - Helpers

/// Runs `draw` in the space drawCharacter draws the body in: origin at the feet, y down, after bob and lean.
func inBody(_ ctx: CGContext, _ pose: Pose, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: feet.x, y: feet.y + pose.bob + (pose.sitting ? 15 : 0))
    ctx.rotate(by: pose.lean)
    draw()
    ctx.restoreGState()
}

/// Where a hand ends up for an arm angle (same geometry as drawCharacter's arms).
func hand(_ angle: CGFloat, front: Bool) -> CGPoint {
    CGPoint(x: (front ? 9 : -9) + sin(angle) * 15, y: -44 + cos(angle) * 15)
}

func drawHand(_ ctx: CGContext, _ p: CGPoint, _ look: Look, dark: Bool = false) {
    ctx.fill({ $0.addEllipse(in: CGRect(x: p.x - 3.4, y: p.y - 3.4, width: 6.8, height: 6.8)) },
             dark ? look.skinShade : look.skin, outlineWidth: 1.2)
}

/// Redraws an arm on top of a prop that was drawn over it.
func drawArm(_ ctx: CGContext, _ angle: CGFloat, _ look: Look, front: Bool) {
    limb(ctx, from: CGPoint(x: front ? 9 : -9, y: -44), angle: angle, length: 15, width: 5,
         color: front ? look.sleeve : look.sleeveDark) { drawHand(ctx, $0, look, dark: !front) }
}

/// A teardrop flame `size` tall, rising from `base` (the bottom of its round end).
func drawFlame(_ ctx: CGContext, at base: CGPoint, size s: CGFloat, lean: CGFloat = 0, colors: [CGColor]) {
    let w = s * 0.32
    let tip = CGPoint(x: base.x + lean * s, y: base.y - s)
    let path = CGMutablePath()
    path.move(to: tip)
    path.addQuadCurve(to: CGPoint(x: base.x + w, y: base.y - w), control: CGPoint(x: base.x + w * 1.15, y: base.y - s * 0.55))
    path.addArc(center: CGPoint(x: base.x, y: base.y - w), radius: w, startAngle: 0, endAngle: .pi, clockwise: false)
    path.addQuadCurve(to: tip, control: CGPoint(x: base.x - w * 1.15, y: base.y - s * 0.55))
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: base, end: tip, options: [])
    ctx.restoreGState()
}

let nezukoFlame = [rgb(0xE8336F, 0.95), rgb(0xFF6FA8, 0.9), rgb(0xFFD6E8, 0.7)]

// MARK: - Anya: telepathy and the smug "heh"

private func anyaTelepathy(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    let reach: CGFloat = i % 4 < 2 ? 0 : 0.12
    p.armFront = 2.5 + reach; p.armBack = -2.5 - reach
    p.eyes = .sparkle; p.mouth = .open; p.blush = 1
    p.bob = [0, -1, -2, -1, 0, -1, -2, -1][i]
    drawCharacter(ctx, p, look)
    // Waves coming off the hair ornaments.
    inBody(ctx, p) {
        let pulse = CGFloat(i % 4) / 3
        for side: CGFloat in [-1, 1] {
            for k in 0..<2 {
                let r = 9 + CGFloat(k) * 7 + pulse * 4
                ctx.stroke({ path in
                    path.addArc(center: CGPoint(x: side * 20, y: -106), radius: r,
                                startAngle: side > 0 ? -.pi / 2 : -.pi, endAngle: side > 0 ? 0 : -.pi / 2, clockwise: false)
                }, rgb(0xFF6FA8, 0.95 - CGFloat(k) * 0.35), 2.2)
            }
        }
    }
}

private func anyaSmug(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.eyes = .half; p.mouth = .smirk; p.brows = .raised; p.blush = 0.8
    p.armFront = -0.45; p.armBack = 0.45   // hands on hips
    p.tilt = -0.06
    p.bob = i % 4 < 2 ? 0 : -0.8
    drawCharacter(ctx, p, look)
    if (2...5).contains(i) {
        inBody(ctx, p) { fillStar(ctx, CGPoint(x: 31, y: -96), i == 3 || i == 4 ? 5 : 3, rgb(0xFFD84D)) }
    }
}

// MARK: - Nezuko: Exploding Blood (wind-up, then the burst)

private func nezukoWindup(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.bob = 4; p.legFront = 0.45; p.legBack = -0.45
    p.armFront = 0.75; p.armBack = 0.65
    p.eyes = .angry; p.brows = .angry; p.blush = 0.8
    p.hairSwing = [0, 0.03, 0.05, 0.03, 0, -0.03, -0.05, -0.03][i]
    p.lean = 0.05
    let flicker = CGFloat([0, 2, 4, 2, 0, 3, 1, 2][i])
    inBody(ctx, p) {
        for (x, y, s) in [(-22.0, -4.0, 12.0), (20.0, -2.0, 10.0), (-30.0, -38.0, 9.0)] {
            drawFlame(ctx, at: CGPoint(x: x, y: y), size: CGFloat(s) + flicker, colors: nezukoFlame)
        }
    }
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        let h = hand(p.armFront, front: true)
        drawFlame(ctx, at: CGPoint(x: h.x + 2, y: h.y + 3), size: 14 + flicker, colors: nezukoFlame)
    }
}

private func nezukoBurst(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.armFront = 2.3; p.armBack = -2.3
    p.legFront = 0.35; p.legBack = -0.35
    p.eyes = .angry; p.brows = .angry; p.blush = 1
    p.hairSwing = i % 2 == 0 ? 0.1 : -0.06
    p.bob = i % 2 == 0 ? -2 : 0
    // A ring of flame tongues behind her...
    inBody(ctx, p) {
        for k in 0..<10 {
            let a = CGFloat(k) / 10 * 2 * .pi
            let size = 18 + CGFloat((k * 7 + i * 3) % 5) * 3
            drawFlame(ctx, at: CGPoint(x: cos(a) * 34, y: -48 + sin(a) * 38), size: size, lean: cos(a) * 0.3, colors: nezukoFlame)
        }
    }
    drawCharacter(ctx, p, look)
    // ...and a few licking up in front.
    inBody(ctx, p) {
        for (k, x) in [-18.0, 4.0, 22.0].enumerated() {
            drawFlame(ctx, at: CGPoint(x: x, y: 2), size: 12 + CGFloat((k + i) % 3) * 4, colors: nezukoFlame)
        }
    }
}

// MARK: - Frieren: the flower-field spell and the Mimic

private func frierenCast(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.armFront = 2.25; p.armBack = 0.35
    p.eyes = .closed; p.mouth = .flat; p.blush = 0.3
    p.hairSwing = [0, 0.02, 0.04, 0.02, 0, -0.02, -0.04, -0.02][i]
    p.bob = [0, -0.5, -1, -0.5, 0, -0.5, -1, -0.5][i]
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        let h = hand(p.armFront, front: true)
        drawStaff(ctx, grip: h, glow: 0.5 + 0.5 * sin(CGFloat(i) / 8 * 2 * .pi))
        drawHand(ctx, h, look)
        for k in 0..<3 {
            let t = CGFloat((i + k * 3) % 8) / 8
            fillStar(ctx, CGPoint(x: h.x - 4 + CGFloat(k) * 7, y: h.y - 52 - t * 16), 3.5 * (1 - t) + 1, rgb(0xFFF3A8, 1 - t * 0.8))
        }
    }
}

/// Frieren's staff: a wooden shaft topped by a golden crescent holding a red gem.
private func drawStaff(_ ctx: CGContext, grip: CGPoint, glow: CGFloat) {
    let bottom = CGPoint(x: grip.x - 2, y: grip.y + 30), top = CGPoint(x: grip.x + 3, y: grip.y - 40)
    ctx.stroke({ $0.move(to: bottom); $0.addLine(to: top) }, outline, 5.4)
    ctx.stroke({ $0.move(to: bottom); $0.addLine(to: top) }, rgb(0x9B6A43), 3)
    let gem = CGPoint(x: top.x + 0.5, y: top.y - 8)
    ctx.fillEllipse(gem, 9 + glow * 5, 9 + glow * 5, rgb(0xFF8A8A, 0.2 + 0.25 * glow))
    for (color, width) in [(outline, CGFloat(4.8)), (rgb(0xE3B341), CGFloat(2.6))] {
        ctx.stroke({ $0.addArc(center: gem, radius: 7.5, startAngle: -.pi * 0.1, endAngle: .pi * 1.1, clockwise: false) }, color, width)
    }
    ctx.fill({ $0.addEllipse(in: CGRect(x: gem.x - 4.5, y: gem.y - 4.5, width: 9, height: 9)) }, rgb(0xD83A3A), outlineWidth: 1.3)
    ctx.fillEllipse(CGPoint(x: gem.x - 1.5, y: gem.y - 1.5), 1.5, 1.5, rgb(0xFFFFFF, 0.9))
}

/// Wooden chest with gold bands standing on the origin; `open` leaves the lid off (the Mimic's mouth is drawn separately).
func drawChest(_ ctx: CGContext, open: Bool = false) {
    ctx.fillEllipse(.zero, 31, 4.5, rgb(0x000000, 0.18))
    let gold = rgb(0xE3B341)
    let box = CGRect(x: -26, y: -28, width: 52, height: 28)
    ctx.fillGradient({ $0.addRoundedRect(in: box, cornerWidth: 3, cornerHeight: 3) }, [rgb(0xB8743E), rgb(0x8A5228)],
                     from: box.minY, to: box.maxY)
    for y: CGFloat in [-19, -10] {
        ctx.stroke({ $0.move(to: CGPoint(x: -25, y: y)); $0.addLine(to: CGPoint(x: 25, y: y)) }, rgb(0x6E3F1D, 0.7), 1)
    }
    for x: CGFloat in [-18, 14] {
        ctx.fill({ $0.addRect(CGRect(x: x, y: -28, width: 4, height: 28)) }, gold, outlineWidth: 1)
    }
    if open { return }
    ctx.fillGradient({ p in
        p.move(to: CGPoint(x: -26, y: -27)); p.addLine(to: CGPoint(x: -26, y: -33))
        p.addQuadCurve(to: CGPoint(x: 26, y: -33), control: CGPoint(x: 0, y: -50))
        p.addLine(to: CGPoint(x: 26, y: -27)); p.closeSubpath()
    }, [rgb(0xC98450), rgb(0x9A5A2C)], from: -45, to: -27)
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: -4.5, y: -33, width: 9, height: 10), cornerWidth: 2, cornerHeight: 2) }, gold, outlineWidth: 1)
    ctx.fillEllipse(CGPoint(x: 0, y: -29.5), 1.4, 2.2, rgb(0x3A2A20))
}

private func frierenMimic(_ ctx: CGContext, _ look: Look, _ i: Int) {
    let shake: [CGFloat] = [-1.5, 1.5, -1, 1.5, -1.5, 1, -1, 1.5]
    ctx.saveGState()
    ctx.translateBy(x: feet.x + shake[i], y: feet.y)
    // Only her legs stick out, kicking.
    let kick = sin(CGFloat(i) / 4 * 2 * .pi) * 0.4
    drawMimicMouth(ctx)
    for (x, angle, dark) in [(-4.0, CGFloat.pi + 0.25 + kick, true), (4.0, CGFloat.pi - 0.25 - kick, false)] {
        limb(ctx, from: CGPoint(x: x, y: -44), angle: angle, length: 23, width: 6, color: dark ? look.skinShade : look.skin) { foot in
            ctx.fillEllipse(CGPoint(x: foot.x, y: foot.y + 3), 3.6, 3, look.sock)
            ctx.saveGState()
            ctx.translateBy(x: foot.x, y: foot.y)
            ctx.rotate(by: .pi - angle * 0.5)
            ctx.fill({ $0.addEllipse(in: CGRect(x: -4, y: -2, width: 10, height: 6)) }, look.shoe, outlineWidth: 1.2)
            ctx.restoreGState()
        }
    }
    // The robe, upside down: waist in the chest, hem flaring up around her legs.
    ctx.fill({ p in
        p.move(to: CGPoint(x: -10, y: -27)); p.addLine(to: CGPoint(x: -16, y: -47))
        p.addQuadCurve(to: CGPoint(x: 16, y: -47), control: CGPoint(x: 0, y: -51))
        p.addLine(to: CGPoint(x: 10, y: -27)); p.closeSubpath()
    }, look.sleeve)
    ctx.stroke({ p in
        p.move(to: CGPoint(x: -15, y: -43)); p.addQuadCurve(to: CGPoint(x: 15, y: -43), control: CGPoint(x: 0, y: -47))
    }, rgb(0xE3B341), 1.8)
    drawChest(ctx, open: true)
    // Teeth on the box's rim, biting down on her.
    for k in 0..<8 {
        let x = -21 + CGFloat(k) * 6
        ctx.fill({ p in
            p.move(to: CGPoint(x: x - 3, y: -27)); p.addLine(to: CGPoint(x: x + 3, y: -27)); p.addLine(to: CGPoint(x: x, y: -33))
            p.closeSubpath()
        }, white, outlineWidth: 1)
    }
    if i % 2 == 0 {   // flailing lines
        for side: CGFloat in [-1, 1] {
            ctx.stroke({ p in
                p.move(to: CGPoint(x: side * 20, y: -66)); p.addLine(to: CGPoint(x: side * 26, y: -71))
                p.move(to: CGPoint(x: side * 21, y: -57)); p.addLine(to: CGPoint(x: side * 28, y: -59))
            }, outline, 1.6)
        }
    }
    ctx.restoreGState()
}

/// The Mimic's open mouth behind her legs: the lid swung up, its dark inside and the upper teeth along its rim.
private func drawMimicMouth(_ ctx: CGContext) {
    ctx.fill({ p in
        p.move(to: CGPoint(x: -27, y: -29))
        p.addQuadCurve(to: CGPoint(x: 27, y: -29), control: CGPoint(x: 0, y: -70))
        p.addQuadCurve(to: CGPoint(x: -27, y: -29), control: CGPoint(x: 0, y: -52))
    }, rgb(0x9A5A2C))
    ctx.fill({ p in
        p.move(to: CGPoint(x: -24, y: -30))
        p.addQuadCurve(to: CGPoint(x: 24, y: -30), control: CGPoint(x: 0, y: -52))
        p.closeSubpath()
    }, rgb(0x3A1A22), outlineWidth: 1.2)
    for k in 0..<7 {
        // Points on the rim curve, pointing down into the mouth.
        let t = (CGFloat(k) + 0.5) / 7
        let x = -24 + 48 * t, y = -30 - 44 * t * (1 - t)
        ctx.fill({ p in
            p.move(to: CGPoint(x: x - 3, y: y)); p.addLine(to: CGPoint(x: x + 3, y: y)); p.addLine(to: CGPoint(x: x, y: y + 6))
            p.closeSubpath()
        }, white, outlineWidth: 1)
    }
}

// MARK: - Bocchi: guitar solo and melting

private func bocchiGuitar(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.armFront = [0.5, 0.25, 0.5, 0.25, 0.55, 0.2, 0.5, 0.3][i]; p.armBack = -2.1
    p.legFront = 0.15; p.legBack = -0.15
    p.eyes = .half; p.mouth = .flat; p.blush = 0.4
    p.tilt = [0, 0.05, 0.09, 0.05, 0, 0.05, 0.09, 0.05][i]
    p.hairSwing = [0, 0.04, 0.07, 0.04, 0, 0.04, 0.07, 0.04][i]
    p.bob = [0, -1, -1.5, -1, 0, -1, -1.5, -1][i]
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        drawGuitar(ctx)
        drawHand(ctx, hand(p.armBack, front: false), look, dark: true)   // fretting hand over the neck
        drawArm(ctx, p.armFront, look, front: true)                     // strumming arm over the body
    }
}

/// Bocchi's black Les Paul, slung across the body with the neck pointing up behind her.
private func drawGuitar(_ ctx: CGContext) {
    ctx.saveGState()
    ctx.translateBy(x: 6, y: -29)
    ctx.rotate(by: 0.6)
    ctx.fill({ $0.addRect(CGRect(x: -40, y: -2, width: 32, height: 4)) }, rgb(0x5A3A24), outlineWidth: 1.2)
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: -49, y: -3.5, width: 10, height: 7), cornerWidth: 2, cornerHeight: 2) },
             rgb(0x1E1E24), outlineWidth: 1.2)
    for x: CGFloat in [-47, -42.5] {
        ctx.fillEllipse(CGPoint(x: x, y: -4.6), 1.3, 1.3, rgb(0xE3B341))
        ctx.fillEllipse(CGPoint(x: x, y: 4.6), 1.3, 1.3, rgb(0xE3B341))
    }
    // Body: upper and lower bouts with cream binding.
    let body = CGMutablePath()
    body.addEllipse(in: CGRect(x: -10, y: -8, width: 15, height: 16))
    body.addEllipse(in: CGRect(x: -2, y: -10.5, width: 20, height: 21))
    ctx.addPath(body); ctx.setStrokeColor(outline); ctx.setLineWidth(5.2); ctx.strokePath()
    ctx.addPath(body); ctx.setStrokeColor(rgb(0xF2E8D0)); ctx.setLineWidth(3); ctx.strokePath()
    ctx.addPath(body); ctx.setFillColor(rgb(0x1E1E24)); ctx.fillPath()
    for x: CGFloat in [0.5, 7] {
        ctx.fill({ $0.addRoundedRect(in: CGRect(x: x, y: -4, width: 4, height: 8), cornerWidth: 1, cornerHeight: 1) },
                 rgb(0xF2E8D0), outlineWidth: 0.8)
    }
    ctx.fill({ $0.addRect(CGRect(x: 12.5, y: -3, width: 2, height: 6)) }, rgb(0xE3B341), outlineWidth: 0)
    for y: CGFloat in [-1.2, 0, 1.2] {
        ctx.stroke({ $0.move(to: CGPoint(x: -40, y: y)); $0.addLine(to: CGPoint(x: 13.5, y: y)) }, rgb(0xDADDE4, 0.8), 0.4)
    }
    for (x, y) in [(13.0, 6.5), (9.0, 7.5)] { ctx.fillEllipse(CGPoint(x: x, y: y), 1.4, 1.4, rgb(0xE3B341)) }
    ctx.restoreGState()
}

private func bocchiMelt(_ ctx: CGContext, _ look: Look, _ i: Int) {
    if i >= 5 { return drawPuddle(ctx, look, i) }
    var p = Pose()
    p.eyes = .wide; p.mouth = .wavy; p.brows = .sad; p.sweat = true; p.blush = 0.2
    p.armFront = 0.9; p.armBack = 1.1
    let sy: CGFloat = [1, 0.86, 0.68, 0.5, 0.34][i], sx = 1 + (1 - sy) * 0.55
    if i > 0 {
        let rx = 16 + (1 - sy) * 30
        ctx.saveGState()
        ctx.translateBy(x: feet.x, y: feet.y)
        ctx.fill({ $0.addEllipse(in: CGRect(x: -rx, y: -5, width: rx * 2, height: 9)) }, look.hair, outlineWidth: 1.4)
        ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.translateBy(x: feet.x + (i == 0 ? 1.5 : 0), y: feet.y)
    ctx.scaleBy(x: sx, y: sy)
    ctx.translateBy(x: -feet.x, y: -feet.y)
    drawCharacter(ctx, p, look)
    ctx.restoreGState()
}

/// Bocchi melted into a pink puddle that still has her face and hair clips.
private func drawPuddle(_ ctx: CGContext, _ look: Look, _ i: Int) {
    let wobble: CGFloat = [0, 1.5, -1][i - 5]
    ctx.saveGState()
    ctx.translateBy(x: feet.x, y: feet.y)
    ctx.fillGradient({ p in
        p.move(to: CGPoint(x: -44, y: 0))
        p.addCurve(to: CGPoint(x: 0, y: -30 - wobble), control1: CGPoint(x: -40, y: -12), control2: CGPoint(x: -22, y: -30 - wobble))
        p.addCurve(to: CGPoint(x: 44, y: 0), control1: CGPoint(x: 22, y: -30 - wobble), control2: CGPoint(x: 40, y: -12))
        p.addQuadCurve(to: CGPoint(x: -44, y: 0), control: CGPoint(x: 0, y: 6))
    }, [look.hairLight, look.hair, look.hairDark], from: -30, to: 4)
    for (x, y, r) in [(-50.0, -2.0, 3.5), (49.0, -1.0, 2.5), (-36.0, 4.0, 2.0)] {
        ctx.fill({ $0.addEllipse(in: CGRect(x: CGFloat(x) - CGFloat(r), y: CGFloat(y) - CGFloat(r), width: CGFloat(r) * 2, height: CGFloat(r) * 2)) },
                 look.hair, outlineWidth: 1)
    }
    for x: CGFloat in [-7, 7] {
        ctx.fill({ $0.addEllipse(in: CGRect(x: x - 3.5, y: -21 - wobble, width: 7, height: 9)) }, white, outlineWidth: 1.2)
        ctx.fillEllipse(CGPoint(x: x, y: -16.5 - wobble), 1.4, 1.8, look.irisDark)
    }
    drawMouth(ctx, CGPoint(x: 0, y: -9 - wobble), .wavy)
    for (pos, color) in [(CGPoint(x: -18, y: -22), rgb(0xFFD84D)), (CGPoint(x: -11, y: -27), rgb(0x5BA8F5))] {
        ctx.saveGState()
        ctx.translateBy(x: pos.x, y: pos.y - wobble)
        ctx.rotate(by: 0.3)
        ctx.fill({ $0.addRect(CGRect(x: -3.5, y: -3.5, width: 7, height: 7)) }, color, outlineWidth: 1.2)
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

// MARK: - Rem: morning star and oni form

private func remMorningStar(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.armFront = [-0.6, -1.5, -2.5, 3.0, 2.2, 1.25, 0.95, 0.7][i]
    p.armBack = [0.4, 0.5, 0.6, 0.3, -0.2, -0.5, -0.3, 0][i]
    p.lean = [-0.04, -0.07, -0.08, -0.03, 0.05, 0.06, 0.04, 0.02][i]
    p.legFront = [0, 0.1, 0.2, 0.3, 0.4, 0.45, 0.3, 0.1][i]; p.legBack = -p.legFront * 0.6
    p.eyes = i < 4 ? .angry : .open(look: 2); p.brows = i < 4 ? .angry : .none
    p.mouth = i == 5 ? .open : .flat
    p.hairSwing = [0.04, 0.06, 0.04, 0, -0.06, -0.1, -0.06, -0.02][i]
    let h = hand(p.armFront, front: true)
    // The ball trails the swing, then lies where it smashed into the ground.
    let trail = p.armFront + 0.7
    let ball = i >= 5 ? CGPoint(x: 44, y: -8) : CGPoint(x: h.x + sin(trail) * 30, y: h.y + cos(trail) * 30)
    let behind = ball.x < 0
    if behind { inBody(ctx, p) { drawFlail(ctx, from: h, to: ball, impact: false) } }
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        if !behind { drawFlail(ctx, from: h, to: ball, impact: i == 5) }
        drawHand(ctx, h, look)
    }
}

/// Rem's morning star: a handle, a chain and a spiked iron ball.
private func drawFlail(_ ctx: CGContext, from grip: CGPoint, to ball: CGPoint, impact: Bool) {
    let dx = ball.x - grip.x, dy = ball.y - grip.y
    let len = max(hypot(dx, dy), 0.001)
    let dir = CGPoint(x: dx / len, y: dy / len)
    ctx.stroke({ $0.move(to: CGPoint(x: grip.x - dir.x * 4, y: grip.y - dir.y * 4)); $0.addLine(to: CGPoint(x: grip.x + dir.x * 7, y: grip.y + dir.y * 7)) },
               outline, 5.4)
    ctx.stroke({ $0.move(to: CGPoint(x: grip.x - dir.x * 4, y: grip.y - dir.y * 4)); $0.addLine(to: CGPoint(x: grip.x + dir.x * 7, y: grip.y + dir.y * 7)) },
               rgb(0x5A4636), 3.2)
    for k in 1..<6 {
        let t = CGFloat(k) / 6
        let c = CGPoint(x: grip.x + dx * t, y: grip.y + dy * t + sin(t * .pi) * 3)
        ctx.fill({ $0.addEllipse(in: CGRect(x: c.x - 2.2, y: c.y - 1.6, width: 4.4, height: 3.2)) }, rgb(0x9AA3B5), outlineWidth: 0.9)
    }
    for k in 0..<8 {
        let a = CGFloat(k) / 8 * 2 * .pi
        let d = CGPoint(x: cos(a), y: sin(a)), n = CGPoint(x: -sin(a), y: cos(a))
        ctx.fill({ p in
            p.move(to: CGPoint(x: ball.x + d.x * 6 + n.x * 2.8, y: ball.y + d.y * 6 + n.y * 2.8))
            p.addLine(to: CGPoint(x: ball.x + d.x * 13, y: ball.y + d.y * 13))
            p.addLine(to: CGPoint(x: ball.x + d.x * 6 - n.x * 2.8, y: ball.y + d.y * 6 - n.y * 2.8))
            p.closeSubpath()
        }, rgb(0xB8C0CE), outlineWidth: 1.1)
    }
    ctx.fillGradient({ $0.addEllipse(in: CGRect(x: ball.x - 8.5, y: ball.y - 8.5, width: 17, height: 17)) },
                     [rgb(0xC9D1DE), rgb(0x6B7385)], from: ball.y - 8.5, to: ball.y + 8.5, outlineWidth: 1.4)
    ctx.fillEllipse(CGPoint(x: ball.x - 3, y: ball.y - 3), 2.2, 1.6, rgb(0xFFFFFF, 0.8))
    if impact {
        for (x, y, x2, y2) in [(-14.0, 4.0, -22.0, 0.0), (14.0, 4.0, 22.0, 0.0), (-10.0, -6.0, -17.0, -12.0), (10.0, -6.0, 17.0, -12.0)] {
            ctx.stroke({ $0.move(to: CGPoint(x: ball.x + CGFloat(x), y: ball.y + CGFloat(y))); $0.addLine(to: CGPoint(x: ball.x + CGFloat(x2), y: ball.y + CGFloat(y2))) },
                       outline, 1.8)
        }
    }
}

private func remOni(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.eyes = .angry; p.brows = .angry; p.mouth = .flat; p.blush = 0.2
    p.armFront = -0.25; p.armBack = 0.25
    p.bob = [0, -1, -2, -3, -3, -2, -1, 0][i]
    p.hairSwing = [0, 0.03, 0.06, 0.08, 0.06, 0.03, 0, -0.03][i]
    let glow = 0.5 + 0.5 * sin(CGFloat(i) / 8 * 2 * .pi)
    // Wisps of power rising around her.
    inBody(ctx, p) {
        for k in 0..<6 {
            let side: CGFloat = k % 2 == 0 ? -1 : 1
            let t = CGFloat((i + k * 3) % 8) / 8
            let x = side * (26 + CGFloat(k / 2) * 6), y = -10 - CGFloat(k / 2) * 22 - t * 18
            ctx.stroke({ path in
                path.move(to: CGPoint(x: x, y: y)); path.addQuadCurve(to: CGPoint(x: x - side * 4, y: y - 14), control: CGPoint(x: x + side * 5, y: y - 7))
            }, rgb(0xBFE0FF, 0.9 * (1 - t)), 2.4)
        }
    }
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        let base = CGPoint(x: 5, y: -96)
        ctx.fillEllipse(CGPoint(x: base.x + 2, y: base.y - 9), 10 + glow * 4, 12 + glow * 4, rgb(0xDDEEFF, 0.25 + 0.3 * glow))
        ctx.fill({ p in
            p.move(to: CGPoint(x: base.x - 4.5, y: base.y))
            p.addQuadCurve(to: CGPoint(x: base.x + 3, y: base.y - 19), control: CGPoint(x: base.x - 2, y: base.y - 12))
            p.addQuadCurve(to: CGPoint(x: base.x + 4.5, y: base.y), control: CGPoint(x: base.x + 4.5, y: base.y - 10))
            p.closeSubpath()
        }, white, outlineWidth: 1.4)
        ctx.stroke({ $0.move(to: CGPoint(x: base.x - 2, y: base.y - 5)); $0.addLine(to: CGPoint(x: base.x + 2.5, y: base.y - 6)) }, rgb(0xC3C7D6), 1)
    }
}

// MARK: - Trump: the wall and tariffs

/// A thumbs-up on the hand at `h`.
private func drawThumb(_ ctx: CGContext, _ h: CGPoint, _ look: Look) {
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: h.x - 1.6, y: h.y - 8.5, width: 3.6, height: 7), cornerWidth: 1.8, cornerHeight: 1.8) },
             look.skin, outlineWidth: 1.1)
}

/// The wall itself rises in the window (Effect.wall); here he sells it with the "huge" gesture and two thumbs up.
private func trumpWall(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.armFront = [0.3, 1.5, 2.3, 2.5, 2.45, 2.5, 2.45, 2.5][i]
    p.armBack = [0.2, 1.3, 2.1, 2.3, 2.25, 2.3, 2.25, 2.3][i]
    p.lean = [0, -0.04, -0.06, -0.05, -0.05, -0.05, -0.05, -0.05][i]
    p.bob = [0, -1, -2, -1, -2, -1, -2, -1][i]
    p.eyes = i < 2 ? .angry : .happy
    p.brows = i < 2 ? .angry : .raised
    p.mouth = i < 2 ? .open : .grin
    drawCharacter(ctx, p, look)
    if i >= 3 {
        inBody(ctx, p) {
            drawThumb(ctx, hand(p.armFront, front: true), look)
            drawThumb(ctx, hand(p.armBack, front: false), look)
        }
    }
}

/// The famous tariff board, `lift` points below its held position.
private func drawTariffBoard(_ ctx: CGContext, lift: CGFloat) {
    let r = CGRect(x: 28, y: -92 + lift, width: 35, height: 44)
    ctx.fill({ $0.addRoundedRect(in: r, cornerWidth: 2, cornerHeight: 2) }, white, outlineWidth: 1.6)
    ctx.saveGState()
    ctx.addRect(r); ctx.clip()
    ctx.setFillColor(rgb(0x1F3366)); ctx.fill(CGRect(x: r.minX, y: r.minY, width: r.width, height: 11))
    drawText(ctx, "TARIFF", size: 7, at: CGPoint(x: r.minX + 4, y: r.minY + 8), color: white)
    for (k, w) in [CGFloat(24), 17, 27, 12].enumerated() {
        let y = r.minY + 14 + CGFloat(k) * 4.5
        ctx.setFillColor(rgb(0xD8343A)); ctx.fill(CGRect(x: r.minX + 4, y: y, width: w, height: 2.6))
    }
    drawText(ctx, "100%", size: 10, at: CGPoint(x: r.minX + 3, y: r.maxY - 3), color: rgb(0xD8343A))
    ctx.restoreGState()
}

private func trumpTariff(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    let lift: CGFloat = [44, 24, 6, 0, -1, 0, -1, 0][i]
    p.armFront = [0.4, 1.5, 2.0, 2.1, 2.15, 2.1, 2.15, 2.1][i]
    p.armBack = [0.2, 0.6, 1.1, 1.4, 1.5, 1.4, 1.5, 1.4][i]
    p.lean = [0, 0.02, -0.03, -0.05, -0.05, -0.05, -0.05, -0.05][i]
    p.eyes = i < 3 ? .angry : .half
    p.brows = .angry
    p.mouth = i < 3 ? .flat : (i % 2 == 0 ? .open : .smirk)
    p.tilt = -0.05
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        drawTariffBoard(ctx, lift: lift)
        drawArm(ctx, p.armFront, look, front: true)
        // "Look at this!" lines around the board.
        if i >= 3 {
            for k in 0..<3 {
                let a = -0.9 + CGFloat(k) * 0.45
                let c = CGPoint(x: 46, y: -70)
                let r1: CGFloat = 27 + CGFloat(i % 2) * 2
                ctx.stroke({ path in
                    path.move(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
                    path.addLine(to: CGPoint(x: c.x + cos(a) * (r1 + 6), y: c.y + sin(a) * (r1 + 6)))
                }, rgb(0xFFD84D), 2.2)
            }
        }
    }
}

// MARK: - Putin: the judo throw and the bear

private func putinJudo(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.legFront = [0, 0.3, 0.5, 0.4, 0.2, 0.1, 0, 0][i]
    p.legBack = [-0.2, -0.4, -0.6, -0.4, -0.2, 0, 0, 0][i]
    p.armFront = [0.4, 1.4, 2.0, 2.6, 3.0, 2.2, 1.0, 0.3][i]
    p.armBack = [0.2, 1.0, 1.6, 2.2, 2.6, 1.8, 0.8, 0.2][i]
    p.lean = [0, 0.08, 0.14, 0.1, -0.06, -0.1, -0.04, 0][i]
    p.bob = [0, 1, 2, 1, -1, 0, 0, 0][i]
    p.eyes = .angry
    p.brows = .angry
    p.mouth = .flat
    // He changes into a white judo gi with a black belt for the throw.
    var gi = look
    gi.outfit = .judogi
    gi.sleeve = rgb(0xF6F6F8)
    gi.sleeveDark = rgb(0xD5D7DE)
    drawCharacter(ctx, p, gi)
    if (5...7).contains(i) {
        inBody(ctx, p) {
            // Dust where the throw lands.
            for k in 0..<3 {
                let spread = CGFloat(i - 4) * 4
                ctx.fillEllipse(CGPoint(x: 32 + CGFloat(k - 1) * (8 + spread), y: -3 - CGFloat(k % 2) * 3),
                                5 - CGFloat(i - 5), 3.5 - CGFloat(i - 5) * 0.6, rgb(0xD9D2C3, 0.85))
            }
        }
    }
    if (1...5).contains(i) {
        inBody(ctx, p) {
            // The arc of the throw.
            ctx.stroke({ path in
                path.addArc(center: CGPoint(x: 6, y: -50), radius: 34, startAngle: .pi * 0.1, endAngle: .pi * 0.9,
                            clockwise: false)
            }, rgb(0xFFFFFF, 0.8), 2.2)
        }
    }
}

/// The bear Putin rides, drawn under him in the same body space.
private func drawBear(_ ctx: CGContext, frame i: Int) {
    let brown = rgb(0x6B4A32), dark = rgb(0x4E3524), snout = rgb(0xC9A582)
    let gallop = CGFloat(i) / 8 * 2 * .pi
    // Galloping legs.
    for (x, phase) in [(-15.0, CGFloat(0)), (15.0, CGFloat.pi)] {
        let lift = sin(gallop + phase) * 3
        ctx.fill({ $0.addRoundedRect(in: CGRect(x: CGFloat(x) - 5, y: -13 + lift, width: 10, height: 13),
                                     cornerWidth: 4, cornerHeight: 4) }, dark, outlineWidth: 1.2)
    }
    // Body.
    ctx.fillGradient({ $0.addEllipse(in: CGRect(x: -27, y: -32, width: 54, height: 30)) }, [brown, dark],
                     from: -32, to: -2, outlineWidth: 1.4)
    // Head, facing the way the character faces.
    let head = CGPoint(x: 24, y: -38)
    for side: CGFloat in [-1, 1] {
        ctx.fill({ $0.addEllipse(in: CGRect(x: head.x + side * 7 - 4, y: head.y - 12, width: 8, height: 8)) },
                 dark, outlineWidth: 1)
    }
    ctx.fill({ $0.addEllipse(in: CGRect(x: head.x - 10, y: head.y - 9, width: 21, height: 19)) }, brown, outlineWidth: 1.4)
    ctx.fill({ $0.addEllipse(in: CGRect(x: head.x + 2, y: head.y, width: 10, height: 7)) }, snout, outlineWidth: 1)
    ctx.fillEllipse(CGPoint(x: head.x + 7, y: head.y + 2), 1.3, 1.3, rgb(0x2A1A12))
    ctx.fillEllipse(CGPoint(x: head.x + 1, y: head.y - 3), 1.4, 1.4, rgb(0x2A1A12))
}

private func putinBear(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.armFront = 0.9
    p.armBack = 1.05
    p.legFront = 0.45
    p.legBack = 0.45
    p.bob = [0, -2, -4, -2, 0, -2, -4, -2][i]
    p.lean = -0.08
    p.eyes = .happy
    p.mouth = .grin
    p.blush = 0.4
    inBody(ctx, p) { drawBear(ctx, frame: i) }
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        for k in 0..<3 {
            let y = -18 - CGFloat(k) * 13
            let length = 12 + CGFloat((i + k) % 3) * 7
            ctx.stroke({ path in
                path.move(to: CGPoint(x: -30, y: y)); path.addLine(to: CGPoint(x: -30 - length, y: y))
            }, rgb(0xFFFFFF, 0.85), 2)
        }
    }
}

// MARK: - Xi: the parade and the Skynet robot

/// The convoy drives past in the window (Effect.tank / .truck); here he reviews it, waving.
private func xiParade(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    p.armFront = i == 0 ? 0.3 : (i % 2 == 0 ? 2.7 : 3.05)
    p.armBack = 0.1
    p.eyes = .half
    p.mouth = i == 0 ? .flat : .smile
    p.blush = 0.3
    p.tilt = i == 0 ? 0 : (i % 2 == 0 ? 0.03 : 0.05)
    drawCharacter(ctx, p, look)
}

/// A Skynet-style endoskeleton: chrome skull, glowing red eyes, ribbed neck and piston limbs.
/// `built` (0...1) is how much of it has been printed so far, from the feet up; `glow` lights the eyes.
private func drawTerminator(_ ctx: CGContext, at p: CGPoint, built: CGFloat, glow: CGFloat) {
    guard built > 0 else { return }
    let chrome = rgb(0xC9CFD8), steel = rgb(0x8A929E), dark = rgb(0x3A3F48), red = rgb(0xFF2E2E)
    let height: CGFloat = 70
    ctx.saveGState()
    ctx.translateBy(x: p.x, y: p.y)
    ctx.saveGState()
    ctx.clip(to: CGRect(x: -40, y: -height * built - 1, width: 80, height: height * built + 6))

    // Legs: thigh and shin struts with a knee joint, flat steel feet.
    for x: CGFloat in [-6, 6] {
        let knee = CGPoint(x: x * 1.1, y: -12)
        for (from, to) in [(CGPoint(x: x * 0.8, y: -25), knee), (knee, CGPoint(x: x, y: -2))] {
            ctx.stroke({ $0.move(to: from); $0.addLine(to: to) }, outline, 5.6)
            ctx.stroke({ $0.move(to: from); $0.addLine(to: to) }, chrome, 3.4)
        }
        ctx.fill({ $0.addEllipse(in: CGRect(x: knee.x - 2.6, y: knee.y - 2.6, width: 5.2, height: 5.2)) }, steel, outlineWidth: 1)
        ctx.fill({ $0.addRoundedRect(in: CGRect(x: x - 4, y: -3, width: 9, height: 4), cornerWidth: 1.5, cornerHeight: 1.5) },
                 dark, outlineWidth: 1.1)
    }
    // Pelvis.
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: -9, y: -29, width: 18, height: 6), cornerWidth: 2, cornerHeight: 2) }, steel, outlineWidth: 1.2)
    // Spine and ribcage.
    ctx.fill({ $0.addRect(CGRect(x: -2, y: -34, width: 4, height: 6)) }, dark, outlineWidth: 1)
    ctx.fillGradient({ p in
        p.move(to: CGPoint(x: -12, y: -50)); p.addLine(to: CGPoint(x: 12, y: -50))
        p.addQuadCurve(to: CGPoint(x: 7, y: -34), control: CGPoint(x: 13, y: -38))
        p.addLine(to: CGPoint(x: -7, y: -34))
        p.addQuadCurve(to: CGPoint(x: -12, y: -50), control: CGPoint(x: -13, y: -38))
    }, [chrome, steel], from: -50, to: -34, outlineWidth: 1.3)
    for y: CGFloat in [-46, -42, -38] {
        ctx.stroke({ $0.move(to: CGPoint(x: -9, y: y)); $0.addLine(to: CGPoint(x: 9, y: y)) }, dark, 1.1)
    }
    ctx.stroke({ $0.move(to: CGPoint(x: 0, y: -49)); $0.addLine(to: CGPoint(x: 0, y: -35)) }, dark, 1.6)
    // Glowing power core.
    ctx.fillEllipse(CGPoint(x: 0, y: -44), 3 + glow * 2, 3 + glow * 2, rgb(0xFF2E2E, 0.25 + 0.3 * glow))
    ctx.fill({ $0.addEllipse(in: CGRect(x: -2, y: -46, width: 4, height: 4)) }, red, outlineWidth: 0.9)
    // Piston arms hanging forward, claw hands.
    for side: CGFloat in [-1, 1] {
        let shoulder = CGPoint(x: side * 13, y: -48), elbow = CGPoint(x: side * 15, y: -37), hand = CGPoint(x: side * 14 + 3, y: -27)
        for (from, to) in [(shoulder, elbow), (elbow, hand)] {
            ctx.stroke({ $0.move(to: from); $0.addLine(to: to) }, outline, 4.6)
            ctx.stroke({ $0.move(to: from); $0.addLine(to: to) }, chrome, 2.6)
        }
        ctx.fill({ $0.addEllipse(in: CGRect(x: shoulder.x - 3.5, y: shoulder.y - 3.5, width: 7, height: 7)) }, steel, outlineWidth: 1.1)
        ctx.fill({ $0.addEllipse(in: CGRect(x: elbow.x - 2.2, y: elbow.y - 2.2, width: 4.4, height: 4.4)) }, steel, outlineWidth: 0.9)
        for dx: CGFloat in [-2, 0.5, 3] {
            ctx.stroke({ $0.move(to: hand); $0.addLine(to: CGPoint(x: hand.x + dx, y: hand.y + 4)) }, dark, 1.3)
        }
    }
    // Ribbed neck.
    ctx.fill({ $0.addRect(CGRect(x: -3.5, y: -55, width: 7, height: 6)) }, steel, outlineWidth: 1)
    for y: CGFloat in [-53, -51] {
        ctx.stroke({ $0.move(to: CGPoint(x: -3.5, y: y)); $0.addLine(to: CGPoint(x: 3.5, y: y)) }, dark, 0.8)
    }
    // Skull: cranium, cheekbones, jaw of steel teeth.
    ctx.fillGradient({ p in
        p.move(to: CGPoint(x: -6, y: -54))
        p.addLine(to: CGPoint(x: -9, y: -60))
        p.addCurve(to: CGPoint(x: 0, y: -71), control1: CGPoint(x: -13, y: -66), control2: CGPoint(x: -8, y: -71))
        p.addCurve(to: CGPoint(x: 9, y: -60), control1: CGPoint(x: 8, y: -71), control2: CGPoint(x: 13, y: -66))
        p.addLine(to: CGPoint(x: 6, y: -54))
        p.closeSubpath()
    }, [rgb(0xEEF1F5), chrome, steel], from: -71, to: -54, outlineWidth: 1.4)
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: -5, y: -57.5, width: 10, height: 3.5), cornerWidth: 1, cornerHeight: 1) }, dark, outlineWidth: 0.8)
    for x: CGFloat in [-3, -1, 1, 3] {
        ctx.stroke({ $0.move(to: CGPoint(x: x, y: -57.5)); $0.addLine(to: CGPoint(x: x, y: -54)) }, chrome, 0.7)
    }
    // Eye sockets, then red eyes, shifted toward where it looks.
    for x: CGFloat in [-3.5, 4] {
        ctx.fillEllipse(CGPoint(x: x, y: -62.5), 3.2, 2.6, dark)
        if glow > 0 {
            ctx.fillEllipse(CGPoint(x: x, y: -62.5), 2 + glow * 3.5, 2 + glow * 3.5, rgb(0xFF3A2E, 0.35 * glow))
        }
        ctx.fillEllipse(CGPoint(x: x + 0.5, y: -62.5), 1.5 + glow * 0.4, 1.5 + glow * 0.4, glow > 0 ? red : rgb(0x6A1A1A))
        if glow > 0 { ctx.fillEllipse(CGPoint(x: x + 0.1, y: -63), 0.5, 0.5, white) }
    }
    ctx.stroke({ $0.addArc(center: CGPoint(x: -1, y: -64), radius: 6, startAngle: .pi * 1.15, endAngle: .pi * 1.45, clockwise: false) },
               white, 1.4)
    ctx.restoreGState()

    // The red printing line sweeping up while it is being built.
    if built < 1 {
        let y = -height * built
        ctx.stroke({ $0.move(to: CGPoint(x: -18, y: y)); $0.addLine(to: CGPoint(x: 18, y: y)) }, rgb(0xFF2E2E, 0.35), 4)
        ctx.stroke({ $0.move(to: CGPoint(x: -18, y: y)); $0.addLine(to: CGPoint(x: 18, y: y)) }, rgb(0xFF6A5A), 1.4)
    }
    ctx.restoreGState()
}

private func xiRobot(_ ctx: CGContext, _ look: Look, _ i: Int) {
    var p = Pose()
    // Raises a hand to switch it on, then points it at the target.
    p.armFront = [0.6, 2.2, 2.4, 2.3, 1.5, 1.45, 1.5, 1.45][i]
    p.armBack = 0.3
    p.eyes = .half
    p.mouth = i > 3 ? .smirk : .flat
    p.blush = 0.3
    p.lean = i > 3 ? 0.04 : 0
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        // A red holographic grid on the ground where it is printed.
        if i < 4 {
            for k in 0..<3 {
                ctx.stroke({ path in
                    path.addEllipse(in: CGRect(x: 39 - 20 + CGFloat(k) * 4, y: -3 + CGFloat(k), width: 40 - CGFloat(k) * 8, height: 7 - CGFloat(k) * 2))
                }, rgb(0xFF3A2E, 0.75 - CGFloat(k) * 0.2), 1.2)
            }
        }
        let built = [0.15, 0.4, 0.7, 1, 1, 1, 1, 1][i] as CGFloat
        let glow = [0, 0, 0, 0.6, 1, 0.8, 1, 0.85][i] as CGFloat
        drawTerminator(ctx, at: CGPoint(x: 39, y: 0), built: built, glow: glow)
    }
}

// MARK: - Kim: applause and the missile

/// The officials who must applaud along with him.
private let cadre = Look(id: "cadre",
                         hair: rgb(0x26262C), hairDark: rgb(0x131317), hairLight: rgb(0x55555F),
                         iris: rgb(0x5A3A2A), irisDark: rgb(0x2E1A10), irisLight: rgb(0xA07A60),
                         style: .putinShort, outfit: .suit, sleeve: rgb(0x5E6B3A), sleeveDark: rgb(0x434D28),
                         shoe: rgb(0x1E1E24), sock: rgb(0x434D28), restingLid: 0.2)

/// Draws `look` clapping: `open` 0 = hands together, 1 = apart.
private func drawClapper(_ ctx: CGContext, _ look: Look, _ pose: Pose, open: CGFloat) {
    var p = pose
    p.armFront = 0.95 + open * 0.07
    p.armBack = 0.95 - open * 0.05
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        for side: CGFloat in [-1, 1] {
            let c = CGPoint(x: 13 + side * (2.5 + open * 4), y: -34)
            drawHand(ctx, c, look)
            if open == 0 {
                ctx.stroke({ path in
                    path.addArc(center: CGPoint(x: 13, y: -34), radius: 8, startAngle: .pi * (side < 0 ? 1.1 : 1.6),
                                endAngle: .pi * (side < 0 ? 1.4 : 1.9), clockwise: false)
                }, rgb(0xFFFFFF, 0.95), 1.6)
            }
        }
    }
}

private func kimApplause(_ ctx: CGContext, _ look: Look, _ i: Int) {
    // A crowd of tiny officials, each clapping a little out of step, some in tears, some sweating.
    let crowd: [(x: CGFloat, y: CGFloat, scale: CGFloat, front: Bool)] =
        [(-50, -12, 0.38, false), (50, -12, 0.38, false), (-36, 2, 0.45, true), (37, 2, 0.45, true)]
    func official(_ k: Int) {
        let m = crowd[k]
        var q = Pose()
        q.eyes = k % 2 == 0 ? .teary : .happy
        q.mouth = .open
        q.sweat = k % 2 == 1
        q.bob = (i + k) % 2 == 0 ? 0 : -3
        ctx.saveGState()
        ctx.translateBy(x: feet.x + m.x, y: feet.y + m.y)
        ctx.scaleBy(x: m.scale, y: m.scale)
        ctx.translateBy(x: -feet.x, y: -feet.y)
        drawClapper(ctx, cadre, q, open: CGFloat((i + k) % 2))
        ctx.restoreGState()
    }
    for k in crowd.indices where !crowd[k].front { official(k) }
    var p = Pose()
    p.eyes = .happy
    p.mouth = .grin
    p.blush = 0.8
    p.bob = i % 2 == 0 ? 0 : -1.2
    p.tilt = 0.04
    drawClapper(ctx, look, p, open: CGFloat(i % 2))
    for k in crowd.indices where crowd[k].front { official(k) }
}

private func drawLaunchBox(_ ctx: CGContext, at h: CGPoint) {
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: h.x - 6, y: h.y - 11, width: 12, height: 8), cornerWidth: 2, cornerHeight: 2) },
             rgb(0x3A3F48), outlineWidth: 1.2)
    ctx.fill({ $0.addEllipse(in: CGRect(x: h.x - 1.5, y: h.y - 14, width: 5, height: 5)) }, rgb(0xD63A3A), outlineWidth: 1)
}

private func drawRocket(_ ctx: CGContext, at p: CGPoint, flame: Bool) {
    // Fins.
    for side: CGFloat in [-1, 1] {
        ctx.fill({ path in
            path.move(to: CGPoint(x: p.x + side * 4, y: p.y - 2))
            path.addLine(to: CGPoint(x: p.x + side * 9, y: p.y + 6))
            path.addLine(to: CGPoint(x: p.x + side * 4, y: p.y + 7))
            path.closeSubpath()
        }, rgb(0xC23A3A), outlineWidth: 1)
    }
    // Exhaust.
    if flame {
        ctx.fill({ path in
            path.move(to: CGPoint(x: p.x - 3.5, y: p.y + 7))
            path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + 17), control: CGPoint(x: p.x - 4, y: p.y + 14))
            path.addQuadCurve(to: CGPoint(x: p.x + 3.5, y: p.y + 7), control: CGPoint(x: p.x + 4, y: p.y + 14))
            path.closeSubpath()
        }, rgb(0xFFB43A), outlineWidth: 1)
    }
    // Body and nose cone.
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: p.x - 5, y: p.y - 12, width: 10, height: 20), cornerWidth: 4, cornerHeight: 4) },
             rgb(0xEDEDF2), outlineWidth: 1.3)
    ctx.fill({ path in
        path.move(to: CGPoint(x: p.x - 5, y: p.y - 11))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - 22), control: CGPoint(x: p.x - 4, y: p.y - 18))
        path.addQuadCurve(to: CGPoint(x: p.x + 5, y: p.y - 11), control: CGPoint(x: p.x + 4, y: p.y - 18))
        path.closeSubpath()
    }, rgb(0xC23A3A), outlineWidth: 1.2)
    ctx.fillEllipse(CGPoint(x: p.x, y: p.y - 6), 2, 2, rgb(0x5B8DEF))
}

/// The missile on its launcher rail, `rise` points up from the pad; drawn twice the size of a carry-on rocket.
private func drawMissile(_ ctx: CGContext, rise: CGFloat, flame: Bool) {
    ctx.saveGState()
    ctx.translateBy(x: 44, y: -16 - rise)
    ctx.scaleBy(x: 1.8, y: 1.8)
    if flame {
        // A long exhaust plume pointing down.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: 5); ctx.scaleBy(x: 1, y: -1)
        drawFlame(ctx, at: .zero, size: 18, colors: [rgb(0xFFF3A8), rgb(0xFFB43A), rgb(0xFF5A1E, 0.8)])
        ctx.restoreGState()
    }
    drawRocket(ctx, at: .zero, flame: flame)
    ctx.restoreGState()
}

private func kimMissile(_ ctx: CGContext, _ look: Look, _ i: Int) {
    let rise: CGFloat = [0, 0, 2, 22, 52, 92, 140, 140][i]
    var p = Pose()
    p.armFront = [1.25, 1.35, 0.9, 0.7, 2.6, 2.8, 2.7, 2.8][i]
    p.armBack = [0.2, 0.2, 0.4, 0.6, 2.4, 2.6, 2.5, 2.6][i]
    p.eyes = i < 2 ? .angry : (i < 4 ? .wide : .happy)
    p.mouth = i < 2 ? .grin : .open
    p.brows = i < 2 ? .angry : .raised
    p.bob = [0, 0, 0, -1, -3, -1, -3, -1][i]
    p.tilt = i >= 2 ? -0.06 : 0
    inBody(ctx, p) {
        // Launcher: a squat olive trailer with a red-and-white rail.
        ctx.fill({ $0.addRoundedRect(in: CGRect(x: 30, y: -12, width: 30, height: 9), cornerWidth: 2, cornerHeight: 2) },
                 rgb(0x5E6B3A), outlineWidth: 1.3)
        for x: CGFloat in [35, 55] {
            ctx.fill({ $0.addEllipse(in: CGRect(x: x - 3.5, y: -6, width: 7, height: 7)) }, rgb(0x2E2E2E), outlineWidth: 1.1)
        }
        ctx.fill({ $0.addRect(CGRect(x: 51, y: -52, width: 3, height: 41)) }, rgb(0x8A929E), outlineWidth: 1)
        if rise < 120 { drawMissile(ctx, rise: rise, flame: i >= 2 && i <= 6) }
        // Smoke billowing off the pad.
        if i >= 2 {
            let puff = min(CGFloat(i - 1), 4)
            for (dx, dy, r) in [(-14.0, -4.0, 6.0), (0.0, -2.0, 8.0), (14.0, -5.0, 6.0), (-7.0, -12.0, 5.0), (8.0, -13.0, 5.0)] {
                ctx.fill({ $0.addEllipse(in: CGRect(x: 44 + CGFloat(dx) * (0.6 + puff * 0.15) - CGFloat(r) - puff,
                                                    y: CGFloat(dy) - CGFloat(r) - puff * 0.8,
                                                    width: (CGFloat(r) + puff) * 2, height: (CGFloat(r) + puff) * 1.6)) },
                         rgb(0xE9EAEF, i == 7 ? 0.6 : 0.95), outlineWidth: i == 7 ? 0 : 1)
            }
        }
        // Smoke trail left by the missile.
        if (3...6).contains(i) {
            ctx.stroke({ $0.move(to: CGPoint(x: 44, y: -18)); $0.addLine(to: CGPoint(x: 44, y: -16 - rise + 10)) },
                       rgb(0xE9EAEF, 0.8), 7)
        }
    }
    drawCharacter(ctx, p, look)
    inBody(ctx, p) {
        if i < 2 { drawLaunchBox(ctx, at: hand(p.armFront, front: true)) }
        if i == 1 { ctx.fillEllipse(CGPoint(x: hand(p.armFront, front: true).x + 0.5, y: hand(p.armFront, front: true).y - 11.5), 5, 5, rgb(0xFF5A3A, 0.5)) }
    }
}
