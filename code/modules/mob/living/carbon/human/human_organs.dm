/mob/living/carbon/human/proc/update_eyes()
	var/obj/item/organ/internal/eyes/eyes = internal_organs_by_name[species.vision_organ ? species.vision_organ : BP_EYES]
	if(eyes)
		eyes.update_colour()
		regenerate_icons()

/mob/living/carbon/var/list/internal_organs = list()
/mob/living/carbon/human/var/list/organs = list()
/mob/living/carbon/human/var/list/organs_by_name = list() // map organ names to organs
/mob/living/carbon/human/var/list/internal_organs_by_name = list() // so internal organs have less ickiness too

/mob/living/carbon/human/proc/get_bodypart_name(var/zone)
	var/obj/item/organ/external/E = get_organ(zone)
	if(E) . = E.name

/mob/living/carbon/human/proc/recheck_bad_external_organs()
	var/damage_this_tick = getToxLoss()
	for(var/obj/item/organ/external/O in organs)
		damage_this_tick += O.burn_dam + O.brute_dam

	if(damage_this_tick > last_dam)
		. = TRUE
	last_dam = damage_this_tick

// Takes care of organ related updates, such as broken and missing limbs
/mob/living/carbon/human/proc/handle_organs()

	var/force_process = recheck_bad_external_organs()

	if(force_process)
		bad_external_organs.Cut()
		for(var/obj/item/organ/external/Ex in organs)
			bad_external_organs |= Ex

	//processing internal organs is pretty cheap, do that first.
	for(var/obj/item/organ/I in internal_organs)
		I.process()

	handle_stance()
	handle_grasp()

	if(!force_process && !bad_external_organs.len)
		return

	for(var/obj/item/organ/external/E in bad_external_organs)
		if(!E)
			continue
		if(!E.need_process())
			bad_external_organs -= E
			continue
		else
			E.process()

			if (!lying && !buckled && world.time - l_move_time < 15)
			//Moving around with fractured ribs won't do you any good
				if (E.is_broken() && E.internal_organs && E.internal_organs.len && prob(15))
					var/obj/item/organ/I = pick(E.internal_organs)
					custom_pain("You feel broken bones moving in your [E.name]!", 50)
					I.take_damage(rand(3,5))

				//Moving makes open wounds get infected much faster
				if (E.wounds.len)
					for(var/datum/wound/W in E.wounds)
						if (W.infection_check())
							W.germ_level += 1

/mob/living/carbon/human/proc/handle_stance()
	// Don't need to process any of this if they aren't standing anyways
	// unless their stance is damaged, and we want to check if they should stay down
	if (!stance_damage && (lying || resting) && (life_tick % 4) != 0)
		return

	stance_damage = 0

	// Buckled to a bed/chair. Stance damage is forced to 0 since they're sitting on something solid
	if (istype(buckled, /obj/structure/bed))
		return

	var/list/stance_limbs = get_stance_limbs()
	var/limb_pain
	for(var/obj/item/organ/external/E in stance_limbs)
		if(!E || !E.is_usable())
			stance_damage += (8 / stance_limbs.len) //for variable-amount limbs; if they only have 1 limb, they will get 8 stance damage off the bat; if they have 4, they get 2 per
		else if(E.is_malfunctioning())
			//malfunctioning only happens intermittently so treat it as a missing limb when it procs
			stance_damage += (8 / stance_limbs.len)
			if(prob(10))
				visible_message("\The [src]'s [E.name] [pick("twitches", "shudders")] and sparks!")
				var/datum/effect/effect/system/spark_spread/spark_system = new ()
				spark_system.set_up(5, 0, src)
				spark_system.attach(src)
				spark_system.start()
				spawn(10)
					qdel(spark_system)
		else if(E.is_broken())
			stance_damage += (4 / stance_limbs.len) // same as the above calculations, but halved- 1 limb = 4 stance; 4 limbs = 1 stance each
		else if(E.is_dislocated())
			stance_damage += (2 / stance_limbs.len) // 1 limb = 2 stance; 4 limbs = 0.5 each

		if(E)
			limb_pain = E.can_feel_pain()


	// Canes and crutches help you stand (if the latter is ever added)
	// One cane mitigates a broken leg+foot, or a missing foot.
	// Two canes are needed for a lost leg. If you are missing both legs, canes aren't gonna help you.
	if (l_hand && istype(l_hand, /obj/item/weapon/cane))
		stance_damage -= 2
	if (r_hand && istype(r_hand, /obj/item/weapon/cane))
		stance_damage -= 2

	// standing is poor
	if(stance_damage >= 4 || (stance_damage >= 2 && prob(5)))
		if(!(lying || resting))
			if(limb_pain)
				emote("scream")
			custom_emote(1, "collapses!")
		Weaken(5) //can't emote while weakened, apparently.

/mob/living/carbon/human/proc/handle_grasp()
	if(!l_hand && !r_hand)
		return

	// You should not be able to pick anything up, but stranger things have happened.
	if(l_hand)
		for(var/limb_tag in list(BP_L_HAND, BP_L_ARM))
			var/obj/item/organ/external/E = get_organ(limb_tag)
			if(!E)
				visible_message("<span class='danger'>Lacking a functioning left hand, \the [src] drops \the [l_hand].</span>")
				drop_from_inventory(l_hand)
				break

	if(r_hand)
		for(var/limb_tag in list(BP_R_HAND, BP_R_ARM))
			var/obj/item/organ/external/E = get_organ(limb_tag)
			if(!E)
				visible_message("<span class='danger'>Lacking a functioning right hand, \the [src] drops \the [r_hand].</span>")
				drop_from_inventory(r_hand)
				break

	// Check again...
	if(!l_hand && !r_hand)
		return

	for (var/obj/item/organ/external/E in organs)
		if(!E || !E.can_grasp)
			continue

		if((E.is_broken() || E.is_dislocated()) && !E.splinted)
			switch(E.body_part)
				if(HAND_LEFT, ARM_LEFT)
					if(!l_hand)
						continue
					drop_from_inventory(l_hand)
				if(HAND_RIGHT, ARM_RIGHT)
					if(!r_hand)
						continue
					drop_from_inventory(r_hand)

			var/emote_scream = pick("screams in pain and", "lets out a sharp cry and", "cries out and")
			var/grasp_name = E.name
			if((E.body_part in list(ARM_LEFT, ARM_RIGHT)) && E.children.len)
				var/obj/item/organ/external/hand = pick(E.children)
				grasp_name = hand.name

			emote("me", 1, "[!E.can_feel_pain() ? "" : emote_scream] drops what they were holding in their [grasp_name]!")

		else if(E.is_malfunctioning())
			switch(E.body_part)
				if(HAND_LEFT, ARM_LEFT)
					if(!l_hand)
						continue
					drop_from_inventory(l_hand)
				if(HAND_RIGHT, ARM_RIGHT)
					if(!r_hand)
						continue
					drop_from_inventory(r_hand)

			emote("me", 1, "drops what they were holding, their [E.name] malfunctioning!")

			var/datum/effect/effect/system/spark_spread/spark_system = new /datum/effect/effect/system/spark_spread()
			spark_system.set_up(5, 0, src)
			spark_system.attach(src)
			spark_system.start()
			spawn(10)
				qdel(spark_system)

//Handles chem traces
/mob/living/carbon/human/proc/handle_trace_chems()
	//New are added for reagents to random organs.
	for(var/datum/reagent/A in reagents.reagent_list)
		var/obj/item/organ/O = pick(organs)
		O.trace_chemicals[A.name] = 100

/mob/living/carbon/human/proc/sync_organ_dna()
	var/list/all_bits = internal_organs|organs
	for(var/obj/item/organ/O in all_bits)
		O.set_dna(dna)

//Helper procs
/mob/living/carbon/human/proc/can_use_active_hand()
	var/obj/item/organ/external/temp
	if(hand)
		temp = get_organ(BP_L_HAND)
	else
		temp = get_organ(BP_R_HAND)
	if(!temp)
		src << "<span class='notice'>You try to use your hand, but realize it is no longer attached!</span>"
		return 0
	if(!temp.is_usable())
		src << "<span class='notice'>You try to move your [temp.name], but cannot!</span>"
		return 0
	return 1
