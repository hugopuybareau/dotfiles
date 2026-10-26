-- Move and resize windows instantly instead of animating
hs.window.animationDuration = 0

hs.loadSpoon("ReloadConfiguration"):start()
hs.loadSpoon("AppKeybindings"):init()
hs.loadSpoon("AppPositions"):init()
hs.loadSpoon("GraphicalKeyLogger"):init()

hs.alert.show("Hammerspoon config loaded")
