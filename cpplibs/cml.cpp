extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

#include <vector>
#include <string>
#include <cmath>
#include <cctype>
#include <cstdlib>
#include <stdio.h>

// LUA COMPAT
#ifndef lua_rawlen
#define lua_rawlen(L, i) lua_objlen(L, i)
#endif

#ifndef luaL_newlib
static inline void luaL_newlib(lua_State* L, const luaL_Reg* l) {
    lua_newtable(L);
    luaL_setfuncs(L, l, 0);
}
#endif

// METRICS
struct Metrics {
    double r2;
    double mse;
    double rmse;
};

struct TrainResult {
    Metrics train;
    Metrics test;
};

// NUM PARSER
static inline double parse_number(const char* s) {
    if (!s) return NAN;

    while (*s && isspace((unsigned char)*s)) s++;
    if (*s == 0) return NAN;

    std::string tmp(s);

    for (char& c : tmp)
        if (c == ',') c = '.';

    char* end = nullptr;
    double v = strtod(tmp.c_str(), &end);

    if (end == tmp.c_str()) return NAN;
    while (*end && isspace((unsigned char)*end)) end++;
    return (*end == 0) ? v : NAN;
}

static inline double to_number(lua_State* L, int idx) {
    if (lua_isnumber(L, idx)) return lua_tonumber(L, idx);
    if (lua_isstring(L, idx)) return parse_number(lua_tostring(L, idx));
    return NAN;
}

// LINEAR REGRESSION
struct LinearRegression {
    std::vector<std::string> features;
    std::string target;

    std::vector<double> weights;

    std::vector<std::vector<double>> X;
    std::vector<double> y;

    std::vector<double> mean_x;
    std::vector<double> std_x;

    double mean_y = 0.0;
    double std_y  = 1.0;

    // LOAD RAW DATASET
    void build_matrix(lua_State* L, int idx) {
        X.clear();
        y.clear();

        int n = (int)lua_rawlen(L, idx);
        int k = (int)features.size();

        for (int i = 1; i <= n; i++) {
            lua_rawgeti(L, idx, i);
            std::vector<double> row(k);
            bool ok = true;

            for (int j = 0; j < k; j++) {
                lua_getfield(L, -1, features[j].c_str());
                double v = to_number(L, -1);
                lua_pop(L, 1);

                if (!std::isfinite(v)) ok = false;
                row[j] = v;
            }

            lua_getfield(L, -1, target.c_str());
            double yt = to_number(L, -1);
            lua_pop(L, 1);
            lua_pop(L, 1);

            if (!ok || !std::isfinite(yt)) continue;

            X.push_back(row);
            y.push_back(yt);
        }
    }

    // TRAIN STATS ONLY
    void compute_stats(
        const std::vector<std::vector<double>>& X_train,
        const std::vector<double>& y_train
    ) {
        int n = (int)X_train.size();
        int k = (int)features.size();

        mean_x.assign(k, 0.0);
        std_x.assign(k, 0.0);

        mean_y = 0.0;
        std_y  = 0.0;

        for (int i = 0; i < n; i++) {
            mean_y += y_train[i];
            for (int j = 0; j < k; j++) mean_x[j] += X_train[i][j];
        }

        mean_y /= n;
        for (int j = 0; j < k; j++) mean_x[j] /= n;
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < k; j++) {
                double d = X_train[i][j] - mean_x[j];
                std_x[j] += d * d;
            }
            double dy = y_train[i] - mean_y;
            std_y += dy * dy;
        }

        for (int j = 0; j < k; j++) std_x[j] = std::sqrt(std_x[j] / n + 1e-12);
        std_y = std::sqrt(std_y / n + 1e-12);
    }

    // NORMALIZE USING TRAIN STATS
    void normalize_dataset(
        std::vector<std::vector<double>>& Xd,
        std::vector<double>& yd
    ) {
        int n = (int)Xd.size();
        int k = (int)features.size();

        for (int i = 0; i < n; i++) {
            for (int j = 0; j < k; j++) { Xd[i][j] = (Xd[i][j] - mean_x[j]) / (std_x[j] + 1e-12); }
            yd[i] = (yd[i] - mean_y) / (std_y + 1e-12);
        }
    }

    // TRAIN IN NORMALIZED SPACE
    void fit(
        double lr,
        int epochs,
        const std::vector<std::vector<double>>& X_train,
        const std::vector<double>& y_train
    ) {
        int n = (int)X_train.size();
        int k = (int)features.size();

        weights.assign(k + 1, 0.0);

        for (int e = 0; e < epochs; e++) {
            std::vector<double> grad(k + 1, 0.0);
            for (int i = 0; i < n; i++) {
                double pred = weights[0];

                for (int j = 0; j < k; j++) pred += weights[j + 1] * X_train[i][j];

                double err = pred - y_train[i];
                grad[0] += err;

                for (int j = 0; j < k; j++) grad[j + 1] += err * X_train[i][j];
            }

            for (int j = 0; j <= k; j++) weights[j] -= lr * grad[j] / n;
        }
    }

    // RAW PREDICT
    double predict_row(lua_State* L, int idx) {
        int k = (int)features.size();
        double pred = weights[0];

        for (int j = 0; j < k; j++) {
            lua_getfield(L, idx, features[j].c_str());
            double v = to_number(L, -1);
            lua_pop(L, 1);

            v = (v - mean_x[j]) / (std_x[j] + 1e-12);

            pred += weights[j + 1] * v;
        }

        return pred * std_y + mean_y;
    }
};

// SPLIT
static void split_dataset(
    const std::vector<std::vector<double>>& X,
    const std::vector<double>& y,
    double ratio,

    std::vector<std::vector<double>>& X_train,
    std::vector<double>& y_train,

    std::vector<std::vector<double>>& X_test,
    std::vector<double>& y_test
) {
    int n = (int)X.size();
    int split = (int)(n * ratio);

    if (split < 1) split = 1;
    if (split >= n) split = n - 1;

    X_train.assign(X.begin(), X.begin() + split);
    y_train.assign(y.begin(), y.begin() + split);

    X_test.assign(X.begin() + split, X.end());
    y_test.assign(y.begin() + split, y.end());
}

// EVALUATE (normalized X/y)
static Metrics evaluate(
    LinearRegression& m,
    const std::vector<std::vector<double>>& Xd,
    const std::vector<double>& yd
) {
    int n = (int)Xd.size();
    int k = (int)m.features.size();

    double mean = 0.0;
    for (int i = 0; i < n; i++)
        mean += yd[i];

    mean /= n;

    double ss_res = 0.0;
    double ss_tot = 0.0;

    for (int i = 0; i < n; i++) {
        double pred = m.weights[0];
        for (int j = 0; j < k; j++)
            pred += m.weights[j + 1] * Xd[i][j];

        double err = yd[i] - pred;
        ss_res += err * err;

        double diff = yd[i] - mean;
        ss_tot += diff * diff;
    }

    double mse = ss_res / n;
    double rmse = std::sqrt(mse);

    double r2 = 0.0;
    if (ss_tot > 1e-12) r2 = 1.0 - ss_res / ss_tot;

    return {r2, mse, rmse};
}

// FULL TRAIN
static TrainResult fit_full(
    LinearRegression& m,
    double lr,
    int epochs,
    double ratio
) {
    std::vector<std::vector<double>> X_train, X_test;
    std::vector<double> y_train, y_test;

    split_dataset(
        m.X, m.y, ratio,
        X_train, y_train,
        X_test, y_test
    );

    m.compute_stats(X_train, y_train);

    m.normalize_dataset(X_train, y_train);
    m.normalize_dataset(X_test, y_test);

    m.fit(lr, epochs, X_train, y_train);

    Metrics train_m = evaluate(m, X_train, y_train);
    Metrics test_m  = evaluate(m, X_test, y_test);

    return {train_m, test_m};
}

// LUA BINDINGS
static LinearRegression* check_lr(lua_State* L) {
    return *(LinearRegression**)luaL_checkudata(
        L, 1, "cml.LinearRegression"
    );
}

static int lr_new(lua_State* L) {
    auto** obj = (LinearRegression**)lua_newuserdata(L, sizeof(LinearRegression*));
    *obj = new LinearRegression();
    luaL_getmetatable(L, "cml.LinearRegression");
    lua_setmetatable(L, -2);

    lua_getfield(L, 1, "features");

    int n = (int)lua_rawlen(L, -1);

    for (int i = 1; i <= n; i++) {
        lua_rawgeti(L, -1, i);
        (*obj)->features.push_back(lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    lua_pop(L, 1);

    lua_getfield(L, 1, "target");
    (*obj)->target = lua_tostring(L, -1);
    lua_pop(L, 1);

    return 1;
}

static int lr_fit(lua_State* L) {
    auto* m = check_lr(L);

    double lr     = luaL_optnumber(L, 3, 0.01);
    int epochs    = (int)luaL_optinteger(L, 4, 1000);
    double ratio  = luaL_optnumber(L, 5, 0.8);

    m->build_matrix(L, 2);

    TrainResult r = fit_full(*m, lr, epochs, ratio);

    lua_newtable(L);

    lua_newtable(L);
    lua_pushnumber(L, r.train.r2);   lua_setfield(L, -2, "r2");
    lua_pushnumber(L, r.train.mse);  lua_setfield(L, -2, "mse");
    lua_pushnumber(L, r.train.rmse); lua_setfield(L, -2, "rmse");
    lua_setfield(L, -2, "train");

    lua_newtable(L);
    lua_pushnumber(L, r.test.r2);   lua_setfield(L, -2, "r2");
    lua_pushnumber(L, r.test.mse);  lua_setfield(L, -2, "mse");
    lua_pushnumber(L, r.test.rmse); lua_setfield(L, -2, "rmse");
    lua_setfield(L, -2, "test");

    return 1;
}

static int lr_predict(lua_State* L) {
    auto* m = check_lr(L);
    lua_pushnumber(L, m->predict_row(L, 2));
    return 1;
}

static int lr_gc(lua_State* L) {
    auto** obj = (LinearRegression**)luaL_checkudata(L, 1, "cml.LinearRegression");
    delete *obj;
    return 0;
}

static int lr_export(lua_State* L) {
    auto* m = check_lr(L);
    lua_newtable(L);

    // features
    lua_newtable(L);
    for (size_t i = 0; i < m->features.size(); i++) {
        lua_pushstring(L, m->features[i].c_str());
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "features");

    // weights
    lua_newtable(L);
    for (size_t i = 0; i < m->weights.size(); i++) {
        lua_pushnumber(L, m->weights[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "weights");

    // FIX REAL: bias reconstruido en espacio original
    double bias = m->weights[0] * m->std_y + m->mean_y;

    for (size_t j = 0; j < m->features.size(); j++) {
        bias -= (m->weights[j + 1] * m->mean_x[j] * m->std_y / (m->std_x[j] + 1e-12));
    }

    lua_pushnumber(L, bias);
    lua_setfield(L, -2, "bias");

    return 1;
}

// TABLES
static const luaL_Reg methods[] = {
    {"fit",     lr_fit},
    {"predict", lr_predict},
    {"export",  lr_export},
    {NULL, NULL}
};

static const luaL_Reg lib[] = {
    {"LinearRegression", lr_new},
    {NULL, NULL}
};


// LOGISTIC REGRESSION
struct LogisticRegression {
    std::vector<std::string> features;
    std::string target;

    std::vector<double> weights;

    std::vector<std::vector<double>> X;
    std::vector<double> y;

    std::vector<double> mean_x;
    std::vector<double> std_x;

    // LOAD DATASET
    void build_matrix(lua_State* L, int idx) {
        X.clear();
        y.clear();

        int n = (int)lua_rawlen(L, idx);
        int k = (int)features.size();

        for (int i = 1; i <= n; i++) {
            lua_rawgeti(L, idx, i);
            std::vector<double> row(k);
            bool ok = true;

            for (int j = 0; j < k; j++) {
                lua_getfield(L, -1, features[j].c_str());
                double v = to_number(L, -1);
                lua_pop(L, 1);

                if (!std::isfinite(v)) ok = false;

                row[j] = v;
            }

            lua_getfield(L, -1, target.c_str());
            double yt = to_number(L, -1);
            lua_pop(L, 1);
            lua_pop(L, 1);

            if (!ok || !std::isfinite(yt)) continue;

            yt = (yt >= 0.5) ? 1.0 : 0.0;

            X.push_back(row);
            y.push_back(yt);
        }
    }

    // NORMALIZATION
    void compute_stats() {
        int n = (int)X.size();
        int k = (int)features.size();

        mean_x.assign(k, 0.0);
        std_x.assign(k, 0.0);

        for (int i = 0; i < n; i++)
            for (int j = 0; j < k; j++)
                mean_x[j] += X[i][j];

        for (int j = 0; j < k; j++) mean_x[j] /= n;

        for (int i = 0; i < n; i++) {
            for (int j = 0; j < k; j++) {
                double d = X[i][j] - mean_x[j];
                std_x[j] += d * d;
            }
        }

        for (int j = 0; j < k; j++)
            std_x[j] = std::sqrt(std_x[j] / n + 1e-12);
    }

    void normalize() {
        int n = (int)X.size();
        int k = (int)features.size();

        compute_stats();

        for (int i = 0; i < n; i++)
            for (int j = 0; j < k; j++)
                X[i][j] = (X[i][j] - mean_x[j]) / std_x[j];
    }

    static inline double sigmoid(double z) {
        if (z > 35.0) return 1.0;
        if (z < -35.0) return 0.0;

        return 1.0 / (1.0 + std::exp(-z));
    }

    // TRAIN
    void fit(double lr, int epochs) {
        int n = (int)X.size();
        int k = (int)features.size();

        weights.assign(k + 1, 0.0);

        for (int e = 0; e < epochs; e++) {
            std::vector<double> grad(k + 1, 0.0);
            for (int i = 0; i < n; i++) {
                double z = weights[0];
                for (int j = 0; j < k; j++) z += weights[j + 1] * X[i][j];
                double pred = sigmoid(z);
                double err  = pred - y[i];
                grad[0] += err;
                for (int j = 0; j < k; j++) grad[j + 1] += err * X[i][j];
            }

            for (int j = 0; j <= k; j++) weights[j] -= lr * grad[j] / n;
        }
    }

    double probability_row(lua_State* L, int idx) {
        int k = (int)features.size();
        double z = weights[0];

        for (int j = 0; j < k; j++) {
            lua_getfield(L, idx, features[j].c_str());
            double v = to_number(L, -1);
            lua_pop(L, 1);
            v = (v - mean_x[j]) / std_x[j];
            z += weights[j + 1] * v;
        }

        return sigmoid(z);
    }

    double predict_row(lua_State* L, int idx) {
        return probability_row(L, idx) >= 0.5 ? 1.0 : 0.0;
    }

    double accuracy(lua_State* L, int idx) {
        int n = (int)lua_rawlen(L, idx);
        int ok = 0;
        int total = 0;

        for (int i = 1; i <= n; i++) {
            lua_rawgeti(L, idx, i);

            lua_getfield(L, -1, target.c_str());
            double real = to_number(L, -1);
            lua_pop(L, 1);

            if (std::isfinite(real)) {
                double pred = predict_row(L, -1);

                if ((real >= 0.5 && pred == 1.0) ||
                    (real < 0.5 && pred == 0.0))
                    ok++;

                total++;
            }

            lua_pop(L, 1);
        }

        if (total == 0)
            return 0.0;

        return (double)ok / total;
    }
};

static LogisticRegression* check_logr(lua_State* L) {
    return *(LogisticRegression**)luaL_checkudata(
        L, 1, "cml.LogisticRegression"
    );
}

static int logr_new(lua_State* L) {
    auto** obj = (LogisticRegression**)lua_newuserdata(L, sizeof(LogisticRegression*));
    *obj = new LogisticRegression();

    luaL_getmetatable(L, "cml.LogisticRegression");
    lua_setmetatable(L, -2);

    lua_getfield(L, 1, "features");

    int n = (int)lua_rawlen(L, -1);

    for (int i = 1; i <= n; i++) {
        lua_rawgeti(L, -1, i);
        (*obj)->features.push_back(lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    lua_pop(L, 1);

    lua_getfield(L, 1, "target");
    (*obj)->target = lua_tostring(L, -1);
    lua_pop(L, 1);

    return 1;
}

static int logr_normalize(lua_State* L) {
    auto* m = check_logr(L);
    m->normalize();
    return 0;
}

static int logr_train(lua_State* L) {
    auto* m = check_logr(L);

    double lr  = luaL_optnumber(L, 2, 0.01);
    int epochs = (int)luaL_optinteger(L, 3, 1000);

    m->fit(lr, epochs);
    return 0;
}

static int logr_load(lua_State* L) {
    auto* m = check_logr(L);
    m->build_matrix(L, 2);
    return 0;
}

static int logr_predict(lua_State* L) {
    auto* m = check_logr(L);
    lua_pushnumber(L, m->predict_row(L, 2));
    return 1;
}

static int logr_probability(lua_State* L) {
    auto* m = check_logr(L);
    lua_pushnumber(L, m->probability_row(L, 2));
    return 1;
}

static int logr_accuracy(lua_State* L) {
    auto* m = check_logr(L);
    lua_pushnumber(L, m->accuracy(L, 2));
    return 1;
}

static int logr_gc(lua_State* L) {
    auto** obj =
        (LogisticRegression**)luaL_checkudata(
            L, 1, "cml.LogisticRegression"
        );

    delete *obj;
    return 0;
}

static int logr_fit(lua_State* L) {
    auto* m = check_logr(L);

    double lr    = luaL_optnumber(L, 3, 0.01);
    int epochs   = (int)luaL_optinteger(L, 4, 1000);
    double ratio = luaL_optnumber(L, 5, 0.8);

    m->build_matrix(L, 2);

    int n = (int)m->X.size();
    if (n < 2) {
        lua_newtable(L);
        return 1;
    }

    int split = (int)(n * ratio);
    if (split < 1) split = 1;
    if (split >= n) split = n - 1;

    auto Xtrain = std::vector<std::vector<double>>(m->X.begin(), m->X.begin() + split);
    auto ytrain = std::vector<double>(m->y.begin(), m->y.begin() + split);

    auto Xtest  = std::vector<std::vector<double>>(m->X.begin() + split, m->X.end());
    auto ytest  = std::vector<double>(m->y.begin() + split, m->y.end());

    // IMPORTANTE: stats SOLO en train
    m->compute_stats();

    // normalizar COPIAS, no el objeto base
    auto norm = [&](auto& Xd) {
        for (auto& row : Xd) {
            for (size_t j = 0; j < row.size(); j++) {
                row[j] = (row[j] - m->mean_x[j]) / (m->std_x[j] + 1e-12);
            }
        }
    };

    norm(Xtrain);
    norm(Xtest);

    m->weights.assign(m->features.size() + 1, 0.0);

    // train
    for (int e = 0; e < epochs; e++) {
        std::vector<double> grad(m->weights.size(), 0.0);

        for (size_t i = 0; i < Xtrain.size(); i++) {
            double z = m->weights[0];

            for (size_t j = 0; j < m->features.size(); j++)
                z += m->weights[j + 1] * Xtrain[i][j];

            double pred = LogisticRegression::sigmoid(z);
            double err = pred - ytrain[i];

            grad[0] += err;
            for (size_t j = 0; j < m->features.size(); j++)
                grad[j + 1] += err * Xtrain[i][j];
        }

        for (size_t j = 0; j < m->weights.size(); j++)
            m->weights[j] -= lr * grad[j] / Xtrain.size();
    }

    // eval train
    int ok_train = 0;
    for (size_t i = 0; i < Xtrain.size(); i++) {
        double z = m->weights[0];
        for (size_t j = 0; j < m->features.size(); j++)
            z += m->weights[j + 1] * Xtrain[i][j];

        ok_train += (LogisticRegression::sigmoid(z) >= 0.5) == (ytrain[i] > 0.5);
    }

    // eval test
    int ok_test = 0;
    for (size_t i = 0; i < Xtest.size(); i++) {
        double z = m->weights[0];
        for (size_t j = 0; j < m->features.size(); j++)
            z += m->weights[j + 1] * Xtest[i][j];

        ok_test += (LogisticRegression::sigmoid(z) >= 0.5) == (ytest[i] > 0.5);
    }

    lua_newtable(L);

    lua_newtable(L);
    lua_pushnumber(L, (double)ok_train / Xtrain.size());
    lua_setfield(L, -2, "accuracy");
    lua_setfield(L, -2, "train");

    lua_newtable(L);
    lua_pushnumber(L, (double)ok_test / Xtest.size());
    lua_setfield(L, -2, "accuracy");
    lua_setfield(L, -2, "test");

    return 1;
}

static int logr_get_weights(lua_State* L) {
    auto* m = check_logr(L);
    lua_newtable(L);

    for (size_t i = 0; i < m->weights.size(); i++) {
        lua_pushnumber(L, m->weights[i]);
        lua_rawseti(L, -2, i + 1);
    }

    return 1;
}

static int logr_export(lua_State* L) {
    auto* m = check_logr(L);
    lua_newtable(L);

    // features
    lua_newtable(L);
    for (size_t i = 0; i < m->features.size(); i++) {
        lua_pushstring(L, m->features[i].c_str());
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "features");

    // weights
    lua_newtable(L);
    for (size_t i = 0; i < m->weights.size(); i++) {
        lua_pushnumber(L, m->weights[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "weights");

    // bias (seguro)
    lua_pushnumber(L, m->weights.empty() ? 0.0 : m->weights[0]);
    lua_setfield(L, -2, "bias");

    return 1;
}

static const luaL_Reg logistic_methods[] = {
    {"load",        logr_load},
    {"normalize",   logr_normalize},
    {"train",       logr_train},
    {"predict",     logr_predict},
    {"probability", logr_probability},
    {"accuracy",    logr_accuracy},
    {"fit",         logr_fit},
    {"get_weights", logr_get_weights},
    {"export",      logr_export},
    {NULL, NULL}
};

// MODULE ENTRY
extern "C"
int luaopen_cml(lua_State* L) {
    // LinearRegression metatable
    luaL_newmetatable(L, "cml.LinearRegression");

    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    luaL_setfuncs(L, methods, 0);

    lua_pushcfunction(L, lr_gc);
    lua_setfield(L, -2, "__gc");

    lua_pop(L, 1);

    // LogisticRegression metatable
    luaL_newmetatable(L, "cml.LogisticRegression");

    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    luaL_setfuncs(L, logistic_methods, 0);

    lua_pushcfunction(L, logr_gc);
    lua_setfield(L, -2, "__gc");

    lua_pop(L, 1);

    // Main module table
    lua_newtable(L);

    lua_pushcfunction(L, lr_new);
    lua_setfield(L, -2, "LinearRegression");

    lua_pushcfunction(L, logr_new);
    lua_setfield(L, -2, "LogisticRegression");

    return 1;
}
