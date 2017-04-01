--[[
	enemy生成、管理、销毁
--]]
local GameObject = UnityEngine.GameObject
local Sequence = DG.Tweening.Sequence
local Tweener = DG.Tweening.Tweener
local DOTween = DG.Tweening.DOTween
local UpdateBeat = UpdateBeat

local enemy_mgr = {}
local TAG = "enemy_mgr"
local this = enemy_mgr

function enemy_mgr.init()

	this.UID = 0
	this.enemys = {}

	-- update
	UpdateBeat:Add(this.Update, this)
end

function enemy_mgr.create(id)

	local monster = chMgr:AddEnemy(1001, math.random(6, 40), 0, math.random(6, 12))
	monster.ID = this.UID
	this.UID = this.UID + 1

	local transform = monster.transform

	local bar = ObjectPool.Spawn('HealthBar', battle.canvas)
	local follow = bar:GetComponent('Follow')
	follow.target = transform
	follow.offset = Vector3.New(0, 1, 0)

	local slider = bar.transform:Find('Slider'):GetComponent('Slider') 
	slider.value = 1

	this.enemys[monster.ID] = {monster, monster.gameObject, transform, bar, slider}
end

function enemy_mgr.Update()
	local n = 0
	for k in pairs(this.enemys) do
		if this.enemys[k] then n = n + 1 end
	end

	if n < 3 then
		this.create(1001)
	end
end

function enemy_mgr.get_enemy(id)
	local id = tonumber(id)
	return this.enemys[id]
end


function enemy_mgr.enemy_hit(id, attack)
	local id = tonumber(id)
	local enemy = this.enemys[id]
	if enemy == nil then return nil end
	
	if enemy[1].HP == 0 then return nil end

	local hp = math.max(0, enemy[1].HP - attack)
	enemy[1].HP = hp
	enemy[5].value = hp / 100

	if hp == 0 then 
		-- die, balance
		this.enemy_die(id)

		local pos = enemy[3].position+Vector3.New(0, 0.5, 0)
   	 	local item = ObjectPool.Spawn('Coin', pos).transform
		Util.ChangeLayers(item, 'Item')
		
		local rot = item:DORotate(Vector3.New(0, 720, 0), 1, DG.Tweening.RotateMode.FastBeyond360)
		local move = item:DOMoveY(pos.y+1.5, 1, false)

		local sequence = DOTween.Sequence()
		sequence:Append(rot)
		sequence:Join(move)
		sequence:AppendCallback(DG.Tweening.TweenCallback(function ()
			item:SetParent(battle.canvas_ui)
			local spos = battle.camera:WorldToScreenPoint(pos)
			local wpos = battle.camera_ui:ScreenToWorldPoint(spos)
			--wpos.z = 0
			item.position = wpos
			Util.ChangeLayers(item, 'UI')

			local move = item:DOLocalMove(Vector3.New(-400, 250, 0), 1, false)
			local sequence = DOTween.Sequence()
			sequence:Append(move)
			sequence:AppendCallback(DG.Tweening.TweenCallback(function ()
				ObjectPool.Recycle(item.gameObject)
			end))
			sequence:SetAutoKill()

		end))
		sequence:Play()
		sequence:SetAutoKill()
	end

	return enemy
end

function enemy_mgr.enemy_die(id)
	local id = tonumber(id)
	local enemy = this.enemys[id]
	if enemy == nil then return end


	enemy[1]:ActDie()		
	
	-- remove bar
	ObjectPool.Recycle(enemy[4])

	local renderer = enemy[2]:GetComponentInChildren(typeof(UnityEngine.SkinnedMeshRenderer))
	local mat = renderer.material

	alpha = mat:DOFade(0, 2)
	
	local sequence = DOTween.Sequence()
	sequence:AppendInterval(1)
	sequence:Append(alpha)
	sequence:AppendCallback(DG.Tweening.TweenCallback(function ()
		-- remove
		chMgr:Remove(enemy[1])
		this.enemys[id] = nil
	end))
	sequence:Play()
end


_G['enemy_mgr'] = enemy_mgr

return enemy_mgr