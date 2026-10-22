import AppKit

/// Small transparent, click-through panel that follows a pet around every screen.
final class PetWindow: NSPanel {
    static let size = CGSize(width: 240, height: 194)
    /// Where the pet's feet sit inside the window (bottom-left origin); room below is for the name tag.
    static let feet = CGPoint(x: 120, y: 22)

    init(view: NSView) {
        super.init(contentRect: CGRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Let the pet walk across screen edges without AppKit pushing the window back.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    func place(feetAt p: CGPoint) {
        let origin = CGPoint(x: (p.x - Self.feet.x).rounded(), y: (p.y - Self.feet.y).rounded())
        if origin != frame.origin { setFrameOrigin(origin) }
    }
}

/// Layer-hosting view. The sprite and emote are CALayers whose contents are swapped per frame and
/// composited by the window server; only the bubble and name tag are drawn, and only when their text changes.
final class PetView: NSView {
    weak var pet: Pet?

    /// Area of the window covered by the character body, used for hit testing.
    let bodyRect = CGRect(x: PetWindow.feet.x - 30, y: PetWindow.feet.y, width: 60, height: 112)
    private let headTop = PetWindow.feet.y + 118
    private let effectOrigin = CGPoint(x: PetWindow.feet.x + 30, y: PetWindow.feet.y + 82)

    private let spriteLayer = CALayer()
    private let effectLayer = CALayer()
    private let textLayer = CALayer()
    /// A prop standing on the ground next to the pet (Frieren's treasure chest).
    private let propLayer = CALayer()

    private var shownFrame: CGImage?
    private var shownFacing: CGFloat = 1
    private var shownScale: CGFloat = 1
    private var shownThought = false
    private var shownEffect: CGImage?
    private var shownRise: CGFloat = -1
    private var shownBubble: String?
    private var shownTag: String?

    init() {
        super.init(frame: CGRect(origin: .zero, size: PetWindow.size))
        layer = CALayer()   // set before wantsLayer: we own the layer tree and AppKit never redraws it
        wantsLayer = true
        let layout = SpriteSheet.layout
        let size = layout.frameSize
        spriteLayer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        // Pin the frame's feet to the window's feet point, which is also the axis for flipping.
        spriteLayer.anchorPoint = CGPoint(x: layout.anchor.x / size, y: (size - layout.anchor.y) / size)
        spriteLayer.position = PetWindow.feet
        propLayer.bounds = spriteLayer.bounds
        propLayer.anchorPoint = spriteLayer.anchorPoint
        effectLayer.bounds = CGRect(x: 0, y: 0, width: 52, height: 52)
        effectLayer.anchorPoint = .zero
        textLayer.frame = bounds
        for sublayer in [propLayer, spriteLayer, effectLayer, textLayer] {
            sublayer.contentsGravity = .resize
            layer!.addSublayer(sublayer)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        textLayer.contents = overlayImage()
    }

    /// Applies the pet's current look; does nothing when nothing visible changed.
    func render(frame: CGImage?, facing: CGFloat, scale: CGFloat, effect: CGImage?, effectAge: TimeInterval,
                bubble: String?, thought: Bool, tag: String?) {
        let rise = effect == nil ? 0 : (CGFloat(min(effectAge, 0.4) / 0.4) * 8).rounded()
        guard frame !== shownFrame || facing != shownFacing || scale != shownScale || effect !== shownEffect || rise != shownRise
                || bubble != shownBubble || thought != shownThought || tag != shownTag else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if frame !== shownFrame { spriteLayer.contents = frame }
        if facing != shownFacing || scale != shownScale {
            spriteLayer.setAffineTransform(CGAffineTransform(scaleX: facing * scale, y: scale))
        }
        if effect !== shownEffect { effectLayer.contents = effect }
        if rise != shownRise { effectLayer.position = CGPoint(x: effectOrigin.x, y: effectOrigin.y + rise) }
        if bubble != shownBubble || thought != shownThought || tag != shownTag {
            shownBubble = bubble
            shownThought = thought
            shownTag = tag
            textLayer.contents = overlayImage()
        }
        CATransaction.commit()
        shownFrame = frame
        shownFacing = facing
        shownScale = scale
        shownEffect = effect
        shownRise = rise
    }

    /// Bubble and name tag rendered once into a bitmap at the screen's scale.
    private func overlayImage() -> CGImage? {
        guard shownBubble != nil || shownTag != nil else { return nil }
        let scale = window?.backingScaleFactor ?? 2
        guard let ctx = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        if let tag = shownTag { drawTag(tag, feet: PetWindow.feet) }
        if let bubble = shownBubble { drawBubble(bubble, headTop: headTop, thought: shownThought) }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    /// Small name plate under the feet of agent mascots.
    private func drawTag(_ text: String, feet: CGPoint) {
        let string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail
                return style
            }(),
        ])
        let size = string.size()
        let w = min(bounds.width - 8, ceil(size.width) + 12), h = ceil(size.height) + 4
        let rect = CGRect(x: feet.x - w / 2, y: feet.y - h - 4, width: w, height: h)
        NSColor(calibratedRed: 0.17, green: 0.16, blue: 0.22, alpha: 0.82).setFill()
        NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2).fill()
        string.draw(with: rect.insetBy(dx: 6, dy: 2), options: [.usesLineFragmentOrigin])
    }

    /// Speech bubble with a pointer, or a rounder thought bubble trailing little puffs.
    private func drawBubble(_ text: String, headTop: CGFloat, thought: Bool) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.29, green: 0.18, blue: 0.23, alpha: 1),
        ]
        let string = NSAttributedString(string: text, attributes: attrs)
        let maxWidth = bounds.width - 12
        let textSize = string.boundingRect(with: CGSize(width: maxWidth - 16, height: 60),
                                           options: [.usesLineFragmentOrigin]).size
        let w = min(maxWidth, ceil(textSize.width) + 16), h = ceil(textSize.height) + 10
        let rect = CGRect(x: (bounds.width - w) / 2, y: min(headTop + 12, bounds.height - h - 2), width: w, height: h)

        let radius: CGFloat = thought ? min(rect.height / 2, 14) : 9
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let tail = NSBezierPath()
        if thought {
            tail.appendOval(in: CGRect(x: rect.midX - 9, y: rect.minY - 9, width: 7, height: 6))
            tail.appendOval(in: CGRect(x: rect.midX - 13, y: rect.minY - 15, width: 4.5, height: 4))
        } else {
            tail.move(to: CGPoint(x: rect.midX - 5, y: rect.minY + 1))
            tail.line(to: CGPoint(x: rect.midX + 1, y: rect.minY - 7))
            tail.line(to: CGPoint(x: rect.midX + 5, y: rect.minY + 1))
        }
        NSColor.white.withAlphaComponent(0.96).setFill()
        path.fill(); tail.fill()
        NSColor(calibratedRed: 0.29, green: 0.18, blue: 0.23, alpha: 0.85).setStroke()
        path.lineWidth = 1.4
        path.stroke()
        if thought {
            tail.lineWidth = 1.2
            tail.stroke()
        }
        string.draw(with: rect.insetBy(dx: 8, dy: 5), options: [.usesLineFragmentOrigin])
    }

    // MARK: Special-move effects
    // Fire-and-forget Core Animation: once added, the window server runs them with no per-frame work here.

    private var feet: CGPoint { PetWindow.feet }
    private var bodyCenter: CGPoint { CGPoint(x: feet.x, y: feet.y + 52) }
    private var headCenter: CGPoint { CGPoint(x: feet.x + 2, y: feet.y + 98) }

    /// Adds a layer for `seconds` (behind the sprite, or in front of it below the bubble).
    private func addTransient(_ sublayer: CALayer, for seconds: TimeInterval, behind: Bool = false) {
        if behind { layer!.insertSublayer(sublayer, below: spriteLayer) } else { layer!.insertSublayer(sublayer, below: textLayer) }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { sublayer.removeFromSuperlayer() }
    }

    private func withoutActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    /// An expanding, fading ring.
    private func ring(at center: CGPoint, radius: CGFloat, squash: CGFloat = 1, color: CGColor, width: CGFloat,
                      to scale: CGFloat, duration: TimeInterval, delay: TimeInterval = 0) {
        let ring = CAShapeLayer()
        ring.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius * squash, width: radius * 2, height: radius * 2 * squash), transform: nil)
        ring.fillColor = nil
        ring.strokeColor = color
        ring.lineWidth = width
        ring.position = center
        ring.opacity = 0
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.4
        grow.toValue = scale
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 0.95, 0]
        fade.keyTimes = [0, 0.2, 1]
        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = duration
        group.beginTime = CACurrentMediaTime() + delay
        ring.add(group, forKey: nil)
        addTransient(ring, for: delay + duration + 0.1)
    }

    /// A one-off burst of particles; `configure` sets up the single emitter cell.
    private func burst(at point: CGPoint, image: Effect, rate: Float, for seconds: TimeInterval, lasting lifetime: Float,
                       size: CGSize = CGSize(width: 30, height: 30), behind: Bool = false, configure: (CAEmitterCell) -> Void) {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .circle
        emitter.emitterSize = size
        let cell = CAEmitterCell()
        cell.contents = SpriteSheet.effect(image)
        cell.birthRate = rate
        cell.lifetime = lifetime
        configure(cell)
        emitter.emitterCells = [cell]
        addTransient(emitter, for: seconds + TimeInterval(lifetime) + 0.3, behind: behind)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { emitter.birthRate = 0 }
    }

    /// A puff of smoke (transformations, popping out of a chest, landing a blow).
    func puff(at point: CGPoint? = nil) {
        withoutActions {
            burst(at: point ?? bodyCenter, image: .puff, rate: 70, for: 0.12, lasting: 0.6) { cell in
                cell.velocity = 50; cell.velocityRange = 20; cell.emissionRange = .pi * 2
                cell.scale = 0.1; cell.scaleRange = 0.03; cell.scaleSpeed = 0.12
                cell.alphaSpeed = -1.6; cell.spinRange = 1.5
            }
        }
    }

    /// Anya's telepathy: rings rippling out from her head.
    func telepathy() {
        withoutActions {
            for i in 0..<4 {
                ring(at: headCenter, radius: 18, color: CGColor(srgbRed: 1, green: 0.44, blue: 0.66, alpha: 1), width: 2.5,
                     to: 2.8, duration: 1.1, delay: Double(i) * 0.4)
            }
        }
    }

    /// Nezuko's Exploding Blood: pink flames bursting out in every direction.
    func flameBurst() {
        withoutActions {
            ring(at: bodyCenter, radius: 30, color: CGColor(srgbRed: 1, green: 0.42, blue: 0.66, alpha: 1), width: 6,
                 to: 3.2, duration: 0.5)
            burst(at: bodyCenter, image: .flame, rate: 170, for: 0.35, lasting: 0.75, size: CGSize(width: 50, height: 60)) { cell in
                cell.lifetimeRange = 0.25
                cell.velocity = 115; cell.velocityRange = 40; cell.emissionRange = .pi * 2
                cell.yAcceleration = 90
                cell.scale = 0.12; cell.scaleRange = 0.05; cell.scaleSpeed = -0.08
                cell.alphaSpeed = -1.2
            }
        }
    }

    /// Frieren's spell: a field of flowers popping up around her feet, wilting after `seconds`.
    func flowerField(for seconds: TimeInterval) {
        let images = [Effect.flower1, .flower2, .flower3].compactMap(SpriteSheet.effect)
        let now = CACurrentMediaTime()
        withoutActions {
            for i in 0..<18 {
                let flower = CALayer()
                flower.contents = images[i % images.count]
                let size = CGFloat.random(in: 20...30)
                flower.bounds = CGRect(x: 0, y: 0, width: size, height: size)
                flower.anchorPoint = CGPoint(x: 0.5, y: 0.03)   // the bottom of the stem
                let a = CGFloat.random(in: 0..<(2 * .pi)), r = CGFloat.random(in: 0.3...1)
                flower.position = CGPoint(x: feet.x + cos(a) * 104 * r, y: feet.y - 2 + sin(a) * 16 * r)
                let pop = CAKeyframeAnimation(keyPath: "transform.scale")
                pop.values = [0, 1.25, 1]
                pop.keyTimes = [0, 0.7, 1]
                pop.duration = 0.45
                pop.beginTime = now + Double(i) * 0.07
                pop.fillMode = .backwards
                let wilt = CABasicAnimation(keyPath: "opacity")
                wilt.fromValue = 1
                wilt.toValue = 0
                wilt.duration = 0.6
                wilt.beginTime = now + seconds - 0.6
                wilt.fillMode = .forwards
                wilt.isRemovedOnCompletion = false
                flower.add(pop, forKey: "pop")
                flower.add(wilt, forKey: "wilt")
                // Flowers nearer the viewer than her feet grow in front of her.
                addTransient(flower, for: seconds, behind: flower.position.y > feet.y)
            }
            burst(at: CGPoint(x: feet.x, y: feet.y + 4), image: .sparkle, rate: 6, for: seconds - 1.5, lasting: 1.6,
                  size: CGSize(width: 200, height: 10)) { cell in
                cell.velocity = 20; cell.emissionLongitude = .pi / 2; cell.emissionRange = 0.6
                cell.scale = 0.07; cell.scaleRange = 0.03; cell.alphaSpeed = -0.5
            }
        }
    }

    /// Notes floating up from Bocchi's guitar.
    func notes(for seconds: TimeInterval, facing: CGFloat) {
        withoutActions {
            burst(at: CGPoint(x: feet.x + facing * 10, y: feet.y + 40), image: .note, rate: 3, for: seconds, lasting: 2.2,
                  size: CGSize(width: 10, height: 10)) { cell in
                cell.velocity = 35; cell.velocityRange = 10
                cell.emissionLongitude = .pi / 2 - facing * 0.5; cell.emissionRange = 0.6
                cell.scale = 0.16; cell.scaleRange = 0.04; cell.alphaSpeed = -0.4; cell.spinRange = 0.8
                cell.redRange = 0.5; cell.greenRange = 0.3; cell.blueRange = 0.2
            }
        }
    }

    /// Rem's oni form: a pulsing glow behind her and light rising around her.
    func aura(for seconds: TimeInterval) {
        withoutActions {
            let glow = CAGradientLayer()
            glow.type = .radial
            glow.colors = [CGColor(srgbRed: 0.75, green: 0.88, blue: 1, alpha: 0.55), CGColor(srgbRed: 0.55, green: 0.73, blue: 0.97, alpha: 0)]
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 1)
            glow.bounds = CGRect(x: 0, y: 0, width: 150, height: 190)
            glow.position = CGPoint(x: bodyCenter.x, y: bodyCenter.y + 12)
            glow.opacity = 0
            let pulse = CAKeyframeAnimation(keyPath: "opacity")
            pulse.values = [0, 1, 0.6, 1, 0.6, 1, 0]
            pulse.duration = seconds
            glow.add(pulse, forKey: nil)
            addTransient(glow, for: seconds, behind: true)
            burst(at: CGPoint(x: feet.x, y: feet.y + 10), image: .glow, rate: 22, for: seconds - 0.5, lasting: 1.3,
                  size: CGSize(width: 70, height: 20)) { cell in
                cell.velocity = 30; cell.velocityRange = 10; cell.emissionLongitude = .pi / 2; cell.emissionRange = 0.3
                cell.scale = 0.07; cell.scaleRange = 0.03; cell.alphaSpeed = -0.7
            }
        }
    }

    /// Rem's morning star hitting the ground `dx` points in front of her.
    func impact(dx: CGFloat) {
        let ground = CGPoint(x: feet.x + dx, y: feet.y + 4)
        withoutActions {
            ring(at: ground, radius: 22, squash: 0.3, color: CGColor(gray: 0.45, alpha: 1), width: 3, to: 2.2, duration: 0.45)
        }
        puff(at: ground)
    }

    /// Shows `image` standing on the ground `dx` points from the pet, or removes it.
    func showProp(_ image: CGImage?, dx: CGFloat) {
        withoutActions {
            propLayer.contents = image
            propLayer.position = CGPoint(x: feet.x + dx, y: feet.y)
        }
        guard image != nil else { return }
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0, 1.15, 1]
        pop.duration = 0.35
        propLayer.add(pop, forKey: "pop")
    }

    // MARK: Mouse

    private var grabOffset: CGPoint = .zero
    private var mouseDownAt: CGPoint = .zero
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        guard let pet else { return }
        let mouse = NSEvent.mouseLocation
        mouseDownAt = mouse
        grabOffset = CGPoint(x: mouse.x - pet.position.x, y: mouse.y - pet.position.y)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pet else { return }
        let mouse = NSEvent.mouseLocation
        if !didDrag && hypot(mouse.x - mouseDownAt.x, mouse.y - mouseDownAt.y) < 4 { return }
        if !didDrag { didDrag = true; pet.beginDrag() }
        pet.drag(to: CGPoint(x: mouse.x - grabOffset.x, y: mouse.y - grabOffset.y))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag { pet?.endDrag() } else { pet?.clicked() }
    }

    /// Right-click lists the character's special moves.
    override func rightMouseDown(with event: NSEvent) {
        guard let pet, pet.agent == nil, !pet.character.skills.isEmpty else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: pet.character.displayName(in: Language.current), action: nil, keyEquivalent: "")
        for skill in pet.character.skills {
            let item = menu.addItem(withTitle: skill.title, action: #selector(useSkill(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = skill.rawValue
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func useSkill(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let skill = Skill(rawValue: raw) else { return }
        pet?.useSkill(skill)
    }
}
