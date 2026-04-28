# Actividad 4 (Parte 2) --- Análisis de Sobrevivencia en el Titanic con Regresión Logística Binaria

## Resumen Ejecutivo

En esta actividad se implementó un modelo de regresión logística binaria
para predecir la sobrevivencia en el Titanic. A diferencia de enfoques
tradicionales, el dataset **no es procesado en Python**, sino que es:

-   Descargado dinámicamente
-   Limpiado y tipado en C++
-   Procesado en memoria en LuaJIT
-   Modelado con un motor en C++

Python únicamente se utiliza para visualización a partir de los
coeficientes exportados.

------------------------------------------------------------------------

# Objetivos

## Objetivo General

Predecir la sobrevivencia de pasajeros del Titanic.

## Objetivos Específicos

-   Limpieza robusta de datos
-   Feature engineering
-   Entrenamiento de modelo
-   Interpretación de coeficientes

------------------------------------------------------------------------

# Dataset

Fuente: https://www.openml.org/data/get_csv/16826755/phpMYEkMl

## Variable Dependiente

-   survived

## Variables Independientes

  -   sex
  -   pclass
  -   age
  -   fare
  -   sibsp
  -   parch
  -   family_size
  -   is_alone

Dataset limpio final: **1045 registros**

------------------------------------------------------------------------

# Pipeline

C++ (csvfast) → Limpieza → LuaJIT → Modelo (cml) → JSON → Python

------------------------------------------------------------------------

# Limpieza de Datos

Realizada en C++:

-   Eliminación de valores inválidos (NA, NULL, ?, etc.)
-   Manejo de NaN
-   Detección automática de columnas numéricas (\>85%)
-   Limpieza de strings (UTF-8, espacios, comillas)

------------------------------------------------------------------------

# Resultados

## Métricas

-   Train Accuracy: 0.8002
-   Test Accuracy: 0.7799
-   Train Loss: 0.1997
-   Test Loss: 0.2200

------------------------------------------------------------------------

# Correlaciones

-   fare vs survived: 0.2491
-   age vs survived: -0.0539

------------------------------------------------------------------------

# Coeficientes

  | Variable | Peso |
  |-------------|---------|
  |sex | 1.2084 |
  |pclass | -0.8700 |
  |age | -0.5948 |
  |fare | 0.0764 |
  |sibsp | -0.3726 |
  |parch | -0.0048 |
  |family_size | -0.2389 |
  |is_alone | -0.3877 |

Bias: -0.4143

------------------------------------------------------------------------

# Interpretación

-   Ser mujer aumenta significativamente la sobrevivencia
-   Mayor clase social incrementa probabilidad
-   Mayor tarifa mejora sobrevivencia
-   Viajar solo reduce probabilidad

------------------------------------------------------------------------

# Conclusión

El modelo logra \~78% de accuracy en test. Se demuestra que un pipeline
basado en C++ + LuaJIT puede ser altamente eficiente para machine
learning sin depender de frameworks pesados.
