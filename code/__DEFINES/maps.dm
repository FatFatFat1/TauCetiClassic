// helpers for modifying jobs, used in various job_changes.dm files
#define MAP_JOB_CHECK if(SSmapping.config.map_name != JOB_MODIFICATION_MAP_NAME) { return; }
#define MAP_JOB_CHECK_BASE if(SSmapping.config.map_name != JOB_MODIFICATION_MAP_NAME) { return ..(); }
#define MAP_REMOVE_JOB(jobpath) /datum/job/##jobpath/map_check() { return (SSmapping.config.map_name != JOB_MODIFICATION_MAP_NAME) && ..() }

// traits
// boolean - marks a level as having that property if present
#define ZTRAIT_CENTCOM "CentCom"
#define ZTRAIT_STATION "Station"
#define ZTRAIT_MINING "Mining"
#define ZTRAIT_REEBE "Reebe"
#define ZTRAIT_RESERVED "Transit/Reserved"
#define ZTRAIT_AWAY "Away Mission"
#define ZTRAIT_SPACE_RUINS "Space Ruins"
#define ZTRAIT_LAVA_RUINS "Lava Ruins"
#define ZTRAIT_JUNKYARD "Junkyard"

// number - bombcap is multiplied by this before being applied to bombs
#define ZTRAIT_BOMBCAP_MULTIPLIER "Bombcap Multiplier"

// number - default gravity if there's no gravity generators or area overrides present
#define ZTRAIT_GRAVITY "Gravity"

// enum - how space transitions should affect this level
#define ZTRAIT_LINKAGE "Linkage"
    // UNAFFECTED if absent - no space transitions
    #define UNAFFECTED null
    // SELFLOOPING - space transitions always self-loop
    #define SELFLOOPING "Self"
    // CROSSLINKED - mixed in with the cross-linked space pool
    #define CROSSLINKED "Cross"

// enum - environment type
#define ZTRAIT_ENV_TYPE "Environment Type"
    // ENV_TYPE_SPACE if absent - no environment generation
    #define ENV_TYPE_SPACE null
    // ENV_TYPE_SNOW - snow environment generation
    #define ENV_TYPE_SNOW "Snow"

// default trait definitions, used by SSmapping
#define ZTRAITS_CENTCOM list(ZTRAIT_CENTCOM = TRUE)
#define ZTRAITS_STATION list(ZTRAIT_LINKAGE = CROSSLINKED, ZTRAIT_STATION = TRUE)
#define ZTRAITS_SPACE list(ZTRAIT_LINKAGE = CROSSLINKED, ZTRAIT_SPACE_RUINS = TRUE)
#define ZTRAITS_ASTEROID list(ZTRAIT_LINKAGE = CROSSLINKED, ZTRAIT_MINING = TRUE)

#define CAMERA_LOCK_STATION 1
#define CAMERA_LOCK_MINING 2
#define CAMERA_LOCK_CENTCOM 4

#define DL_NAME "name"
#define DL_TRAITS "traits"
#define DECLARE_LEVEL(NAME, TRAITS) list(DL_NAME = NAME, DL_TRAITS = TRAITS)

// must correspond to compiled-in maps for things to work correctly
#define DEFAULT_MAP_TRAITS list(\
    DECLARE_LEVEL("CentCom", ZTRAITS_CENTCOM),\
)
