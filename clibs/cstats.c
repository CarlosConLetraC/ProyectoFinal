#include <lua.h>
#include <lauxlib.h>
#include <math.h>
#include <stddef.h>

/*
Compatibilidad mejorada:
- Acepta userdata + n   (puntero C)
- Acepta tabla Lua      {1,2,3}
- Validaciones extra
- Evita division por cero
- Soporta datasets grandes usando size_t internamente
*/

// HELPERS
static int is_array_userdata(lua_State *L, int idx) {
    return lua_isuserdata(L, idx);
}

static int is_array_table(lua_State *L, int idx) {
    return lua_istable(L, idx);
}

static size_t get_table_len(lua_State *L, int idx) {
#if LUA_VERSION_NUM >= 502
    return (size_t)lua_rawlen(L, idx);
#else
    return (size_t)lua_objlen(L, idx);
#endif
}

static double get_table_number(lua_State *L, int idx, size_t i) {
    lua_rawgeti(L, idx, (lua_Integer)i);
    double v = lua_tonumber(L, -1);
    lua_pop(L, 1);
    return v;
}

static size_t get_length(lua_State *L, int idx, int len_arg_pos) {
    if (is_array_userdata(L, idx)) {
        return (size_t)luaL_checkinteger(L, len_arg_pos);
    }

    if (is_array_table(L, idx)) {
        return get_table_len(L, idx);
    }

    luaL_error(L, "expected userdata or table");
    return 0;
}

static double get_value(lua_State *L, int idx, size_t i) {
    if (is_array_userdata(L, idx)) {
        double *ptr = (double*)lua_touserdata(L, idx);
        return ptr[i - 1];
    }

    return get_table_number(L, idx, i);
}

// MEAN
static int l_mean(lua_State *L) {
    size_t n = get_length(L, 1, 2);

    if (n == 0) {
        lua_pushnumber(L, 0);
        return 1;
    }

    double sum = 0.0;

    for (size_t i = 1; i <= n; i++) {
        sum += get_value(L, 1, i);
    }

    lua_pushnumber(L, sum / (double)n);
    return 1;
}

// VARIANCE
static int l_var(lua_State *L) {
    size_t n = get_length(L, 1, 2);

    if (n == 0) {
        lua_pushnumber(L, 0);
        return 1;
    }

    double mean = 0.0;

    for (size_t i = 1; i <= n; i++) {
        mean += get_value(L, 1, i);
    }

    mean /= (double)n;

    double var = 0.0;

    for (size_t i = 1; i <= n; i++) {
        double d = get_value(L, 1, i) - mean;
        var += d * d;
    }

    lua_pushnumber(L, var / (double)n);
    return 1;
}

// STD
static int l_std(lua_State *L) {
    lua_pushcfunction(L, l_var);
    lua_pushvalue(L, 1);

    if (lua_isuserdata(L, 1))
        lua_pushvalue(L, 2);

    lua_call(L, lua_isuserdata(L, 1) ? 2 : 1, 1);

    double var = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_pushnumber(L, sqrt(var));
    return 1;
}

// MSE
static int l_mse(lua_State *L) {
    size_t n;

    if (lua_isuserdata(L, 1) && lua_isuserdata(L, 2)) {
        n = (size_t)luaL_checkinteger(L, 3);
    } else {
        size_t n1 = get_length(L, 1, 3);
        size_t n2 = get_length(L, 2, 3);
        n = (n1 < n2) ? n1 : n2;
    }

    if (n == 0) {
        lua_pushnumber(L, 0);
        return 1;
    }

    double sum = 0.0;

    for (size_t i = 1; i <= n; i++) {
        double d = get_value(L, 1, i) - get_value(L, 2, i);
        sum += d * d;
    }

    lua_pushnumber(L, sum / (double)n);
    return 1;
}

// R2 SCORE
static int l_r2(lua_State *L) {
    size_t n;

    if (lua_isuserdata(L, 1) && lua_isuserdata(L, 2)) {
        n = (size_t)luaL_checkinteger(L, 3);
    } else {
        size_t n1 = get_length(L, 1, 3);
        size_t n2 = get_length(L, 2, 3);
        n = (n1 < n2) ? n1 : n2;
    }

    if (n == 0) {
        lua_pushnumber(L, 0);
        return 1;
    }

    double mean = 0.0;

    for (size_t i = 1; i <= n; i++) {
        mean += get_value(L, 1, i);
    }

    mean /= (double)n;

    double ss_res = 0.0;
    double ss_tot = 0.0;

    for (size_t i = 1; i <= n; i++) {
        double y = get_value(L, 1, i);
        double p = get_value(L, 2, i);

        double r = y - p;
        ss_res += r * r;

        double t = y - mean;
        ss_tot += t * t;
    }

    if (ss_tot == 0.0) {
        lua_pushnumber(L, 0);
        return 1;
    }

    lua_pushnumber(L, 1.0 - (ss_res / ss_tot));
    return 1;
}

// CORRELATION
static int l_corr(lua_State *L) {
    size_t n;

    if (lua_isuserdata(L, 1) && lua_isuserdata(L, 2)) {
        n = (size_t)luaL_checkinteger(L, 3);
    } else {
        size_t n1 = get_length(L, 1, 3);
        size_t n2 = get_length(L, 2, 3);
        n = (n1 < n2) ? n1 : n2;
    }

    if (n < 2) {
        lua_pushnumber(L, 0);
        return 1;
    }

    double mx = 0.0, my = 0.0;

    for (size_t i = 1; i <= n; i++) {
        mx += get_value(L, 1, i);
        my += get_value(L, 2, i);
    }

    mx /= (double)n;
    my /= (double)n;

    double num = 0.0;
    double dx = 0.0;
    double dy = 0.0;

    for (size_t i = 1; i <= n; i++) {
        double vx = get_value(L, 1, i) - mx;
        double vy = get_value(L, 2, i) - my;

        num += vx * vy;
        dx += vx * vx;
        dy += vy * vy;
    }

    if (dx == 0.0 || dy == 0.0) {
        lua_pushnumber(L, 0);
        return 1;
    }

    lua_pushnumber(L, num / sqrt(dx * dy));
    return 1;
}

// MAE (Mean Absolute Error)
static int l_mae(lua_State* L) {
    size_t n;

    if (lua_isuserdata(L, 1) && lua_isuserdata(L, 2)) {
        n = (size_t)luaL_checkinteger(L, 3);
    } else {
        size_t n1 = get_length(L, 1, 3);
        size_t n2 = get_length(L, 2, 3);
        n = (n1 < n2) ? n1 : n2;
    }

    if (n == 0) {
        lua_pushnumber(L, 0);
        return 1;
    }

    double sum = 0.0;

    for (size_t i = 1; i <= n; i++) {
        double a = get_value(L, 1, i);
        double b = get_value(L, 2, i);

        sum += fabs(a - b);
    }

    lua_pushnumber(L, sum / (double)n);
    return 1;
}

// REGISTRO
static const luaL_Reg stats_lib[] = {
    {"corr", l_corr},
    {"mae",  l_mae},
    {"mean", l_mean},
    {"mse",  l_mse},
    {"r2",   l_r2},
    {"std",  l_std},
    {"var",  l_var},
    {NULL, NULL}
};

int luaopen_cstats(lua_State *L) {
    luaL_newlib(L, stats_lib);
    return 1;
}