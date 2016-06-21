/*
	DR Settings Monitor 
	1.0.6
	MastaMan 
*/

try(DestroyDialog _DR_MONITOR)catch()

global _DR_MONITOR
global _DR_RUN = "DR_UI.ms"
global drPath = @"\\visco.local\data\Instal_Sync\scripts\dr\"
global drINI = drPath + "dr.ini"

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

fn signin =
(
	global signin_l = ""
	global signin_p = ""
	global _DR_USER_SIGNED = false
		
	rollout _DR_LOGIN "Login"
	(
		label lblLogin "Login:" align: #left
		edittext edtLogin ""
		label lblPassword "Password:" align: #left
		edittext edtPassword ""
		button btnSign "Sign In"
		
		fn clearLogin = 
		(
			signin_l = ""
			signin_p = ""
			edtLogin.text = ""
			edtPassword.text = ""
		)
		
		on edtPassword changed x do
		(
			signin_p += trimLeft x "*"
			
			z = ""		
			for i in 1 to signin_p.count do z += "*"
			edtPassword.text = z
		)
		
		on edtLogin changed x do signin_l = edtLogin.text
		
		on btnSign pressed do
		(							
			if(signin_l != "admin" or signin_p != "renderfarm") do 
			(				
				messageBox "Wrong login or password!" title: "Error!"				
				return false
			)
			
			_DR_USER_SIGNED = true
			clearLogin()
			try(destroyDialog _DR_LOGIN)catch()	
		)
	
		on _DR_LOGIN close do
		(
			signin_p = ""
			edtLogin.text = ""
			edtPassword.text = ""
		)
	)

	createDialog _DR_LOGIN 150 125 modal: true
	
	return _DR_USER_SIGNED
)

fn shutdown =
(	
	if(signin() == false) do return false
	
	callbacks.removescripts id:#fwdSetDRWindowPos	
	try(destroyDialog _DR_MONITOR)catch()
	try(destroyDialog _DR) catch()				
)

fn admin =
(			
	if(signin() == false) do return false

	try(destroyDialog _DR_ADMIN)catch()
	try(destroyDialog _DR) catch()		
	
	rollout _DR_ADMIN "Admin Panel"
	(	
		listbox lbxUsers "Users:" height: 22
		button btnDelUser "Remove" across: 2
		button btnUpdateUser "Update"
		group "Offline Service"
		(
			edittext edtOfflineMessage "" text: "Service under maintenance!"
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

rollout _DR_MONITOR ""
(	
	on _DR_MONITOR open do
	(												
		callbacks.removescripts id:#fwdUserIni1
		callbacks.addScript #systemPostReset "deleteUser()" id:#fwdUserIni1 persistent:false	
		
		callbacks.removescripts id:#fwdUserIni2
		callbacks.addScript #systemPostNew "deleteUser()" id:#fwdUserIni2 persistent:false	
		
		callbacks.removescripts id:#fwdUserIni3
		callbacks.addScript #preSystemShutdown "deleteUser()" id:#fwdUserIni3 persistent:false	
		
		callbacks.removescripts id:#fwdPreRender
		callbacks.addScript #preRender "addNodes()" id:#fwdPreRender persistent:false	

				
		SetDialogPos _DR_MONITOR [-1000,0]
						
		fn blockDr =
		(			
			enabled = getINISetting drINI "OFFLINE" "ENABLE"	
									
			hwnd = dialogMonitorOps.getWindowHandle()
			
			dialogTitle = uiAccessor.getWindowText hwnd
			
			if (dialogTitle == "V-Ray distributed rendering settings" and enabled != "false") do
			(
				UIAccessor.CloseDialog hwnd	
							
				try(fileIn (getFilenamePath (getThisScriptFilename())  + _DR_RUN))catch(messageBox "Lost network connection!" title: "Warning")												
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
		
	on _DR_MONITOR close do
	(
		dialogMonitorOps.unregisterNotification id:#closeDrWindow
		dialogMonitorOps.enabled = false
		
		callbacks.removescripts id:#fwdUserIni1
		callbacks.removescripts id:#fwdUserIni2
		callbacks.removescripts id:#fwdUserIni3
		callbacks.removescripts id:#fwdPreRender
	)
)

createDialog _DR_MONITOR 0 0 style: #()