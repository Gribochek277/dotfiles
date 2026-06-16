-- ## Workspace Management ###

-- Switch workspaces with mainMod + [0-9]
hl.bind(var_mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(var_mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(var_mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(var_mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(var_mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(var_mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(var_mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(var_mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(var_mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(var_mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move active window to a workspace with mainMod + CTRL + [0-9]
hl.bind(var_mainMod .. " + CTRL + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(var_mainMod .. " + CTRL + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(var_mainMod .. " + CTRL + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(var_mainMod .. " + CTRL + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(var_mainMod .. " + CTRL + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(var_mainMod .. " + CTRL + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(var_mainMod .. " + CTRL + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(var_mainMod .. " + CTRL + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(var_mainMod .. " + CTRL + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(var_mainMod .. " + CTRL + 0", hl.dsp.window.move({ workspace = 10 }))

-- ## Special Workspaces ###

-- Magic workspace (Telegram, email, etc.)
hl.bind("XF86Messenger", hl.dsp.workspace.toggle_special("magic"))
hl.bind(var_mainMod .. " + mouse:274", hl.dsp.workspace.toggle_special("magic"))
hl.bind(var_mainMod .. " + space", hl.dsp.workspace.toggle_special("magic"))
hl.bind("CTRL + space", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind("XF86Mail", hl.dsp.workspace.toggle_special("magic"))
hl.bind("CTRL + XF86Messenger", hl.dsp.window.move({ workspace = "special:magic" }))

-- Temp workspace (Browser apps, battery, etc.)
hl.bind(var_mainMod .. " + Home", hl.dsp.workspace.toggle_special("temp"))
hl.bind(var_mainMod .. " + grave", hl.dsp.workspace.toggle_special("temp"))
hl.bind(var_mainMod .. " + CTRL + Home", hl.dsp.window.move({ workspace = "special:temp" }))

-- VPN workspace
hl.bind(var_mainMod .. " + CTRL + V", hl.dsp.workspace.toggle_special("vpn"))

-- ## Workspace Navigation ###

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(var_mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(var_mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL + " .. var_mainMod .. " + N", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("CTRL + " .. var_mainMod .. " + P", hl.dsp.focus({ workspace = "e-1" }))
