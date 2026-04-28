#!/usr/bin/env python3
import json
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os
import pandas as pd
import scipy.stats as stats

# CONFIG
OUT_DIR = "plots"
os.makedirs(OUT_DIR, exist_ok=True)
sns.set(style="whitegrid")

# 1. LOAD MODEL
with open("data/coeficientes.json", "r") as f:
    model = json.load(f)

features = model["features"]
weights  = np.array(model["weights"], dtype=float)
bias     = model.get("bias", 0.0)

# 2. SIMULATED FEATURE SPACE
np.random.seed(42)
N = 1000

X = {}

for f in features:
    match f:
        case "sex" | "is_alone":
            X[f] = np.random.randint(0, 2, N)

        case "pclass":
            X[f] = np.random.randint(1, 4, N)

        case "age":
            X[f] = np.random.normal(30, 12, N).clip(0, 80)

        case "fare":
            X[f] = np.random.gamma(2, 20, N)

        case _:
            X[f] = np.random.normal(0, 1, N)

# 3. LOGISTIC MODEL
def sigmoid(z): return 1 / (1 + np.exp(-z))

Z = bias
for i, f in enumerate(features): Z += X[f] * weights[i]
proba = sigmoid(Z)

# Generar variable realista
y_real = np.random.binomial(1, proba)

pred = (proba > 0.5).astype(int)

# 4. DATAFRAME
df = pd.DataFrame(X)
df["proba"] = proba
df["pred"] = pred
df["y_real"] = y_real

# 5. RESIDUOS
residuos = y_real - proba

# 6. VISUALIZACIONES EXISTENTES

# Survival rate by sex
sex = X.get("sex", np.zeros(N))

plt.figure(figsize=(6,4))
plt.bar(["Hombre", "Mujer"], [pred[sex==0].mean(), pred[sex==1].mean()])
plt.title("Supervivencia simulada por sexo")
plt.savefig(f"{OUT_DIR}/parte2_01_sex.png")
plt.close()

# Distribucion de probabilidades
plt.figure(figsize=(7,4))
plt.hist(proba, bins=30, alpha=0.7)
plt.title("Distribucion de probabilidades del modelo")
plt.savefig(f"{OUT_DIR}/parte2_02_proba.png")
plt.close()

# Feature importance
plt.figure(figsize=(8,4))
sns.barplot(x=features, y=weights)
plt.xticks(rotation=35)
plt.title("Importancia de features")
plt.savefig(f"{OUT_DIR}/parte2_03_weights.png")
plt.close()

# Odds ratios
plt.figure(figsize=(8,4))
sns.barplot(x=features, y=np.exp(weights))
plt.xticks(rotation=35)
plt.title("Odds ratios")
plt.savefig(f"{OUT_DIR}/parte2_04_odds.png")
plt.close()

# 7. NUEVAS GRAFICAS

# Residuos vs ajustados
plt.figure(figsize=(6,4))
plt.scatter(proba, residuos, alpha=0.5)
plt.axhline(0, linestyle='--')
plt.xlabel("Valores ajustados (proba)")
plt.ylabel("Residuos")
plt.title("Residuos vs Valores Ajustados")
plt.savefig(f"{OUT_DIR}/parte2_05_residuos_vs_ajustados.png")
plt.close()

# Q-Q plot
plt.figure(figsize=(6,4))
stats.probplot(residuos, dist="norm", plot=plt)
plt.title("Q-Q Plot de Residuos")
plt.savefig(f"{OUT_DIR}/parte2_06_qqplot.png")
plt.close()

# Histograma de residuos
plt.figure(figsize=(6,4))
plt.hist(residuos, bins=30, alpha=0.7)
plt.xlabel("Residuos")
plt.ylabel("Frecuencia")
plt.title("Histograma de Residuos")
plt.savefig(f"{OUT_DIR}/parte2_07_hist_residuos.png")
plt.close()

# Matriz de correlacion
plt.figure(figsize=(10,6))
corr = df.corr(numeric_only=True)
sns.heatmap(corr, cmap="coolwarm", center=0)
plt.title("Matriz de Correlacion")
plt.savefig(f"{OUT_DIR}/parte2_08_correlacion.png")
plt.close()

# 8. SUMMARY
print("\n=========== MODELO ===========")
for f, w in zip(features, weights): print(f"{f:<15} weight={w:8.4f}")

print("\nBias:", bias)
print("Accuracy simulada:", (pred == y_real).mean())
print("Prob media:", proba.mean())
