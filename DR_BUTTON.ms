/*
	Floating button for visCo Distributed Rendering
	1.0.4
	MastaMan 
*/

try(DestroyDialog _DR_STARTUP)catch()

global _DR_STARTUP
global _DR_STARTUP_POS = [0,0]
global _DR_RUN = "DR_UI.ms"
global _DR_LAUNCHER = @"\\visco.local\data\Instal_Sync\scripts\MENU.ms"
global drPath = @"\\visco.local\data\Instal_Sync\scripts\dr\"
global drINI = drPath + "dr.ini"
global drSettingsINI = @"c:\temp\dr_settings.ini"

fn getCurrMaxVer =
(
	v = maxVersion()
	v = (v[1] / 1000) - 2
	v = (2000 + v) as string
	return v
)

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

		append z s
	)
	
	f = for i in z where i == v1 collect i
	
	return #(f.count, (makeUniqueArray z))
)

fn restartDRScript = 
(
	_DR_STARTUP.tmrReload.active = true
)

fn deleteUser =
(
	r = getMaxCopies()
	v = getCurrMaxVer()
	
	if(r[1] > 1) do return false
	
	u = sysInfo.username	
		
	dr = getINISetting drINI "DR"
		
	for i in dr do
	(
		z = getINISetting drINI "DR" i
		uu = FilterString z "|"
		if(uu[1] == undefined) do continue
		
		if(r[2].count > 1 and uu[1] == u and uu[2] == v) then setINISetting drINI "DR" i ""
		else if(uu[1] == u) then setINISetting drINI "DR" i ""
	)
		
	dr_cfg = (getDir #plugcfg) + @"\vray_dr.cfg"
	
	f = openFile dr_cfg mode: "wt"
	format ("") to:f
	flush f
	close f	
	
	deleteFile dr_cfg
	
	distributedOn false
)

fn getMaxVersion =
(
	v = maxVersion()
	v = (v[1] / 1000) - 2
	v = (2000 + v) as string
	return v
)

global _DR_LOGIN
global _DR_ADMIN

fn getRunCopies =
(
	Process = dotNetClass " System.Diagnostics.Process"			
	Processes = Process.GetProcesses()
	
	c = #()
	runCopy = true
	
	for i in Processes where i.ProcessName == "3dsmax" do
	(		
		s = (filterString i.MainWindowTitle "x ")
	
		runCopy = appendIfUnique c s[s.count-1]
	)

		
	return #(runCopy, c.count)
)

fn shutdown =
(
	callbacks.removescripts id:#fwdSetDRWindowPos	
	try(destroyDialog _DR_STARTUP)catch()
)

fn admin =
(
	try(destroyDialog _DR_ADMIN)catch()

	global admin_signin_l = ""
	global admin_signin_p = ""
	
	rollout _DR_LOGIN "Login"
	(
		label lblLogin "Login:" align: #left
		edittext edtLogin ""
		label lblPassword "Password:" align: #left
		edittext edtPassword ""
		button btnSign "Sign In"
		
		on edtPassword changed x do
		(
			admin_signin_p += trimLeft x "*"
			
			z = ""		
			for i in 1 to admin_signin_p.count do z += "*"
			edtPassword.text = z
		)
		
		on edtLogin changed x do admin_signin_l = edtLogin.text
	
		on btnSign pressed do
		(								
			try(destroyDialog _DR_ADMIN)catch()
			
			rollout _DR_ADMIN "Admin Panel"
			(	
				listbox lbxUsers "Users:" height: 22
				button btnDelUser "Remove" across: 2
				button btnUpdateUser "Update"
				group "Offline Service"
				(
					edittext edtOfflineMessage "" text:"Service under maintance!"
					checkbutton btnDisable "Online"
				)
				
				fn updateAdmin =
				(					
					u = sysInfo.username	
										
					dr = getINISetting drINI "DR"
					udr = for i in dr collect getINISetting drINI "DR" i
					udr = makeUniqueArray udr
					
					lbxUsers.items = udr
				)
				
				on _DR_ADMIN open do
				(
					if(admin_signin_l != "admin" or admin_signin_p != "renderfarm") do try(destroyDialog _DR_ADMIN)catch()
					try(destroyDialog _DR_LOGIN)catch()
					
					updateAdmin()
					
					enabled = getINISetting drINI "OFFLINE" "ENABLE"	
					btnDisable.checked = if(enabled == "false") then false else true
					
					if(enabled == "false") do btnDisable.caption = "Offline"
					edtOfflineMessage.text = getINISetting drINI "OFFLINE" "MESSAGE"	
				)
				
				on btnDelUser pressed do
				(
					l = lbxUsers.selected 
					if(l == undefined) do return false
					
					u = sysInfo.username	
										
					dr = getINISetting drINI "DR"
					
					for i in dr where (getINISetting drINI "DR" i) == l do setINISetting drINI "DR" i ""
					
					updateAdmin()
				)
				
				on btnUpdateUser pressed do
				(
					updateAdmin()
				)
				
				on btnDisable changed x do
				(
					btnDisable.caption = "Offline"
					if(x) do btnDisable.caption = "Online"
					setINISetting drINI "OFFLINE" "ENABLE" (x as string)
					setINISetting drINI "OFFLINE" "MESSAGE" (edtOfflineMessage.text)
				)
			)
			
			createDialog _DR_ADMIN 220 450
			
			admin_signin_l = ""
			admin_signin_p = ""
			edtLogin.text = ""
			edtPassword.text = ""
		)
		
		on _DR_LOGIN close do
		(
			admin_signin_p = ""
			edtLogin.text = ""
			edtPassword.text = ""
		)
	)
	
	createDialog _DR_LOGIN 150 125
)

fn addNodes =
(
	u = sysInfo.username		
		
	enabled = getINISetting drINI "OFFLINE" "ENABLE"	
	if(enabled == "false") do return false
	
	v = getCurrMaxVer()
		
	dr = getINISetting drINI "DR"
	udr = #()
	for i in dr do
	(
		z = getINISetting drINI "DR" i
		uu = filterString z "|"
		
		if(uu[1] == undefined or uu[2] == undefined) do continue

		if(uu[1] == u and uu[2] == v) do append udr i		
	)
	
	if(udr.count == 0) do 
	(		
		dr_cfg = (getDir #plugcfg) + @"\vray_dr.cfg"
		deleteFile dr_cfg
		
		f = openFile dr_cfg mode: "wt"
		format ("") to:f
		flush f
		close f	
		
		return false
	)	
)

rollout _DR_STARTUP ""
(
	imgTag btnOpenMonitor "Render Farm" height: 24 width: 28 pos: [0,0] 
	imgTag btnOpenLauncher "M" height: 24 width: 28 pos: [28, 0] 
	timer tmrReload "" active: false interval: 3000

	on tmrReload tick do
	(
		try(fileIn(getThisScriptFilename()))catch()
			
		tmrReload.active = false
	)
	
	fn setImg a p =
	(
		drScriptPath = getFilenamePath (getThisScriptFilename())
		b = openBitMap (drScriptPath  + p)			
		a.bitmap = b		
	)
	
	fn moveToolBar side: #left = 
	(
		if(not keyboard.shiftPressed) do return false
		
		d = sysInfo.desktopSize
		
	
		o = GetDialogPos _DR_STARTUP		
		x = 0
		print d[1]
		print o[1]
		if(o[1] >= d[1] - 100 and side == #right) do return false
		if(o[1] <= 100 and side == #left) do return false
		
		case side of
		(
			#left: x = o[1] - 15
			default: x = o[1] + 15
		)
				
		_DR_STARTUP_POS = [x, 0]
		SetDialogPos _DR_STARTUP _DR_STARTUP_POS
		
		setINISetting drSettingsINI "SETTINGS" "POSX" (x as string)
	)

	
	fn getWindowPos =
	(
		x = 359
		
		size = sysInfo.desktopSize
		o = GetDialogPos _DR_STARTUP
		w = (size[1] - o[1])
	
		w = o[1] - w 
	
		if(w > 0) do x = w + x + (_DR_STARTUP.width)
		
		return x
	)
	
	on btnOpenMonitor mouseover do 
	(	
		setImg btnOpenMonitor "dr_open_icon_hover.bmp"		
		--moveToolBar side: #right
	)
	on btnOpenMonitor mouseout do  setImg btnOpenMonitor "dr_open_icon.bmp"	
	
	on btnOpenLauncher mouseover do 
	(
		setImg btnOpenLauncher "dr_menu_icon_hover.bmp"	
		
		--moveToolBar side: #left
	)
		
	on btnOpenLauncher mouseout do  setImg btnOpenLauncher "dr_menu_icon.bmp"
	
	
	on _DR_STARTUP open do
	(											
		callbacks.removescripts id:#fwdSetDRWindowPos
		callbacks.addScript #filePostSave "restartDRScript()" id:#fwdSetDRWindowPos persistent:false		
		
		callbacks.removescripts id:#fwdUserIni1
		callbacks.addScript #systemPostReset "deleteUser()" id:#fwdUserIni1 persistent:false	
		
		callbacks.removescripts id:#fwdUserIni2
		callbacks.addScript #systemPostNew "deleteUser()" id:#fwdUserIni2 persistent:false	
		
		callbacks.removescripts id:#fwdUserIni3
		callbacks.addScript #preSystemShutdown "deleteUser()" id:#fwdUserIni3 persistent:false	
		
		callbacks.removescripts id:#fwdPreRender
		callbacks.addScript #preRender "addNodes()" id:#fwdPreRender persistent:false	
			
		
		x = getWindowPos()
	
		pos = getINISetting drSettingsINI "SETTINGS" "POSX"
		if(pos != "" and pos.count > 1) do x = pos as float
		
		_DR_STARTUP_POS = [x, 0]
		SetDialogPos _DR_STARTUP _DR_STARTUP_POS
					
		setImg btnOpenLauncher "dr_menu_icon.bmp"	
		setImg btnOpenMonitor "dr_open_icon.bmp"		
						
		fn blockDr =
		(			
			enabled = getINISetting drINI "OFFLINE" "ENABLE"	
									
			hwnd = dialogMonitorOps.getWindowHandle()
			
			dialogTitle = uiAccessor.getWindowText hwnd
			
			if (dialogTitle == "V-Ray distributed rendering settings" and enabled != "false") do
			(
				UIAccessor.CloseDialog hwnd	
							
				try(fileIn (getFilenamePath (getThisScriptFilename())  + _DR_RUN))catch(messageBox "Network Error!" title: "Warning")												
			)
						
			true			
		)	
				
		dialogMonitorOps.unregisterNotification id:#closeDrWindow
		dialogMonitorOps.enabled = true
		dialogMonitorOps.interactive = false
		dialogMonitorOps.registerNotification blockDr id:#closeDrWindow
		
		u = sysInfo.username	
				
		dr = getINISetting drINI "DR"
		udr = for i in dr where (getINISetting drINI "DR" i) == u collect i		
	)
		
	on _DR_STARTUP close do
	(
		dialogMonitorOps.unregisterNotification id:#closeDrWindow
		dialogMonitorOps.enabled = false
	)
	
	on btnOpenMonitor click do
	(
		p = getFilenamePath (getThisScriptFilename()) + _DR_RUN
		
		enabled = getINISetting drINI "OFFLINE" "ENABLE"				
		if(enabled == "false") do return messageBox (getINISetting drINI "OFFLINE" "MESSAGE") title: "Offline!" beep: false
			
		try(fileIn p)catch(messageBox "Network Error!" title: "Warning")
	)
	
	on btnOpenLauncher click do
	(		
		try(fileIn _DR_LAUNCHER)catch(messageBox "Network Error!" title: "Warning")
	)
)

createDialog _DR_STARTUP 56 24 style: #()