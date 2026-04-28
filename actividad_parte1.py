import os
import glob
import json
import math
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import scipy.stats as stats

# CONFIG
JSON_PATTERN = "data/output_worker_*.json"
OUT_DIR = "plots"

os.makedirs(OUT_DIR, exist_ok=True)
sns.set(style="whitegrid")

# LOAD FILES
files = sorted(glob.glob(JSON_PATTERN))

if not files:
    # print("No se encontraron JSON.")
    exit()

rows = []

# HELPERS
def num(v):
    try:
        if v is None:
            return math.nan
        return float(v)
    except:
        return math.nan

# ==============================
# READ JSON (RESUMEN)
# ==============================
for file in files:
    with open(file, "r", encoding="utf-8") as f:
        data = json.load(f)

    metrics = data.get("metrics", {})
    correlations = data.get("correlations", {})
    preds = data.get("predictions", [])

    row = {
        "worker_id": data.get("worker_id", 0),

        "rows_total": num(data.get("rows_total")),
        "train_size": num(data.get("train_size")),
        "test_size": num(data.get("test_size")),

        "r2_train": num(metrics.get("r2_train")),
        "mse_train": num(metrics.get("mse_train")),
        "rmse_train": num(metrics.get("rmse_train")),

        "r2_test": num(metrics.get("r2_test")),
        "mse_test": num(metrics.get("mse_test")),
        "rmse_test": num(metrics.get("rmse_test")),

        "corr_odometer": num(correlations.get("odometer_price")),
        "corr_mmr": num(correlations.get("mmr_price")),

        "pred_count": len(preds)
    }

    rows.append(row)

df = pd.DataFrame(rows)

if df.empty:
    print("No hay datos.")
    exit()

df = df.sort_values("worker_id")
df.replace([math.inf, -math.inf], math.nan, inplace=True)

# ==============================
# EXTRAER REAL VS PRED GLOBAL
# ==============================
reales = []
preds = []

for file in files:
    with open(file, "r", encoding="utf-8") as f:
        data = json.load(f)

    for item in data.get("predictions", []):
        real = num(item.get("real"))
        pred = num(item.get("pred"))

        if not math.isnan(real) and not math.isnan(pred):
            reales.append(real)
            preds.append(pred)

reales = pd.Series(reales)
preds = pd.Series(preds)

# ==============================
# RESIDUOS
# ==============================
if len(reales) > 0:
    residuos = reales - preds
else:
    residuos = pd.Series(dtype=float)

# ==============================
# GUARDAR CSV
# ==============================
df.to_csv(f"{OUT_DIR}/resumen_workers.csv", index=False)

# ==============================
# GRAFICAS EXISTENTES
# ==============================
tmp = df.dropna(subset=["r2_test"])
if not tmp.empty:
    plt.figure(figsize=(12,6))
    plt.bar(tmp["worker_id"], tmp["r2_test"])
    plt.title("R² Test por Worker")
    plt.savefig(f"{OUT_DIR}/parte1_r2_test.png", dpi=200)
    plt.close()

tmp = df.dropna(subset=["rmse_test"])
if not tmp.empty:
    plt.figure(figsize=(12,6))
    plt.bar(tmp["worker_id"], tmp["rmse_test"])
    plt.title("RMSE Test por Worker")
    plt.savefig(f"{OUT_DIR}/parte1_rmse_test.png", dpi=200)
    plt.close()

tmp = df.dropna(subset=["rows_total"])
if not tmp.empty:
    plt.figure(figsize=(12,6))
    plt.bar(tmp["worker_id"], tmp["rows_total"])
    plt.title("Cantidad de registros por Worker")
    plt.savefig(f"{OUT_DIR}/parte1_rows_worker.png", dpi=200)
    plt.close()

# ==============================
# NUEVAS GRAFICAS
# ==============================

# 1. Residuos vs valores ajustados
if len(residuos) > 0:
    plt.figure(figsize=(6,4))
    plt.scatter(preds, residuos, alpha=0.5)
    plt.axhline(0, linestyle='--')
    plt.xlabel("Valores ajustados (pred)")
    plt.ylabel("Residuos")
    plt.title("Residuos vs Valores Ajustados")
    plt.savefig(f"{OUT_DIR}/parte2_residuos_vs_ajustados.png", dpi=200)
    plt.close()

# 2. Q-Q plot
if len(residuos) > 0:
    plt.figure(figsize=(6,4))
    stats.probplot(residuos, dist="norm", plot=plt)
    plt.title("Q-Q Plot de Residuos")
    plt.savefig(f"{OUT_DIR}/parte2_qqplot.png", dpi=200)
    plt.close()

# 3. Histograma de residuos
if len(residuos) > 0:
    plt.figure(figsize=(6,4))
    plt.hist(residuos, bins=30, alpha=0.7)
    plt.title("Histograma de Residuos")
    plt.savefig(f"{OUT_DIR}/parte2_hist_residuos.png", dpi=200)
    plt.close()

# 4. Matriz de correlación (workers)
plt.figure(figsize=(10,6))
corr = df.corr(numeric_only=True)
sns.heatmap(corr, cmap="coolwarm", center=0)
plt.title("Matriz de Correlación (Workers)")
plt.savefig(f"{OUT_DIR}/parte2_correlacion.png", dpi=200)
plt.close()

# 5. Real vs Pred (ya lo tenías, lo dejo)
if len(reales) > 0:
    plt.figure(figsize=(8,8))
    plt.scatter(reales, preds, alpha=0.55)

    mn = min(min(reales), min(preds))
    mx = max(max(reales), max(preds))

    plt.plot([mn, mx], [mn, mx], "--")
    plt.title("Real vs Predicho")
    plt.savefig(f"{OUT_DIR}/parte1_real_vs_pred.png", dpi=250)
    plt.close()

# ==============================
# RESUMEN
# ==============================
print("\n===== RESUMEN GENERAL =====")
print(df.describe())

if df["r2_test"].notna().any():
    best = df.loc[df["r2_test"].idxmax()]
    print("\nMejor Worker:")
    print(best[["worker_id", "r2_test", "rmse_test"]])

if df["rmse_test"].notna().any():
    worst = df.loc[df["rmse_test"].idxmax()]
    print("\nPeor Worker:")
    print(worst[["worker_id", "r2_test", "rmse_test"]])

print(f"\nGraficas guardadas en: {OUT_DIR}")