--[[ =====================================================================
  PORTAL JURASICO - Constructor del mapa (volcan, senderos, palmeras,
  macizos de flores, portal fosil, vallas de madera e iluminacion).

  COMO USARLO (Studio en modo Edit, NO en Play)
  1. Explorador > ServerStorage > (+) > Script. Renombrarlo: ConstruirMapa
  2. Abrirlo, borrar lo que trae y pegar TODO este codigo.
  3. En la Command Bar pegar esto y apretar Ctrl+Enter:
       loadstring(game.ServerStorage.ConstruirMapa.Source)()
  - Todo queda en un solo paso del historial: si no te gusta, Ctrl+Z.
  - Si algo falla a mitad de camino, se deshace solo y avisa en Salida.
  - Se puede correr de nuevo: borra lo que construyo antes y lo rehace.

  QUE NO TOCA
  - No mueve ni rota las parcelas ni los pads (PadDino/PadCobro/PadMejora).
  - No toca el pasto, el circuito, la maquina de huevos ni el spawn.
  - Las rejas grises viejas NO se borran: se guardan en
    ServerStorage.RejasViejas. La decoracion vieja que quede encima de
    algo nuevo va a ServerStorage.DecoracionRetirada.
===================================================================== ]]

local REEMPLAZAR_REJAS = true -- false = no toca las rejas de las parcelas

local CHS = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

-- ---------------------------------------------------------------------
-- Paleta (todo Plastic con studs)
-- ---------------------------------------------------------------------
local C = {
	piedraClara = Color3.fromRGB(198, 192, 180),
	piedraOscura = Color3.fromRGB(166, 160, 150),
	roca = Color3.fromRGB(105, 100, 102),
	rocaOscura = Color3.fromRGB(72, 70, 72),
	tierra = Color3.fromRGB(130, 84, 54),
	tierraOscura = Color3.fromRGB(100, 64, 42),
	lava = Color3.fromRGB(255, 120, 20),
	lavaClara = Color3.fromRGB(255, 200, 60),
	madera = Color3.fromRGB(142, 100, 64),
	maderaOscura = Color3.fromRGB(104, 72, 46),
	hueso = Color3.fromRGB(238, 230, 206),
	hoja = Color3.fromRGB(80, 160, 70),
	hojaOscura = Color3.fromRGB(42, 115, 52),
	tronco = Color3.fromRGB(156, 110, 68),
	troncoOscuro = Color3.fromRGB(128, 88, 54),
	hierro = Color3.fromRGB(62, 62, 66),
	cartel = Color3.fromRGB(255, 214, 64),
}
local FLORES = {
	Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 210, 40), Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(90, 160, 255), Color3.fromRGB(255, 150, 40),
}

local AV = 6 -- media avenida central (ancho total 12)
local SEN = 4 -- medio sendero hacia las parcelas (ancho total 8)
local LADO_PLAZA = 60 -- plaza cuadrada del volcan

local nPiezas, nLuces = 0, 0
local resumen = {}

-- ---------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------
local function pieza(padre, nombre, size, cf, color, opciones)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	if opciones and opciones.neon then
		p.Material = Enum.Material.Neon
	end
	if opciones and opciones.sinColision then
		p.CanCollide = false
		p.CastShadow = false
	end
	p.Parent = padre
	nPiezas = nPiezas + 1
	return p
end

local function carpeta(padre, nombre)
	local f = padre:FindFirstChild(nombre)
	if not f then
		f = Instance.new("Folder")
		f.Name = nombre
		f.Parent = padre
	end
	return f
end

local function partesDe(inst)
	local lista = {}
	if inst:IsA("BasePart") then
		table.insert(lista, inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(lista, d)
		end
	end
	return lista
end

-- Caja alineada al mundo que envuelve una lista de partes: min, max
local function cajaDe(partes)
	local x0, y0, z0 = math.huge, math.huge, math.huge
	local x1, y1, z1 = -math.huge, -math.huge, -math.huge
	for _, p in ipairs(partes) do
		local cf, s = p.CFrame, p.Size / 2
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local ex = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z
		local ey = math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z
		local ez = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
		local c = cf.Position
		x0 = math.min(x0, c.X - ex); x1 = math.max(x1, c.X + ex)
		y0 = math.min(y0, c.Y - ey); y1 = math.max(y1, c.Y + ey)
		z0 = math.min(z0, c.Z - ez); z1 = math.max(z1, c.Z + ez)
	end
	if x0 == math.huge then
		return nil
	end
	return Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)
end

-- Rectangulos en el piso (X/Z) para no pisar nada
local function rect(xa, xb, za, zb)
	return { x0 = math.min(xa, xb), x1 = math.max(xa, xb), z0 = math.min(za, zb), z1 = math.max(za, zb) }
end
local function rectCentro(x, z, ancho, largo)
	return rect(x - ancho / 2, x + ancho / 2, z - largo / 2, z + largo / 2)
end
local function agrandar(r, m)
	return rect(r.x0 - m, r.x1 + m, r.z0 - m, r.z1 + m)
end
local function solapan(a, b)
	return a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
end
local function chocaCon(r, lista)
	for _, o in ipairs(lista) do
		if solapan(r, o) then
			return true
		end
	end
	return false
end
local function rectDe(inst, margen)
	local mn, mx = cajaDe(partesDe(inst))
	if not mn then
		return nil
	end
	return agrandar(rect(mn.X, mx.X, mn.Z, mx.Z), margen or 0)
end

local function esGris(c)
	local hi = math.max(c.R, c.G, c.B)
	local lo = math.min(c.R, c.G, c.B)
	return (hi - lo) < 0.09 and hi > 0.25 and hi < 0.9
end

-- ---------------------------------------------------------------------
-- Construccion principal
-- ---------------------------------------------------------------------
local function construir()
	local mapa = workspace:FindFirstChild("MapaGranja")
	local baseParcelas = workspace:FindFirstChild("Parcela de base")
	assert(mapa, "No encontre Workspace.MapaGranja")
	assert(baseParcelas, "No encontre Workspace['Parcela de base']")

	-- Limpia lo de una corrida anterior
	local vieja = mapa:FindFirstChild("PlazaJurasica")
	if vieja then
		vieja.Parent = nil
	end
	for i = 1, 8 do
		local p = baseParcelas:FindFirstChild("Parcela" .. i)
		local v = p and p:FindFirstChild("Vallas")
		if v then
			v.Parent = nil
		end
	end

	local raiz = carpeta(mapa, "PlazaJurasica")

	-- Limites de la plaza = interior del circuito
	local plaza = { x0 = -83.2, x1 = 83.2, z0 = -7.2, z1 = 453.2 }
	local circExt = { x0 = -92.8, x1 = 92.8 }
	local circuito = mapa:FindFirstChild("Circuito")
	if circuito then
		local cajas = {}
		for _, n in ipairs({ "Oeste", "Este", "Norte", "Sur" }) do
			local o = circuito:FindFirstChild(n)
			if o then
				local mn, mx = cajaDe(partesDe(o))
				if mn then
					cajas[n] = { mn = mn, mx = mx, c = (mn + mx) / 2 }
				end
			end
		end
		if cajas.Oeste and cajas.Este and cajas.Norte and cajas.Sur then
			local izq, der = cajas.Oeste, cajas.Este
			if izq.c.X > der.c.X then
				izq, der = der, izq
			end
			local aba, arr = cajas.Sur, cajas.Norte
			if aba.c.Z > arr.c.Z then
				aba, arr = arr, aba
			end
			local p = { x0 = izq.mx.X, x1 = der.mn.X, z0 = aba.mx.Z, z1 = arr.mn.Z }
			if p.x1 - p.x0 > 60 and p.z1 - p.z0 > 150 then
				plaza = p
				circExt = { x0 = izq.mn.X, x1 = der.mx.X }
			end
		end
	end

	-- Altura del pasto
	local ySuelo
	local pasto = mapa:FindFirstChild("PASTO")
	local suelo = pasto and pasto:FindFirstChild("SueloStuds")
	local baldosa = suelo and suelo:FindFirstChildWhichIsA("BasePart", true)
	if baldosa then
		ySuelo = baldosa.Position.Y + baldosa.Size.Y / 2
	else
		local res = workspace:Raycast(Vector3.new(0, 1000, (plaza.z0 + plaza.z1) / 2), Vector3.new(0, -2000, 0))
		ySuelo = res and res.Position.Y or 0
	end

	-- Zonas prohibidas: maquina de huevos, huevo, spawn, tienda, etc.
	local prohibidas = {}
	local function prohibir(inst, margen)
		local r = inst and rectDe(inst, margen)
		if r then
			table.insert(prohibidas, r)
		end
	end
	local maquina = workspace:FindFirstChild("Eclosionador")
	local contenedorViejo = workspace:FindFirstChild("Model")
	local maquinaVieja = contenedorViejo and contenedorViejo:FindFirstChild("Neon verde eclosioandor heuvos")
	maquina = maquina or maquinaVieja
	prohibir(workspace:FindFirstChild("Eclosionador"), 6)
	prohibir(maquinaVieja, 6)
	prohibir(workspace:FindFirstChild("HuevoVerde"), 4)
	prohibir(mapa:FindFirstChild("SpawnGranja"), 4)
	prohibir(mapa:FindFirstChild("ZonaCompras"), 4)

	local posSpawn
	local spawnGranja = mapa:FindFirstChild("SpawnGranja")
	if spawnGranja then
		local mn, mx = cajaDe(partesDe(spawnGranja))
		if mn then
			posSpawn = (mn + mx) / 2
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			prohibir(d, 4)
			posSpawn = posSpawn or d.Position
		end
	end

	-- Cualquier otro objeto chico que ya este dentro de la plaza
	local ignorar = {
		Camera = true, Terrain = true, MapaGranja = true, ["Parcela de base"] = true,
		Clutter_Revisar = true, Decoracion = true, Mapa = true, Granjas = true,
	}
	local function revisarSuelto(item)
		if not (item:IsA("Model") or item:IsA("BasePart")) then
			return
		end
		local mn, mx = cajaDe(partesDe(item))
		if not mn then
			return
		end
		local c = (mn + mx) / 2
		local chico = (mx.X - mn.X) < 60 and (mx.Z - mn.Z) < 60
		if chico and c.X > plaza.x0 and c.X < plaza.x1 and c.Z > plaza.z0 and c.Z < plaza.z1 then
			table.insert(prohibidas, agrandar(rect(mn.X, mx.X, mn.Z, mx.Z), 4))
		end
	end
	for _, hijo in ipairs(workspace:GetChildren()) do
		if not ignorar[hijo.Name] then
			if hijo:IsA("Folder") then
				for _, item in ipairs(hijo:GetChildren()) do
					revisarSuelto(item)
				end
			else
				revisarSuelto(hijo)
			end
		end
	end

	-- -----------------------------------------------------------------
	-- Parcelas: perimetro, rejas grises viejas y hueco de la entrada
	-- -----------------------------------------------------------------
	local function esProtegida(d, parcela)
		if parcela:IsA("Model") and d == parcela.PrimaryPart then
			return true
		end
		local a = d
		while a and a ~= parcela do
			local n = a.Name
			if n:match("^Pad") or n:match("^Piso") or n == "Vallas" or n:match("Cartel")
				or n:match("Spawn") or n:match("Entrada") then
				return true
			end
			a = a.Parent
		end
		for _, h in ipairs(d:GetChildren()) do
			if h:IsA("LuaSourceContainer") or h:IsA("ClickDetector") or h:IsA("ProximityPrompt")
				or h:IsA("SurfaceGui") or h:IsA("BillboardGui") then
				return true
			end
		end
		return false
	end

	local function analizarParcela(parcela)
		local todas = {}
		for _, d in ipairs(parcela:GetDescendants()) do
			if d:IsA("BasePart") and not d:FindFirstAncestor("Vallas") then
				table.insert(todas, d)
			end
		end
		local mn, mx = cajaDe(todas)
		if not mn then
			return nil
		end

		local yPiso = ySuelo
		local piso = parcela:FindFirstChild("PisoBaldosas", true)
		if piso then
			local _, pmx = cajaDe(partesDe(piso))
			if pmx then
				yPiso = pmx.Y
			end
		end

		-- Rejas grises: partes grises, altas y pegadas al borde de la parcela
		local rejas = {}
		for _, p in ipairs(todas) do
			if esGris(p.Color) and not esProtegida(p, parcela) then
				local a, b = cajaDe({ p })
				local c = (a + b) / 2
				local cercaBorde = (c.X - mn.X) < 5 or (mx.X - c.X) < 5 or (c.Z - mn.Z) < 5 or (mx.Z - c.Z) < 5
				if cercaBorde and (b.Y - a.Y) >= 1.5 and b.Y > yPiso + 1.5 then
					table.insert(rejas, p)
				end
			end
		end

		-- Si ya se corrio antes, las rejas viejas estan guardadas: sirven de referencia
		local refs = {}
		for _, p in ipairs(rejas) do
			table.insert(refs, p)
		end
		local guardadas = ServerStorage:FindFirstChild("RejasViejas")
		guardadas = guardadas and guardadas:FindFirstChild(parcela.Name)
		if guardadas then
			for _, p in ipairs(partesDe(guardadas)) do
				table.insert(refs, p)
			end
		end

		local pmn, pmx = mn, mx
		if #refs > 0 then
			local rmn, rmx = cajaDe(refs)
			if (rmx.X - rmn.X) > 0.6 * (mx.X - mn.X) and (rmx.Z - rmn.Z) > 0.6 * (mx.Z - mn.Z) then
				pmn, pmx = rmn, rmx
			end
		end

		-- La entrada mira al centro del mapa (X = 0)
		local cx = (pmn.X + pmx.X) / 2
		local frenteEnMin = cx > 0
		local xFrente = frenteEnMin and pmn.X or pmx.X

		-- Busca el hueco mas grande en el lado de la entrada
		local intervalos = {}
		for _, p in ipairs(refs) do
			local a, b = cajaDe({ p })
			if math.abs((a.X + b.X) / 2 - xFrente) < 4 then
				table.insert(intervalos, { a.Z, b.Z })
			end
		end
		local gap0, gap1
		if #intervalos > 0 then
			table.sort(intervalos, function(u, v)
				return u[1] < v[1]
			end)
			local mejor, cursor = 0, pmn.Z
			local function probar(g0, g1)
				if g1 - g0 > mejor then
					mejor = g1 - g0
					gap0, gap1 = g0, g1
				end
			end
			for _, iv in ipairs(intervalos) do
				if iv[1] > cursor + 0.5 then
					probar(cursor, iv[1])
				end
				cursor = math.max(cursor, iv[2])
			end
			if pmx.Z > cursor + 0.5 then
				probar(cursor, pmx.Z)
			end
			if mejor < 6 then
				gap0 = nil
			end
		elseif #refs > 0 then
			gap0, gap1 = pmn.Z, pmx.Z -- el frente ya estaba abierto
		end
		if not gap0 then
			local cz = (pmn.Z + pmx.Z) / 2
			gap0, gap1 = cz - 7, cz + 7
		end

		return {
			parcela = parcela, rejas = rejas, nRefs = #refs, y = yPiso,
			x0 = pmn.X, x1 = pmx.X, z0 = pmn.Z, z1 = pmx.Z,
			frenteEnMin = frenteEnMin, gap0 = gap0, gap1 = gap1, cz = (gap0 + gap1) / 2,
		}
	end

	local parcelas = {}
	for i = 1, 8 do
		local parcela = baseParcelas:FindFirstChild("Parcela" .. i)
		local info = parcela and analizarParcela(parcela)
		if info then
			table.insert(parcelas, info)
		else
			warn("[Mapa] No encontre Parcela" .. i .. " (la salteo)")
		end
	end

	-- Filas de parcelas (una fila = parcela izquierda + derecha a la misma Z)
	local filas = {}
	for _, info in ipairs(parcelas) do
		local fila
		for _, f in ipairs(filas) do
			if math.abs(f.z - info.cz) < 20 then
				fila = f
			end
		end
		if fila then
			table.insert(fila.parcelas, info)
			fila.z = (fila.z * (#fila.parcelas - 1) + info.cz) / #fila.parcelas
		else
			table.insert(filas, { z = info.cz, parcelas = { info } })
		end
	end
	table.sort(filas, function(a, b)
		return a.z < b.z
	end)

	-- -----------------------------------------------------------------
	-- Distribucion (primero se calcula todo, despues se construye)
	-- -----------------------------------------------------------------
	local sendasZ, sendasX = {}, {} -- caminos a lo largo de Z y a lo largo de X
	table.insert(sendasZ, rect(-AV, AV, plaza.z0, plaza.z1))
	for _, f in ipairs(filas) do
		table.insert(sendasX, rect(plaza.x0, -AV, f.z - SEN, f.z + SEN))
		table.insert(sendasX, rect(AV, plaza.x1, f.z - SEN, f.z + SEN))
		for _, info in ipairs(f.parcelas) do
			if info.frenteEnMin and info.x0 > circExt.x1 + 2 then
				table.insert(sendasX, rect(circExt.x1, info.x0, info.cz - SEN, info.cz + SEN))
			elseif not info.frenteEnMin and info.x1 < circExt.x0 - 2 then
				table.insert(sendasX, rect(info.x1, circExt.x0, info.cz - SEN, info.cz + SEN))
			end
		end
	end

	-- Volcan: entre dos filas de parcelas, lo mas al centro posible y sin pisar nada
	local centroZ = (plaza.z0 + plaza.z1) / 2
	local candidatos = {}
	for i = 1, #filas - 1 do
		table.insert(candidatos, (filas[i].z + filas[i + 1].z) / 2)
	end
	table.insert(candidatos, centroZ)
	table.sort(candidatos, function(a, b)
		return math.abs(a - centroZ) < math.abs(b - centroZ)
	end)
	local zVolcan, zonaPlaza
	for _, z in ipairs(candidatos) do
		local r = rectCentro(0, z, LADO_PLAZA, LADO_PLAZA)
		local libre = not chocaCon(agrandar(r, 2), prohibidas)
			and r.z0 > plaza.z0 + 25 and r.z1 < plaza.z1 - 25
		for _, f in ipairs(filas) do
			if math.abs(f.z - z) < LADO_PLAZA / 2 + SEN + 2 then
				libre = false
			end
		end
		if libre then
			zVolcan, zonaPlaza = z, r
			break
		end
	end
	if not zVolcan then
		warn("[Mapa] No encontre lugar libre para el volcan: lo salteo")
	end

	-- Portal: en el borde de la plaza mas cercano al spawn
	local frenteEnZ0 = true
	if posSpawn then
		frenteEnZ0 = posSpawn.Z < centroZ
	end
	local dirIn = frenteEnZ0 and 1 or -1 -- hacia adentro de la plaza
	local zBorde = frenteEnZ0 and plaza.z0 or plaza.z1
	local function rectsPortal(z)
		local lista = {}
		for _, s in ipairs({ -1, 1 }) do
			table.insert(lista, rect(s * 6.6, s * 12.6, z - 2.6, z + 2.6)) -- pilar
			table.insert(lista, rect(s * 6.6, s * 7.6, z + dirIn * 2.5, z + dirIn * 9.5)) -- puerta abierta
		end
		return lista
	end
	local zArco
	for k = 0, 12 do
		local z = zBorde + dirIn * (4 + k * 6)
		local ok = true
		for _, r in ipairs(rectsPortal(z)) do
			if chocaCon(r, prohibidas) then
				ok = false
			end
		end
		if ok then
			zArco = z
			break
		end
	end
	if not zArco then
		warn("[Mapa] No encontre lugar libre para el portal: lo salteo")
	end

	-- Zona de la maquina de huevos: borde de piedra + camino a la avenida
	local anillo, cMaquina
	if maquina then
		local partes = partesDe(maquina)
		local mmn, mmx = cajaDe(partes)
		if mmn then
			cMaquina = (mmn + mmx) / 2
			local huevo = workspace:FindFirstChild("HuevoVerde")
			if huevo then
				local hmn, hmx = cajaDe(partesDe(huevo))
				if hmn and ((hmn + hmx) / 2 - cMaquina).Magnitude < 30 then
					for _, p in ipairs(partesDe(huevo)) do
						table.insert(partes, p)
					end
					mmn, mmx = cajaDe(partes)
				end
			end
			anillo = agrandar(rect(mmn.X, mmx.X, mmn.Z, mmx.Z), 7)
			if cMaquina.X > AV + 10 and anillo.x0 > AV then
				table.insert(sendasX, rect(AV, anillo.x0, cMaquina.Z - SEN, cMaquina.Z + SEN))
			elseif cMaquina.X < -AV - 10 and anillo.x1 < -AV then
				table.insert(sendasX, rect(anillo.x1, -AV, cMaquina.Z - SEN, cMaquina.Z + SEN))
			end
		end
	end

	-- Ocupado = todo lo nuevo (para no encimar cosas entre si)
	local ocupadas = {}
	for _, r in ipairs(sendasZ) do table.insert(ocupadas, r) end
	for _, r in ipairs(sendasX) do table.insert(ocupadas, r) end
	if zonaPlaza then table.insert(ocupadas, zonaPlaza) end
	if zArco then
		table.insert(ocupadas, rect(-13, 13, zArco - 3, zArco + dirIn * 10))
	end
	if anillo then table.insert(ocupadas, anillo) end

	local function dentroPlaza(r)
		return r.x0 > plaza.x0 + 1 and r.x1 < plaza.x1 - 1 and r.z0 > plaza.z0 + 1 and r.z1 < plaza.z1 - 1
	end
	-- Reserva un lugar si esta libre
	local function ubicar(r, dentroDeLaPlazaDelVolcan)
		if not dentroPlaza(r) or chocaCon(r, prohibidas) then
			return false
		end
		for _, o in ipairs(ocupadas) do
			if solapan(r, o) and not (dentroDeLaPlazaDelVolcan and o == zonaPlaza) then
				return false
			end
		end
		table.insert(ocupadas, r)
		return true
	end

	local palmeras, macizos, antorchasPlaza, bancos = {}, {}, {}, {}
	if zVolcan then
		-- 4 palmeras en las esquinas de la plaza + 2 a los costados
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x, z = sx * 25, zVolcan + sz * 25
				if ubicar(rectCentro(x, z, 3, 3), true) then
					table.insert(palmeras, Vector3.new(x, 0, z))
				end
			end
			local x2 = sx * 44
			if ubicar(rectCentro(x2, zVolcan, 4, 4)) then
				table.insert(palmeras, Vector3.new(x2, 0, zVolcan))
			end
		end
		-- Bancos mirando al volcan
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x, z = sx * 24, zVolcan + sz * 8
				if ubicar(rectCentro(x, z, 3, 7), true) then
					table.insert(bancos, Vector3.new(x, 0, z))
				end
			end
		end
		-- Antorchas donde la avenida entra a la plaza
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x, z = sx * 8.5, zVolcan + sz * (LADO_PLAZA / 2 + 1.5)
				if ubicar(rectCentro(x, z, 2, 2)) then
					table.insert(antorchasPlaza, Vector3.new(x, 0, z))
				end
			end
		end
	end

	-- Macizos de flores
	local candMacizos = {}
	if zVolcan then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(candMacizos, Vector3.new(sx * 44, 0, zVolcan + sz * 22))
			end
		end
	end
	if zArco then
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(candMacizos, Vector3.new(sx * 22, 0, zArco + dirIn * 16))
		end
	end
	local cortes = { plaza.z0 }
	for _, f in ipairs(filas) do
		table.insert(cortes, f.z)
	end
	table.insert(cortes, plaza.z1)
	for i = 1, #cortes - 1 do
		local zm = (cortes[i] + cortes[i + 1]) / 2
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(candMacizos, Vector3.new(sx * 20, 0, zm))
		end
	end
	for _, p in ipairs(candMacizos) do
		if ubicar(rectCentro(p.X, p.Z, 8, 8)) then
			table.insert(macizos, p)
		end
	end

	-- -----------------------------------------------------------------
	-- Guarda rejas viejas y decoracion que quede encima de lo nuevo
	-- -----------------------------------------------------------------
	if REEMPLAZAR_REJAS then
		for _, info in ipairs(parcelas) do
			if #info.rejas > 0 then
				local destino = carpeta(carpeta(ServerStorage, "RejasViejas"), info.parcela.Name)
				for _, p in ipairs(info.rejas) do
					p.Parent = destino
				end
			end
			if #info.rejas > 0 then
				table.insert(resumen, info.parcela.Name .. ": " .. #info.rejas .. " partes de reja vieja guardadas")
			end
		end
	end

	local reservadas = {}
	for _, r in ipairs(ocupadas) do
		table.insert(reservadas, agrandar(r, 1))
	end
	local nRetirados = 0
	local function revisarDeco(contenedor, nombreDestino)
		for _, item in ipairs(contenedor:GetChildren()) do
			if item:IsA("Folder") then
				revisarDeco(item, nombreDestino .. "_" .. item.Name)
			elseif item:IsA("Model") or item:IsA("BasePart") then
				local mn, mx = cajaDe(partesDe(item))
				if mn then
					-- solo cuenta el "centro" del objeto (tronco, base), no las hojas
					local c, t = (mn + mx) / 2, (mx - mn) * 0.35
					if chocaCon(rect(c.X - t.X, c.X + t.X, c.Z - t.Z, c.Z + t.Z), reservadas) then
						item.Parent = carpeta(carpeta(ServerStorage, "DecoracionRetirada"), nombreDestino)
						nRetirados = nRetirados + 1
					end
				end
			end
		end
	end
	for _, fuente in ipairs({
		{ mapa:FindFirstChild("DecoracionJurasica"), "DecoracionJurasica" },
		{ mapa:FindFirstChild("Arboles"), "Arboles" },
		{ mapa:FindFirstChild("Palmeras"), "Palmeras" },
		{ workspace:FindFirstChild("Decoracion"), "Decoracion" },
	}) do
		if fuente[1] then
			revisarDeco(fuente[1], fuente[2])
		end
	end
	table.insert(resumen, "Decoracion vieja retirada (estaba encima de lo nuevo): " .. nRetirados)

	-- -----------------------------------------------------------------
	-- Piezas reutilizables
	-- -----------------------------------------------------------------
	local function antorcha(padre, base)
		pieza(padre, "Palo", Vector3.new(0.5, 2.5, 0.5), CFrame.new(base + Vector3.new(0, 1.25, 0)), C.madera)
		pieza(padre, "Brasero", Vector3.new(1.3, 0.5, 1.3), CFrame.new(base + Vector3.new(0, 2.75, 0)), C.hierro)
		local llama = pieza(padre, "Llama", Vector3.new(0.8, 1, 0.8), CFrame.new(base + Vector3.new(0, 3.5, 0)), C.lava, { neon = true, sinColision = true })
		pieza(padre, "LlamaCentro", Vector3.new(0.45, 0.6, 0.45), CFrame.new(base + Vector3.new(0, 4.1, 0)), C.lavaClara, { neon = true, sinColision = true })
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 170, 80)
		luz.Range = 12
		luz.Brightness = 1.5
		luz.Shadows = false
		luz.Parent = llama
		nLuces = nLuces + 1
	end

	local evitarPiso = {}
	for _, r in ipairs(prohibidas) do
		table.insert(evitarPiso, r)
	end
	-- Camino de adoquines: tiras de 4 studs con colores alternados
	local function pavimentar(padre, r, largoEnZ)
		local desde = largoEnZ and r.z0 or r.x0
		local hasta = largoEnZ and r.z1 or r.x1
		local i, a = 0, desde
		while a < hasta - 0.5 do
			local b = math.min(a + 4, hasta)
			local tira = largoEnZ and rect(r.x0, r.x1, a, b) or rect(a, b, r.z0, r.z1)
			if not chocaCon(tira, evitarPiso) then
				local color = (i % 2 == 0) and C.piedraClara or C.piedraOscura
				pieza(padre, "Adoquin",
					Vector3.new(tira.x1 - tira.x0, 0.4, tira.z1 - tira.z0),
					CFrame.new((tira.x0 + tira.x1) / 2, ySuelo + 0.2, (tira.z0 + tira.z1) / 2), color)
			end
			i = i + 1
			a = b
		end
		table.insert(evitarPiso, r) -- para no encimar caminos (parpadean)
	end

	local function palmera(padre, base, semilla)
		local rng = Random.new(semilla)
		local ix, iz = rng:NextNumber(-0.35, 0.35), rng:NextNumber(-0.35, 0.35)
		local h = 2.4
		for i = 1, 6 do
			local c = Vector3.new(base.X + ix * (i - 1), ySuelo + (i - 0.5) * h, base.Z + iz * (i - 1))
			pieza(padre, "Tronco", Vector3.new(2, h, 2), CFrame.new(c), (i % 2 == 0) and C.tronco or C.troncoOscuro)
		end
		local top = Vector3.new(base.X + ix * 5, ySuelo + 6 * h + 0.5, base.Z + iz * 5)
		pieza(padre, "Copa", Vector3.new(2.6, 1.4, 2.6), CFrame.new(top), C.hojaOscura)
		for k = 0, 5 do
			local ang = math.rad(k * 60 + rng:NextNumber(-12, 12))
			local cf = CFrame.new(top) * CFrame.Angles(0, ang, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -4.2)
			pieza(padre, "Hoja", Vector3.new(1.8, 0.5, 8), cf, (k % 2 == 0) and C.hoja or C.hojaOscura, { sinColision = true })
		end
		for _, s in ipairs({ -1, 1 }) do
			pieza(padre, "Coco", Vector3.new(0.9, 0.9, 0.9), CFrame.new(top + Vector3.new(s * 0.9, -1.1, 0.4 * s)), C.tierraOscura, { sinColision = true })
		end
	end

	local function macizo(padre, base, semilla)
		local rng = Random.new(semilla)
		local y = ySuelo
		pieza(padre, "Borde", Vector3.new(8, 0.8, 8), CFrame.new(base.X, y + 0.4, base.Z), C.madera)
		pieza(padre, "Tierra", Vector3.new(7, 0.2, 7), CFrame.new(base.X, y + 0.9, base.Z), C.tierraOscura)
		for _ = 1, 2 do
			local p = Vector3.new(base.X + rng:NextNumber(-2, 2), y + 1.8, base.Z + rng:NextNumber(-2, 2))
			pieza(padre, "Arbusto", Vector3.new(2.2, 1.6, 2.2), CFrame.new(p), C.hojaOscura, { sinColision = true })
		end
		for _ = 1, 6 do
			local x, z = base.X + rng:NextNumber(-2.8, 2.8), base.Z + rng:NextNumber(-2.8, 2.8)
			pieza(padre, "Tallo", Vector3.new(0.3, 1.4, 0.3), CFrame.new(x, y + 1.7, z), C.hoja, { sinColision = true })
			local color = FLORES[rng:NextInteger(1, #FLORES)]
			pieza(padre, "Flor", Vector3.new(1.1, 0.7, 1.1), CFrame.new(x, y + 2.75, z), color, { sinColision = true })
		end
	end

	local function banco(padre, base, mirarA)
		local pos = Vector3.new(base.X, ySuelo + 0.4, base.Z)
		local cf = CFrame.lookAt(pos, Vector3.new(mirarA.X, pos.Y, mirarA.Z))
		pieza(padre, "Asiento", Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.5, 0), C.madera)
		pieza(padre, "Respaldo", Vector3.new(6, 1.8, 0.4), cf * CFrame.new(0, 2.65, 0.8), C.maderaOscura)
		for _, s in ipairs({ -1, 1 }) do
			pieza(padre, "Pata", Vector3.new(0.6, 1.25, 1.6), cf * CFrame.new(s * 2.4, 0.625, 0), C.maderaOscura)
		end
	end

	-- -----------------------------------------------------------------
	-- Construir: senderos
	-- -----------------------------------------------------------------
	local fSendas = carpeta(raiz, "Senderos")
	if zonaPlaza then
		pavimentar(fSendas, zonaPlaza, true) -- piso de la plaza del volcan
	end
	for _, r in ipairs(sendasZ) do
		pavimentar(fSendas, r, true)
	end
	for _, r in ipairs(sendasX) do
		pavimentar(fSendas, r, false)
	end

	-- -----------------------------------------------------------------
	-- Construir: volcan
	-- -----------------------------------------------------------------
	if zVolcan then
		local fV = carpeta(raiz, "Volcan")
		local y0 = ySuelo + 0.4 -- arriba del piso de la plaza
		local pisos = {
			{ lado = 36, alto = 4, color = C.roca },
			{ lado = 31, alto = 5, color = C.tierra },
			{ lado = 25, alto = 5, color = C.tierraOscura },
			{ lado = 19, alto = 5, color = C.tierra },
		}
		local techo = y0
		for _, p in ipairs(pisos) do
			pieza(fV, "Roca", Vector3.new(p.lado, p.alto, p.lado), CFrame.new(0, techo + p.alto / 2, zVolcan), p.color)
			p.base = techo
			techo = techo + p.alto
			p.techo = techo
		end
		-- Crater (anillo de 13 con agujero de 7)
		local crater = { lado = 13, alto = 4, color = C.tierraOscura, base = techo, techo = techo + 4 }
		local yc = techo + 2
		for _, s in ipairs({ -1, 1 }) do
			pieza(fV, "Crater", Vector3.new(13, 4, 3), CFrame.new(0, yc, zVolcan + s * 5), crater.color)
			pieza(fV, "Crater", Vector3.new(3, 4, 7), CFrame.new(s * 5, yc, zVolcan), crater.color)
		end
		local lava = pieza(fV, "Lava", Vector3.new(7, 2.8, 7), CFrame.new(0, techo + 1.4, zVolcan), C.lava, { neon = true })
		local luz = Instance.new("PointLight")
		luz.Color = C.lava
		luz.Range = 22
		luz.Brightness = 3
		luz.Shadows = false
		luz.Parent = lava
		nLuces = nLuces + 1

		-- Rios de lava bajando por dos caras (hacia el portal y hacia un costado)
		table.insert(pisos, crater)
		local centro = Vector3.new(0, 0, zVolcan)
		local haciaPortal = Vector3.new(0, 0, -dirIn)
		for _, dir in ipairs({ haciaPortal, Vector3.new(1, 0, 0) }) do
			local function losa(dist, y, size)
				local pos = centro + dir * dist + Vector3.new(0, y, 0)
				pieza(fV, "RioLava", size, CFrame.lookAt(pos, pos + dir), C.lava, { neon = true, sinColision = true })
			end
			losa(5, crater.techo + 0.15, Vector3.new(3, 0.3, 3)) -- desborde sobre el borde del crater
			for i = #pisos, 1, -1 do
				local p = pisos[i]
				losa(p.lado / 2 + 0.2, p.base + p.alto / 2, Vector3.new(3, p.alto, 0.4)) -- cara vertical
				local abajo = pisos[i - 1]
				if abajo then
					local largo = (abajo.lado - p.lado) / 2
					losa(p.lado / 2 + largo / 2, abajo.techo + 0.15, Vector3.new(3, 0.3, largo)) -- escalon
				end
			end
		end
		-- Rocas de lava en el primer escalon
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				pieza(fV, "RocaLava", Vector3.new(2, 1.4, 2), CFrame.new(sx * 16.8, pisos[1].techo + 0.7, zVolcan + sz * 16.8), C.rocaOscura)
			end
		end

		-- Humo y chispas (sutiles)
		local emisor = pieza(fV, "EmisorHumo", Vector3.new(6, 1, 6), CFrame.new(0, crater.techo + 1, zVolcan), C.roca, { sinColision = true })
		emisor.Transparency = 1
		emisor.CanQuery = false
		emisor.CanTouch = false
		local humo = Instance.new("ParticleEmitter")
		humo.Name = "Humo"
		humo.Texture = "rbxasset://textures/particles/smoke_main.dds"
		humo.Color = ColorSequence.new(Color3.fromRGB(130, 124, 118), Color3.fromRGB(80, 76, 72))
		humo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		humo.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 1),
		})
		humo.Lifetime = NumberRange.new(4, 6)
		humo.Rate = 4
		humo.Speed = NumberRange.new(4, 7)
		humo.SpreadAngle = Vector2.new(12, 12)
		humo.Rotation = NumberRange.new(0, 360)
		humo.RotSpeed = NumberRange.new(-15, 15)
		humo.Acceleration = Vector3.new(1, 0.5, 0)
		humo.Parent = emisor
		local chispas = Instance.new("ParticleEmitter")
		chispas.Name = "Chispas"
		chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		chispas.Color = ColorSequence.new(C.lavaClara, C.lava)
		chispas.LightEmission = 1
		chispas.Size = NumberSequence.new(0.4, 0)
		chispas.Lifetime = NumberRange.new(1, 2)
		chispas.Rate = 3
		chispas.Speed = NumberRange.new(8, 12)
		chispas.SpreadAngle = Vector2.new(20, 20)
		chispas.Acceleration = Vector3.new(0, -15, 0)
		chispas.Parent = emisor

		local fP = carpeta(raiz, "Palmeras")
		for i, p in ipairs(palmeras) do
			palmera(fP, p, i * 17)
		end
		local fB = carpeta(raiz, "Bancos")
		for _, p in ipairs(bancos) do
			banco(fB, p, Vector3.new(0, 0, p.Z))
		end
		local fA = carpeta(raiz, "Antorchas")
		for _, p in ipairs(antorchasPlaza) do
			pieza(fA, "Pedestal", Vector3.new(1.6, 1.2, 1.6), CFrame.new(p.X, ySuelo + 0.6, p.Z), C.roca)
			antorcha(fA, Vector3.new(p.X, ySuelo + 1.2, p.Z))
		end
		table.insert(resumen, string.format("Volcan en Z=%.0f (%d palmeras, %d bancos)", zVolcan, #palmeras, #bancos))
	end

	-- Macizos de flores
	local fM = carpeta(raiz, "Macizos")
	for i, p in ipairs(macizos) do
		macizo(fM, p, i * 31)
	end
	table.insert(resumen, "Macizos de flores: " .. #macizos)

	-- -----------------------------------------------------------------
	-- Construir: portal fosil en la entrada
	-- -----------------------------------------------------------------
	if zArco then
		local fPo = carpeta(raiz, "Portal")
		local y = ySuelo
		for _, s in ipairs({ -1, 1 }) do
			local colores = { C.roca, C.piedraOscura, C.roca }
			for k = 1, 3 do
				local ancho = (k == 2) and 4.6 or 5
				pieza(fPo, "Pilar", Vector3.new(ancho, 6, ancho), CFrame.new(s * 10, y + (k - 0.5) * 6, zArco), colores[k])
			end
			-- Puerta de madera abierta hacia adentro (no tapa la avenida)
			local zp = zArco + dirIn * 6
			pieza(fPo, "Puerta", Vector3.new(0.8, 12, 7), CFrame.new(s * 7.1, y + 6.2, zp), C.madera)
			for _, h in ipairs({ 3, 9 }) do
				pieza(fPo, "Herraje", Vector3.new(0.9, 0.6, 7.1), CFrame.new(s * 7.1, y + h, zp), C.hierro)
			end
			-- Antorcha en la cara de afuera del pilar
			local zAfuera = zArco - dirIn * 3.1
			pieza(fPo, "Soporte", Vector3.new(0.6, 0.6, 1.4), CFrame.new(s * 10, y + 9, zArco - dirIn * 2.6), C.hierro)
			antorcha(fPo, Vector3.new(s * 10, y + 8, zAfuera))
			-- Colmillos de hueso en las puntas de la viga
			pieza(fPo, "Colmillo", Vector3.new(1.6, 3, 1.6), CFrame.new(s * 12, y + 22.5, zArco), C.hueso)
			pieza(fPo, "Colmillo", Vector3.new(1.3, 2.6, 1.3), CFrame.new(s * 12.7, y + 24.7, zArco) * CFrame.Angles(0, 0, -s * math.rad(25)), C.hueso)
			pieza(fPo, "Colmillo", Vector3.new(1, 2, 1), CFrame.new(s * 13.8, y + 26.4, zArco) * CFrame.Angles(0, 0, -s * math.rad(50)), C.hueso)
		end
		pieza(fPo, "Viga", Vector3.new(28, 3, 4.4), CFrame.new(0, y + 19.5, zArco), C.maderaOscura)
		-- Calavera fosil arriba al centro
		pieza(fPo, "Calavera", Vector3.new(4.5, 3.2, 3.4), CFrame.new(0, y + 22.6, zArco), C.hueso)
		for _, s in ipairs({ -1, 1 }) do
			pieza(fPo, "Ojo", Vector3.new(1, 1, 0.3), CFrame.new(s * 1.1, y + 23, zArco - dirIn * 1.75), C.rocaOscura)
		end
		-- Cartel
		local cartel = pieza(fPo, "Cartel", Vector3.new(16, 3, 0.5), CFrame.new(0, y + 16.5, zArco - dirIn * 1.2), C.madera)
		local sg = Instance.new("SurfaceGui")
		sg.Face = (dirIn == 1) and Enum.NormalId.Front or Enum.NormalId.Back -- cara de afuera
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		local texto = Instance.new("TextLabel")
		texto.Size = UDim2.fromScale(1, 1)
		texto.BackgroundTransparency = 1
		texto.Text = "PORTAL JURÁSICO"
		texto.TextScaled = true
		texto.Font = Enum.Font.FredokaOne
		texto.TextColor3 = C.cartel
		texto.TextStrokeTransparency = 0
		texto.TextStrokeColor3 = Color3.fromRGB(60, 35, 20)
		texto.Parent = sg
		sg.Parent = cartel
		table.insert(resumen, string.format("Portal en Z=%.0f", zArco))
	end

	-- -----------------------------------------------------------------
	-- Construir: zona de la maquina de huevos (no se mueve la maquina)
	-- -----------------------------------------------------------------
	if anillo then
		local fZ = carpeta(raiz, "ZonaEclosion")
		local y = ySuelo
		local abiertoHaciaX = cMaquina.X > AV + 10 or cMaquina.X < -AV - 10
		local ladoAbierto -- lado del anillo que mira a la avenida
		if abiertoHaciaX then
			ladoAbierto = (cMaquina.X > 0) and "x0" or "x1"
		else
			ladoAbierto = (dirIn == 1) and "z0" or "z1"
		end
		local function borde(a, b)
			local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			if d.Magnitude < 0.5 then return end
			local m = Vector3.new((a.X + b.X) / 2, y + 0.5, (a.Z + b.Z) / 2)
			pieza(fZ, "Borde", Vector3.new(1, 1, d.Magnitude), CFrame.lookAt(m, m + d.Unit), C.piedraOscura, { sinColision = true })
		end
		local r = anillo
		local mz, mx = (r.z0 + r.z1) / 2, (r.x0 + r.x1) / 2
		local esquinas = {
			x0z0 = Vector3.new(r.x0, 0, r.z0), x0z1 = Vector3.new(r.x0, 0, r.z1),
			x1z0 = Vector3.new(r.x1, 0, r.z0), x1z1 = Vector3.new(r.x1, 0, r.z1),
		}
		local lados = {
			x0 = { esquinas.x0z0, esquinas.x0z1 }, x1 = { esquinas.x1z0, esquinas.x1z1 },
			z0 = { esquinas.x0z0, esquinas.x1z0 }, z1 = { esquinas.x0z1, esquinas.x1z1 },
		}
		for nombre, l in pairs(lados) do
			if nombre == ladoAbierto then
				-- hueco de 8 studs en el medio
				local a, b = l[1], l[2]
				local m = (nombre == "x0" or nombre == "x1") and Vector3.new(a.X, 0, mz) or Vector3.new(mx, 0, a.Z)
				local u = (b - a).Unit
				borde(a, m - u * 4)
				borde(m + u * 4, b)
			else
				borde(l[1], l[2])
			end
		end
		for _, e in pairs(esquinas) do
			pieza(fZ, "Pedestal", Vector3.new(1.6, 1.2, 1.6), CFrame.new(e.X, y + 0.6, e.Z), C.roca)
			antorcha(fZ, Vector3.new(e.X, y + 1.2, e.Z))
		end
	end

	-- -----------------------------------------------------------------
	-- Construir: vallas de madera con postes de hueso en cada parcela
	-- -----------------------------------------------------------------
	local function poste(padre, x, z, y, tipo)
		if tipo == "esquina" then
			pieza(padre, "PosteEsquina", Vector3.new(2, 6.5, 2), CFrame.new(x, y + 3.25, z), C.maderaOscura)
			pieza(padre, "Hueso", Vector3.new(2.6, 0.8, 2.6), CFrame.new(x, y + 6.9, z), C.hueso)
			pieza(padre, "Cuerno", Vector3.new(0.8, 1.4, 0.8), CFrame.new(x, y + 8, z), C.hueso)
		elseif tipo == "entrada" then
			pieza(padre, "PosteEntrada", Vector3.new(1.8, 7, 1.8), CFrame.new(x, y + 3.5, z), C.maderaOscura)
			antorcha(padre, Vector3.new(x, y + 7, z))
		else
			pieza(padre, "Poste", Vector3.new(1.2, 5, 1.2), CFrame.new(x, y + 2.5, z), C.madera)
		end
	end
	local function tramo(padre, a, b, y)
		local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local largo = d.Magnitude
		if largo < 1 then
			return
		end
		local n = math.max(1, math.ceil(largo / 8))
		for k = 1, n - 1 do
			local p = a + d * (k / n)
			poste(padre, p.X, p.Z, y, "normal")
		end
		local m = Vector3.new((a.X + b.X) / 2, 0, (a.Z + b.Z) / 2)
		for _, h in ipairs({ 1.8, 3.8 }) do
			local c = Vector3.new(m.X, y + h, m.Z)
			pieza(padre, "Baranda", Vector3.new(0.5, 0.7, largo), CFrame.lookAt(c, c + d.Unit), C.madera)
		end
	end
	if REEMPLAZAR_REJAS then
		for _, info in ipairs(parcelas) do
			if info.nRefs == 0 then
				-- sin rejas de referencia no se sabe donde esta la entrada: mejor no tapar nada
				warn("[Mapa] No encontre rejas grises en " .. info.parcela.Name .. ": no le puse vallas")
			else
				local padre = carpeta(info.parcela, "Vallas")
				local x0, x1, z0, z1 = info.x0 + 0.75, info.x1 - 0.75, info.z0 + 0.75, info.z1 - 0.75
				local y = info.y
				local xF = info.frenteEnMin and x0 or x1 -- lado de la entrada
				local xT = info.frenteEnMin and x1 or x0 -- lado de atras
				local g0, g1 = math.max(info.gap0, z0), math.min(info.gap1, z1)
				for _, e in ipairs({ { x0, z0 }, { x0, z1 }, { x1, z0 }, { x1, z1 } }) do
					poste(padre, e[1], e[2], y, "esquina")
				end
				tramo(padre, Vector3.new(xT, 0, z0), Vector3.new(xT, 0, z1), y)
				tramo(padre, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), y)
				tramo(padre, Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), y)
				if g0 - z0 > 1.5 then
					tramo(padre, Vector3.new(xF, 0, z0), Vector3.new(xF, 0, g0), y)
					poste(padre, xF, g0, y, "entrada")
				end
				if z1 - g1 > 1.5 then
					tramo(padre, Vector3.new(xF, 0, g1), Vector3.new(xF, 0, z1), y)
					poste(padre, xF, g1, y, "entrada")
				end
			end
		end
	end

	-- -----------------------------------------------------------------
	-- Iluminacion tropical
	-- -----------------------------------------------------------------
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.05
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.Ambient = Color3.fromRGB(95, 85, 75)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
	pcall(function()
		Lighting.Technology = Enum.Technology.ShadowMap -- sombras nitidas
	end)
	local cc = Lighting:FindFirstChild("ColorTropical") or Instance.new("ColorCorrectionEffect")
	cc.Name = "ColorTropical"
	cc.Saturation = 0.15
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 248, 235)
	cc.Parent = Lighting
end

-- ---------------------------------------------------------------------
-- Ejecutar dentro del historial (Ctrl+Z deshace todo junto)
-- Si la Command Bar ya graba su propio paso, TryBeginRecording devuelve
-- nil: igual queda todo en un solo Ctrl+Z.
-- ---------------------------------------------------------------------
if game:GetService("RunService"):IsRunning() then
	warn("[Mapa] Estas en Play: frena el juego (cuadrado rojo) y correlo de nuevo.")
else
	local id = CHS:TryBeginRecording("MapaJurasico", "Mapa Jurasico")
	local ok, err = pcall(construir)
	if ok then
		if id then
			CHS:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
		end
		print("[Mapa] LISTO. Piezas nuevas: " .. nPiezas .. " | Luces: " .. nLuces)
		for _, linea in ipairs(resumen) do
			print("[Mapa] " .. linea)
		end
		print("[Mapa] Si no te gusta: Ctrl+Z")
	elseif id then
		CHS:FinishRecording(id, Enum.FinishRecordingOperation.Cancel)
		warn("[Mapa] ERROR, no se cambio nada: " .. tostring(err))
	else
		warn("[Mapa] ERROR: " .. tostring(err))
		warn("[Mapa] Apreta Ctrl+Z para deshacer lo que alcanzo a hacer.")
	end
end
