#if !defined(USING_MAP_DATUM)

	#include "eros_areas.dm"

	#include "eros-1.dmm"
	#include "eros-2.dmm"
	#include "eros-3.dmm"
	#include "eros-4.dmm"
	#include "eros-5.dmm"
	#include "eros-6.dmm"

	#include "../../code/modules/lobby_music/absconditus.dm"
	#include "../../code/modules/lobby_music/clouds_of_fire.dm"
	#include "../../code/modules/lobby_music/endless_space.dm"
	#include "../../code/modules/lobby_music/dilbert.dm"
	#include "../../code/modules/lobby_music/space_oddity.dm"

	#define USING_MAP_DATUM /datum/map/eros

#elif !defined(MAP_OVERRIDE)

	#warn A map has already been included, ignoring eros

#endif
