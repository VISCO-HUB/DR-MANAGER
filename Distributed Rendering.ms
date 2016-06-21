/*  
[INFO] 

NAME = Distributed Rendering
VERSION = 1.0.3
AUTHOR = MastaMan
DEV = Visco CG
HELP = 

[1.0.0]

* First release =

[1.0.1]

* Changed: Button "Cancel" to "Close" (Danya proposal)=
* Changed: Distributed Rendering Settings. Now added all original settings from Vray=

[1.0.2]

* Changed: Created script from DR_BUTTON without interface for  monitoring actions with Distributed Rendering Settings and add nodes pre render=
* Changed: Startup File=
+ Added: Copy DR Monitor to startup folder=
- BugFix: modal window hinge=

[1.0.3]

* Changed: Moved manipulation buttons under list=
+ Added: Buttons Admin Panel and Disable DR=

[ABOUT]

This script enhance standard V-Ray Distributed Rendering Settings.=
You not longer to add render nodes manually, just check it in list.=
_=
Features:=
- List of render nodes=
- Colored rendering status=
- Batch Select/Drop nodes=
- Render node reservation=
- Comments and priorities=
- Standard V-Ray settings=
- Usability=

_=

For sign in to Admin Panel:=
@=
Login: admin=
Password: renderfarm=

[TEST]

Check: None=
@=
None=

[SCRIPT]
*/	


dr_Path = @"\\visco.local\data\Instal_Sync\scripts\dr\DR_UI.ms"
try(fileIn dr_Path)catch(messageBox "Lost network connection!" title: "Error!")