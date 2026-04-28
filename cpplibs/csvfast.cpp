extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <vector>
#include <string>
#include <fstream>
#include <cctype>
#include <cstdlib>
#include <cmath>
#include <algorithm>
#include <limits.h>

// LUA COMPAT (LuaJIT / Lua 5.1)
#ifndef lua_rawlen
#define lua_rawlen(L, i) lua_objlen(L, i)
#endif

#ifndef luaL_newlib
static void luaL_newlib(lua_State* L, const luaL_Reg* l) {
	lua_newtable(L);
	luaL_register(L, NULL, l);
}
#endif

// UTIL
static inline std::string trim(std::string s) {
	size_t i = 0;
	size_t j = s.size();

	while (i < j && std::isspace((unsigned char)s[i])) i++;
	while (j > i && std::isspace((unsigned char)s[j - 1])) j--;

	return s.substr(i, j - i);
}

static inline std::string clean_cr(std::string s) {
	s.erase(
		std::remove_if(
			s.begin(),
			s.end(),
			[](unsigned char c) {
				return c == '\r' || c == '\n' || c == '\t';
			}),
		s.end()
	);
	return s;
}

static inline std::string clean_token(std::string s) {
	s = trim(s);
	if (s.empty()) return "";
	if (s.size() >= 3 &&
		(unsigned char)s[0] == 0xEF &&
		(unsigned char)s[1] == 0xBB &&
		(unsigned char)s[2] == 0xBF) {
		s.erase(0, 3);
	}
	s = clean_cr(s);
	s = trim(s);
	return s;
}

static inline std::string to_upper(std::string s) {
	std::transform(
		s.begin(),
		s.end(),
		s.begin(),
		[](unsigned char c) { return std::toupper(c); }
	);
	return s;
}

// INVALID TOKENS
static inline bool is_invalid(const std::string& s) {
	std::string v = to_upper(clean_token(s));
	return (
		v.empty() ||
		v == "?" ||
		v == "NA" ||
		v == "N/A" ||
		v == "NULL"
	);
}

static inline bool to_number(const std::string& s, double& out) {
	std::string v = clean_token(s);
	if (is_invalid(v)) return false;

	char* end = NULL;
	out = std::strtod(v.c_str(), &end);

	if (end == v.c_str()) return false;
	while (*end && std::isspace((unsigned char)*end)) end++;

	return (*end == '\0');
}

static inline std::string sanitize(const std::string& s) {
	std::string v = clean_token(s);
	if (is_invalid(v)) return "";

	std::string out;
	bool space = false;

	for (char c : v) {
		if (std::isspace((unsigned char)c)) {
			if (!space) out.push_back(' ');
			space = true;
		} else {
			out.push_back(c);
			space = false;
		}
	}

	return out;
}

// STRUCT
struct CSVTable {
	int rows;
	int cols;

	std::vector<std::string> headers;
	std::vector<std::vector<double> > num_cols;
	std::vector<bool> is_numeric;

	CSVTable() : rows(0), cols(0) {}
};

// SPLIT CSV
static std::vector<std::string> split_line(const std::string& line) {

	std::vector<std::string> out;
	std::string cur;
	bool in_quotes = false;

	for (size_t i = 0; i < line.size(); i++) {
		char c = line[i];
		if (c == '"') {
			in_quotes = !in_quotes;
			continue;
		}

		if (c == ',' && !in_quotes) {
			out.push_back(clean_token(cur));
			cur.clear();
		} else {
			cur.push_back(c);
		}
	}

	out.push_back(clean_token(cur));
	return out;
}

static std::string unquote(std::string s) {
	s = clean_token(s);

	if (s.size() >= 2 &&
		s[0] == '"' &&
		s[s.size() - 1] == '"') {
		s = s.substr(1, s.size() - 2);
	}

	return clean_token(s);
}

// READ COLUMNS
static int l_read_columns(lua_State* L) {
	const char* path = luaL_checkstring(L, 1);
	bool has_config = lua_istable(L, 2);

	std::ifstream file(path);
	if (!file.is_open()) return luaL_error(L, "cannot open file");

	std::string line;
	if (!std::getline(file, line)) return luaL_error(L, "empty file");

	std::vector<std::string> headers = split_line(line);

	CSVTable* t = new CSVTable();
	t->cols = (int)headers.size();
	t->headers = headers;

	// TYPE MAP (solo true = number)
	std::vector<bool> as_number(t->cols, false);

	if (has_config) {
		for (int c = 0; c < t->cols; c++) {
			lua_getfield(L, 2, headers[c].c_str());

			if (lua_isboolean(L, -1) && lua_toboolean(L, -1)) {
				as_number[c] = true;
			}

			lua_pop(L, 1);
		}
	}

	t->is_numeric.assign(t->cols, false);
	t->num_cols.resize(t->cols);

	std::vector<std::vector<std::string>> raw;
	raw.reserve(1000);

	// READ ALL ROWS
	while (std::getline(file, line)) {
		line = clean_cr(line);
		if (!trim(line).empty())
			raw.push_back(split_line(line));
	}

	t->rows = (int)raw.size();

	// BUILD NUMERIC COLUMNS
	for (int c = 0; c < t->cols; c++) {
		if (!as_number[c]) continue;
		t->is_numeric[c] = true;
		t->num_cols[c].reserve(t->rows);

		for (int r = 0; r < t->rows; r++) {
			std::string v = (c < (int)raw[r].size()) ? raw[r][c] : "";

			double x;
			if (to_number(v, x))
				t->num_cols[c].push_back(x);
			else
				t->num_cols[c].push_back(NAN);
		}
	}

	// EXPORT TO LUA
	lua_newtable(L);

	for (int c = 0; c < t->cols; c++) {
		lua_newtable(L);
		if (as_number[c]) {
			const auto& col = t->num_cols[c];
			for (size_t i = 0; i < col.size(); i++) {
				lua_pushnumber(L, col[i]);
				lua_rawseti(L, -2, i + 1);
			}
		} else {
			for (int r = 0; r < t->rows; r++) {
				std::string v = (c < (int)raw[r].size()) ? sanitize(raw[r][c]) : "";
				lua_pushstring(L, v.c_str());
				lua_rawseti(L, -2, r + 1);
			}
		}

		lua_setfield(L, -2, t->headers[c].c_str());
	}
	lua_pushlightuserdata(L, t);
	lua_setfield(L, -2, "_ptr");

	return 1;
}

// SAVE COLUMNS
static int l_save_columns(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	const char* path = luaL_checkstring(L, 2);

	std::ofstream out(path);
	if (!out.is_open()) return luaL_error(L, "cannot open output file");
	std::vector<std::string> headers;

	// collect headers
	lua_pushnil(L);
	while (lua_next(L, 1)) {
		if (lua_type(L, -2) == LUA_TSTRING) {
			std::string key = lua_tostring(L, -2);
			if (key != "_ptr") headers.push_back(key);
		}
		lua_pop(L, 1);
	}

	if (headers.empty()) {
		out.close();
		return 0;
	}

	// HEADER
	for (size_t i = 0; i < headers.size(); i++) {
		if (i) out << ",";
		out << headers[i];
	}
	out << "\n";

	// ROW COUNT
	int rows = 0;

	for (size_t i = 0; i < headers.size(); i++) {
		lua_getfield(L, 1, headers[i].c_str());
		int n = (int)lua_rawlen(L, -1);
		lua_pop(L, 1);
		if (n > rows) rows = n;
	}

	// DATA
	for (int r = 1; r <= rows; r++) {
		for (size_t c = 0; c < headers.size(); c++) {
			if (c) out << ",";

			lua_getfield(L, 1, headers[c].c_str());
			lua_rawgeti(L, -1, r);

			int t = lua_type(L, -1);

			// NUMBER
			if (t == LUA_TNUMBER) {
				double v = lua_tonumber(L, -1);
				if (std::isfinite(v) && !std::isnan(v)) out << v;
			}

			// STRING
			else if (t == LUA_TSTRING) {
				std::string s = lua_tostring(L, -1);

				if (!is_invalid(s)) {
					s = sanitize(s);
					bool quote =
						(s.find(',') != std::string::npos ||
						 s.find('"') != std::string::npos);

					if (quote) {
						out << "\"";
						for (char ch : s) {
							if (ch == '"') out << "\"\"";
							else out << ch;
						}
						out << "\"";
					} else {
						out << s;
					}
				}
			}
			lua_pop(L, 2);
		}
		out << "\n";
	}

	out.close();

	lua_pushboolean(L, 1);
	return 1;
}

// COUNT ROWS
static int l_count_rows(lua_State* L) {
	const char* path = luaL_checkstring(L, 1);
	std::ifstream file(path);
	if (!file.is_open()) return luaL_error(L, "cannot open file");

	std::string line;
	std::getline(file, line); // header

	int rows = 0;
	while (std::getline(file, line)) rows++;

	lua_pushinteger(L, rows);
	return 1;
}

// VARIANCE
static int l_variance(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	double sum = 0.0;
	int n = 0;

	lua_pushnumber(L, NAN);
	while (lua_next(L, 1)) {
		double v = lua_tonumber(L, -1);
		if (!std::isnan(v)) {
			sum += v;
			n++;
		}
		lua_pop(L, 1);
	}

	if (n == 0) {
		lua_pushnumber(L, 0);
		return 1;
	}

	double mean = sum / n;
	double var = 0.0;

	lua_pushnil(L);
	while (lua_next(L, 1)) {
		double v = lua_tonumber(L, -1);

		if (!std::isnan(v)) {
			double d = v - mean;
			var += d * d;
		}

		lua_pop(L, 1);
	}

	lua_pushnumber(L, var / n);
	return 1;
}

// TO NUMBER
static int l_to_number(lua_State* L) {
	const char* s = luaL_checkstring(L, 1);

	double v;
	if (!to_number(s, v)) {
		lua_pushnil(L);
		return 1;
	}

	lua_pushnumber(L, v);
	return 1;
}

// EACH
static int l_each(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    // ---- CONFIG ----
    if (!lua_istable(L, 3)) {
        return luaL_error(L, "config table required");
    }

    int config_idx = 3;

    int start_row = 1;
    int offset = 0;
    int sample = 1;
    int limit = INT_MAX;

    // OPTIONS
    lua_getfield(L, config_idx, "start_row");
    if (lua_isnumber(L, -1))
        start_row = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, config_idx, "offset");
    if (lua_isnumber(L, -1))
        offset = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, config_idx, "sample");
    if (lua_isnumber(L, -1))
        sample = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, config_idx, "limit");
    if (lua_isnumber(L, -1))
        limit = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);

    if (sample <= 0) sample = 1;

    // ---- FILE ----
    std::ifstream file(path);
    if (!file.is_open())
        return luaL_error(L, "cannot open file");

    std::string line;
    if (!std::getline(file, line))
        return 0;

    // ---- HEADERS ----
    std::vector<std::string> raw_headers = split_line(line);
    int cols_n = (int)raw_headers.size();

    std::vector<std::string> headers(cols_n);

    for (int c = 0; c < cols_n; c++) {
        headers[c] = trim(clean_cr(raw_headers[c]));
    }

    // ---- SCHEMA OBLIGATORIO ----
    lua_getfield(L, config_idx, "schema");

    if (!lua_istable(L, -1)) {
        return luaL_error(L, "config.schema required");
    }

    int schema_idx = lua_gettop(L);

    // ---- TYPE MAP ----
    std::vector<bool> as_number(cols_n, false);

    for (int c = 0; c < cols_n; c++) {
        const std::string& h = headers[c];
        if (h.empty()) continue;

        lua_getfield(L, schema_idx, h.c_str());

        if (lua_isnil(L, -1)) {
            return luaL_error(L,
                "schema missing column: %s",
                h.c_str()
            );
        }

        if (!lua_isboolean(L, -1)) {
            return luaL_error(L,
                "schema must be boolean: %s",
                h.c_str()
            );
        }

        as_number[c] = lua_toboolean(L, -1);
        lua_pop(L, 1);
    }

    lua_pop(L, 1); // pop schema

    // ---- STREAM ----
    int i = 0;
    int emitted = 0;

    while (std::getline(file, line)) {
        line = clean_cr(line);
        if (trim(line).empty()) continue;

        i++;
        if (i < start_row) continue;

        int rel_i = i - start_row + 1;
        if (rel_i <= offset) continue;
        if (((rel_i - offset) % sample) != 0) continue;

        std::vector<std::string> cols = split_line(line);

        lua_pushvalue(L, 2); // callback
        lua_newtable(L);     // row

        for (int c = 0; c < cols_n; c++) {
            const std::string& h = headers[c];
            if (h.empty()) continue;

            std::string v = (c < (int)cols.size()) ? cols[c] : "";

            if (as_number[c]) {
                double num;
                if (to_number(v, num))
                    lua_pushnumber(L, num);
                else
                    lua_pushnumber(L, NAN);
            } else {
                std::string s = sanitize(v);
                lua_pushstring(L, s.c_str());
            }

            lua_setfield(L, -2, h.c_str());
        }

        emitted++;

        lua_pushinteger(L, emitted);
        lua_pushinteger(L, i);

        lua_call(L, 3, 0);

        if (emitted >= limit) break;
    }

    file.close();
    return 0;
}
static int l_export_rows(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	const char* path = luaL_checkstring(L, 2);

	std::ofstream out(path);
	if (!out.is_open()) return luaL_error(L, "cannot open output file");

	int row_count = (int)lua_rawlen(L, 1);
	if (row_count == 0) return luaL_error(L, "dataset vacío");

	// 1. HEADERS desde fila 1 (orden estable + completo)
	lua_rawgeti(L, 1, 1);
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return luaL_error(L, "row[1] inválida");
	}
	std::vector<std::string> headers;
	lua_pushnil(L);
	while (lua_next(L, -2)) {
		if (lua_type(L, -2) == LUA_TSTRING) {
			headers.push_back(lua_tostring(L, -2));
		}
		lua_pop(L, 1);
	}
	lua_pop(L, 1);
	if (headers.empty()) return luaL_error(L, "no headers encontrados");

	// 2. CSV HEADER
	for (size_t i = 0; i < headers.size(); i++) {
		if (i) out << ",";
		out << headers[i];
	}
	out << "\n";

	// 3. ROWS
	for (int i = 1; i <= row_count; i++) {
		lua_rawgeti(L, 1, i);
		if (!lua_istable(L, -1)) {
			lua_pop(L, 1);
			continue;
		}

		for (size_t c = 0; c < headers.size(); c++) {
			if (c) out << ",";
			lua_getfield(L, -1, headers[c].c_str());
			int t = lua_type(L, -1);
			if (t == LUA_TNUMBER) {
				double v = lua_tonumber(L, -1);
				if (std::isfinite(v))
					out << v;
				else
					out << "NaN";
			}
			else if (t == LUA_TSTRING) {
				std::string s = lua_tostring(L, -1);
				if (is_invalid(s)) {
					out << "NaN";
				} else {
					s = sanitize(s);
					bool quote = (s.find(',') != std::string::npos || s.find('"') != std::string::npos);
					if (quote) {
						out << "\"";
						for (char ch : s) {
							if (ch == '"') out << "\"\"";
							else out << ch;
						}
						out << "\"";
					} else {
						out << s;
					}
				}
			}
			else {
				// NIL u otro tipo
				out << "NaN";
			}

			lua_pop(L, 1);
		}
		lua_pop(L, 1);
		out << "\n";
	}
	out.close();
	lua_pushboolean(L, 1);
	return 1;
}

// MODULE
extern "C" {
static const luaL_Reg funcs[] = {
	{"read_columns", l_read_columns},
	{"save_columns", l_save_columns},
	{"export_rows", l_export_rows},
	{"count_rows", l_count_rows},
	{"each", l_each},
	{"to_number", l_to_number},
	{"variance", l_variance},
	{NULL, NULL}
};

int luaopen_csvfast(lua_State* L) {
	luaL_newlib(L, funcs);
	return 1;
}
}
