VERSION ?= 1.2.0
APP     := build/OllieBoard.app
DMG     := build/OllieBoard-$(VERSION).dmg
STAGE   := build/dmg-stage

.PHONY: help app run dmg sprites clean

help:
	@echo "make app       build $(APP) (sprites + release build + ad-hoc signing)"
	@echo "make run       build and open the app"
	@echo "make dmg       package $(DMG)  (VERSION=x.y sets the app version)"
	@echo "make sprites   regenerate the sprite sheets only"
	@echo "make clean     remove build output"
	@echo "Set SIGN_IDENTITY to sign with a real certificate instead of ad-hoc."

app:
	VERSION=$(VERSION) ./scripts/build-app.sh

run: app
	open $(APP)

dmg: app
	rm -rf $(STAGE) $(DMG)
	mkdir -p $(STAGE)
	cp -R $(APP) $(STAGE)/
	ln -s /Applications $(STAGE)/Applications
	hdiutil create -volname OllieBoard -srcfolder $(STAGE) -ov -format UDZO $(DMG)
	rm -rf $(STAGE)
	hdiutil verify $(DMG)

sprites:
	swift run -c release SpriteGen

clean:
	rm -rf build
	swift package clean
