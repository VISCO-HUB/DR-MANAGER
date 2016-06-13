/* 
	Author: Mastaman
	Version: 1.0.2
	ViscoCG
*/
try(DestroyDialog _DR)catch()	

rollout _DR "visCo | Distributed Rendering Settings" 
(

	global spawnersVer = #("2014", "2016")
	global drPath = @"\\visco.local\data\Instal_Sync\scripts\dr\"
	global drStartup = @"\\visco.local\data\Instal_Sync\scripts\dr\DR_STARTUP.ms"
	global drInstallLnk = @"\\visco.local\data\Instal_Sync\scripts\dr\install_monitor.lnk"
	global drINI = drPath + "dr.ini"
	
	global LOGIN = "visco\jrender"
	global PWD = "!ViscoLviv!"
		
	global cpuPath = @"C:\temp\"
	global cpuINI = cpuPath + "cpu.ini"
	global asyncCpuINI = #((cpuPath + "asunc_cpu1.ini"), (cpuPath + "asunc_cpu2.ini"), (cpuPath + "asunc_cpu3.ini"))
	
	global iCPU = 1
	global bExitState = #none
	
	global Clr = dotNetClass "System.Drawing.Color"	
	global BoldFont = dotNetObject "System.Drawing.Font" "Microsoft Sans Serif" 11 (dotNetClass "System.Drawing.FontStyle").Bold (dotNetClass "System.Drawing.GraphicsUnit").Pixel

	checkbutton btnUpdate "Updating..." width: 87 height: 23 align: #left checked: true offset: [-11, 0] across: 6
	button btnRefresh "Refresh" width: 87 height: 23 align: #left offset: [-25, 0]
	button btnCheckAll "Check All" width: 87 height: 23 align: #right offset: [51, 0]
	button btnCheckFree "Check Free" width: 87 height: 23 align: #right offset: [37, 0]
	button btnLastUsed "Last Used" width: 87 height: 23 align: #right offset: [23, 0]
	button btnUncheckAll "Uncheck All" width: 87 height: 23 align: #right offset: [9, 0]	
	dotNetControl lbxServerList "system.windows.forms.listView" height:589 width: 644 offset: [-10, 0]
	
	
	button btnDropNodes "Drop Nodes" width: 87 height: 23 align: #left offset: [-11, 0] across: 2
	button btnHighlight "Highlight Nodes" width: 87 height: 23 offset: [-233, 0] align: #left enabled: false
	--button btnStartSpawner "Start Spawners" width: 87 height: 23 offset: [-233, 0] align: #left enabled: false
	
	group "Used Nodes:"
	(
		label lblPriority "Priority:" align: #left offset: [-1, 3] across: 3
		dropdownlist ddlPriority ""  width: 60 items: #("Low", "Medium", "High") align: #left offset: [-150, 0]	
		edittext edtComment "Comment:" width: 250 align: #left offset: [-270, 4]	
	)
	
	group "Distributed Rendering Settings:"
	(
		checkbox cbxRestartServersOnRenderEnd "Restart servers on render end" across: 2
		checkbox cbxTransferMissingAssets "Transfer missing assets"
		checkbox cbxUseLocalHost "Use local host" across: 2 checked: true
		checkbox cbxUseCachedAssets "Use cached assets" across: 2 enabled: false
		dropdownlist ddlCacheLimitType "" width: 90 items: #("None", "Age (hours)", "Size (GB)") align: #right offset: [90,0] across: 2 enabled: false
		label lblCacheLimitType  "Cache limit type" align: #right offset: [-140, 3] enabled: false
		button btnResetToDefaults "Reset to defaults" across: 3 align: #left
		spinner spnCacheLimitValue "" width: 60 range: [0.0, 1000000.0, 100] align: #right offset: [-45,0] enabled: false
		label lblCacheLimitValue "Cache limit value" align: #right offset: [-136, 0] enabled: false
	)
	
	button btnOk "Apply" width: 75 height: 23 align: #right offset: [240, 0] across: 2
	button btnCancel "Close" width: 75 height: 23 align: #right offset: [10, 0]
	
	timer tmrUpdate "" active: false interval: 400
	timer trmAsyncUpdate "" active: true interval: 100
	timer tmrAsync "" active: true interval: 10

	fn isVray =
	(
		_Vray = renderers.current
		if(matchPattern (_Vray as string) pattern:"V_Ray_Adv*") do return true
		return false
	)
	
	fn distributedOn s =
	(	
		_Vray = renderers.current
		if(isVray() == true) do _Vray.system_distributedRender = s
	)
	
	fn getCurrMaxVer =
	(
		v = maxVersion()
		v = (v[1] / 1000) - 2
		v = (2000 + v) as string
		return v
	)
	
	fn getMaxCopies =
	(
		Process = dotNetClass " System.Diagnostics.Process"			
		Processes = Process.GetProcesses()
		
		v1 = getCurrMaxVer()
			
		z = #()
		runCopy = true
		
		for i in Processes where i.ProcessName == "3dsmax" and i.MainWindowTitle != undefined do
		(						
			f = " - Autodesk 3ds Max"
			p = findString i.MainWindowTitle f
			
			if(p == undefined) do continue
			
			s = substring i.MainWindowTitle (p + f.count) i.MainWindowTitle.count
				
			f = findString s " x64"
			if(f != undefined) do s = substring s 1 f
			s = trimRight (trimLeft s)

			appendIfUnique z s
		)
		
		f = for i in z where i == v1 collect i
		
		return #(f.count, z)
	)
	
	fn getUser = sysInfo.username
	fn getDr = return getINISetting drINI "DR"
	fn getDrUser s = 
	(	
		u = getINISetting drINI "DR" s
		z = filterString u "|"		

		if(z.count == 0) do z = #("","")
		if(z.count == 1) do z = #(z[1],"")
		
		return z		
	)
	fn setDrUser s del:false = setINISetting drINI "DR" s (if(del == false) then (getUser() + "|" + getCurrMaxVer()) else "")
	fn getCpu s i = return getINISetting asyncCpuINI[i] "CPU" s
	fn getPriority u = return getINISetting drINI "PRIORITY" u

	fn gCPU i =
	(
		case (mod i 2 == 1) of
		(
			false: return 1
			true: return 2
		)
	)
	
	fn findDrByUser dr =
	(
		u = getUser()
		s = #()
		c = #()
		
		for i in dr do
		(
			uu = getDrUser i
			if(u == uu[1]) do 
			(
				append s i
				append c uu[2]
			)
		)
		
		return #(s, c)
	)

	
	fn getComment s =
	(
		u = getDrUser s
		c = getINISetting drINI "COMMENT" u[1]
				
		return c
	)

	fn setComment =
	(
		u = getUser()
		s = filterString edtComment.text "\n"
		
		c = ""
		for i in s do c += i + " "
		
		setINISetting drINI "COMMENT" u c
	)
	
	fn setUsedDR =
	(
		c = lbxServerList.Items.Count - 1
		
		z = ""
		for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined and lbxServerList.Items.Item[i].Checked == true do z += lbxServerList.Items.Item[i].text + "|"
	
		u = getUser()
		if(z != "" and bExitState == #apply) do setINISetting drINI "USED" u z
	)
	
	fn getBool b = if(b == "true") then return true else return false
	fn getInt i = if(i != undefined and i != "0" and i != "") then return i as integer else return 0
	fn getFloat  f = if(f != undefined  and f != "") then return f as float else return 100.0
	fn boolToString b = if(b) then return "1" else return "0"
	
	fn drSettings t:#get =
	(
		u = getUser()
		
		TransferMissingAssets = cbxTransferMissingAssets.checked as string
		UseCachedAssets = cbxUseCachedAssets.checked as string
		CacheLimitType = (ddlCacheLimitType.selection - 1) as string
		CacheLimitValue = spnCacheLimitValue.value as string
		
		RestartServersOnRenderEnd = cbxRestartServersOnRenderEnd.checked as string
		UseLocalHost = cbxUseLocalHost.checked as string
		
		case t of
		(
			#get:
			(
				l = getINISetting drINI "USE_LOCALHOST" u
				UseLocalHost = if(l == undefined or l == "") then true else getBool l
				cbxUseLocalHost.checked  = UseLocalHost
				
				RestartServersOnRenderEnd = getBool (getINISetting drINI "RESTART_SERVERS" u)
				cbxRestartServersOnRenderEnd.checked = RestartServersOnRenderEnd
				
				/* ASSETS */
				
				TransferMissingAssets = getBool (getINISetting drINI "MISSING_ASSET" u)
				cbxTransferMissingAssets.checked = TransferMissingAssets
				
				cbxUseCachedAssets.enabled = TransferMissingAssets
				
				UseCachedAssets = getBool (getINISetting drINI "CACHED_ASSET" u)
				cbxUseCachedAssets.checked  = UseCachedAssets
				
				ddlCacheLimitType.enabled = UseCachedAssets and TransferMissingAssets
				lblCacheLimitType.enabled = UseCachedAssets and TransferMissingAssets
				
				CacheLimitType = getInt (getINISetting drINI "CACHED_LIMIT_TYPE" u)  + 1				
				ddlCacheLimitType.selection = CacheLimitType
				
				spnCacheLimitValue.enabled = CacheLimitType > 1 and TransferMissingAssets and UseCachedAssets
				lblCacheLimitValue.enabled = CacheLimitType > 1 and TransferMissingAssets and UseCachedAssets
				
				CacheLimitValue = getFloat (getINISetting drINI "CACHED_LIMIT_VALUE" u) 
				spnCacheLimitValue.value = CacheLimitValue
			)
			default: 
			(
				setINISetting drINI "MISSING_ASSET" u TransferMissingAssets
				setINISetting drINI "CACHED_ASSET" u UseCachedAssets
				setINISetting drINI "CACHED_LIMIT_TYPE" u CacheLimitType				
				setINISetting drINI "CACHED_LIMIT_VALUE" u CacheLimitValue
								
				setINISetting drINI "USE_LOCALHOST" u UseLocalHost
				setINISetting drINI "RESTART_SERVERS" u RestartServersOnRenderEnd								
			)
		)	 
	)
	
	
	
	fn addNodes =
	(
		u = getUser()		
			
		enabled = getINISetting drINI "OFFLINE" "ENABLE"	
		if(enabled == "false") do return false
		
		distributedOn true

		v = getCurrMaxVer()
		
		dr_cfg = (getDir #plugcfg) + @"\vray_dr.cfg"
		deleteFile dr_cfg
		
		f = openFile dr_cfg mode: "wt"
		format ("") to:f
		flush f
		close f	
		
		dr = getDr()
		udr = #()
		
		for i in dr do
		(		
			uu = getDrUser i
			
			if(uu[1] == undefined or uu[2] == undefined) do continue

			if(uu[1] == u and uu[2] == v) do append udr i		
		)
		
		if(udr.count == 0) do 
		(
			distributedOn false
			return false
		)
			
		f = openFile dr_cfg mode: "wt"
		
		for i in udr where i != undefined do
		(
			format (i + " 1 20204\n") to:f
		)
		
		RestartServersOnRenderEnd = boolToString (cbxRestartServersOnRenderEnd.checked) 
		UseLocalHost = boolToString (cbxUseLocalHost.checked) 		
		TransferMissingAssets = boolToString (cbxTransferMissingAssets.checked) 
		UseCachedAssets = boolToString (cbxUseCachedAssets.checked) 
		CacheLimitType = (ddlCacheLimitType.selection - 1) as string
		CacheLimitValue = spnCacheLimitValue.value as string
		
		format("restart_slaves " + RestartServersOnRenderEnd + "\n")  to:f
		format("list_in_scene 0\n")  to:f
		format("max_servers 0\n")  to:f
		format("use_local_machine " + UseLocalHost + "\n")  to:f
		format("transfer_missing_assets " + TransferMissingAssets + "\n")  to:f
		format("use_cached_assets " + UseCachedAssets + "\n")  to:f
		format("cache_limit_type " + CacheLimitType + "\n")  to:f
		format("cache_limit " + CacheLimitValue + "\n")  to:f

		flush f
		close f
		
	)
	
	fn initDotNet =
	(		
		lbxServerList.Clear()
		lbxServerList.View = (dotNetClass "System.Windows.Forms.View").Details	
		lbxServerList.FullRowSelect = true
		lbxServerList.GridLines = true		
		lbxServerList.ShowItemToolTips = true
		lbxServerList.MultiSelect = true
		lbxServerList.CheckBoxes = true
		lbxServerList.HideSelection = false		
		lbxServerList.Columns.Add "Host name" 150
		lbxServerList.Columns.Add "Status" 70
		lbxServerList.Columns.Add "Priority" 60
		lbxServerList.Columns.Add "Version" 60
		lbxServerList.Columns.Add "User" 110
		lbxServerList.Columns.Add "Comment" 170
			
		lbxServerList.Update()
		lbxServerList.Refresh()

	)
	
	fn setItemColor li id c: #green bold: true =
	(		
		li.UseItemStyleForSubItems = false
		
		b = case c of
		(
			#green: Clr.fromARGB 147 196 125
			#yellow: Clr.fromARGB 255 229 153
			#grey: Clr.fromARGB 202 202 202
			#red: Clr.fromARGB 221 126 107
			#lgreen: Clr.fromARGB 217 234 211
			#lyellow: Clr.fromARGB 255 242 204
			#lred: Clr.fromARGB 230 184 175
		)
		
		f = case c of
		(
			#green: Clr.fromARGB 56 119 44
			#yellow: Clr.fromARGB 205 144 0
			#grey: Clr.fromARGB 102 102 102
			#red: Clr.fromARGB 133 32 12
			#lgreen: Clr.fromARGB 106 168 87
			#lyellow: Clr.fromARGB 241 195 75
			#lred: Clr.fromARGB 204 65 41
		)
		
		li.subitems.item[id].BackColor = b
		li.subitems.item[id].ForeColor = f
		if(bold) do li.subitems.item[id].Font = BoldFont
	)
	
	fn setRenderStatus dr = 
	(
		
		dr = getDr()
		currClr = #grey
		
				
		for s in dr do
		(
			li = lbxServerList.FindItemWithText(s)
			
			if(li == undefined) do continue
			
			szStatus = "Unknown"			
			
			c1 = getCpu s 1
			c2 = getCpu s 2
			c3 = getCpu s 3
				
			c = ""
				
			c = case of
			(
				(c1 == "" and c2 == "" and c3 == "" ): c = ""
				(c1 as integer >= 15): c = "100"
				(c2 as integer >= 15): c = "100"
				(c3 as integer >= 15): c = "100"
				(c1 as integer < 15): c = "0"
				(c2 as integer < 15): c = "0"
				(c3 as integer < 15): c = "0"
				default: c = ""
			)
									
			case of
			(
				(c == ""):
				(
					szStatus = "Unknown"
					currClr = #grey
				)
				(c as integer >= 15): 
				(
					szStatus = "Rendering"
					currClr = #red
				)
				(c as integer < 15): 
				(
					szStatus = "Free"
					currClr = #green
				)
			)
			
			t = li.subitems.item[1].text
			setItemColor li 1 c: currClr
			
			if(t == szStatus) do continue
						
			li.subitems.item[1].text = szStatus
		)
	)
	
	fn setUserStatus dr =
	(
		for s in dr do
		(
			li = lbxServerList.FindItemWithText(s)
			if(li == undefined) do continue
			
			t = li.subitems.item[4].text
			
			u = getDrUser s
			
			if(u[1] != t) do 
			(
				li.subitems.item[4].text = u[1]
				li.subitems.item[3].text = u[2]
			)
		)
	)
	
	fn setCommentStatus dr =
	(
		for s in dr do
		(
			li = lbxServerList.FindItemWithText(s)
			t = li.subitems.item[5].text
			
			c = getComment s
			
			if(c != t) do li.subitems.item[5].text = c
		)
	)
	
	fn setPriorityStatus dr =
	(
		currClr = #lyellow
		dr = getDr()
				
		for s in dr do
		(
			li = lbxServerList.FindItemWithText(s)
			
			if(li == undefined) do continue
			
			
			u = getDrUser s
			p = getPriority u[1]
			
			if(p == "") do p = "Medium"
			
			currClr = case p of 
			(
				default: currClr = #lyellow
				"High": currClr = #lred
				"Low": currClr = #lgreen
			)	
			
			t = li.subitems.item[2].text
			setItemColor li 2 c: currClr
			
			if(t == p) do continue
						
			li.subitems.item[2].text = p
		)
	)
	
	fn addToLbxList r =
	(
		lbxServerList.Items.Clear()
		rows = #()	

		usedNodes = false
		
		for x in r do	
		(
			li = dotNetObject "System.Windows.Forms.ListViewItem" ""
			li.text = x
			
			u = getDrUser x
			v = getCurrMaxVer()
			if(u[1] == getUser() and u[2] == v) then 
			(
				li.checked = true
				usedNodes = true
			)
						
			li.subitems.add "Unknown"
			setItemColor li 1 c: #grey
											
			li.subitems.add "Medium"
			setItemColor li 2 c: #lyellow
			
			li.subitems.add u[2]
				
			li.subitems.add u[1]
			
			li.subitems.add (getComment x)
		
			append rows li		
		)
			
		lbxServerList.Items.addRange rows
		
		return usedNodes
	)

	fn getVisible =
	(
		c = lbxServerList.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined and lbxServerList.Items.Item[i].Checked == true do
		(
			lbxServerList.EnsureVisible(i)
			exit
		)
	)

	fn getCheckedLbxList =
	(
		c = lbxServerList.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined and lbxServerList.Items.Item[i].Checked == true collect lbxServerList.Items.Item[i].Text	
		return z					
	)
	
	fn setSelectedLbxList s =
	(
		c = lbxServerList.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined do
		(
			q = false
			if(findItem s (lbxServerList.Items.Item[i].Text) != 0 ) do q = true
			
			lbxServerList.Items.Item[i].Selected = q						
		)
	)
	

	fn uncheckAll =
	(
		c = lbxServerList.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined do lbxServerList.Items.Item[i].Checked = false 
	)
	
	fn setCheckedLbxList s =
	(
		v = getCurrMaxVer()
		
		uncheckAll()
		
		for i in s do 
		(
			li = lbxServerList.FindItemWithText(i)
			if(li == undefined) do continue
			
			vv = li.subitems.item[3].text			
			if(vv == v) do li.Checked = true					
		)
	)
	
	fn checkAll =
	(
		u = getUser()
		c = lbxServerList.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined do 
		(	
			uu = lbxServerList.Items.Item[i].subitems.item[3].text
			
			if(uu == "" or uu == u) do lbxServerList.Items.Item[i].Checked = true 
		)
	)
	
	fn checkFree =
	(
		uncheckAll()
		
		u = getUser()
		c = lbxServerList.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined do 
		(	
			uu = lbxServerList.Items.Item[i].subitems.item[3].text
			f = lbxServerList.Items.Item[i].subitems.item[1].text
			
			if((uu == "" or uu == u) and f == "Free") do lbxServerList.Items.Item[i].Checked = true 
		)
	)
	
	fn checkLastUsed =
	(
		uncheckAll()
		
		u = getUser()
		
		l = getINISetting drINI "USED" u
		ll = filterString l "|"
		
		c = lbxServerList.Items.Count - 1
		z = for i = 0 to c where c > 0 and lbxServerList.Items.Item[i] != undefined do 
		(	
			t = lbxServerList.Items.Item[i].text
			
			if(findItem ll t != 0) do lbxServerList.Items.Item[i].Checked = true 
		)
	)
		
	fn setUnchecked s = 
	(		
		u = getUser()
		m = getMaxCopies()
		v = getCurrMaxVer()
		
		maxVersions = #()
		userNodes = #()
		for i in s do
		(
			n = getDrUser i
			if(n[1] == u) do
			(
				append userNodes i
				appendIfUnique maxVersions n[2]
			)
		)
		
		if(m[2].count > 1 and (maxVersions.count > 1 or maxVersions[1] != v)) do 
		(
			q = queryBox "Keep nodes for other opened 3Ds Max versions?"
			if(q == true) do return false
		)
		
		for i in userNodes do
		(			
			item = lbxServerList.FindItemWithText(i)		
			if(item != undefined) do if(lbxServerList.Items.Item[item.index].Checked == false) do setDrUser i del:true
		)
	)
	
	fn setPriority =
	(
		u = getUser()
		setINISetting drINI "PRIORITY" u (ddlPriority.selected)
	)

	fn saveChecked = 
	(		
		z = getCheckedLbxList()
		
		u = getUser()
		
		bError = false
		
		for i in z do
		(
			n = getDrUser i
			if(n[1] == "" or n[1] == u) then setDrUser i else bError = true				
		)
		
		return bError
	)
		
	fn disableUI d =
	(		
		for i in _DR.controls do i.enabled = d
		_DR.btnCancel.enabled = true
		--_DR.lblStatus.enabled = true
	)
	
	fn getOffLine = 
	(
		disableUI true
		
		drSettings t:#get
		
		enabled = getINISetting drINI "OFFLINE" "ENABLE"				
		if(enabled == "false") do 
		(
			disableUI false
			return messageBox (getINISetting drINI "OFFLINE" "MESSAGE") title: "Offline!" beep: false
		)	
	)
	
	/* -- OLD FUNCTION
	fn getCpuUsage =
	(	
		makeDir cpuPath
		deleteFile cpuINI

		if(not doesFileExist drINI) do return undefined
		
		s = getDr()

		HiddenDOSCommand ("ECHO [CPU] > \"" + cpuINI + "\"") 

		for i in s do
		(
			cmd = "FOR /F \"SKIP=1\" %a IN ('WMIC /NODE: \"" + i + "\" /USER: visco\jrender /PASSWORD: !ViscoLviv! CPU GET LOADPERCENTAGE') DO IF %a GTR 0 ECHO " + i + "=%a >> \"" + cpuINI +"\""
			HiddenDOSCommand cmd donotwait: true 
		)

		if (doesFileExist drINI) do return cpuINI
		
		return undefined
	)
	*/
	fn updateLbxList =
	(					
		t = try(lbxServerList.TopItem.index)catch(0)
		
		s = getDr()
		
		addToLbxList s
						
		setRenderStatus s
		setPriorityStatus s
		
		try(lbxServerList.TopItem = lbxServerList.Items.Item[t])catch()
		
		getOffLine()
	)
	
	fn dropNodes s = 
	(
		q = queryBox "Do you really want to drop nodes?"
		if(q == false) do return false
		
		foundUser = #()
		v = getCurrMaxVer()
		
		foundUser = findDrByUser s
		
		verCnt = makeUniqueArray foundUser[2]
		
		if(verCnt.count > 1) do 
		(
			q = queryBox "Drop nodes for all 3Ds Max versions?"
			if(q == false) do 
			(
				for i in 1 to foundUser[1].count where foundUser[2][i] == v do setDrUser foundUser[1][i] del:true			
				return false
			)
		)
				
		for i in foundUser[1] do setDrUser i del:true
	)
	/*
	fn stopSpawners s =
	(
		ps = @"\\visco.local\data\Instal_Sync\PsService.exe"
		
		for v in spawnersVer do
		(
			for i in s do
			(			
				cmd = ps + @" \\" + i + " -u " + LOGIN + " -p " + PWD + " stop \"VRaySpawner " + v + "\""				
				
				HiddenDOSCommand cmd donotwait: true prompt: ""
			)
		)	
	)*/
	/*
	fn startSpawners s =
	(
		f = findDrByUser s
		v = getCurrMaxVer()
		
		c = makeUniqueArray f[2]
		ps = @"\\visco.local\data\Instal_Sync\PsService.exe"
		
		stopSpawners f[1]
		
		for i in 1 to f[1].count where f[2][i] == v do
		(
			cmd = ps + @" \\" + f[1][i] + " -u " + LOGIN + " -p " + PWD + " stop \"VRaySpawner " + v + "\""
			
			HiddenDOSCommand cmd donotwait: true prompt: ""
		)
	)*/
	
	/* MAIN UPDATE FUNCTION */
	global asyncCpu = 1
	
	on trmAsyncUpdate tick do
	(
		s = getDr()
		
		if(s.count == 0) do return false
		
		--lblStatus.caption = "Please wait, updating servers status..."
		btnUpdate.caption = "Updating..."
		
		if(iCPU > 3) do 
		(
			iCPU = 1
			--lblStatus.caption = "Server status updated!"
			btnUpdate.checked = false
			btnUpdate.caption = "Update Status"
			trmAsyncUpdate.active = false			
		)
		
		c = iCPU --gCPU (iCPU)
		
		if(asyncCpu == 1) then 
		(									
			makeDir cpuPath			
			HiddenDOSCommand ("ECHO [CPU] > \"" + asyncCpuINI[c] + "\"") prompt: ""						
		)
				
		cmd = "FOR /F \"SKIP=1\" %a IN ('WMIC /NODE: \"" + s[asyncCpu] + "\" /USER: " + LOGIN + " /PASSWORD: " +  PWD + " CPU GET LOADPERCENTAGE') DO IF %a GTR -1 ECHO " + s[asyncCpu] + "=%a >> \"" + asyncCpuINI[c] + "\""		
		HiddenDOSCommand cmd donotwait: true prompt: ""
						
		-- Update Render Status status
	
		if(asyncCpu >= s.count) then 
		(
			asyncCpu = 1			
			setRenderStatus s	
		)
		else asyncCpu += 1
		
		if(asyncCpu == 1) do iCPU += 1			
	)
	
	on tmrAsync tick do
	(
		s = getDr()
		
		setPriorityStatus s
		setUserStatus s
		setCommentStatus s
		
		c = findDrByUser s		
		setCheckedLbxList c[1]
		
		
		getOffLine()
		tmrAsync.active = false
	)
	
	/* -- OLD FUNCTION
	global iCpu = 0
	global iRetry = 0
	global iTmrCnt = 1
	
	on tmrUpdate tick do
	(				
		lblStatus.caption = "Udpate server status... "
		c = getINISetting cpuINI "CPU"
		
		if(c.count == iCpu) do iRetry += 1
		
		if(iTmrCnt == 1 and getCpuUsage() == undefined) do 
		(
			lblStatus.caption = "Failed to update server staus!"
			disableUI true
			tmrUpdate.active = false
			return false
		)
				
		if(iRetry > 2) do
		(
			iTmrCnt = 1
			iCpu = 0
			iRetry = 0
		
			updateLbxList()
			disableUI true
			lblStatus.caption = "Server status updated"			
			tmrUpdate.active = false
		)
		
		
		if(iTmrCnt > 10) do
		(
			lblStatus.caption = "Update server status timeout! Please try again..."
			disableUI true
			tmrUpdate.active = false
		)
		
		iTmrCnt += 1
		iCpu = c.count							
	)
	*/
	
	fn writeFile f s =
	(			
		f = createFile f mode: "wt"

		format(s as string) to:f

		flush f
		close f
	)
	
	on _DR open do
	(								
		initDotNet()
		
		ddlPriority.selection = 2
		
		deleteFile asyncCpuINI[1]
		deleteFile asyncCpuINI[2]
		deleteFile asyncCpuINI[3]
		
		drSettings t:#get	
		
		updateLbxList()	

		startupScripts = (getDir #startupScripts) + @"\"
		monitorScript = startupScripts + (filenameFromPath  drStartup)
		
		if(not doesFileExist monitorScript) do
		(
			f = @"c:\temp\"
			makeDir f
			f += "install.bat"
			s = "xcopy \"" + drStartup + "\" \"" + startupScripts  + "\" /Y"
				
			writeFile f s
		
			HiddenDOSCommand drInstallLnk 
			
			try(fileIn monitorScript) catch
			(
				destroyDialog _DR
				messageBox "DR Monitor is not running!!\nThis may lead to malfunction!" title: "Warning!"
			)						
		)		
	)
	
	on _DR close do
	(		
		setUsedDR()
	)
	
	on btnUpdate changed x do 
	(	
		trmAsyncUpdate.active = x
		
		--if(x == false) do lblStatus.caption = "Update status disabled..."
		if(x == false) do btnUpdate.caption = "Update Status"
		
		updateLbxList()				
	)
	
	on btnRefresh pressed do tmrAsync.active = true
	
	on btnCancel pressed do 
	(	
		--bExitState = #cancel
		try(DestroyDialog _DR)catch()
	)

	on btnCheckAll pressed do checkAll()
	on btnUncheckAll pressed do uncheckAll()
	on btnCheckFree pressed do checkFree()
	on btnLastUsed pressed do checkLastUsed()
	on btnDropNodes pressed do
	(
		dr = getDr()
		
		dropNodes dr
		
		tmrAsync.active = true
	)
	
	on btnHighlight pressed do
	(
		s = getDr()
		u = findDrByUser s
		setSelectedLbxList u[1]
		lbxServerList.Focus()
	)
	
	on btnStartSpawner pressed do
	(
		dr = getDr()
		
		startSpawners dr
	)
	
	on btnOk pressed do
	(	
		if(saveChecked() == true) do messageBox "Some servers already used!" title: "Warning!"
		
		s = getDr()
		
		setUnchecked s
		setPriority()
							
		setRenderStatus s
		setPriorityStatus s
		setComment()
		
		drSettings t:#set
		
		updateLbxList()	
		
		addNodes()
		
		bExitState = #apply		
	)
	
	on cbxTransferMissingAssets changed x do
	(
		i = ddlCacheLimitType.selection
		ii = cbxUseCachedAssets.checked
		
		cbxUseCachedAssets.enabled = x
		
		
		ddlCacheLimitType.enabled = x and ii 
		lblCacheLimitType.enabled = x and ii
		spnCacheLimitValue.enabled = x and i != 1
		lblCacheLimitValue.enabled = x and i != 1		
	)
	
	on cbxUseCachedAssets changed x do
	(
		i = ddlCacheLimitType.selection
		
		ddlCacheLimitType.enabled = x
		lblCacheLimitType.enabled = x
		spnCacheLimitValue.enabled = x and i != 1
		lblCacheLimitValue.enabled = x and i != 1
	)
	
	on ddlCacheLimitType selected x do
	(
		i = ddlCacheLimitType.selection
		
		spnCacheLimitValue.enabled = (i != 1)
		lblCacheLimitValue.enabled = (i != 1)
	)
	
	on btnResetToDefaults pressed do
	(
		cbxRestartServersOnRenderEnd.checked = false
		cbxUseLocalHost.checked = true
		cbxTransferMissingAssets.checked = false
		cbxUseCachedAssets.checked = false
		ddlCacheLimitType.selection = 1
		spnCacheLimitValue.value = 100.0
		
		cbxUseCachedAssets.enabled = false
		ddlCacheLimitType.enabled = false
		spnCacheLimitValue.enabled = false
		lblCacheLimitType.enabled = false
		lblCacheLimitValue.enabled = false
		
		drSettings t:#set
		drSettings t:#get
	)
)

createDialog _DR 650 853 modal: true
