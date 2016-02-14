/*
	Global associative list for caching humanoid icons.
	Index format m or f, followed by a string of 0 and 1 to represent bodyparts followed by husk fat hulk skeleton 1 or 0.
	TODO: Proper documentation
	icon_key is [species.race_key][g][husk][fat][hulk][skeleton][s_tone]
*/
var/global/list/human_icon_cache = list()

	///////////////////////
	//UPDATE_ICONS SYSTEM//
	///////////////////////
/*
Calling this  a system is perhaps a bit trumped up. It is essentially update_clothing dismantled into its
core parts. The key difference is that when we generate overlays we do not generate either lying or standing
versions. Instead, we generate both and store them in two fixed-length lists, both using the same list-index
(The indexes are in update_icons.dm): Each list for humans is (at the time of writing) of length 19.
This will hopefully be reduced as the system is refined.

	var/overlays_lying[19]			//For the lying down stance
	var/overlays_standing[19]		//For the standing stance

When we call update_icons, the 'lying' variable is checked and then the appropriate list is assigned to our overlays!
That in itself uses a tiny bit more memory (no more than all the ridiculous lists the game has already mind you).

On the other-hand, it should be very CPU cheap in comparison to the old system.
In the old system, we updated all our overlays every life() call, even if we were standing still inside a crate!
or dead!. 25ish overlays, all generated from scratch every second for every xeno/human/monkey and then applied.
More often than not update_clothing was being called a few times in addition to that! CPU was not the only issue,
all those icons had to be sent to every client. So really the cost was extremely cumulative. To the point where
update_clothing would frequently appear in the top 10 most CPU intensive procs during profiling.

Another feature of this new system is that our lists are indexed. This means we can update specific overlays!
So we only regenerate icons when we need them to be updated! This is the main saving for this system.

In practice this means that:
	everytime you fall over, we just switch between precompiled lists. Which is fast and cheap.
	Everytime you do something minor like take a pen out of your pocket, we only update the in-hand overlay
	etc...


There are several things that need to be remembered:

>	Whenever we do something that should cause an overlay to update (which doesn't use standard procs
	( i.e. you do something like l_hand = /obj/item/something new(src) )
	You will need to call the relevant update_inv_* proc:
		update_inv_head()
		update_inv_wear_suit()
		update_inv_gloves()
		update_inv_shoes()
		update_inv_w_uniform()
		update_inv_glasse()
		update_inv_l_hand()
		update_inv_r_hand()
		update_inv_belt()
		update_inv_wear_id()
		update_inv_ears()
		update_inv_s_store()
		update_inv_pockets()
		update_inv_back()
		update_inv_handcuffed()
		update_inv_wear_mask()

	All of these are named after the variable they update from. They are defined at the mob/ level like
	update_clothing was, so you won't cause undefined proc runtimes with usr.update_inv_wear_id() if the usr is a
	slime etc. Instead, it'll just return without doing any work. So no harm in calling it for slimes and such.


>	There are also these special cases:
		update_mutations()	//handles updating your appearance for certain mutations.  e.g TK head-glows
		update_mutantrace()	//handles updating your appearance after setting the mutantrace var
		UpdateDamageIcon()	//handles damage overlays for brute/burn damage //(will rename this when I geta round to it)
		update_body()	//Handles updating your mob's icon to reflect their gender/race/complexion etc
		update_hair()	//Handles updating your hair overlay (used to be update_face, but mouth and
																			...eyes were merged into update_body)
		update_targeted() // Updates the target overlay when someone points a gun at you

>	All of these procs update our overlays_lying and overlays_standing, and then call update_icons() by default.
	If you wish to update several overlays at once, you can set the argument to 0 to disable the update and call
	it manually:
		e.g.
		update_inv_head()
		update_inv_l_hand()
		update_inv_r_hand()		//<---calls update_icons()

	or equivillantly:
		update_inv_head()
		update_inv_l_hand()
		update_inv_r_hand()
		update_icons()

>	If you need to update all overlays you can use regenerate_icons(). it works exactly like update_clothing used to.

>	I reimplimented an old unused variable which was in the code called (coincidentally) var/update_icon
	It can be used as another method of triggering regenerate_icons(). It's basically a flag that when set to non-zero
	will call regenerate_icons() at the next life() call and then reset itself to 0.
	The idea behind it is icons are regenerated only once, even if multiple events requested it.

This system is confusing and is still a WIP. It's primary goal is speeding up the controls of the game whilst
reducing processing costs. So please bear with me while I iron out the kinks. It will be worth it, I promise.
If I can eventually free var/lying stuff from the life() process altogether, stuns/death/status stuff
will become less affected by lag-spikes and will be instantaneous! :3

If you have any questions/constructive-comments/bugs-to-report/or have a massivly devestated butt...
Please contact me on #coderbus IRC. ~Carn x
*/

//Human Overlays Indexes/////////
#define BODY_LAYER				27
#define MUTANTRACE_LAYER		26
#define MUTATIONS_LAYER			25
#define DAMAGE_LAYER			24
#define SURGERY_LAYER			23		//bs12 specific.
#define BANDAGE_LAYER			22
#define UNIFORM_LAYER			21
#define TAIL_LAYER				20		//bs12 specific. this hack is probably gonna come back to haunt me
#define ID_LAYER				19
#define SHOES_LAYER				18
#define GLOVES_LAYER			17
#define EARS_LAYER				16
#define SUIT_LAYER				15
#define GLASSES_LAYER			14
#define BELT_LAYER				13		//Possible make this an overlay of somethign required to wear a belt?
#define SUIT_STORE_LAYER		12
#define BACK_LAYER				11
#define HAIR_LAYER				10		//TODO: make part of head layer?
#define FACEMASK_LAYER			9
#define HEAD_LAYER				8
#define COLLAR_LAYER			7
#define HANDCUFF_LAYER			6
#define LEGCUFF_LAYER			5
#define L_HAND_LAYER			4
#define R_HAND_LAYER			3
#define TARGETED_LAYER			2		//BS12: Layer for the target overlay from weapon targeting system
#define FIRE_LAYER				1
#define TOTAL_LAYERS			27
//////////////////////////////////
//Human Damage Overlays Indexes///
#define D_HEAD_LAYER			11
#define D_TORSO_LAYER			10
#define D_L_ARM_LAYER			9
#define D_L_HAND_LAYER			8
#define D_R_ARM_LAYER			7
#define D_R_HAND_LAYER			6
#define D_GROIN_LAYER			5
#define D_L_LEG_LAYER			4
#define D_L_FOOT_LAYER			3
#define D_R_LEG_LAYER			2
#define D_R_FOOT_LAYER			1
#define TOTAL_DAMAGE_LAYERS		11
//////////////////////////////////

/mob/living/carbon/human
	var/list/overlays_standing[TOTAL_LAYERS]
	var/list/overlays_damage[TOTAL_DAMAGE_LAYERS]

/mob/living/carbon/human/proc/apply_overlay(cache_index)
	var/image/I = overlays_standing[cache_index]
	if(I)
		overlays += I

/mob/living/carbon/human/proc/remove_overlay(cache_index)
	if(overlays_standing[cache_index])
		overlays -= overlays_standing[cache_index]
		overlays_standing[cache_index] = null

/mob/living/carbon/human/proc/apply_damage_overlay(cache_index)
	var/image/I = overlays_damage[cache_index]
	if(I)
		overlays += I

/mob/living/carbon/human/proc/remove_damage_overlay(cache_index)
	if(overlays_damage[cache_index])
		overlays -= overlays_damage[cache_index]
		overlays_damage[cache_index] = null

//UPDATES OVERLAYS FROM OVERLAYS_LYING/OVERLAYS_STANDING
//this proc is messy as I was forced to include some old laggy cloaking code to it so that I don't break cloakers
//I'll work on removing that stuff by rewriting some of the cloaking stuff at a later date.
/mob/living/carbon/human/update_icons()
	update_hud()		//TODO: remove the need for this

	//prevent from updating overlays when abductor in stealth
	if(istype(wear_suit, /obj/item/clothing/suit/armor/abductor/vest))
		for(var/obj/item/clothing/suit/armor/abductor/vest/V in list(wear_suit))
			if(V.stealth_active)	return

	//overlays.Cut()

	//icon = stand_icon
	//for(var/image/I in overlays_standing)
	//	overlays += I

//DAMAGE OVERLAYS
/mob/living/carbon/human/UpdateDamageIcon(datum/organ/external/O)
	remove_damage_overlay(O.damage_layer)
	overlays_damage[O.damage_layer]	= image("icon"='icons/mob/dam_human.dmi', "icon_state"="[O.icon_name]_[O.damage_state]", "layer"=-DAMAGE_LAYER)
	apply_damage_overlay(O.damage_layer)


//BASE MOB SPRITE
/mob/living/carbon/human/proc/update_body()
	//remove_overlay(BODY_LAYER)

	var/hulk_color_mod = rgb(48,224,40)
	var/necrosis_color_mod = rgb(10,50,0)

	var/fat //= (FAT in src.mutations)
	var/hulk = (HULK in src.mutations)
	if( FAT in mutations )
		fat = "fat"

	var/g = (gender == FEMALE ? "f" : "m")
	var/has_head = 0

	//CACHING: Generate an index key from visible bodyparts.
	//0 = destroyed, 1 = normal, 2 = robotic, 3 = necrotic.

	//Create a new, blank icon for our mob to use.
	if(stand_icon)
		qdel(stand_icon)

	stand_icon = new(species.icon_template ? species.icon_template : 'icons/mob/human.dmi',"blank")

	var/icon_key = "[species.race_key][g][s_tone]"
	for(var/datum/organ/external/part in organs)

		if(istype(part,/datum/organ/external/head) && !(part.status & ORGAN_DESTROYED))
			has_head = 1

		if(part.status & ORGAN_DESTROYED)
			icon_key = "[icon_key]0"
		else if(part.status & ORGAN_ROBOT)
			icon_key = "[icon_key]2"
		else if(part.status & ORGAN_DEAD) //Do we even have necrosis in our current code? ~Z
			icon_key = "[icon_key]3"
		else
			icon_key = "[icon_key]1"

	icon_key = "[icon_key][fat ? 1 : 0][hulk ? 1 : 0][s_tone]"

	var/icon/base_icon
	if(human_icon_cache[icon_key])
		//Icon is cached, use existing icon.
		base_icon = human_icon_cache[icon_key]

	//	log_debug("Retrieved cached mob icon ([icon_key] \icon[human_icon_cache[icon_key]]) for [src].")

	else

	//BEGIN CACHED ICON GENERATION.

		var/race_icon =   species.icobase
		var/deform_icon = species.icobase

		//Robotic limbs are handled in get_icon() so all we worry about are missing or dead limbs.
		//No icon stored, so we need to start with a basic one.
		var/datum/organ/external/chest = get_organ("chest")
		base_icon = chest.get_icon(race_icon,deform_icon,g,fat)

		if(chest.status & ORGAN_DEAD)
			base_icon.ColorTone(necrosis_color_mod)
			base_icon.SetIntensity(0.7)

		for(var/datum/organ/external/part in organs)

			var/icon/temp //Hold the bodypart icon for processing.

			if(part.status & ORGAN_DESTROYED)
				continue

			if (istype(part, /datum/organ/external/groin) || istype(part, /datum/organ/external/head))
				temp = part.get_icon(race_icon,deform_icon,g)
			else
				temp = part.get_icon(race_icon,deform_icon)

			if(part.status & ORGAN_DEAD)
				temp.ColorTone(necrosis_color_mod)
				temp.SetIntensity(0.7)

			//That part makes left and right legs drawn topmost and lowermost when human looks WEST or EAST
			//And no change in rendering for other parts (they icon_position is 0, so goes to 'else' part)
			if(part.icon_position&(LEFT|RIGHT))

				var/icon/temp2 = new('icons/mob/human.dmi',"blank")

				temp2.Insert(new/icon(temp,dir=NORTH),dir=NORTH)
				temp2.Insert(new/icon(temp,dir=SOUTH),dir=SOUTH)

				if(!(part.icon_position & LEFT))
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)

				if(!(part.icon_position & RIGHT))
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)

				base_icon.Blend(temp2, ICON_OVERLAY)

				if(part.icon_position & LEFT)
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)

				if(part.icon_position & RIGHT)
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)

				base_icon.Blend(temp2, ICON_UNDERLAY)

			else

				base_icon.Blend(temp, ICON_OVERLAY)

		if(hulk)
			var/list/tone = ReadRGB(hulk_color_mod)
			base_icon.MapColors(rgb(tone[1],0,0),rgb(0,tone[2],0),rgb(0,0,tone[3]))

		//Skin tone.
		if(!hulk)
			if(species.flags & HAS_SKIN_TONE)
				if(s_tone >= 0)
					base_icon.Blend(rgb(s_tone, s_tone, s_tone), ICON_ADD)
				else
					base_icon.Blend(rgb(-s_tone,  -s_tone,  -s_tone), ICON_SUBTRACT)

		human_icon_cache[icon_key] = base_icon

		//log_debug("Generated new cached mob icon ([icon_key] \icon[human_icon_cache[icon_key]]) for [src]. [human_icon_cache.len] cached mob icons.")

	//END CACHED ICON GENERATION.

	stand_icon.Blend(base_icon,ICON_OVERLAY)

	//Skin colour. Not in cache because highly variable (and relatively benign).
	if (species.flags & HAS_SKIN_COLOR)
		stand_icon.Blend(rgb(r_skin, g_skin, b_skin), ICON_ADD)

	if(has_head)
		//Eyes
		var/icon/eyes = new/icon('icons/mob/human_face.dmi', species.eyes)
		eyes.Blend(rgb(r_eyes, g_eyes, b_eyes), ICON_ADD)
		stand_icon.Blend(eyes, ICON_OVERLAY)

		//Mouth	(lipstick!)
		if(lip_style && (species && species.flags & HAS_LIPS))	//skeletons are allowed to wear lipstick no matter what you think, agouri.
			stand_icon.Blend(new/icon('icons/mob/human_face.dmi', "lips_[lip_style]_s"), ICON_OVERLAY)

	//Underwear
	if(underwear >0 && underwear < 12 && species.flags & HAS_UNDERWEAR)
		if(!fat)
			stand_icon.Blend(new /icon('icons/mob/human.dmi', "underwear[underwear]_[g]_s"), ICON_OVERLAY)

	if(undershirt>0 && undershirt < undershirt_t.len && species.flags & HAS_UNDERWEAR)
		if(!fat)
			stand_icon.Blend(new /icon('icons/mob/human_undershirt.dmi', "undershirt[undershirt]_s"), ICON_OVERLAY)

	//tail
	update_tail_showing()

	//var/image/standing = image("icon"='icons/mob/dam_human.dmi', "icon_state"="00", "layer"=-DAMAGE_LAYER)
	//overlays_standing[DAMAGE_LAYER]	= standing
	//standing.overlays += ConstructOverlay
	//var/image/standing = image("icon"='icons/mob/dam_human.dmi', "icon_state"="00", "layer"=-BODY_LAYER)
	//overlays_standing[BODY_LAYER]	= standing
	//standing.overlays += stand_icon
	icon = stand_icon

	//apply_overlay(BODY_LAYER)




//HAIR OVERLAY
/mob/living/carbon/human/proc/update_hair()
	//Reset our hair
	remove_overlay(HAIR_LAYER)

	var/datum/organ/external/head/head_organ = get_organ("head")
	if(!head_organ || (head_organ.status & ORGAN_DESTROYED))
		return

	//masks and helmets can obscure our hair.
	if((HUSK in mutations) || (head && (head.flags & BLOCKHAIR)) || (wear_mask && (wear_mask.flags & BLOCKHAIR)))
		return

	//base icons
	var/list/standing	= list()

	if(f_style)
		var/datum/sprite_accessory/facial_hair_style = facial_hair_styles_list[f_style]
		if(facial_hair_style && facial_hair_style.species_allowed && (species.name in facial_hair_style.species_allowed))
			var/image/facial_s = image("icon"=facial_hair_style.icon, "icon_state"="[facial_hair_style.icon_state]_s", "layer"=-HAIR_LAYER)
			if(facial_hair_style.do_colouration)
				facial_s.color = rgb(r_facial, g_facial, b_facial)
			standing	+= facial_s

	if(h_style && !(head && (head.flags & BLOCKHEADHAIR)))
		var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
		if(hair_style && hair_style.species_allowed && (species.name in hair_style.species_allowed))
			var/image/hair_s = image("icon"=hair_style.icon, "icon_state"="[hair_style.icon_state]_s", "layer"=-HAIR_LAYER)
			if(hair_style.do_colouration)
				hair_s.color = rgb(r_hair,g_hair,b_hair)
			standing	+= hair_s

	if(standing.len)
		overlays_standing[HAIR_LAYER]	= standing

	apply_overlay(HAIR_LAYER)


/mob/living/carbon/human/update_mutations()
	remove_overlay(MUTATIONS_LAYER)
	var/fat
	if(FAT in mutations)
		fat = "fat"

	//if(husk)
	//	base_icon.ColorTone(husk_color_mod)
	//else if(hulk)
	//	var/list/tone = ReadRGB(hulk_color_mod)
	//	base_icon.MapColors(rgb(tone[1],0,0),rgb(0,tone[2],0),rgb(0,0,tone[3]))

	var/list/standing	= list()

	if(species && (HUSK in mutations))
		var/husk_color_mod = rgb(96,88,80)
		var/icon/race_icon = icon(species.icobase)

		var/icon/mask = new(race_icon)
		mask.ColorTone(husk_color_mod)
		var/icon/husk_over = new(species.icobase,"overlay_husk")
		mask.MapColors(0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,0)
		husk_over.Blend(mask, ICON_ADD)
		race_icon.Blend(husk_over, ICON_OVERLAY)

		//var/image/husk_overlay = image("icon"=species.icobase, "icon_state"="overlay_husk", "layer"=-MUTATIONS_LAYER)
		standing	+= race_icon
	else
		var/g = (gender == FEMALE) ? "f" : "m"
		for(var/datum/dna/gene/gene in dna_genes)
			if(!gene.block)
				continue
			if(gene.is_active(src))
				var/underlay=gene.OnDrawUnderlays(src,g,fat)
				if(underlay)
					standing += underlay
		for(var/mut in mutations)
			switch(mut)
				/*
				if(HULK)
					if(fat)
						standing.underlays	+= "hulk_[fat]_s"
					else
						standing.underlays	+= "hulk_[g]_s"
				if(COLD_RESISTANCE)
					standing.underlays	+= "fire[fat]_s"
				if(TK)
					standing.underlays	+= "telekinesishead[fat]_s"
				*/
				if(LASER)
					standing	+= image("icon"='icons/effects/genetics.dmi', "icon_state"="lasereyes_s", "layer"=-MUTATIONS_LAYER)
	if(standing.len)
		overlays_standing[MUTATIONS_LAYER]	= standing

	apply_overlay(MUTATIONS_LAYER)


/mob/living/carbon/human/proc/update_mutantrace()
	remove_overlay(MUTANTRACE_LAYER)

	var/fat
	if(FAT in mutations)
		fat = "fat"

	if(dna)
		switch(dna.mutantrace)
			if("slime")
				overlays_standing[MUTANTRACE_LAYER]	= image("icon" = 'icons/effects/genetics.dmi', "icon_state" = "[dna.mutantrace][fat]_[gender]_[species.name]_s")
			if("golem","shadow","adamantine")
				overlays_standing[MUTANTRACE_LAYER]	= image("icon" = 'icons/effects/genetics.dmi', "icon_state" = "[dna.mutantrace][fat]_[gender]_s")
			if("shadowling")
				overlays_standing[MUTANTRACE_LAYER]	= image("icon" = 'tauceti/icons/mob/shadow_ling.dmi', "icon_state" = "[dna.mutantrace]_s")
				overlays_standing[MUTATIONS_LAYER]	= image("icon" = 'tauceti/icons/mob/shadow_ling.dmi', "icon_state" = "[dna.mutantrace]_ms_s", "layer" = GLASSES_LAYER)
			else
				overlays_standing[MUTANTRACE_LAYER]	= null

	if(!dna || !(dna.mutantrace in list("golem","metroid")))
		update_body()

	update_hair()

	apply_overlay(MUTANTRACE_LAYER)


//Call when target overlay should be added/removed
/mob/living/carbon/human/update_targeted()
	remove_overlay(TARGETED_LAYER)

	if(targeted_by && target_locked)
		overlays_standing[TARGETED_LAYER]	= target_locked
	else if (!targeted_by && target_locked)
		qdel(target_locked)

	apply_overlay(TARGETED_LAYER)


/mob/living/carbon/human/update_fire() //TG-stuff, fire layer
	remove_overlay(TARGETED_LAYER)

	if(on_fire)
		overlays_standing[FIRE_LAYER]	= image("icon"='icons/mob/OnFire.dmi', "icon_state"="Standing")

	apply_overlay(TARGETED_LAYER)


/* --------------------------------------- */
//For legacy support.
/mob/living/carbon/human/regenerate_icons()
	..()
	if(monkeyizing)		return
	update_hair()
	update_mutations()
	update_mutantrace()
	update_inv_w_uniform()
	update_inv_wear_id()
	update_inv_gloves()
	update_inv_glasses()
	update_inv_ears()
	update_inv_shoes()
	update_inv_s_store()
	update_inv_wear_mask()
	update_inv_head()
	update_inv_belt()
	update_inv_back()
	update_inv_wear_suit()
	update_inv_r_hand()
	update_inv_l_hand()
	update_inv_handcuffed()
	update_inv_legcuffed()
	update_inv_pockets()
	update_surgery()
	update_bandage()
	for(var/datum/organ/external/O in organs)
		UpdateDamageIcon(O)
	update_icons()
	update_transform()
	//Hud Stuff
	update_hud()


/* --------------------------------------- */
//vvvvvv UPDATE_INV PROCS vvvvvv

/mob/living/carbon/human/update_inv_w_uniform()
	remove_overlay(UNIFORM_LAYER)

	if(istype(w_uniform, /obj/item/clothing/under))
		var/obj/item/clothing/under/U = w_uniform
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
			U.screen_loc = ui_iclothing
			client.screen += U
		var/t_color = U.item_color
		if(!t_color)		t_color = icon_state
		var/image/standing = image("icon_state" = "[t_color]_s")
		if(!U.tc_custom || U.icon_override || species.sprite_sheets["uniform"])
			standing.icon	= (U.icon_override ? U.icon_override : (species.sprite_sheets["uniform"] ? species.sprite_sheets["uniform"] : 'icons/mob/uniform.dmi'))
		else
			standing = image("icon" = U.tc_custom, "icon_state" = "[t_color]_mob")
		overlays_standing[UNIFORM_LAYER]	= standing

		if(U.blood_DNA)
			var/image/bloodsies	= image("icon" = 'icons/effects/blood.dmi', "icon_state" = "uniformblood")
			bloodsies.color		= U.blood_color
			standing.overlays	+= bloodsies

		if(U.hastie)	//WE CHECKED THE TYPE ABOVE. THIS REALLY SHOULD BE FINE.
			var/tie_color = U.hastie.item_color
			if(!tie_color) tie_color = U.hastie.icon_state

			if(U.hastie.tc_custom)
				standing.overlays	+= image("icon" = U.hastie.tc_custom, "icon_state" = "[tie_color]_mob")
			else
				standing.overlays	+= image("icon" = 'icons/mob/ties.dmi', "icon_state" = "[tie_color]")

		if(FAT in mutations)
			if(U.flags & ONESIZEFITSALL)
				standing.icon	= 'icons/mob/uniform_fat.dmi'
			else
				src << "\red You burst out of \the [U]!"
				drop_from_inventory(U)
				return

	else
		// Automatically drop anything in store / id / belt if you're not wearing a uniform.	//CHECK IF NECESARRY
		for(var/obj/item/thing in list(r_store, l_store, wear_id, belt))						//
			drop_from_inventory(thing)

	apply_overlay(UNIFORM_LAYER)


/mob/living/carbon/human/update_inv_wear_id()
	remove_overlay(ID_LAYER)
	if(wear_id)
		if(client && hud_used && hud_used.hud_shown)
			wear_id.screen_loc = ui_id	//TODO
			client.screen += wear_id

		overlays_standing[ID_LAYER]	= image("icon" = 'icons/mob/mob.dmi', "icon_state" = "id")

	hud_updateflag |= 1 << ID_HUD
	hud_updateflag |= 1 << WANTED_HUD

	apply_overlay(ID_LAYER)


/mob/living/carbon/human/update_inv_gloves()
	remove_overlay(GLOVES_LAYER)
	if(gloves)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
			gloves.screen_loc = ui_gloves
			client.screen += gloves

		var/t_state = gloves.item_state
		if(!t_state)	t_state = gloves.icon_state
		var/image/standing
		if(!gloves:tc_custom || gloves.icon_override || species.sprite_sheets["gloves"])
			standing = image("icon" = ((gloves.icon_override) ? gloves.icon_override : (species.sprite_sheets["gloves"] ? species.sprite_sheets["gloves"] : 'icons/mob/hands.dmi')), "icon_state" = "[t_state]")
		else
			standing = image("icon" = gloves:tc_custom, "icon_state" = "[t_state]_mob")
		overlays_standing[GLOVES_LAYER]	= standing

		if(gloves.blood_DNA)
			var/image/bloodsies	= image("icon" = 'icons/effects/blood.dmi', "icon_state" = "bloodyhands")
			bloodsies.color = gloves.blood_color
			standing.overlays	+= bloodsies
	else
		if(blood_DNA)
			var/image/bloodsies	= image("icon" = 'icons/effects/blood.dmi', "icon_state" = "bloodyhands")
			bloodsies.color = hand_blood_color
			overlays_standing[GLOVES_LAYER]	= bloodsies

	apply_overlay(GLOVES_LAYER)


/mob/living/carbon/human/update_inv_glasses()
	remove_overlay(GLASSES_LAYER)

	if(glasses)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
			glasses.screen_loc = ui_glasses
			client.screen += glasses
		if(!glasses:tc_custom || glasses.icon_override || species.sprite_sheets["eyes"])
			overlays_standing[GLASSES_LAYER] = image("icon" = ((glasses.icon_override) ? glasses.icon_override : (species.sprite_sheets["eyes"] ? species.sprite_sheets["eyes"] : 'icons/mob/eyes.dmi')), "icon_state" = "[glasses.icon_state]")
		else
			overlays_standing[GLASSES_LAYER] = image("icon" = glasses:tc_custom, "icon_state" = "[glasses.icon_state]_mob")

	apply_overlay(GLASSES_LAYER)


/mob/living/carbon/human/update_inv_ears()
	remove_overlay(EARS_LAYER)

	if(l_ear || r_ear)
		if(l_ear)
			if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
				l_ear.screen_loc = ui_l_ear
				client.screen += l_ear
			if(!l_ear:tc_custom || l_ear.icon_override || species.sprite_sheets["ears"])
				overlays_standing[EARS_LAYER] = image("icon" = ((l_ear.icon_override) ? l_ear.icon_override : (species.sprite_sheets["ears"] ? species.sprite_sheets["ears"] : 'icons/mob/ears.dmi')), "icon_state" = "[l_ear.icon_state]")
			else
				overlays_standing[EARS_LAYER] = image("icon" = l_ear:tc_custom, "icon_state" = "[l_ear.icon_state]_mob")

		if(r_ear)
			if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
				r_ear.screen_loc = ui_r_ear
				client.screen += r_ear
			if(!r_ear:tc_custom || r_ear.icon_override || species.sprite_sheets["ears"])
				overlays_standing[EARS_LAYER] = image("icon" = ((r_ear.icon_override) ? r_ear.icon_override : (species.sprite_sheets["ears"] ? species.sprite_sheets["ears"] : 'icons/mob/ears.dmi')), "icon_state" = "[r_ear.icon_state]")
			else
				overlays_standing[EARS_LAYER] = image("icon" = r_ear:tc_custom, "icon_state" = "[r_ear.icon_state]_mob")

	apply_overlay(EARS_LAYER)


/mob/living/carbon/human/update_inv_shoes()
	remove_overlay(SHOES_LAYER)

	if(shoes)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
			shoes.screen_loc = ui_shoes
			client.screen += shoes

		var/image/standing
		if(!shoes:tc_custom || shoes.icon_override || species.sprite_sheets["feet"])
			standing = image("icon" = ((shoes.icon_override) ? shoes.icon_override : (species.sprite_sheets["feet"] ? species.sprite_sheets["feet"] : 'icons/mob/feet.dmi')), "icon_state" = "[shoes.icon_state]")
		else
			standing = image("icon" = shoes:tc_custom, "icon_state" = "[shoes.icon_state]_mob")
		overlays_standing[SHOES_LAYER] = standing

		if(shoes.blood_DNA)
			var/image/bloodsies = image("icon" = 'icons/effects/blood.dmi', "icon_state" = "shoeblood")
			bloodsies.color = shoes.blood_color
			standing.overlays += bloodsies
	else
		if(feet_blood_DNA)
			var/image/bloodsies = image("icon" = 'icons/effects/blood.dmi', "icon_state" = "shoeblood")
			bloodsies.color = feet_blood_color
			overlays_standing[SHOES_LAYER] = bloodsies

	apply_overlay(SHOES_LAYER)


/mob/living/carbon/human/update_inv_s_store()
	remove_overlay(SUIT_STORE_LAYER)

	if(s_store)
		if(client && hud_used && hud_used.hud_shown)
			s_store.screen_loc = ui_sstore1		//TODO
			client.screen += s_store

		var/t_state = s_store.item_state
		if(!t_state)	t_state = s_store.icon_state
		overlays_standing[SUIT_STORE_LAYER]	= image("icon" = 'icons/mob/belt_mirror.dmi', "icon_state" = "[t_state]")

	apply_overlay(SUIT_STORE_LAYER)


/mob/living/carbon/human/update_inv_head()
	remove_overlay(HEAD_LAYER)

	if(head)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
			head.screen_loc = ui_head		//TODO
			client.screen += head

		var/image/standing
		if(istype(head,/obj/item/clothing/head/kitty))
			var/obj/item/clothing/head/kitty/K = head
			standing	= image("icon" = K.mob)
		else
			if(!head:tc_custom || head.icon_override || species.sprite_sheets["head"])
				standing = image("icon" = ((head.icon_override) ? head.icon_override : (species.sprite_sheets["head"] ? species.sprite_sheets["head"] : 'icons/mob/head.dmi')), "icon_state" = "[head.icon_state]")
			else
				standing = image("icon" = head:tc_custom, "icon_state" = "[head.icon_state]_mob")
		overlays_standing[HEAD_LAYER]	= standing

		if(head.blood_DNA)
			var/image/bloodsies = image("icon" = 'icons/effects/blood.dmi', "icon_state" = "helmetblood")
			bloodsies.color = head.blood_color
			standing.overlays	+= bloodsies

	apply_overlay(HEAD_LAYER)


/mob/living/carbon/human/update_inv_belt()
	remove_overlay(BELT_LAYER)

	if(belt)
		if(client && hud_used && hud_used.hud_shown)
			belt.screen_loc = ui_belt
			client.screen += belt

		var/t_state = belt.item_state
		if(!t_state)	t_state = belt.icon_state

		if(!belt:tc_custom || belt.icon_override || species.sprite_sheets["belt"])
			overlays_standing[BELT_LAYER] = image("icon" = ((belt.icon_override) ? belt.icon_override : (species.sprite_sheets["belt"] ? species.sprite_sheets["belt"] : 'icons/mob/belt.dmi')), "icon_state" = "[t_state]")
		else
			overlays_standing[BELT_LAYER] = image("icon" = belt:tc_custom, "icon_state" = "[belt.icon_state]_mob")

	apply_overlay(BELT_LAYER)


/mob/living/carbon/human/update_inv_wear_suit()
	remove_overlay(SUIT_LAYER)

	if(istype(wear_suit, /obj/item/clothing/suit))
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
			wear_suit.screen_loc = ui_oclothing	//TODO
			client.screen += wear_suit

		var/image/standing
		if(!wear_suit:tc_custom || wear_suit.icon_override || species.sprite_sheets["suit"])
			standing = image("icon" = ((wear_suit.icon_override) ? wear_suit.icon_override : (species.sprite_sheets["suit"] ? species.sprite_sheets["suit"] : 'icons/mob/suit.dmi')), "icon_state" = "[wear_suit.icon_state]")
		else
			standing = image("icon" = wear_suit:tc_custom, "icon_state" = "[wear_suit.icon_state]_mob")
		overlays_standing[SUIT_LAYER]	= standing

		if(istype(wear_suit, /obj/item/clothing/suit/straight_jacket))
			drop_from_inventory(handcuffed)
			drop_l_hand()
			drop_r_hand()

		if(wear_suit.blood_DNA)
			var/obj/item/clothing/suit/S = wear_suit
			var/image/bloodsies = image("icon" = 'icons/effects/blood.dmi', "icon_state" = "[S.blood_overlay_type]blood")
			bloodsies.color = wear_suit.blood_color
			standing.overlays	+= bloodsies

		if(FAT in mutations)
			if(!(wear_suit.flags & ONESIZEFITSALL))
				src << "\red You burst out of \the [wear_suit]!"
				drop_from_inventory(wear_suit)
				return

		if(istype(wear_suit,/obj/item/clothing/suit/wintercoat))
			var/obj/item/clothing/suit/wintercoat/W = wear_suit
			if(W.hooded) //used for coat hood due to hair layer viewed over the suit
				overlays_standing[HAIR_LAYER]   = null
				overlays_standing[HEAD_LAYER]	= null

		update_inv_shoes()
		update_tail_showing()

	update_collar()

	apply_overlay(SUIT_LAYER)


/mob/living/carbon/human/update_inv_pockets()
	if(l_store)
		if(client && hud_used && hud_used.hud_shown)
			l_store.screen_loc = ui_storage1	//TODO
			client.screen += l_store
	if(r_store)
		if(client && hud_used && hud_used.hud_shown)
			r_store.screen_loc = ui_storage2	//TODO
			client.screen += r_store


/mob/living/carbon/human/update_inv_wear_mask()
	remove_overlay(FACEMASK_LAYER)

	if(istype(wear_mask, /obj/item/clothing/mask) || istype(wear_mask, /obj/item/clothing/tie))
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown)
			wear_mask.screen_loc = ui_mask	//TODO
			client.screen += wear_mask

		var/image/standing
		if(!wear_mask:tc_custom || wear_mask.icon_override || species.sprite_sheets["mask"])
			standing = image("icon" = ((wear_mask.icon_override) ? wear_mask.icon_override : (species.sprite_sheets["mask"] ? species.sprite_sheets["mask"] : 'icons/mob/mask.dmi')), "icon_state" = "[wear_mask.icon_state]")
		else
			standing = image("icon" = wear_mask:tc_custom, "icon_state" = "[wear_mask.icon_state]_mob")
		overlays_standing[FACEMASK_LAYER]	= standing

		if(wear_mask.blood_DNA && !istype(wear_mask, /obj/item/clothing/mask/cigarette))
			var/image/bloodsies = image("icon" = 'icons/effects/blood.dmi', "icon_state" = "maskblood")
			bloodsies.color = wear_mask.blood_color
			standing.overlays	+= bloodsies

	apply_overlay(FACEMASK_LAYER)


/mob/living/carbon/human/update_inv_back()
	remove_overlay(BACK_LAYER)

	if(back)
		if(client && hud_used && hud_used.hud_shown)
			back.screen_loc = ui_back	//TODO
			client.screen += back

		if(!back:tc_custom || back.icon_override || species.sprite_sheets["back"])
			overlays_standing[BACK_LAYER]	= image("icon" = ((back.icon_override) ? back.icon_override : (species.sprite_sheets["back"] ? species.sprite_sheets["back"] : 'icons/mob/back.dmi')), "icon_state" = "[back.icon_state]")
		else
			overlays_standing[BACK_LAYER]	= image("icon" = back:tc_custom, "icon_state" = "[back.icon_state]_mob")

	apply_overlay(BACK_LAYER)


/mob/living/carbon/human/update_hud()	//TODO: do away with this if possible
	if(client)
		client.screen |= contents
		if(hud_used)
			hud_used.hidden_inventory_update() 	//Updates the screenloc of the items on the 'other' inventory bar


/mob/living/carbon/human/update_inv_handcuffed()
	remove_overlay(HANDCUFF_LAYER)

	if(handcuffed)
		drop_r_hand()
		drop_l_hand()
		stop_pulling()	//TODO: should be handled elsewhere
		overlays_standing[HANDCUFF_LAYER]	= image("icon" = 'icons/mob/mob.dmi', "icon_state" = "handcuff1")

	apply_overlay(HANDCUFF_LAYER)


/mob/living/carbon/human/update_inv_legcuffed()
	remove_overlay(LEGCUFF_LAYER)

	if(legcuffed)
		if(src.m_intent != "walk")
			src.m_intent = "walk"
			if(src.hud_used && src.hud_used.move_intent)
				src.hud_used.move_intent.icon_state = "walking"

		overlays_standing[LEGCUFF_LAYER]	= image("icon" = 'icons/mob/mob.dmi', "icon_state" = "legcuff1")

	apply_overlay(LEGCUFF_LAYER)


/mob/living/carbon/human/update_inv_r_hand()
	remove_overlay(R_HAND_LAYER)

	if(r_hand)
		r_hand.screen_loc = ui_rhand	//TODO
		var/t_state = r_hand.item_state
		if(!t_state)	t_state = r_hand.icon_state

		if(!r_hand:tc_custom || r_hand.icon_override || species.sprite_sheets["held"])
			if(r_hand.icon_override || species.sprite_sheets["held"]) t_state = "[t_state]_r"
			overlays_standing[R_HAND_LAYER] = image("icon" = ((r_hand.icon_override) ? r_hand.icon_override : (species.sprite_sheets["held"] ? species.sprite_sheets["held"] : 'icons/mob/items_righthand.dmi')), "icon_state" = "[t_state]")
		else
			overlays_standing[R_HAND_LAYER] = image("icon" = r_hand:tc_custom, "icon_state" = "[t_state]_r")

		if (handcuffed) drop_r_hand()

	apply_overlay(R_HAND_LAYER)


/mob/living/carbon/human/update_inv_l_hand()
	remove_overlay(L_HAND_LAYER)

	if(l_hand)
		l_hand.screen_loc = ui_lhand	//TODO
		var/t_state = l_hand.item_state
		if(!t_state)	t_state = l_hand.icon_state

		if(!l_hand:tc_custom || l_hand.icon_override || species.sprite_sheets["held"])
			if(l_hand.icon_override || species.sprite_sheets["held"]) t_state = "[t_state]_l"
			overlays_standing[L_HAND_LAYER] = image("icon" = ((l_hand.icon_override) ? l_hand.icon_override : (species.sprite_sheets["held"] ? species.sprite_sheets["held"] : 'icons/mob/items_lefthand.dmi')), "icon_state" = "[t_state]")
		else
			overlays_standing[L_HAND_LAYER] = image("icon" = l_hand:tc_custom, "icon_state" = "[t_state]_l")

		if (handcuffed) drop_l_hand()

	apply_overlay(L_HAND_LAYER)


/mob/living/carbon/human/proc/update_tail_showing()
	remove_overlay(TAIL_LAYER)

	if(species.tail && species.flags & HAS_TAIL)
		if(!wear_suit || !(wear_suit.flags_inv & HIDETAIL) && !istype(wear_suit, /obj/item/clothing/suit/space))
			var/icon/tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[species.tail]_s")
			tail_s.Blend(rgb(r_skin, g_skin, b_skin), ICON_ADD)

			overlays_standing[TAIL_LAYER]	= image(tail_s)

	apply_overlay(TAIL_LAYER)


//Adds a collar overlay above the helmet layer if the suit has one
//	Suit needs an identically named sprite in icons/mob/collar.dmi
/mob/living/carbon/human/proc/update_collar()
	remove_overlay(COLLAR_LAYER)

	if(wear_suit)
		var/icon/C = new('icons/mob/collar.dmi')
		if(wear_suit.icon_state in C.IconStates())
			var/image/standing
			standing = image("icon" = C, "icon_state" = "[wear_suit.icon_state]")
			overlays_standing[COLLAR_LAYER]	= standing

	apply_overlay(COLLAR_LAYER)


/mob/living/carbon/human/proc/update_surgery()
	remove_overlay(SURGERY_LAYER)

	var/image/total
	for(var/datum/organ/external/E in organs)
		if(E.open)
			var/image/I = image("icon"='icons/mob/surgery.dmi', "icon_state"="[E.name][round(E.open)]", "layer"=-SURGERY_LAYER)
			total.overlays += I
	overlays_standing[SURGERY_LAYER] = total

	apply_overlay(SURGERY_LAYER)


/mob/living/carbon/human/proc/update_bandage()
	remove_overlay(BANDAGE_LAYER)

	var/image/total
	for(var/datum/organ/external/E in organs)
		if(E.wounds.len)
			for(var/datum/wound/W in E.wounds)
				if(W.bandaged)
					var/image/I = image("icon"='icons/mob/bandages.dmi', "icon_state"="[E.name]", "layer"=-BANDAGE_LAYER)
					total.overlays += I
	overlays_standing[BANDAGE_LAYER] = total

	apply_overlay(BANDAGE_LAYER)


/mob/living/carbon/human/proc/get_overlays_copy()
	var/list/out = new
	out = overlays_standing.Copy()
	return out

//Human Overlays Indexes/////////
#undef BODY_LAYER
#undef MUTANTRACE_LAYER
#undef MUTATIONS_LAYER
#undef DAMAGE_LAYER
#undef SURGERY_LAYER
#undef BANDAGE_LAYER
#undef UNIFORM_LAYER
#undef TAIL_LAYER
#undef ID_LAYER
#undef SHOES_LAYER
#undef GLOVES_LAYER
#undef EARS_LAYER
#undef SUIT_LAYER
#undef GLASSES_LAYER
#undef FACEMASK_LAYER
#undef BELT_LAYER
#undef SUIT_STORE_LAYER
#undef BACK_LAYER
#undef HAIR_LAYER
#undef HEAD_LAYER
#undef COLLAR_LAYER
#undef HANDCUFF_LAYER
#undef LEGCUFF_LAYER
#undef L_HAND_LAYER
#undef R_HAND_LAYER
#undef TARGETED_LAYER
#undef FIRE_LAYER
#undef TOTAL_LAYERS
