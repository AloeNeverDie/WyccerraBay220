// Returns which access is relevant to passed network. Used by the program.
// A return value of 0 indicates no access reqirement
/proc/get_camera_access(network)
	if(!network)
		return 0
	. = GLOB.using_map.get_network_access(network)
	if(.)
		return

	switch(network)
		if(GLOB.NETWORK_ENGINEERING, NETWORK_ALARM_ATMOS, NETWORK_ALARM_CAMERA, NETWORK_ALARM_FIRE, NETWORK_ALARM_POWER)
			return GLOB.access_engine
		if(GLOB.NETWORK_CRESCENT, GLOB.NETWORK_ERT)
			return GLOB.access_cent_specops
		if(GLOB.NETWORK_MEDICAL)
			return GLOB.access_medical
		if(GLOB.NETWORK_MINE)
			return GLOB.access_mailsorting // Cargo office - all cargo staff should have access here.
		if(GLOB.NETWORK_RESEARCH)
			return GLOB.access_research
		if(GLOB.NETWORK_THUNDER)
			return 0
		if(GLOB.NETWORK_HELMETS)
			return GLOB.access_eva

	return GLOB.access_security // Default for all other networks

/datum/computer_file/program/camera_monitor
	filename = "cammon"
	filedesc = "Camera Monitoring"
	nanomodule_path = /datum/nano_module/camera_monitor
	program_icon_state = "cameras"
	program_key_state = "generic_key"
	program_menu_icon = "search"
	extended_desc = "This program allows remote access to the camera system. Some camera networks may have additional access requirements."
	size = 12
	available_on_ntnet = TRUE
	requires_ntnet = FALSE
	category = PROG_MONITOR

/datum/nano_module/camera_monitor
	name = "Camera Monitoring program"
	var/obj/machinery/camera/current_camera = null
	var/current_network = null


/datum/nano_module/camera_monitor/Destroy()
	reset_current()
	. = ..()


/datum/nano_module/camera_monitor/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1, state = GLOB.default_state)
	var/list/data = host.initial_data()

	data["current_camera"] = current_camera ? current_camera.nano_structure() : null
	data["current_network"] = current_network

	var/list/all_networks[0]
	for(var/network in GLOB.using_map.station_networks)
		all_networks.Add(list(list(
							"tag" = network,
							"has_access" = can_GLOB.access_network(user, get_camera_access(network))
							)))

	all_networks = modify_networks_list(all_networks)

	data["networks"] = all_networks

	if(current_network)
		data["cameras"] = camera_repository.cameras_in_network(current_network)

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "sec_camera.tmpl", "Camera Monitoring", 900, 800, state = state)
		// ui.auto_update_layout = 1 // Disabled as with suit sensors monitor - breaks the UI map. Re-enable once it's fixed somehow.

		ui.add_template("mapContent", "sec_camera_map_content.tmpl")
		ui.add_template("mapHeader", "sec_camera_map_header.tmpl")
		ui.set_initial_data(data)
		ui.open()

	user.machine = nano_host()
	user.reset_view(current_camera)

// Intended to be overriden by subtypes to manually add non-station networks to the list.
/datum/nano_module/camera_monitor/proc/modify_networks_list(list/networks)
	return networks

/datum/nano_module/camera_monitor/proc/can_GLOB.access_network(mob/user, network_access)
	// No access passed, or 0 which is considered no access requirement. Allow it.
	if(!network_access)
		return 1

	return check_access(user, GLOB.access_security) || check_access(user, network_access)

/datum/nano_module/camera_monitor/Topic(href, href_list)
	if(..())
		return 1

	if(href_list["switch_camera"])
		var/obj/machinery/camera/C = locate(href_list["switch_camera"]) in GLOB.cameranet.cameras
		var/datum/extension/interactive/ntos/os = get_extension(nano_host(), /datum/extension/interactive/ntos)
		if(!C)
			return
		if(!(current_network in C.network))
			return
		if(!AreConnectedZLevels(get_z(C), get_z(host)) && !(get_z(C) in GLOB.using_map.admin_levels))
			to_chat(usr, "Unable to establish a connection.")
			return
		if (!os?.get_ntnet_status() && !C.is_helmet_cam)
			to_chat(usr, "Unable to establish a connection.")
			return
		if (C.inoperable(MACHINE_STAT_EMPED))
			to_chat(usr, "Unable to establish a connection.")
			return

		switch_to_camera(usr, C)
		return 1

	else if(href_list["switch_network"])
		// Either security access, or access to the specific camera network's department is required in order to access the network.
		if(GLOB.access_network(usr, get_camera_access(href_list["switch_network"])))
			current_network = href_list["switch_network"]
		else
			to_chat(usr, "\The [nano_host()] shows an \"Network Access Denied\" error message.")
		return 1

	else if(href_list["reset"])
		reset_current()
		usr.reset_view(current_camera)
		return 1

/datum/nano_module/camera_monitor/proc/switch_to_camera(mob/user, obj/machinery/camera/C)
	//don't need to check if the camera works for AI because the AI jumps to the camera location and doesn't actually look through cameras.
	if(isAI(user))
		var/mob/living/silicon/ai/A = user
		// Only allow non-carded AIs to view because the interaction with the eye gets all wonky otherwise.
		if(!A.is_in_chassis())
			return 0

		A.eyeobj.setLoc(get_turf(C))
		A.client.eye = A.eyeobj
		return 1

	set_current(C)
	return 1

/datum/nano_module/camera_monitor/proc/set_current(obj/machinery/camera/C)
	if(current_camera == C)
		return

	if(current_camera)
		reset_current()

	current_camera = C
	if(current_camera)
		GLOB.destroyed_event.register(current_camera, src, PROC_REF(reset_current))
		GLOB.moved_event.register(current_camera, src, PROC_REF(camera_moved))
		var/mob/living/L = current_camera.loc
		if(istype(L))
			L.tracking_initiated()

/datum/nano_module/camera_monitor/proc/camera_moved(atom/movable/moved_atom, atom/old_loc, atom/new_loc)
	if (AreConnectedZLevels(get_z(old_loc), get_z(new_loc)))
		return
	reset_current()

/datum/nano_module/camera_monitor/proc/reset_current()
	if(current_camera)
		GLOB.destroyed_event.unregister(current_camera, src, PROC_REF(reset_current))
		GLOB.moved_event.unregister(current_camera, src, PROC_REF(camera_moved))
		var/mob/living/L = current_camera.loc
		if(istype(L))
			L.tracking_cancelled()
	current_camera = null

/datum/nano_module/camera_monitor/check_eye(mob/user as mob)
	if(!current_camera)
		return 0
	var/viewflag = current_camera.check_eye(user)
	if ( viewflag < 0 ) //camera doesn't work
		reset_current()
	return viewflag


// ERT Variant of the program
/datum/computer_file/program/camera_monitor/ert
	filename = "ntcammon"
	filedesc = "Advanced Camera Monitoring"
	extended_desc = "This program allows remote access to the camera system. Some camera networks may have additional access requirements. This version has an integrated database with additional encrypted keys."
	size = 14
	nanomodule_path = /datum/nano_module/camera_monitor/ert
	available_on_ntnet = FALSE

/datum/nano_module/camera_monitor/ert
	name = "Advanced Camera Monitoring Program"
	available_to_ai = FALSE

// The ERT variant has access to ERT and crescent cams, but still checks for accesses. ERT members should be able to use it.
/datum/nano_module/camera_monitor/ert/modify_networks_list(list/networks)
	..()
	networks.Add(list(list("tag" = GLOB.NETWORK_ERT, "has_access" = 1)))
	networks.Add(list(list("tag" = GLOB.NETWORK_CRESCENT, "has_access" = 1)))
	return networks

/datum/nano_module/camera_monitor/apply_visual(mob/M)
	if(current_camera)
		current_camera.apply_visual(M)
	else
		remove_visual(M)

/datum/nano_module/camera_monitor/remove_visual(mob/M)
	if(current_camera)
		current_camera.remove_visual(M)
