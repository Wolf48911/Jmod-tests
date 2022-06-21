-- Jackarunda 2021
AddCSLuaFile()
ENT.Base="ent_jack_gmod_ezresource"
ENT.PrintName="EZ Silver Ingot"
ENT.Category="JMod-EZ Resources"
ENT.IconOverride="materials/ez_resource_icons/silver.png"
ENT.Spawnable=true
ENT.AdminSpawnable=true
---
ENT.EZsupplies=JMod.EZ_RESOURCE_TYPES.SILVER
ENT.JModPreferredCarryAngles=Angle(180,90,-90)
ENT.Model="models/props_mining/ingot001.mdl"
ENT.Material="models/props_mining/ingot_jack_silver"
ENT.Color=Color(150,150,150)
ENT.ModelScale=1.5
ENT.Mass=40
ENT.ImpactNoise1="SolidMetal.ImpactHard"
ENT.DamageThreshold=120
ENT.BreakNoise="SolidMetal.ImpactHard"
---
if(SERVER)then
	function ENT:UseEffect(pos,ent)
		-- it's metal
	end
elseif(CLIENT)then
	function ENT:Draw()
		self:DrawModel()
		JMod.HoloGraphicDisplay(self,Vector(0,-3,4.9),Angle(0,0,0),.025,300,function()
			JMod.StandardResourceDisplay(JMod.EZ_RESOURCE_TYPES.SILVER,self:GetResource(),nil,0,0,200,false,nil,nil,nil,0)
		end)
	end
	language.Add(ENT.ClassName,ENT.PrintName)
end
