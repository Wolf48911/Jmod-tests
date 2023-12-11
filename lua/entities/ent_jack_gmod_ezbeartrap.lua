﻿-- Jackarunda 2021
AddCSLuaFile()
ENT.Type = "anim"
ENT.Author = "Jackarunda"
ENT.Category = "JMod - EZ Misc."
ENT.Information = "glhfggwpezpznore"
ENT.PrintName = "EZ Bear Trap"
ENT.NoSitAllowed = true
ENT.Spawnable = true
ENT.AdminSpawnable = true
---
ENT.JModGUIcolorable = true
ENT.JModEZstorable = true
ENT.EZscannerDanger = true
ENT.JModPreferredCarryAngles = Angle(0, -90, 0)

ENT.BlacklistedNPCs = {"bullseye_strider_focus", "npc_turret_floor", "npc_turret_ceiling", "npc_turret_ground"}

ENT.WhitelistedNPCs = {"npc_rollermine"}

---
local STATE_BROKEN, STATE_CLOSED, STATE_OPEN = -1, 0, 1

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
end

---
if SERVER then
	function ENT:SpawnFunction(ply, tr)
		local SpawnPos = tr.HitPos + tr.HitNormal * 40
		local ent = ents.Create(self.ClassName)
		ent:SetAngles(Angle(0, 0, 0))
		ent:SetPos(SpawnPos)
		JMod.SetEZowner(ent, ply)
		ent:Spawn()
		ent:Activate()

		return ent
	end

	function ENT:Initialize()
		self:SetModel("models/jmod/beartrap01a.mdl")
		--self:SetMaterial("models/jacky_camouflage/digi2")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		self:GetPhysicsObject():SetMass(20)

		---
		timer.Simple(.01, function()
			self:GetPhysicsObject():SetMass(20)
			self:GetPhysicsObject():Wake()
		end)

		---
		self:SetState(STATE_CLOSED)
		self:SetBodygroup(1, 1)

		if istable(WireLib) then
			self.Inputs = WireLib.CreateInputs(self, {"Snap", "Arm"}, {"This will directly Snap the trap", "Arms trap when > 0"})

			self.Outputs = WireLib.CreateOutputs(self, {"State"}, {"-1 is broken \n 0 is closed \n 1 is open \n 2 is triggered"})
		end
		---
		self.StillTicks = 0
		self.PryProgress = 0
		self.PryNeeded = 10
		self.NextPryFail = 0
		self.NextPry = 0

		if self.AutoArm then
			self:NextThink(CurTime() + math.Rand(.1, 1))
		end
	end

	function ENT:TriggerInput(iname, value)
		if iname == "Snap" and value > 0 then
			self:Snap()
		elseif iname == "Arm" and value > 0 then
			self:Arm()
		end
	end

	function ENT:GetTrappedPlayer()
		if self:GetState() ~= STATE_CLOSED then
			self.EZtrappedPlayer = nil

			return nil
		else

			return self.EZtrappedPlayer
		end
	end

	function ENT:PhysicsCollide(data, physobj)
		if (data.DeltaTime > 0.2) then
			if (data.Speed > 10) then
				if (self:GetState() == STATE_OPEN) then
					if self:ShouldSnap(data.HitEntity) then
						self:Snap(data.HitEntity)
					end
				else
					self:EmitSound("Weapon.ImpactHard")
				end
			end
		end
	end

	function ENT:ShouldSnap(ent)
		if IsValid(ent) and ent:IsPlayer() or (table.HasValue(self.WhiteListedNPCs, ent:GetClass()) or not(table.HasValue(self.BlackListedNPCs, ent:GetClass()))) then
			
			return true
		end

		return false
	end

	function ENT:OnTakeDamage(dmginfo)
		self:TakePhysicsDamage(dmginfo)
		local Dam = dmginfo:GetDamage()
		if JMod.LinCh(Dam, 10, 20) then
			local Pos, State = self:GetPos(), self:GetState()

			if State == STATE_OPEN then
				self:Snap()
			end
		end
		
		if Dam > 20 then
			self:SetState(STATE_BROKEN)
			self:SetBodygroup(1, 0)
			self.BrokenRemoveTime = CurTime() + 2
		end
	end

	function ENT:Use(activator)
		local State, Time = self:GetState(), CurTime()
		if State < 0 then return end
		self.AutoArm = false
		local Alt = activator:KeyDown(JMod.Config.General.AltFunctionKey)

		if State == STATE_CLOSED then

			if IsValid(self.EZtrappedPlayer) then
				if self.NextPry < Time then
					self.NextPry = Time + .2
					self.PryProgress = self.PryProgress + JMod.Config.Explosives.BombDisarmSpeed
					self.NextPryFail = Time + 1
					activator:PrintMessage(HUD_PRINTCENTER, "Prying: " .. self.PryProgress .. "/" .. math.ceil(self.PryNeeded))

					if self.PryProgress >= self.PryNeeded then
						self.PryProgress = 0
						self.EZtrappedPlayer = nil
						sound.Play("snds_jack_gmod/beartrap_set.wav", self:GetPos(), 60, math.random(90, 110))
						self:SetBodygroup(1, 0)
						timer.Simple(1, function()
							if IsValid(self) and (self:GetState() == STATE_CLOSED) then self:SetBodygroup(1, 1) end
						end)
					end

					JMod.Hint(activator, "defuse")
				end
			else
				if Alt then
					SafeRemoveEntity(self.Anchor)
					self:SetMaterial("models/jacky_camouflage/digi2")
					JMod.SetEZowner(self, activator)
					net.Start("JMod_ColorAndArm")
					net.WriteEntity(self)
					net.Send(activator)
				else
					SafeRemoveEntity(self.Anchor)
					activator:PickupObject(self)
					JMod.Hint(activator, "arm")
				end
			end
		elseif not (activator.KeyDown and activator:KeyDown(IN_SPEED)) then
			--self:EmitSound("snd_jack_minearm.wav", 60, 70)
			self:SetState(STATE_CLOSED)
			self:SetBodygroup(1, 1)
			JMod.SetEZowner(self, activator)
			self:DrawShadow(true)
			self:SetMaterial("")
			self:SetColor(Color(255, 255, 255))
		end
	end

	function ENT:Snap(victim)
		if (self:GetState() == STATE_CLOSED) then return end
		local SelfPos = self:LocalToWorld(self:OBBCenter())
		if not(IsValid(victim)) then
			local Traec = util.QuickTrace(SelfPos, Vector(0, 0, 5), self)
			victim = Traec.HitEntity
		else
			local SnapDamage = DamageInfo(victim:GetPos())
			SnapDamage:SetDamagePosition(self:GetPos())
			SnapDamage:SetDamageType(DMG_SLASH)
			SnapDamage:SetInflictor(self)
			SnapDamage:SetAttacker(JMod.GetEZowner(self))
			if victim:IsPlayer() then
				JMod.EZimmobilize(victim, 9e9, self)
				self.EZtrappedPlayer = victim
				SnapDamage:SetDamage(20)
			else
				if victim:IsNPC() then
					victim.EZNPCincapacitate = (victim.EZNPCincapacitate or CurTime()) + math.Rand(2, 5)
				end
				SnapDamage:SetDamage(40)
			end
			victim:TakeDamageInfo(SnapDamage)
		end
		sound.Play("snds_jack_gmod/beartrap_snap" .. math.random(1, 2) .. ".wav", SelfPos, 70, math.random(90, 110))
		self:SetBodygroup(1, 1)
		self:SetMaterial("")
		self:SetColor(Color(255, 255, 255))
		-- chance to break
		if (math.random(1, 10) == 5) then
			self:SetState(STATE_BROKEN)
			self.BrokenRemoveTime = CurTime() + 10
			self:SetBodygroup(1, 0)
		else
			self:SetState(STATE_CLOSED)
		end
	end

	function ENT:Arm(armer, autoColor)
		local State = self:GetState()
		if State ~= STATE_CLOSED then return end

		local Tr = util.QuickTrace(self:GetPos(), self:GetUp()*-5, self)
		if Tr.Hit then
			self.Anchor = constraint.Weld(Tr.Entity, self, 0, 0, 10000, false, false)
			--
			if IsValid(self.Anchor) then
				local Fff = EffectData()
				Fff:SetOrigin(Tr.HitPos)
				Fff:SetNormal(Tr.HitNormal)
				Fff:SetScale(1)
				util.Effect("eff_jack_sminebury", Fff, true, true)
				sound.Play("snds_jack_gmod/beartrap_set.wav", self:GetPos(), 60, math.random(90, 110))
				--
				JMod.SetEZowner(self, armer or game.GetWorld())
				self:SetState(STATE_OPEN)
				self:SetBodygroup(1, 0)
				self:RemoveAllDecals()
				self:DrawShadow(false)
			end
		end
	end

	function ENT:Think()
		if istable(WireLib) then
			WireLib.TriggerOutput(self, "State", self:GetState())
		end

		local State, Time = self:GetState(), CurTime()

		if self.NextPryFail < Time then
			self.PryProgress = 0
		end

		if State == STATE_OPEN then
			if not IsValid(self.Anchor) then
				self:Snap()
			end
			self:NextThink(Time + .3)

			return true
		elseif State == STATE_BROKEN then
			if self.BrokenRemoveTime and self.BrokenRemoveTime < Time then
				SafeRemoveEntity(self)
			end

			self:NextThink(Time + 1)

			return true
		elseif self.AutoArm then
			local Vel = self:GetPhysicsObject():GetVelocity()

			if Vel:Length() < 1 then
				self.StillTicks = self.StillTicks + 1
			else
				self.StillTicks = 0
			end

			if self.StillTicks > 4 then
				self:Arm(JMod.GetEZowner(self), true)
			end

			self:NextThink(Time + .5)

			return true
		end
	end

	function ENT:OnRemove()
	end
	--aw fuck you
elseif CLIENT then
	function ENT:Initialize()
	end

	function ENT:Draw()
		self:DrawModel()
		--[[local State, Vary = self:GetState(), math.sin(CurTime() * 50) / 2 + .5

		if State == STATE_OPEN then
		elseif State == STATE_CLOSED then
		end--]]
	end

	language.Add("ent_jack_gmod_ezbeartrap", "EZ Bear Trap")
end
