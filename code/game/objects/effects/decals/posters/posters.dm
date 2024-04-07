/obj/structure/sign/poster
	name = "poster"
	desc = "A large piece of space-resistant printed paper."
	icon = 'icons/obj/structures/contraband.dmi'
	icon_state = "random_poster"
	anchored = TRUE
	var/poster_type
	var/ruined = 0
	var/random_poster_base_type = /singleton/poster
	var/excluded_poster_flags = GLOB.POSTER_FLAG_CONTRABAND

/obj/structure/sign/poster/bay_9
	poster_type = /singleton/poster/bay_9

/obj/structure/sign/poster/bay_50
	poster_type = /singleton/poster/bay_50

/obj/structure/sign/poster/New(newloc, placement_dir = null, given_poster_type = null)
	..(newloc)

	if(given_poster_type && !ispath(given_poster_type, /singleton/poster))
		CRASH("Invalid poster type: [log_info_line(given_poster_type)]")

	poster_type = given_poster_type || poster_type || GetRandomPosterType()
	set_poster(poster_type)

	switch (placement_dir)
		if (NORTH)
			pixel_x = 0
			pixel_y = 32
		if (SOUTH)
			pixel_x = 0
			pixel_y = -32
		if (EAST)
			pixel_x = 32
			pixel_y = 0
		if (WEST)
			pixel_x = -32
			pixel_y = 0

/// Returns a random poster type.
/// Uses the random_poster_base_type and excluded_poster_flags vars to limit the potential set of poster types to select from.
/obj/structure/sign/poster/proc/GetRandomPosterType()
	return get_random_poster_type(random_poster_base_type, excluded_poster_flags)

/obj/structure/sign/poster/proc/set_poster(poster_type)
	var/singleton/poster/design = GET_SINGLETON(poster_type)
	SetName("[initial(name)] - [design.name]")
	desc = "[initial(desc)] [design.desc]"
	icon_state = design.icon_state

/obj/structure/sign/poster/screwdriver_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	balloon_alert(user, "нужны кусачки!")

/obj/structure/sign/poster/wirecutter_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_SUCCESS
	if(!tool.use_as_tool(src, user, volume = 50, do_flags = DO_REPAIR_CONSTRUCT))
		return
	// Wirecutters - Remove poster
	if(ruined)
		user.visible_message(
			SPAN_NOTICE("[user] removes the remnants of [src] with [tool]."),
			SPAN_NOTICE("You remove the remnants of [src] with [tool].")
		)
		qdel(src)
		return
	user.visible_message(
		SPAN_NOTICE("[user] removes [src] with [tool]."),
		SPAN_NOTICE("You remove [src] with [tool].")
	)
	roll_and_drop(user.loc)


/obj/structure/sign/poster/attack_hand(mob/user as mob)
	if(ruined)
		return

	if(alert("Do I want to rip the poster from the wall?","You think...","Yes","No") == "Yes")
		if(ruined || !user.Adjacent(src))
			return

		visible_message(SPAN_WARNING("[user] rips [src] in a single, decisive motion!") )
		playsound(src.loc, 'sound/items/poster_ripped.ogg', 100, 1)
		ruined = 1
		icon_state = "poster_ripped"
		SetName("ripped poster")
		desc = "You can't make out anything from the poster's original print. It's ruined."
		add_fingerprint(user)

/obj/structure/sign/poster/proc/roll_and_drop(turf/newloc)
	var/obj/item/contraband/poster/poster_item = new/obj/item/contraband/poster(newloc, poster_type)
	transfer_fingerprints_to(poster_item)
	qdel_self()

/singleton/poster
	// Name suffix. Poster - [name]
	var/name=""
	// Description suffix
	var/desc=""
	var/icon_state=""
	var/poster_flags = GLOB.POSTER_FLAG_RANDOM_PICK
	abstract_type = /singleton/poster

/// Picks and returns a random (sub)type of the provided random_poster_base_type which:
/// * Is not abstract, and
/// * Has a poster_flags value with the POSTER_FLAG_RANDOM_PICK flag, and
/// * Has a poster_flags value which does not match one or more of the excluded_flags (if provided)
/proc/get_random_poster_type(random_poster_base_type = /singleton/poster, excluded_flags)
	var/list/valid_posters = new()
	for (var/singleton/poster/poster_type as anything in typesof(random_poster_base_type))
		if (is_abstract(poster_type))
			continue

		var/poster_flags = initial(poster_type.poster_flags)
		if ((poster_flags & GLOB.POSTER_FLAG_RANDOM_PICK) && (!excluded_flags || !(poster_flags & excluded_flags)))
			valid_posters += poster_type

	return pick(valid_posters)
