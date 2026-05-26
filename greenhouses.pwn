#define Greenhouse:%0(%1) Greenhouse_%0(%1)

#define GREENHOUSE_MAX                (5000)
#define GREENHOUSE_MAX_PLAYER         (5)

#define GREENHOUSE_INVALID_ID         (-1)

#define GREENHOUSE_GROW_TIME          (600)
#define GREENHOUSE_UPDATE_INTERVAL    (5)

#define GREENHOUSE_STAGE_EMPTY        (0)
#define GREENHOUSE_STAGE_SMALL        (1)
#define GREENHOUSE_STAGE_MEDIUM       (2)
#define GREENHOUSE_STAGE_READY        (3)

#define GREENHOUSE_UPGRADE_NONE       (0)
#define GREENHOUSE_UPGRADE_SPEED      (1)

#define GREENHOUSE_DISTANCE           (3.0)

#define GREENHOUSE_MODEL              (19377)

#define GREENHOUSE_OBJECT_SMALL       (806)
#define GREENHOUSE_OBJECT_MEDIUM      (805)
#define GREENHOUSE_OBJECT_READY       (1369)

#define COLOR_RED                     (0xFF0000FF)
#define COLOR_GREEN                   (0x33CC33FF)
#define COLOR_WHITE                   (0xFFFFFFFF)
#define COLOR_YELLOW                  (0xFFFF00FF)

#define INVALID_GREENHOUSE_SLOT       (-1)

forward Greenhouse_UpdateTimer();
forward Greenhouse_OnLoad();
forward Greenhouse_OnPlayerLoad(playerid);
forward Greenhouse_OnCreated(playerid, greenhouseid);

enum E_GREENHOUSE_DATA
{
    E_DATABASE_ID,

    Float:E_POS_X,
    Float:E_POS_Y,
    Float:E_POS_Z,

    E_OWNER_ID,

    E_STAGE,

    E_CREATED_AT,

    E_UPGRADE,

    bool:E_EXISTS,

    STREAMER_TAG_OBJECT:E_OBJECT,
    STREAMER_TAG_OBJECT:E_STAGE_OBJECT,
    STREAMER_TAG_3D_TEXT_LABEL:E_LABEL
};

new g_greenhouse_data[GREENHOUSE_MAX][E_GREENHOUSE_DATA];

new g_player_greenhouse[MAX_PLAYERS][GREENHOUSE_MAX_PLAYER];
new g_player_greenhouse_count[MAX_PLAYERS];

stock Greenhouse:Init()
{
    for(new i; i < GREENHOUSE_MAX; i++)
    {
        g_greenhouse_data[i][E_DATABASE_ID] = GREENHOUSE_INVALID_ID;
    }

    for(new playerid; playerid < MAX_PLAYERS; playerid++)
    {
        for(new slot; slot < GREENHOUSE_MAX_PLAYER; slot++)
        {
            g_player_greenhouse[playerid][slot] = INVALID_GREENHOUSE_SLOT;
        }
    }

    Greenhouse:Load();

    SetTimer("Greenhouse_UpdateTimer", GREENHOUSE_UPDATE_INTERVAL * 1000, true);

    return 1;
}

stock Greenhouse:Load()
{
    mysql_tquery(g_SQL, "SELECT * FROM greenhouses", "Greenhouse_OnLoad");
    return 1;
}

public Greenhouse_OnLoad()
{
    new rows = cache_num_rows();

    for(new row; row < rows; row++)
    {
        new greenhouseid = Greenhouse:GetFreeSlot();

        if(greenhouseid == INVALID_GREENHOUSE_SLOT)
        {
            break;
        }

        g_greenhouse_data[greenhouseid][E_DATABASE_ID] = cache_get_field_int(row, "id");

        g_greenhouse_data[greenhouseid][E_POS_X] = cache_get_field_float(row, "pos_x");
        g_greenhouse_data[greenhouseid][E_POS_Y] = cache_get_field_float(row, "pos_y");
        g_greenhouse_data[greenhouseid][E_POS_Z] = cache_get_field_float(row, "pos_z");

        g_greenhouse_data[greenhouseid][E_OWNER_ID] = cache_get_field_int(row, "owner_id");

        g_greenhouse_data[greenhouseid][E_STAGE] = cache_get_field_int(row, "stage");
        g_greenhouse_data[greenhouseid][E_CREATED_AT] = cache_get_field_int(row, "created_at");
        g_greenhouse_data[greenhouseid][E_UPGRADE] = cache_get_field_int(row, "upgrade_type");

        g_greenhouse_data[greenhouseid][E_EXISTS] = true;

        Greenhouse:CreateEntity(greenhouseid);
    }

    printf("[GREENHOUSE] Loaded: %d", rows);

    return 1;
}

stock Greenhouse:GetFreeSlot()
{
    for(new i; i < GREENHOUSE_MAX; i++)
    {
        if(g_greenhouse_data[i][E_DATABASE_ID] == GREENHOUSE_INVALID_ID)
        {
            return i;
        }
    }

    return INVALID_GREENHOUSE_SLOT;
}

stock Greenhouse:CreateEntity(greenhouseid)
{
    g_greenhouse_data[greenhouseid][E_OBJECT] =
        CreateDynamicObject(
            GREENHOUSE_MODEL,
            g_greenhouse_data[greenhouseid][E_POS_X],
            g_greenhouse_data[greenhouseid][E_POS_Y],
            g_greenhouse_data[greenhouseid][E_POS_Z],
            0.0,
            0.0,
            0.0
        );

    Greenhouse:UpdateVisual(greenhouseid);
    Greenhouse:UpdateLabel(greenhouseid);

    return 1;
}

stock Greenhouse:DestroyEntity(greenhouseid)
{
    if(IsValidDynamicObject(g_greenhouse_data[greenhouseid][E_OBJECT]))
    {
        DestroyDynamicObject(g_greenhouse_data[greenhouseid][E_OBJECT]);
    }

    if(IsValidDynamicObject(g_greenhouse_data[greenhouseid][E_STAGE_OBJECT]))
    {
        DestroyDynamicObject(g_greenhouse_data[greenhouseid][E_STAGE_OBJECT]);
    }

    if(IsValidDynamic3DTextLabel(g_greenhouse_data[greenhouseid][E_LABEL]))
    {
        DestroyDynamic3DTextLabel(g_greenhouse_data[greenhouseid][E_LABEL]);
    }

    return 1;
}

stock Greenhouse:GetGrowTime(greenhouseid)
{
    new grow_time = GREENHOUSE_GROW_TIME;

    if(g_greenhouse_data[greenhouseid][E_UPGRADE] == GREENHOUSE_UPGRADE_SPEED)
    {
        grow_time /= 2;
    }

    return grow_time;
}

stock Greenhouse:GetStageByProgress(progress)
{
    if(progress >= 100)
    {
        return GREENHOUSE_STAGE_READY;
    }

    if(progress >= 66)
    {
        return GREENHOUSE_STAGE_MEDIUM;
    }

    if(progress >= 33)
    {
        return GREENHOUSE_STAGE_SMALL;
    }

    return GREENHOUSE_STAGE_EMPTY;
}

stock Greenhouse:GetProgress(greenhouseid)
{
    new passed = gettime() - g_greenhouse_data[greenhouseid][E_CREATED_AT];

    if(passed < 0)
    {
        passed = 0;
    }

    new grow_time = Greenhouse:GetGrowTime(greenhouseid);

    new progress = floatround((float(passed) / float(grow_time)) * 100.0);

    if(progress > 100)
    {
        progress = 100;
    }

    return progress;
}

stock Greenhouse:Process(greenhouseid)
{
    new progress = Greenhouse:GetProgress(greenhouseid);
    new stage = Greenhouse:GetStageByProgress(progress);

    if(stage != g_greenhouse_data[greenhouseid][E_STAGE])
    {
        g_greenhouse_data[greenhouseid][E_STAGE] = stage;

        Greenhouse:UpdateVisual(greenhouseid);
        Greenhouse:UpdateLabel(greenhouseid);

        Greenhouse:Save(greenhouseid);
    }

    return 1;
}

stock Greenhouse:UpdateVisual(greenhouseid)
{
    if(IsValidDynamicObject(g_greenhouse_data[greenhouseid][E_STAGE_OBJECT]))
    {
        DestroyDynamicObject(g_greenhouse_data[greenhouseid][E_STAGE_OBJECT]);
    }

    new modelid = -1;

    switch(g_greenhouse_data[greenhouseid][E_STAGE])
    {
        case GREENHOUSE_STAGE_SMALL: modelid = GREENHOUSE_OBJECT_SMALL;
        case GREENHOUSE_STAGE_MEDIUM: modelid = GREENHOUSE_OBJECT_MEDIUM;
        case GREENHOUSE_STAGE_READY: modelid = GREENHOUSE_OBJECT_READY;
    }

    if(modelid == -1)
    {
        return 1;
    }

    g_greenhouse_data[greenhouseid][E_STAGE_OBJECT] =
        CreateDynamicObject(
            modelid,
            g_greenhouse_data[greenhouseid][E_POS_X],
            g_greenhouse_data[greenhouseid][E_POS_Y],
            g_greenhouse_data[greenhouseid][E_POS_Z] + 1.0,
            0.0,
            0.0,
            0.0
        );

    return 1;
}

stock Greenhouse:UpdateLabel(greenhouseid)
{
    if(IsValidDynamic3DTextLabel(g_greenhouse_data[greenhouseid][E_LABEL]))
    {
        DestroyDynamic3DTextLabel(g_greenhouse_data[greenhouseid][E_LABEL]);
    }

    new string[144];

    format(
        string,
        sizeof(string),
        "{FFFFFF}Теплица\n{00FF00}Рост: %d%%\n{FFFF00}Стадия: %d",
        Greenhouse:GetProgress(greenhouseid),
        g_greenhouse_data[greenhouseid][E_STAGE]
    );

    g_greenhouse_data[greenhouseid][E_LABEL] =
        CreateDynamic3DTextLabel(
            string,
            COLOR_WHITE,
            g_greenhouse_data[greenhouseid][E_POS_X],
            g_greenhouse_data[greenhouseid][E_POS_Y],
            g_greenhouse_data[greenhouseid][E_POS_Z] + 2.0,
            15.0
        );

    return 1;
}

stock Greenhouse:Save(greenhouseid)
{
    new query[256];

    mysql_format(
        g_SQL,
        query,
        sizeof(query),
        "UPDATE greenhouses SET stage = '%d', created_at = '%d', upgrade_type = '%d' WHERE id = '%d'",
        g_greenhouse_data[greenhouseid][E_STAGE],
        g_greenhouse_data[greenhouseid][E_CREATED_AT],
        g_greenhouse_data[greenhouseid][E_UPGRADE],
        g_greenhouse_data[greenhouseid][E_DATABASE_ID]
    );

    mysql_tquery(g_SQL, query);

    return 1;
}

stock Greenhouse:Create(playerid, Float:x, Float:y, Float:z)
{
    if(g_player_greenhouse_count[playerid] >= GREENHOUSE_MAX_PLAYER)
    {
        SendClientMessage(playerid, COLOR_RED, "Лимит теплиц.");
        return 1;
    }

    new query[256];

    mysql_format(
        g_SQL,
        query,
        sizeof(query),
        "INSERT INTO greenhouses (owner_id, pos_x, pos_y, pos_z, stage, created_at, upgrade_type) VALUES('%d', '%f', '%f', '%f', '0', '%d', '0')",
        GetPlayerSQLID(playerid),
        x,
        y,
        z,
        gettime()
    );

    mysql_tquery(g_SQL, query, "Greenhouse_OnCreated", "d", playerid);

    return 1;
}

public Greenhouse_OnCreated(playerid, greenhouseid)
{
    new slot = Greenhouse:GetFreeSlot();

    if(slot == INVALID_GREENHOUSE_SLOT)
    {
        return 1;
    }

    g_greenhouse_data[slot][E_DATABASE_ID] = cache_insert_id();
    g_greenhouse_data[slot][E_OWNER_ID] = GetPlayerSQLID(playerid);
    g_greenhouse_data[slot][E_CREATED_AT] = gettime();
    g_greenhouse_data[slot][E_STAGE] = GREENHOUSE_STAGE_EMPTY;
    g_greenhouse_data[slot][E_EXISTS] = true;

    GetPlayerPos(playerid,
        g_greenhouse_data[slot][E_POS_X],
        g_greenhouse_data[slot][E_POS_Y],
        g_greenhouse_data[slot][E_POS_Z]
    );

    Greenhouse:CreateEntity(slot);

    Greenhouse:AddPlayerGreenhouse(playerid, slot);

    SendClientMessage(playerid, COLOR_GREEN, "Теплица создана.");

    return 1;
}

stock Greenhouse:Delete(greenhouseid)
{
    new query[128];

    mysql_format(
        g_SQL,
        query,
        sizeof(query),
        "DELETE FROM greenhouses WHERE id = '%d'",
        g_greenhouse_data[greenhouseid][E_DATABASE_ID]
    );

    mysql_tquery(g_SQL, query);

    Greenhouse:DestroyEntity(greenhouseid);

    g_greenhouse_data[greenhouseid][E_DATABASE_ID] = GREENHOUSE_INVALID_ID;
    g_greenhouse_data[greenhouseid][E_EXISTS] = false;

    return 1;
}

stock Greenhouse:AddPlayerGreenhouse(playerid, greenhouseid)
{
    for(new slot; slot < GREENHOUSE_MAX_PLAYER; slot++)
    {
        if(g_player_greenhouse[playerid][slot] == INVALID_GREENHOUSE_SLOT)
        {
            g_player_greenhouse[playerid][slot] = greenhouseid;
            g_player_greenhouse_count[playerid]++;
            return 1;
        }
    }

    return 0;
}

stock Greenhouse:LoadPlayer(playerid)
{
    new ownerid = GetPlayerSQLID(playerid);

    for(new i; i < GREENHOUSE_MAX; i++)
    {
        if(!g_greenhouse_data[i][E_EXISTS])
        {
            continue;
        }

        if(g_greenhouse_data[i][E_OWNER_ID] != ownerid)
        {
            continue;
        }

        Greenhouse:AddPlayerGreenhouse(playerid, i);
    }

    return 1;
}

stock Greenhouse:UnloadPlayer(playerid)
{
    for(new slot; slot < GREENHOUSE_MAX_PLAYER; slot++)
    {
        g_player_greenhouse[playerid][slot] = INVALID_GREENHOUSE_SLOT;
    }

    g_player_greenhouse_count[playerid] = 0;

    return 1;
}

stock Greenhouse:GetNearest(playerid)
{
    for(new i; i < GREENHOUSE_MAX; i++)
    {
        if(!g_greenhouse_data[i][E_EXISTS])
        {
            continue;
        }

        if(IsPlayerInRangeOfPoint(
            playerid,
            GREENHOUSE_DISTANCE,
            g_greenhouse_data[i][E_POS_X],
            g_greenhouse_data[i][E_POS_Y],
            g_greenhouse_data[i][E_POS_Z]
        ))
        {
            return i;
        }
    }

    return INVALID_GREENHOUSE_SLOT;
}

stock Greenhouse:Harvest(playerid, greenhouseid)
{
    if(g_greenhouse_data[greenhouseid][E_STAGE] != GREENHOUSE_STAGE_READY)
    {
        SendClientMessage(playerid, COLOR_RED, "Урожай еще не созрел.");
        return 1;
    }

    g_greenhouse_data[greenhouseid][E_STAGE] = GREENHOUSE_STAGE_EMPTY;
    g_greenhouse_data[greenhouseid][E_CREATED_AT] = gettime();

    Greenhouse:UpdateVisual(greenhouseid);
    Greenhouse:UpdateLabel(greenhouseid);

    Greenhouse:Save(greenhouseid);

    GivePlayerMoney(playerid, 1000);

    SendClientMessage(playerid, COLOR_GREEN, "Вы собрали урожай.");

    return 1;
}

public Greenhouse_UpdateTimer()
{
    foreach(new playerid : Player)
    {
        for(new slot; slot < GREENHOUSE_MAX_PLAYER; slot++)
        {
            new greenhouseid = g_player_greenhouse[playerid][slot];

            if(greenhouseid == INVALID_GREENHOUSE_SLOT)
            {
                continue;
            }

            Greenhouse:Process(greenhouseid);
        }
    }

    return 1;
}

CMD:harvest(playerid)
{
    new greenhouseid = Greenhouse:GetNearest(playerid);

    if(greenhouseid == INVALID_GREENHOUSE_SLOT)
    {
        SendClientMessage(playerid, COLOR_RED, "Рядом нет теплицы.");
        return 1;
    }

    Greenhouse:Harvest(playerid, greenhouseid);

    return 1;
}

CMD:buygreenhouse(playerid)
{
    new Float:x, Float:y, Float:z;

    GetPlayerPos(playerid, x, y, z);

    Greenhouse:Create(playerid, x, y, z);

    return 1;
}