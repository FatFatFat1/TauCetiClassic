//Xeno Overlays Indexes//////////
#define X_HEAD_LAYER			1
#define X_SUIT_LAYER			2
#define X_L_HAND_LAYER			3
#define X_R_HAND_LAYER			4
#define TARGETED_LAYER			5
#define X_FIRE_LAYER			6
#define X_SHRIEC_LAYER			7
#define X_TOTAL_LAYERS			7
/////////////////////////////////

/mob/living/carbon/xenomorph
	var/list/overlays_standing[X_TOTAL_LAYERS]

/mob/living/carbon/xenomorph/humanoid/update_icons()
	update_hud()		//TODO: remove the need for this to be here
	cut_overlays()
	for(var/image/I in overlays_standing)
		add_overlay(I)

	if(stat == DEAD)
		//If we mostly took damage from fire
		if(fireloss > 125)
			icon_state = "alien[caste]_husked"
		else
			icon_state = "alien[caste]_dead"
	else if((stat == UNCONSCIOUS && !IsSleeping()) || weakened)
		icon_state = "alien[caste]_unconscious"
	else if(leap_on_click)
		icon_state = "alien[caste]_pounce"
	else if(lying || crawling)
		icon_state = "alien[caste]_sleep"
	else if(m_intent == MOVE_INTENT_RUN)
		icon_state = "alien[caste]_running"
	else
		icon_state = "alien[caste]_s"

	if(leaping)
		if(alt_icon == initial(alt_icon))
			var/old_icon = icon
			icon = alt_icon
			alt_icon = old_icon
		icon_state = "alien[caste]_leap"
		pixel_x = -32
		pixel_y = -32
	else
		if(alt_icon != initial(alt_icon))
			var/old_icon = icon
			icon = alt_icon
			alt_icon = old_icon

		pixel_x = get_pixel_x_offset()
		pixel_y = get_pixel_y_offset()

		default_pixel_x = pixel_x
		default_pixel_y = pixel_y

/mob/living/carbon/xenomorph/humanoid/regenerate_icons()
	..()
	if (notransform)
		return

	update_inv_head(0)
	update_inv_wear_suit(0)
	update_inv_r_hand(0)
	update_inv_l_hand(0)
	update_inv_pockets(0)
	update_hud()
	update_transform()

/mob/living/carbon/xenomorph/humanoid/update_transform() //The old method of updating lying/standing was update_icons(). Aliens still expect that.
	update_icons()
	..()

/mob/living/carbon/xenomorph/humanoid/get_lying_angle()	//so that the sprite does not unfold
	return

/mob/living/carbon/xenomorph/humanoid/update_hud()
	//TODO
	if(client)
		client.screen |= contents



/mob/living/carbon/xenomorph/humanoid/update_inv_wear_suit(update_icons = TRUE)
	if(wear_suit)
		var/t_state = wear_suit.item_state
		if(!t_state)
			t_state = wear_suit.icon_state
		var/image/standing = image(icon = 'icons/mob/mob.dmi', icon_state = "[t_state]")

		if(wear_suit.blood_DNA)
			var/t_suit = "suit"
			if( istype(wear_suit, /obj/item/clothing/suit/armor) )
				t_suit = "armor"
			standing.overlays += image(icon = 'icons/effects/blood.dmi', icon_state = "[t_suit]blood")

		//TODO
		wear_suit.screen_loc = ui_alien_oclothing
		if (istype(wear_suit, /obj/item/clothing/suit/straight_jacket))
			drop_from_inventory(handcuffed)
			drop_r_hand()
			drop_l_hand()

		overlays_standing[X_SUIT_LAYER] = standing
	else
		overlays_standing[X_SUIT_LAYER] = null
	if(update_icons)
		update_icons()


/mob/living/carbon/xenomorph/humanoid/update_inv_head(update_icons = TRUE)
	if (head)
		var/t_state = head.item_state
		if(!t_state)
			t_state = head.icon_state
		var/image/standing = image(icon = 'icons/mob/mob.dmi', icon_state = "[t_state]")
		if(head.blood_DNA)
			standing.overlays += image(icon = 'icons/effects/blood.dmi', icon_state = "helmetblood")
		head.screen_loc = ui_alien_head
		overlays_standing[X_HEAD_LAYER] = standing
	else
		overlays_standing[X_HEAD_LAYER] = null
	if(update_icons)
		update_icons()


/mob/living/carbon/xenomorph/humanoid/update_inv_pockets(update_icons = TRUE)
	if(l_store)		l_store.screen_loc = ui_storage1
	if(r_store)		r_store.screen_loc = ui_storage2
	if(update_icons)	update_icons()


/mob/living/carbon/xenomorph/humanoid/update_inv_r_hand(update_icons = TRUE)
	if(r_hand)
		var/t_state = r_hand.item_state
		if(!t_state)
			t_state = r_hand.icon_state
		r_hand.screen_loc = ui_rhand
		overlays_standing[X_R_HAND_LAYER] = image(icon = r_hand.righthand_file, icon_state = t_state)
	else
		overlays_standing[X_R_HAND_LAYER] = null
	if(update_icons)
		update_icons()

/mob/living/carbon/xenomorph/humanoid/update_inv_l_hand(update_icons = TRUE)
	if(l_hand)
		var/t_state = l_hand.item_state
		if(!t_state)
			t_state = l_hand.icon_state
		l_hand.screen_loc = ui_lhand
		overlays_standing[X_L_HAND_LAYER] = image(icon = l_hand.lefthand_file, icon_state = t_state)
	else
		overlays_standing[X_L_HAND_LAYER] = null
	if(update_icons)
		update_icons()

//Call when target overlay should be added/removed
/mob/living/carbon/xenomorph/humanoid/update_targeted(update_icons = TRUE)
	if(targeted_by && target_locked)
		overlays_standing[TARGETED_LAYER] = target_locked
	else if(!targeted_by && target_locked)
		qdel(target_locked)
	if(!targeted_by)
		overlays_standing[TARGETED_LAYER] = null
	if(update_icons)
		update_icons()

/mob/living/carbon/xenomorph/humanoid/queen/update_fire()
	cut_overlay(overlays_standing[X_FIRE_LAYER])
	if(on_fire)
		overlays_standing[X_FIRE_LAYER] = image(icon = 'icons/mob/alienqueen.dmi', icon_state = "queen_fire")
		add_overlay(overlays_standing[X_FIRE_LAYER])
		return
	overlays_standing[X_FIRE_LAYER] = null

/mob/living/carbon/xenomorph/humanoid/update_fire()
	cut_overlay(overlays_standing[X_FIRE_LAYER])
	if(on_fire)
		overlays_standing[X_FIRE_LAYER] = image(icon = 'icons/mob/OnFire.dmi', icon_state = "Standing")
		add_overlay(overlays_standing[X_FIRE_LAYER])
		return
	overlays_standing[X_FIRE_LAYER] = null

/mob/living/carbon/xenomorph/update_fire()
	cut_overlay(overlays_standing[X_FIRE_LAYER])
	if(on_fire)
		overlays_standing[X_FIRE_LAYER] = image(icon = 'icons/mob/OnFire.dmi', icon_state = "Generic_mob_burning")
		add_overlay(overlays_standing[X_FIRE_LAYER])
		return
	overlays_standing[X_FIRE_LAYER] = null

/mob/living/carbon/xenomorph/humanoid/proc/create_shriekwave()
	overlays_standing[X_SHRIEC_LAYER] = image(icon = 'icons/mob/alienqueen.dmi', icon_state = "shriek_waves")
	add_overlay(overlays_standing[X_SHRIEC_LAYER])
	addtimer(CALLBACK(src, .proc/remove_xeno_overlay, X_SHRIEC_LAYER), 30)

/mob/living/carbon/xenomorph/proc/remove_xeno_overlay(cache_index)
	if(overlays_standing[cache_index])
		cut_overlay(overlays_standing[cache_index])
		overlays_standing[cache_index] = null

//Xeno Overlays Indexes//////////
#undef X_HEAD_LAYER
#undef X_SUIT_LAYER
#undef X_L_HAND_LAYER
#undef X_R_HAND_LAYER
#undef TARGETED_LAYER
#undef X_FIRE_LAYER
#undef X_SHRIEC_LAYER
#undef X_TOTAL_LAYERS
