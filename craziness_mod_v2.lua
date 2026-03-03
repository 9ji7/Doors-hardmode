local Pl=game:GetService("Players") local TW=game:GetService("TweenService") local RS=game:GetService("ReplicatedStorage") local RU=game:GetService("RunService") local DB=game:GetService("Debris") local LI=game:GetService("Lighting")
local LP=Pl.LocalPlayer local CAM=workspace.CurrentCamera
local EF=workspace:FindFirstChild("craziness entities") or Instance.new("Folder",workspace) EF.Name="craziness entities"
local C={
CS_Name="Common Sense",CS_Face="rbxthumb://type=Asset&id=17831829233&w=420&h=420",CS_Warn="rbxassetid://108716595659503",CS_Fly="rbxassetid://140617516722342",CS_Speed=75,CS_Chance=30,CS_Color=Color3.fromRGB(10,10,10),CS_Hint="Он не терпит спешки. Когда слышишь его гул — ищи убежище немедленно!",
RS_Name="Red Smile",RS_Face="rbxthumb://type=Asset&id=12806964203&w=420&h=420",RS_Far="rbxassetid://9125351660",RS_Near="rbxassetid://133672210406470",RS_Jumpscare="rbxassetid://130452258247912",RS_Speed=125,RS_Chance=35,RS_Rebounds=3,RS_KillRange=45,RS_Color=Color3.fromRGB(220,30,0),RS_Hint="Красная Улыбка видит тебя издалека, но стены — твоя защита!",
DG_Name="Deer God",DG_Face="rbxthumb://type=Asset&id=12331751916&w=420&h=420",DG_Jumpscare="rbxthumb://type=Asset&id=11394027278&w=420&h=420",DG_Ambient="rbxassetid://82890415629830",DG_Footstep="rbxassetid://134645629051473",DG_Speed=22,DG_Chance=10,DG_KillRange=12,DG_Color=Color3.fromRGB(80,160,80),DG_Hint="Олений Бог движется медленно, но неотступно. Прячься и не смотри назад.",
IR_Name="Inverted Rebound",IR_Face="rbxthumb://type=Asset&id=123816386090783&w=420&h=420",IR_Arrival="rbxassetid://136836151370178",IR_Move="rbxassetid://103078219556352",IR_Chance=35,IR_Speed=125,IR_Color=Color3.fromRGB(100,0,200),IR_Hint="Инверсия не терпит шкафов! Оставайся снаружи, пока реальность искажена.",
KillRange=15,ShakeThr=60,HintThr=80,DTick=0.05
}
local IRC=0 local IRA=false local DGA=false local RNG=Random.new() local KDB=false
local SE={} SE.Blur=Instance.new("BlurEffect",LI) SE.Blur.Size=0 SE.CC=Instance.new("ColorCorrectionEffect",LI) SE.CC.Saturation=0 SE.CC.Brightness=0 SE.CC.Contrast=0 SE.BL=Instance.new("BloomEffect",LI) SE.BL.Intensity=0
local function UpdSE(d,n)
	local t=math.clamp(1-d/C.ShakeThr,0,1)
	TW:Create(SE.Blur,TweenInfo.new(0.3),{Size=t*8}):Play()
	TW:Create(SE.CC,TweenInfo.new(0.3),{Saturation=-t*0.7,Brightness=-t*0.15,Contrast=t*0.4}):Play()
	local tc=Color3.new(1,1,1)
	if n==C.RS_Name then tc=Color3.fromRGB(255,math.floor(180-t*180),math.floor(180-t*180)) elseif n==C.IR_Name then tc=Color3.fromRGB(220,180,255) elseif n==C.DG_Name then tc=Color3.fromRGB(180,255,180) end
	TW:Create(SE.CC,TweenInfo.new(0.3),{TintColor=tc}):Play()
end
local function ClrSE() TW:Create(SE.Blur,TweenInfo.new(1),{Size=0}):Play() TW:Create(SE.CC,TweenInfo.new(1),{Saturation=0,Brightness=0,Contrast=0,TintColor=Color3.new(1,1,1)}):Play() end
local function DGJump()
	local sg=Instance.new("ScreenGui",LP.PlayerGui) sg.IgnoreGuiInset=true sg.ResetOnSpawn=false sg.DisplayOrder=999
	local bg=Instance.new("Frame",sg) bg.Size=UDim2.new(1,0,1,0) bg.BackgroundTransparency=1 bg.BorderSizePixel=0
	local im=Instance.new("ImageLabel",bg) im.Size=UDim2.new(1,0,1,0) im.Image=C.DG_Jumpscare im.BackgroundTransparency=1 im.ScaleType=Enum.ScaleType.Fit
	local pu=Instance.new("Frame",bg) pu.Size=UDim2.new(1,0,1,0) pu.BackgroundColor3=Color3.fromRGB(80,0,120) pu.BorderSizePixel=0 pu.BackgroundTransparency=1
	task.spawn(function() local e=tick()+1.1 local s=true while tick()<e do if s then im.ImageTransparency=0 pu.BackgroundTransparency=1 else im.ImageTransparency=1 pu.BackgroundTransparency=0 end s=not s task.wait(0.1) end sg:Destroy() end)
end
local function Flash()
	local sg=Instance.new("ScreenGui",LP.PlayerGui) sg.IgnoreGuiInset=true sg.ResetOnSpawn=false
	local f=Instance.new("Frame",sg) f.Size=UDim2.new(1,0,1,0) f.BackgroundColor3=Color3.new(1,1,1) f.BorderSizePixel=0 f.BackgroundTransparency=0
	task.wait(0.12) TW:Create(f,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play() task.delay(0.5,function() sg:Destroy() end)
end
local shk=0
RU.RenderStepped:Connect(function() if shk>0.01 then CAM.CFrame=CAM.CFrame*CFrame.new((math.random()-0.5)*shk,(math.random()-0.5)*shk,0) shk=shk*0.85 end end)
local function Shake(m) shk=math.max(shk,m) end
local HG=nil local HC={}
local function ShowHint(txt,col)
	if HG then HG:Destroy() end HG=Instance.new("ScreenGui",LP.PlayerGui) HG.ResetOnSpawn=false
	local fr=Instance.new("Frame",HG) fr.Size=UDim2.new(0.5,0,0,70) fr.Position=UDim2.new(0.25,0,0.82,0) fr.BackgroundColor3=Color3.new(0,0,0) fr.BackgroundTransparency=1 fr.BorderSizePixel=0
	Instance.new("UICorner",fr).CornerRadius=UDim.new(0,12)
	local ac=Instance.new("Frame",fr) ac.Size=UDim2.new(0.005,0,1,0) ac.BackgroundColor3=col ac.BorderSizePixel=0
	local lb=Instance.new("TextLabel",fr) lb.Size=UDim2.new(0.99,-8,1,0) lb.Position=UDim2.new(0.005,8,0,0) lb.BackgroundTransparency=1 lb.Text=txt lb.TextColor3=Color3.new(1,1,1) lb.TextWrapped=true lb.Font=Enum.Font.GothamMedium lb.TextSize=14 lb.TextXAlignment=Enum.TextXAlignment.Left lb.TextTransparency=1
	TW:Create(fr,TweenInfo.new(0.3),{BackgroundTransparency=0.35}):Play() TW:Create(lb,TweenInfo.new(0.3),{TextTransparency=0}):Play()
	task.delay(6,function() if HG and HG.Parent then TW:Create(fr,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play() TW:Create(lb,TweenInfo.new(0.5),{TextTransparency=1}):Play() task.delay(0.6,function() if HG then HG:Destroy() HG=nil end end) end end)
end
local function TryHint(n,t,col) if HC[n] then return end HC[n]=true ShowHint(t,col) task.delay(20,function() HC[n]=nil end) end
local function Snd(id,vol,par,loop,spd) local s=Instance.new("Sound",par or workspace) s.SoundId=id s.Volume=vol or 5 s.Looped=loop or false s.PlaybackSpeed=spd or 1 s:Play() if not loop then DB:AddItem(s,10) end return s end
local function Ptcl(par,col,rate)
	local e=Instance.new("ParticleEmitter",par) e.Color=ColorSequence.new(col,Color3.new(0,0,0)) e.LightEmission=0.5 e.LightInfluence=0.2
	e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.5),NumberSequenceKeypoint.new(1,0)})
	e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)})
	e.Texture="rbxasset://textures/particles/smoke_main.dds" e.Rate=rate or 25 e.Speed=NumberRange.new(3,8) e.SpreadAngle=Vector2.new(35,35) e.Lifetime=NumberRange.new(1.5,3) e.RotSpeed=NumberRange.new(-45,45)
end
local function MkEnt(name,face,sz,pos)
	local e=Instance.new("Part",EF) e.Name=name e.Size=Vector3.new(sz,sz,sz) e.Transparency=1 e.Anchored=true e.CanCollide=false e.CastShadow=false e.CFrame=CFrame.new(pos)
	local bg=Instance.new("BillboardGui",e) bg.Size=UDim2.new(sz*2,0,sz*2,0) bg.AlwaysOnTop=false
	local im=Instance.new("ImageLabel",bg) im.Size=UDim2.new(1,0,1,0) im.Image=face im.BackgroundTransparency=1
	return e,bg,im
end
local function CanSee(ep,ch) local hrp=ch:FindFirstChild("HumanoidRootPart") if not hrp then return false end local p=RaycastParams.new() p.FilterDescendantsInstances={ep,ch,EF} p.FilterType=Enum.RaycastFilterType.Exclude return not workspace:Raycast(ep.Position,hrp.Position-ep.Position,p) end
local function GetRooms() local rf=workspace:FindFirstChild("CurrentRooms") if not rf then return {} end local r=rf:GetChildren() table.sort(r,function(a,b) return(tonumber(a.Name)or 0)<(tonumber(b.Name)or 0) end) return r end
local function RNode(room) local n=room:FindFirstChild("Door")or room:FindFirstChild("Nodes") if not n then return room.PrimaryPart and room.PrimaryPart.Position or Vector3.new() end return(n:IsA("Model")and n.PrimaryPart.Position or n.Position) end
local function Move(ent,path,spd,rev)
	local idx={} if rev then for i=#path,1,-1 do idx[#idx+1]=i end else for i=1,#path do idx[#idx+1]=i end end
	for _,i in ipairs(idx) do if not ent or not ent.Parent then return end local t=RNode(path[i])+Vector3.new(0,5,0) local d=(ent.Position-t).Magnitude if d<1 then continue end local ti=d/spd TW:Create(ent,TweenInfo.new(ti,Enum.EasingStyle.Linear),{CFrame=CFrame.new(t)}):Play() task.wait(ti) end
end
local function SpawnCS(rb,_)
	local path=GetRooms() if#path==0 then return end
	Snd(C.CS_Warn,5,workspace) task.wait(2.5)
	local e=MkEnt(C.CS_Name,C.CS_Face,5,RNode(path[1])+Vector3.new(0,5,0))
	local sm=Instance.new("Smoke",e) sm.Color=Color3.new(0,0,0) sm.Size=30 sm.Opacity=0.7 sm.RiseVelocity=3
	Ptcl(e,C.CS_Color,20) local lp=Snd(C.CS_Fly,8,e,true)
	task.spawn(function() for _=1,rb do Move(e,path,C.CS_Speed,false) if not e.Parent then break end end lp:Stop() TW:Create(sm,TweenInfo.new(1),{Opacity=0}):Play() task.wait(1) if e.Parent then e:Destroy() end end)
end
local function SpawnRS(rb,_)
	local path=GetRooms() if#path==0 then return end
	Snd(C.RS_Far,4,workspace) task.wait(1.5)
	local e=MkEnt(C.RS_Name,C.RS_Face,6,RNode(path[1])+Vector3.new(0,5,0))
	local li=Instance.new("PointLight",e) li.Color=C.RS_Color li.Range=60 li.Brightness=12
	Ptcl(e,C.RS_Color,30)
	task.spawn(function() while e.Parent do TW:Create(li,TweenInfo.new(0.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Brightness=20}):Play() task.wait(0.4) TW:Create(li,TweenInfo.new(0.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Brightness=8}):Play() task.wait(0.4) end end)
	local lp=Snd(C.RS_Near,10,e,true)
	task.spawn(function() for _=1,rb do Move(e,path,C.RS_Speed,false) if not e.Parent then break end Move(e,path,C.RS_Speed,true) if not e.Parent then break end end lp:Stop() for i=0,10 do if not e.Parent then break end li.Brightness=(10-i)*1.5 task.wait(0.05) end if e.Parent then e:Destroy() end end)
end
local function SpawnIR(isFirst)
	local path=GetRooms() if#path<2 then return end
	local sp=RNode(path[#path])+Vector3.new(0,5,0)
	if isFirst then Snd(C.IR_Arrival,7,workspace) task.wait(5)
	else local gh=Instance.new("Part",EF) gh.Transparency=1 gh.Anchored=true gh.CanCollide=false gh.CFrame=CFrame.new(sp) gh.Size=Vector3.new(1,1,1) Snd(C.IR_Move,9,gh) DB:AddItem(gh,3) task.wait(2) end
	local e,bg=MkEnt(C.IR_Name,C.IR_Face,5,sp)
	Ptcl(e,C.IR_Color,35)
	local sb=Instance.new("SelectionBox",e) sb.Adornee=e sb.Color3=C.IR_Color sb.LineThickness=0.04 sb.SurfaceTransparency=0.8 sb.SurfaceColor3=C.IR_Color
	task.spawn(function() while e.Parent do TW:Create(bg,TweenInfo.new(0.5,Enum.EasingStyle.Sine),{Size=UDim2.new(14,0,14,0)}):Play() task.wait(0.5) TW:Create(bg,TweenInfo.new(0.5,Enum.EasingStyle.Sine),{Size=UDim2.new(10,0,10,0)}):Play() task.wait(0.5) end end)
	local lp=Snd(C.IR_Move,10,e,true,1.2)
	local ec=Instance.new("EchoSoundEffect",lp) ec.Delay=0.12 ec.Feedback=0.25 ec.DryLevel=0 ec.WetLevel=-1
	task.spawn(function() Move(e,path,C.IR_Speed,true) lp:Stop() if e.Parent then e:Destroy() end end)
end
local function SpawnDG()
	if DGA then return end local path=GetRooms() if#path<2 then return end DGA=true
	local sp=RNode(path[#path])+Vector3.new(0,3,0)
	local amb=Snd(C.DG_Ambient,0,workspace,true,0.2) TW:Create(amb,TweenInfo.new(4),{Volume=6}):Play()
	local e,bg=MkEnt(C.DG_Name,C.DG_Face,6,sp)
	local sm=Instance.new("Smoke",e) sm.Color=Color3.fromRGB(60,120,60) sm.Size=20 sm.Opacity=0.5 sm.RiseVelocity=1.5
	Ptcl(e,C.DG_Color,15)
	local li=Instance.new("PointLight",e) li.Color=Color3.fromRGB(100,200,100) li.Range=40 li.Brightness=5
	task.spawn(function() while e and e.Parent do Snd(C.DG_Footstep,4,e,false,0.2) task.wait(1.1) end end)
	task.spawn(function() while e and e.Parent do local ch=LP.Character local hrp=ch and ch:FindFirstChild("HumanoidRootPart") if hrp then local tp=hrp.Position+Vector3.new(0,3,0) local d=(e.Position-tp).Magnitude TW:Create(e,TweenInfo.new(d/C.DG_Speed,Enum.EasingStyle.Linear),{CFrame=CFrame.new(tp)}):Play() end task.wait(0.5) end end)
	task.delay(90,function() if e and e.Parent then TW:Create(amb,TweenInfo.new(3),{Volume=0}):Play() TW:Create(sm,TweenInfo.new(2),{Opacity=0}):Play() task.wait(3) amb:Stop() e:Destroy() DGA=false end end)
end
task.spawn(function()
	while task.wait(C.DTick) do
		local ch=LP.Character if not ch then continue end
		local hum=ch:FindFirstChild("Humanoid") local hrp=ch:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp or hum.Health<=0 then continue end
		local hide=ch:GetAttribute("Hiding")==true local cd=math.huge local cn=nil local kd=false
		for _,e in ipairs(EF:GetChildren()) do
			if not e:IsA("Part") then continue end
			local d=(e.Position-hrp.Position).Magnitude
			if d<cd then cd=d cn=e.Name end
			if d<C.HintThr then
				if e.Name==C.CS_Name then TryHint(e.Name,C.CS_Hint,C.CS_Color)
				elseif e.Name==C.RS_Name then TryHint(e.Name,C.RS_Hint,C.RS_Color)
				elseif e.Name==C.IR_Name then TryHint(e.Name,C.IR_Hint,C.IR_Color)
				elseif e.Name==C.DG_Name then TryHint(e.Name,C.DG_Hint,C.DG_Color) end
			end
			if d<C.ShakeThr then Shake(math.clamp((C.ShakeThr-d)/C.ShakeThr*0.35,0,0.35)) end
			if kd then continue end
			if e.Name==C.IR_Name then
				if hide and d<55 then kd=true hum:SetAttribute("DeathCause",e.Name) hum.Health=0 end
			elseif e.Name==C.DG_Name then
				if d<C.DG_KillRange and not hide and CanSee(e,ch) then if not KDB then KDB=true kd=true DGJump() task.delay(0.5,function() hum:SetAttribute("DeathCause",e.Name) hum.Health=0 end) task.delay(3,function() KDB=false end) end end
			else
				local rng=(e.Name==C.RS_Name)and C.RS_KillRange or C.KillRange
				if d<rng and not hide and CanSee(e,ch) then if not KDB then KDB=true kd=true if e.Name==C.RS_Name then Flash() Snd(C.RS_Jumpscare,10,workspace) end task.delay(0.15,function() hum:SetAttribute("DeathCause",e.Name) hum.Health=0 end) task.delay(3,function() KDB=false end) end end
			end
		end
		if cd<C.ShakeThr then UpdSE(cd,cn) else ClrSE() end
	end
end)
task.spawn(function()
	local lr=RS:WaitForChild("GameData"):WaitForChild("LatestRoom")
	lr.Changed:Connect(function(val)
		if val<=5 then return end
		if not IRA then if RNG:NextInteger(1,100)<=C.IR_Chance then IRA=true IRC=0 end end
		if IRA then IRC=IRC+1 task.spawn(function() SpawnIR(IRC==1) end) if IRC>=2 then IRA=false IRC=0 end end
		if not DGA and RNG:NextInteger(1,100)<=C.DG_Chance then task.spawn(function() task.wait(2) SpawnDG() end) end
		if RNG:NextInteger(1,100)<=C.CS_Chance then task.spawn(function() SpawnCS(5,val) end) end
		if RNG:NextInteger(1,100)<=C.RS_Chance then task.spawn(function() task.wait(1) SpawnRS(C.RS_Rebounds,val) end) end
	end)
end)
LP.CharacterAdded:Connect(function()
	KDB=false ClrSE() if HG then HG:Destroy() HG=nil end
	for _,e in ipairs(EF:GetChildren()) do e:Destroy() end
	IRC=0 IRA=false DGA=false HC={}
end)
print("Craziness Mod v2.1 LOADED")
