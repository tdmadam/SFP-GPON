# SFP-GPON Stick

Temporary repository, mainly for the Lantyq chipset and maybe for one or two others.


-------------------------------------- GPON ONU/ONT six states of authentication -----------------------------------

O1: Initial state
	ONT is on, waits for the downstream signal, searching for instances of Psync field.
	ONT clears LoS, LoF and synchronizes with the downstream frame.
	
O2: Standby state.
	OLT sends message with uplink overhead parameters to also synchronize ONT in the upstream direction.
	
O3: Serial Number state.
	OLT sends Serial Number request to ONTs. Once it is received, OLT assigns ONU-ID
	
O4: Ranging state.
	Ranging request message is used by the OLT to avoid transmission colisions between ONTs in the upstream direction.
	Based on the ONT round trip response, OLT calculates equalization delay and grants each ONT specific time intervals within the upstream frame.
	
O5: Operation state.
	ONT can now send data.
	
O6: POPUP state.
	If LoF(Loss of Frame) or LoS(Loss of Signal) is detected ONT enters this state. 
	At first it will try to recover the signal and go again to O4 or O5 state. If it fails it enters O1 state.
	
O7: Emergency Stop state.
	ONT receives "disable Serial Number" message and shuts off the laser.
	



---------------------------------------- U-boot repositories ---------------------------------

https://gitlab.denx.de/u-boot/u-boot

https://github.com/danielschwierzeck/u-boot-lantiq
