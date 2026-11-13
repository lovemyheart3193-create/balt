local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local WS = game:GetService("Workspace")
local GiS = game:GetService("GuiService")

local inset = Vector2.zero
pcall(function()
	local a = GiS:GetGuiInset()
	if a then inset = a end
end)

local waitT = (task and task.wait) or wait
local spawnT = (task and task.spawn) or spawn or function(f)
	coroutine.wrap(f)()
end
local deferT = (task and task.defer) or function(f)
	spawnT(f)
end

local function log(...)
	pcall(print, "[aim]", ...)
end

local lp = Players.LocalPlayer
local cam = WS.CurrentCamera
local mobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local function best()
	local t = lp and lp.PlayerGui
	if t then return t end
	local r
	pcall(function()
		r = (gethui and gethui()) or game:GetService("CoreGui")
	end)
	return r
end

local core = best()
log("start | mobile:", mobile, "| parent:", core and core:GetFullName() or "none")

local guis = {}
local function attach(g)
	guis[#guis + 1] = g
	pcall(function()
		g.Parent = core or best()
	end)
end

if core then
	pcall(function()
		for _, c in ipairs(core:GetChildren()) do
			if c:IsA("ScreenGui") and (c.Name == "aim_ui" or c.Name == "aim_ovl" or c.Name == "aim_esp" or c.Name == "aim_diag") then
				c:Destroy()
			end
		end
	end)
end

local diagGui = Instance.new("ScreenGui")
diagGui.Name = "aim_diag"
diagGui.IgnoreGuiInset = true
diagGui.ResetOnSpawn = false
diagGui.DisplayOrder = 999
attach(diagGui)

local diagFrame = Instance.new("Frame")
diagFrame.Position = UDim2.new(0, 10, 0, 54)
diagFrame.Size = UDim2.new(1, -20, 0, 0)
diagFrame.AutomaticSize = Enum.AutomaticSize.Y
diagFrame.BackgroundTransparency = 1
diagFrame.Parent = diagGui

local diagBox = Instance.new("TextLabel")
diagBox.Size = UDim2.new(1, 0, 0, 0)
diagBox.AutomaticSize = Enum.AutomaticSize.Y
diagBox.BackgroundColor3 = Color3.new(0, 0, 0)
diagBox.BackgroundTransparency = 0.1
diagBox.TextColor3 = Color3.fromRGB(255, 95, 95)
diagBox.Font = Enum.Font.Code
diagBox.TextSize = 11
diagBox.TextWrapped = true
diagBox.TextXAlignment = Enum.TextXAlignment.Left
diagBox.TextYAlignment = Enum.TextYAlignment.Top
diagBox.Visible = false
diagBox.Parent = diagFrame

local function setup()
	local WHITE = Color3.new(1, 1, 1)
	local DIM = Color3.fromRGB(48, 48, 52)
	
	local cfg = {
		aim = { fov = 120, draw = true, speed = 100, walls = true, team = true, on = false, holdBtn = false },
		trig = { press = false, react = 60, btn = false },
		move = { speed = 3, infjump = false, jump = 3, stuck = false, boost = true, btnSpd = false, btnJump = false, btnStuck = false },
		vis = { esp = false, name = true, hp = true, team = true, btn = false },
	}
	
	local mods, btnStack, syncBtns

	local rp = RaycastParams.new()
	local ftOk = pcall(function()
		rp.FilterType = Enum.RaycastFilterType.Exclude
	end)
	if not ftOk then
		pcall(function()
			rp.FilterType = Enum.RaycastFilterType.Blacklist
		end)
	end
	rp.FilterDescendantsInstances = {}
	
	local tpr = RaycastParams.new()
	pcall(function()
		tpr.FilterType = rp.FilterType
	end)
	tpr.FilterDescendantsInstances = {}
	
	local function mk(c, p, parent)
		local o = Instance.new(c)
		for k, v in pairs(p) do o[k] = v end
		if parent then o.Parent = parent end
		return o
	end
	
	local function corner(o, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = r
		c.Parent = o
		return c
	end
	
	local function stroke(o, t, a)
		local s = Instance.new("UIStroke")
		s.Color = WHITE
		s.Thickness = t
		s.Transparency = a
		s.Parent = o
		return s
	end
	
	local function hum()
		local ch = lp.Character
		if not ch then return end
		local h = ch:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then return h, ch end
	end
	
	local function same(p)
		if p == lp then return true end
		local t = lp.Team
		if t then return p.Team == t end
		local c = lp.TeamColor
		return p.TeamColor == c and c ~= Enum.TeamColor.White
	end
	
	local function body(p, tc)
		if p == lp then return end
		local ch = p.Character
		if not ch or ch.Parent == nil then return end
		local h = ch:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 or h:GetState() == Enum.HumanoidStateType.Dead then return end
		if tc and same(p) then return end
		local root = ch:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local head = ch:FindFirstChild("Head") or root
		return head, root, ch, h
	end
	
	local function clear(pos, ch)
		if not cfg.aim.walls then return true end
		rp.FilterDescendantsInstances = { lp.Character, ch }
		return WS:Raycast(cam.CFrame.Position, pos - cam.CFrame.Position, rp) == nil
	end
	
	local target, goal, tPos, tDist, locked

	local function aimPos(head)
		return head.Position - Vector3.new(0, math.min(head.Size.Y * 0.35, 0.5), 0)
	end

	local function scan()
		local o = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		local head, root, ch, pos, len
		if locked then
			head, root, ch = body(locked, cfg.aim.team)
			if head then
				pos = aimPos(head)
				if clear(pos, ch) then
					return locked, pos, (root.Position - o).Magnitude
				end
			end
			locked = nil
		end
		local best, bp, bd
		local fov = math.max(cfg.aim.fov, 20)
		for _, p in ipairs(Players:GetPlayers()) do
			head, root, ch = body(p, cfg.aim.team)
			if head then
				pos = aimPos(head)
				local d = pos - o
				len = d.Magnitude
				if len > 0 and len <= 1200 then
					local ang = math.deg(math.acos(math.clamp(look:Dot(d / len), -1, 1)))
					if ang <= fov and (not bd or len < bd) then
						if clear(pos, ch) then
							bd, best, bp = len, p, pos
						end
					end
				end
			end
		end
		if best then
			locked = best
		end
		return best, bp, bd
	end
	
	local function tick(dt)
		if not cam then
			cam = WS.CurrentCamera
		end
		if not cfg.aim.on or not cam then
			goal, target, locked = nil, nil, nil
			return
		end
		local h = hum()
		if not h then
			goal, target, locked = nil, nil, nil
			return
		end
		local p, pos, d = scan()
		target, tPos, tDist = p, pos, d
		if not p then
			goal = nil
			return
		end
		goal = CFrame.lookAt(cam.CFrame.Position, pos)
		if cfg.aim.speed >= 95 then
			cam.CFrame = goal
		else
			local k = 0.5 + (cfg.aim.speed / 100) ^ 2 * 60
			cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(1 - math.exp(-k * dt), 0.005, 1))
		end
	end
	
	local ring
	
	local function drawRing()
		if not cfg.aim.draw or not cam then
			ring.Visible = false
			return
		end
		ring.Visible = true
		local vp = cam.ViewportSize
		local f = math.min(cfg.aim.fov, 179)
		local r = math.tan(math.rad(f / 2)) / math.tan(math.rad(cam.FieldOfView / 2)) * vp.Y / 2
		r = math.clamp(r, 6, math.min(vp.X, vp.Y) * 0.7)
		ring.Size = UDim2.fromOffset(r * 2, r * 2)
		ring.Position = UDim2.fromOffset(vp.X / 2, inset.Y + vp.Y / 2)
	end
	
	local baseUI = mk("ScreenGui", { Name = "aim_ovl", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 20 })
	attach(baseUI)
	
	ring = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 100) }, baseUI)
	corner(ring, UDim.new(1, 0))
	stroke(ring, 1.5, 0.35)
	
	local ui = mk("ScreenGui", { Name = "aim_ui", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50 })
	attach(ui)
	
	local menuBtn = mk("TextButton", {
		Name = "menu", Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.2, Text = "", AutoButtonColor = false, Parent = ui,
	}, ui)
	corner(menuBtn, UDim.new(0, 12))
	stroke(menuBtn, 1, 0.7)
	menuBtn.ZIndex = 20
	
	local micon = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 }, menuBtn)
	local mring = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(15, 15), BackgroundTransparency = 1 }, micon)
	corner(mring, UDim.new(1, 0))
	stroke(mring, 1.5, 0)
	local dot = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, micon)
	corner(dot, UDim.new(1, 0))
	for _, d in ipairs({ { 0, -7 }, { 0, 7 }, { -7, 0 }, { 7, 0 } }) do
		local l = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, d[1], 0.5, d[2]),
			Size = d[1] == 0 and UDim2.fromOffset(1, 3) or UDim2.fromOffset(3, 1),
			BackgroundColor3 = WHITE, BorderSizePixel = 0,
		}, micon)
	end
	
	local frame = mk("Frame", {
		Name = "frame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 40),
		Size = UDim2.fromScale(0.94, 0.86), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.12, Visible = false, ClipsDescendants = true, ZIndex = 1, Parent = ui,
	}, ui)
	corner(frame, UDim.new(0, 16))
	stroke(frame, 1, 0.8)
	
	local left = mk("Frame", { Size = UDim2.new(0.46, -12, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1 }, frame)
	mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
		TextSize = 26, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "A I M", Parent = left,
	}, left)
	mk("TextLabel", {
		Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(140, 140, 145),
		TextXAlignment = Enum.TextXAlignment.Left, Text = "strict / instant lock", Parent = left,
	}, left)
	
	local info = mk("Frame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55 }, left)
	corner(info, UDim.new(0, 10))
	stroke(info, 1, 0.85)
	local pads = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, info)
	pads.Parent = info
	local function line(i, text)
		local l = mk("TextLabel", {
			Position = UDim2.fromOffset(10, 8 + i * 18), Size = UDim2.new(1, -20, 0, 14), BackgroundTransparency = 1,
			Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(190, 190, 195),
			TextXAlignment = Enum.TextXAlignment.Left, Text = text,
		}, pads)
		return l
	end
	local lDev = line(0, "device:  " .. (mobile and "mobile" or "pc"))
	local lSt = line(1, "state:  idle")
	local lTar = line(2, "target:  -")
	local lDist = line(3, "dist:  -")
	local lKey = line(4, "key:  " .. (mobile and "lock button" or "hold C"))
	
	local right = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0.54, -12, 1, -24),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = frame,
	}, frame)
	corner(right, UDim.new(0, 12))
	stroke(right, 1, 0.85)
	
	mk("TextLabel", {
		Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -50, 0, 18), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "MENU", Parent = right,
	}, right)
	local close = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, Text = "x", AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = WHITE, Parent = right,
	}, right)
	corner(close, UDim.new(1, 0))
	
	local tabRow = mk("Frame", { Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 24), BackgroundTransparency = 1 }, right)
	local tlay = mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabRow)
	tabRow.Parent = right
	for _, t in ipairs({ "Combat", "Movement", "Visual" }) do
		local b = mk("TextButton", {
			Size = UDim2.new(1 / 3, -3, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88,
			Text = t, AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(150, 150, 155),
		}, tabRow)
		corner(b, UDim.new(0, 6))
		b.Name = t
	end
	
	local content = mk("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 1, -70), BackgroundTransparency = 1,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.new(1, 1, 1), CanvasSize = UDim2.new(),
		ScrollBarImageTransparency = 0.5, Parent = right,
	}, right)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	mk("UIPadding", { PaddingBottom = UDim.new(0, 10) }, content)
	
	local function rowH(h)
		local r = mk("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1 })
		return r
	end
	
	local function head(text)
		local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
		local l = mk("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
			TextSize = 11, TextColor3 = Color3.fromRGB(120, 120, 128), TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.upper(text), Parent = f,
		}, f)
		return f
	end
	
	local function toggle(parent, text, state, cb)
		local r = rowH(32)
		r.Parent = parent
		local l = mk("TextLabel", {
			Size = UDim2.new(1, -48, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
			TextSize = 12, TextColor3 = Color3.fromRGB(225, 225, 230), TextXAlignment = Enum.TextXAlignment.Left,
			Text = text, Parent = r,
		}, r)
		local b = mk("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(38, 18),
			Text = "", AutoButtonColor = false, BackgroundColor3 = state and WHITE or DIM, BorderSizePixel = 0,
		}, r)
		b.Parent = r
		corner(b, UDim.new(1, 0))
		local k = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = state and Color3.new(0, 0, 0) or WHITE, BorderSizePixel = 0 }, b)
		corner(k, UDim.new(1, 0))
		k.Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
		b.MouseButton1Click:Connect(function()
			state = not state
			b.BackgroundColor3 = state and WHITE or DIM
			k.BackgroundColor3 = state and Color3.new(0, 0, 0) or WHITE
			k.Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
			cb(state)
		end)
	end
	
	local function slider(parent, text, min, max, def, fmt, cb)
		local r = rowH(38)
		r.Parent = parent
		local l = mk("TextLabel", {
			Size = UDim2.new(1, -4, 0, 15), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
			TextSize = 12, TextColor3 = Color3.fromRGB(225, 225, 230), TextXAlignment = Enum.TextXAlignment.Left,
			Text = text .. ":  " .. fmt(def), Parent = r,
		}, r)
		local tr = mk("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -4, 0, 4), BackgroundColor3 = DIM, BorderSizePixel = 0, Parent = r }, r)
		corner(tr, UDim.new(1, 0))
		local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = tr }, tr)
		corner(fill, UDim.new(1, 0))
		local knob = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = tr }, tr)
		corner(knob, UDim.new(1, 0))
		local v = def
		local function apply(nv, fire)
			v = math.clamp(nv, min, max)
			local a = (v - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.new(a, 0, 0.5, 0)
			l.Text = text .. ":  " .. fmt(v)
			if fire then cb(v) end
		end
		apply(def, false)
		local dg
		tr.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				dg = i
				local x = math.clamp((i.Position.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
				apply(math.floor(min + (max - min) * x + 0.5), true)
			end
		end)
		UIS.InputChanged:Connect(function(i)
			if not dg then return end
			local ty = i.UserInputType
			if ty == Enum.UserInputType.Touch and i ~= dg then return end
			if ty ~= Enum.UserInputType.Touch and ty ~= Enum.UserInputType.MouseMovement then return end
			local x = math.clamp((i.Position.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
			apply(math.floor(min + (max - min) * x + 0.5), true)
		end)
		UIS.InputEnded:Connect(function(i)
			if not dg then return end
			local ty = i.UserInputType
			if ty == Enum.UserInputType.Touch and i ~= dg then return end
			dg = nil
		end)
	end
	
	local function text(parent, t, color)
		local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = parent }, parent)
		local l = mk("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
			TextSize = 10, TextColor3 = color or Color3.fromRGB(120, 120, 128), TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = t, Parent = f,
		}, f)
		return f
	end
	
	local pages = {}
	local function clearContent()
		for _, c in ipairs(content:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
	end
	
	pages.Combat = function()
		slider(content, "Fov", 20, 360, cfg.aim.fov, tostring, function(v) cfg.aim.fov = v end)
		toggle(content, "Draw Fov", cfg.aim.draw, function(v) cfg.aim.draw = v end)
		slider(content, "Aim Speed", 1, 100, cfg.aim.speed, tostring, function(v) cfg.aim.speed = v end)
		toggle(content, "Wall Check", cfg.aim.walls, function(v) cfg.aim.walls = v end)
		toggle(content, "Team Check", cfg.aim.team, function(v) cfg.aim.team = v end)
		toggle(content, "Lock AimButton", cfg.aim.holdBtn, function(v) cfg.aim.holdBtn = v end)
		head("TriggerBot").Parent = content
		toggle(content, "Press", cfg.trig.press, function(v) cfg.trig.press = v end)
		toggle(content, "Button", cfg.trig.btn, function(v) cfg.trig.btn = v; syncBtns() end)
		slider(content, "Reaction", 0, 500, cfg.trig.react, function(v) return v .. " ms" end, function(v) cfg.trig.react = v end)
		text(content, "1 = slow, 100 = instant. Press holds the mouse button while the crosshair is on a target.")
	end
	
	pages.Movement = function()
		slider(content, "Speed", 1, 5, cfg.move.speed, tostring, function(v) cfg.move.speed = v end)
		toggle(content, "Button", cfg.move.btnSpd, function(v) cfg.move.btnSpd = v; syncBtns() end)
		toggle(content, "Inf Jump", cfg.move.infjump, function(v) cfg.move.infjump = v; syncBtns() end)
		toggle(content, "Button", cfg.move.btnJump, function(v) cfg.move.btnJump = v; syncBtns() end)
		slider(content, "Jump Speed", 1, 5, cfg.move.jump, tostring, function(v) cfg.move.jump = v end)
		toggle(content, "Air Stuck", cfg.move.stuck, function(v) cfg.move.stuck = v; syncBtns() end)
		toggle(content, "Button", cfg.move.btnStuck, function(v) cfg.move.btnStuck = v; syncBtns() end)
		text(content, "Speed 3 = default, 1 = x0.2, 5 = x10. Jump Speed 1 = x0.2, 5 = x5.")
	end
	
	pages.Visual = function()
		toggle(content, "Esp", cfg.vis.esp, function(v) cfg.vis.esp = v; syncBtns() end)
		toggle(content, "Button", cfg.vis.btn, function(v) cfg.vis.btn = v; syncBtns() end)
		toggle(content, "Name", cfg.vis.name, function(v) cfg.vis.name = v end)
		toggle(content, "Hp", cfg.vis.hp, function(v) cfg.vis.hp = v end)
		toggle(content, "Team Check", cfg.vis.team, function(v) cfg.vis.team = v end)
	end
	
	local openPage
	local function show(name)
		clearContent()
		openPage = name
		for _, b in ipairs(tabRow:GetChildren()) do
			if b:IsA("TextButton") then
				local act = b.Name == name
				b.BackgroundTransparency = act and 0.1 or 0.88
				b.TextColor3 = act and WHITE or Color3.fromRGB(150, 150, 155)
			end
		end
		pages[name]()
		content.CanvasSize = UDim2.new()
	end
	
	for _, b in ipairs(tabRow:GetChildren()) do
		if b:IsA("TextButton") then
			b.MouseButton1Click:Connect(function() show(b.Name) end)
		end
	end
	content.ChildAdded:Connect(function()
		deferT(function()
			local y = content.UIListLayout.AbsoluteContentSize.Y
			content.CanvasSize = UDim2.fromOffset(0, y)
		end)
	end)
	
	local function setMenu(v)
		frame.Visible = v
		menuBtn.BackgroundTransparency = v and 0.6 or 0.2
	end
	
	menuBtn.MouseButton1Click:Connect(function()
		setMenu(not frame.Visible)
		if frame.Visible then show("Combat") end
	end)
	close.MouseButton1Click:Connect(function() setMenu(false) end)
	
	local lock, lockShackle, lx, ly, tx, ty, lockMoved, lockIn

	local function syncLock()
		if not lock then return end
		if cfg.aim.on then
			lockShackle.Position = UDim2.new(0.5, 0, 0, 8)
			lockShackle.Rotation = 0
		else
			lockShackle.Position = UDim2.new(0.5, 7, 0, 4)
			lockShackle.Rotation = 24
		end
	end

	function syncBtns()
		if not mods then return end
		for _, m in ipairs(mods) do
			local vis = m.flag()
			if m.b.Visible ~= vis then
				m.b.Visible = vis
			end
			local on = vis and m.getv()
			m.b.BackgroundColor3 = on and WHITE or Color3.new(0, 0, 0)
			m.b.TextColor3 = on and Color3.new(0, 0, 0) or WHITE
			m.b.BackgroundTransparency = on and 0.1 or 0.2
		end
	end

	if mobile then
		lx, ly = 18, math.floor((cam and cam.ViewportSize.Y or 720) * 0.42)
		tx, ty = lx, ly
		lock = mk("TextButton", {
			AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(lx, ly), Size = UDim2.fromOffset(92, 92),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, ZIndex = 20,
			Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = ui,
		}, ui)
		corner(lock, UDim.new(0, 20))
		stroke(lock, 1.2, 0.6)

		local icon = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1 }, lock)
		lockShackle = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(26, 30), BackgroundTransparency = 1 }, icon)
		corner(lockShackle, UDim.new(1, 0))
		stroke(lockShackle, 5, 0)
		local lockBody = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(34, 24), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, icon)
		corner(lockBody, UDim.new(0, 7))
		local hole = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(4, 7), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, lockBody)
		corner(hole, UDim.new(1, 0))

		local px2, py2
		lock.InputBegan:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			lockIn = i
			px2, py2 = i.Position.X, i.Position.Y
			lockMoved = false
		end)
		UIS.InputChanged:Connect(function(i)
			if not lockIn then return end
			local tp = i.UserInputType
			if tp == Enum.UserInputType.Touch then
				if i ~= lockIn then return end
			elseif tp ~= Enum.UserInputType.MouseMovement then
				return
			end
			local x = i.Position.X - px2
			local y = i.Position.Y - py2
			px2, py2 = i.Position.X, i.Position.Y
			if cfg.aim.holdBtn then return end
			if not lockMoved then
				if math.abs(x) < 6 and math.abs(y) < 6 then return end
				lockMoved = true
			end
			local vp = cam.ViewportSize
			tx = math.clamp(tx + x, 0, math.max(vp.X - 92, 0))
			ty = math.clamp(ty + y, 0, math.max(vp.Y - 92, 0))
		end)
		UIS.InputEnded:Connect(function(i)
			if not lockIn then return end
			local tp = i.UserInputType
			if tp == Enum.UserInputType.Touch then
				if i ~= lockIn then return end
			elseif tp ~= Enum.UserInputType.MouseButton1 then
				return
			end
			lockIn = nil
			if not lockMoved then
				cfg.aim.on = not cfg.aim.on
				syncLock()
			end
		end)
		syncLock()
	end

	btnStack = mk("Frame", {
		Position = UDim2.fromOffset(0, 104), Size = UDim2.new(0, 150, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, ZIndex = 20,
	}, lock or ui)
	if not lock then
		btnStack.Position = UDim2.fromOffset(18, 320)
	end
	mk("UIListLayout", { Padding = UDim.new(0, 8) }, btnStack)

	mods = {}
	local function addBtn(label, flag, getv, setv)
		local b = mk("TextButton", {
			Size = UDim2.fromOffset(150, 92), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2,
			Text = label, Visible = false, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 15,
			TextColor3 = WHITE, BorderSizePixel = 0, ZIndex = 20, Parent = btnStack,
		}, btnStack)
		corner(b, UDim.new(0, 20))
		stroke(b, 1.2, 0.6)
		b.MouseButton1Click:Connect(function()
			setv(not getv())
			syncBtns()
		end)
		mods[#mods + 1] = { b = b, flag = flag, getv = getv }
	end
	addBtn("TRIGGER", function() return cfg.trig.btn end, function() return cfg.trig.press end, function(v) cfg.trig.press = v end)
	addBtn("SPEED", function() return cfg.move.btnSpd end, function() return cfg.move.boost end, function(v) cfg.move.boost = v end)
	addBtn("INFJUMP", function() return cfg.move.btnJump end, function() return cfg.move.infjump end, function(v) cfg.move.infjump = v end)
	addBtn("AIRSTUCK", function() return cfg.move.btnStuck end, function() return cfg.move.stuck end, function(v) cfg.move.stuck = v end)
	addBtn("ESP", function() return cfg.vis.btn end, function() return cfg.vis.esp end, function(v) cfg.vis.esp = v end)

	if mobile then
		RunService.RenderStepped:Connect(function()
			if math.abs(tx - lx) < 0.4 and math.abs(ty - ly) < 0.4 then
				lx, ly = tx, ty
			else
				lx = lx + (tx - lx) * 0.3
				ly = ly + (ty - ly) * 0.3
			end
			lock.Position = UDim2.fromOffset(lx, ly)
		end)
	end
	
	local espUI = mk("ScreenGui", { Name = "aim_esp", IgnoreGuiInset = false, ResetOnSpawn = false, DisplayOrder = 10 })
	attach(espUI)
	
	local pool = {}
	
	local function entry(p)
		local e = pool[p]
		if e then return e end
		local root = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, espUI)
		root.Parent = espUI
		corner(root, UDim.new(0, 2))
		local fill = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, BorderSizePixel = 0 }, root)
		fill.Parent = root
		corner(fill, UDim.new(0, 2))
		local st = stroke(root, 1.4, 0.05)
		local nm = mk("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -3), Size = UDim2.new(1, 90, 0, 13),
			BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = WHITE,
			TextStrokeTransparency = 0.4, Visible = false,
		}, root)
		nm.Parent = root
		local hpb = mk("Frame", { Position = UDim2.new(0, -7, 0, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.fromRGB(18, 18, 18), BorderSizePixel = 0 }, root)
		hpb.Parent = root
		local hpf = mk("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 120), BorderSizePixel = 0 }, hpb)
		hpf.Parent = hpb
		e = { root = root, st = st, nm = nm, hpb = hpb, hpf = hpf }
		pool[p] = e
		return e
	end
	
	Players.PlayerRemoving:Connect(function(p)
		if pool[p] then
			pool[p].root:Destroy()
			pool[p] = nil
		end
	end)
	
	local function esp()
		if not cfg.vis.esp or not cam then
			for _, e in pairs(pool) do e.root.Visible = false end
			return
		end
		local seen = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp and not (cfg.vis.team and same(p)) then
				local head, root, ch, h = body(p, false)
				if head then
					local ok, cfr, size = pcall(function() return ch:GetBoundingBox() end)
					if ok then
						local center = cfr.Position
						local rv = cam.CFrame.RightVector
						local uv = cam.CFrame.UpVector
						local hw = size.X / 2 + 0.1
						local hh = size.Y / 2
						local minX, minY, maxX, maxY, front
						for _, sx in ipairs({ -1, 1 }) do
							for _, sy in ipairs({ -1, 1 }) do
								local wp = center + rv * (hw * sx) + uv * (hh * sy)
								local sp, on = cam:WorldToViewportPoint(wp)
								if on and sp.Z > 0 then
									front = true
									minX = math.min(minX or sp.X, sp.X)
									maxX = math.max(maxX or sp.X, sp.X)
									minY = math.min(minY or sp.Y, sp.Y)
									maxY = math.max(maxY or sp.Y, sp.Y)
								end
							end
						end
						if front and minX then
							local e = entry(p)
							local w = maxX - minX
							local hh2 = maxY - minY
							if w > 1 and hh2 > 1 then
								seen[p] = true
								e.root.Position = UDim2.fromOffset(minX, minY)
								e.root.Size = UDim2.fromOffset(w, hh2)
								e.root.Visible = true
								e.nm.Visible = cfg.vis.name
								e.nm.Text = p.Name
								e.hpb.Visible = cfg.vis.hp
								local frac = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
								e.hpf.Size = UDim2.fromScale(1, frac)
								e.hpf.BackgroundColor3 = frac > 0.7 and Color3.fromRGB(90, 220, 120) or frac > 0.45 and Color3.fromRGB(235, 220, 90) or frac > 0.2 and Color3.fromRGB(240, 160, 60) or Color3.fromRGB(235, 70, 70)
							else
								e.root.Visible = false
							end
						end
					end
				end
			end
		end
		for p, e in pairs(pool) do
			if not seen[p] then e.root.Visible = false end
		end
	end
	
	local pressing = false
	local onSince
	
	local function trig()
		if not cfg.trig.press or mobile then
			if pressing and type(mouse1release) == "function" then
				mouse1release()
			end
			pressing = false
			return
		end
		if not cam then return end
		tpr.FilterDescendantsInstances = { lp.Character }
		local hit = WS:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1200, tpr)
		local p = hit and Players:GetPlayerFromCharacter(hit.Instance:FindFirstAncestorOfClass("Model"))
		local ok = p and p ~= lp and not (cfg.aim.team and same(p))
		local hh = hum()
		if ok and not hh then ok = false end
		if ok then
			onSince = onSince or os.clock()
			if not pressing and (os.clock() - onSince) * 1000 >= cfg.trig.react then
				if type(mouse1press) == "function" then
					mouse1press()
					pressing = true
				end
			end
		else
			onSince = nil
			if pressing then
				if type(mouse1release) == "function" then mouse1release() end
				pressing = false
			end
		end
	end
	
	local function spd(v)
		if v <= 3 then return 0.2 + 0.8 * (v - 1) / 2 end
		return 1 + 9 * (v - 3) / 2
	end
	
	local function jmp(v)
		if v <= 3 then return 0.2 + 0.8 * (v - 1) / 2 end
		return 1 + 4 * (v - 3) / 2
	end
	
	local jumpKeys = {}
	local baseSpeed, savedVel, stuckOn
	
	local function moveTick()
		local h, ch = hum()
		if not h then
			stuckOn = nil
			return
		end
		baseSpeed = baseSpeed or h.WalkSpeed
		if baseSpeed <= 0 then baseSpeed = 16 end
		if cfg.move.boost then
			h.WalkSpeed = baseSpeed * spd(cfg.move.speed)
		else
			h.WalkSpeed = baseSpeed
		end
		local f = jmp(cfg.move.jump)
		if h.UseJumpPower then
			h.JumpPower = 50 * f
		else
			h.JumpHeight = 7.2 * f
		end
		local root = ch:FindFirstChild("HumanoidRootPart")
		if root then
			if cfg.move.stuck then
				if not stuckOn then
					stuckOn = true
					savedVel = root.AssemblyLinearVelocity
				end
				if not root.Anchored then root.Anchored = true end
				root.AssemblyLinearVelocity = Vector3.zero
			elseif stuckOn then
				stuckOn = nil
				root.Anchored = false
				if savedVel then root.AssemblyLinearVelocity = savedVel end
			end
			if cfg.move.infjump then
				local held = UIS:IsKeyDown(Enum.KeyCode.Space) or next(jumpKeys) ~= nil
				if held and not cfg.move.stuck then
					local st = h:GetState()
					if st ~= Enum.HumanoidStateType.Jumping and st ~= Enum.HumanoidStateType.Freefall then
						h:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					local v = root.AssemblyLinearVelocity
					if v.Y < 50 then
						root.AssemblyLinearVelocity = Vector3.new(v.X, 50, v.Z)
					end
				end
			end
		end
	end
	
	UIS.InputBegan:Connect(function(i)
		if i.KeyCode == Enum.KeyCode.Space then jumpKeys[i] = true end
		if i.UserInputType == Enum.UserInputType.Touch and mobile then
			local vp = cam.ViewportSize
			if i.Position.X > vp.X * 0.6 and i.Position.Y > vp.Y * 0.5 then jumpKeys[i] = true end
		end
		if not mobile then
			if i.KeyCode == Enum.KeyCode.C then
				cfg.aim.on = true
			end
		end
	end)
	
	UIS.InputEnded:Connect(function(i)
		jumpKeys[i] = nil
		if not mobile and i.KeyCode == Enum.KeyCode.C then cfg.aim.on = false end
	end)
	
	WS:GetPropertyChangedSignal("CurrentCamera"):Connect(function() cam = WS.CurrentCamera end)
	
	spawnT(function()
		while true do
			waitT(0.12)
			lDev.Text = "device:  " .. (mobile and "mobile" or "pc")
			lSt.Text = "state:  " .. (cfg.aim.on and (target and "locked" or "searching") or "idle")
			lTar.Text = "target:  " .. (target and target.Name or "-")
			lDist.Text = "dist:  " .. (tDist and math.floor(tDist) .. "m" or "-")
			lKey.Text = "key:  " .. (mobile and "lock button" or "hold C")
			if lock then syncLock() end
		syncBtns()
		end
	end)
	
	pcall(function()
		RunService:BindToRenderStep("aimMain", Enum.RenderPriority.Camera.Value + 10, function(dt)
			tick(dt)
			drawRing()
		end)
	end)
	
	pcall(function()
		RunService.PreRender:Connect(function()
			if goal and cfg.aim.speed >= 95 then cam.CFrame = goal end
		end)
	end)
	
	RunService.RenderStepped:Connect(function()
		esp()
		trig()
	end)
	
	RunService.Heartbeat:Connect(moveTick)
	
	show("Combat")
	syncBtns()
end

spawnT(function()
	while true do
		waitT(1)
		if not lp then lp = Players.LocalPlayer end
		if not cam then cam = WS.CurrentCamera end
		local up = lp and lp.PlayerGui
		if up and core ~= up then
			core = up
			for _, g in ipairs(guis) do
				pcall(function()
					g.Parent = up
				end)
			end
		end
		for _, g in ipairs(guis) do
			pcall(function()
				if g.Parent == nil then g.Parent = core or best() end
			end)
		end
	end
end)

local ok, err = xpcall(setup, function(e)
	local msg = tostring(e)
	pcall(function()
		msg = msg .. "\n" .. tostring(debug.traceback("", 2))
	end)
	return msg
end)

if not ok then
	diagBox.Text = err
	diagBox.Visible = true
	log("ERROR", err)
else
	log("ready | parent:", core and core:GetFullName() or "none")
end
