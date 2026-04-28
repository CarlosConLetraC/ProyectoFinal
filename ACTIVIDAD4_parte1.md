# Actividad 4 (Parte 1) --- Procesamiento Distribuido y Regresión Lineal sobre Dataset de Vehículos

## Resumen Ejecutivo

Esta actividad implementa un sistema de procesamiento paralelo de datos utilizando la arquitectura **Moduler**, desarrollada sobre **LuaJIT + C/C++**, con el objetivo de analizar un conjunto masivo de registros de venta de automóviles y entrenar modelos de **regresión lineal distribuida**.

El sistema divide automáticamente el dataset en múltiples particiones (workers), ejecuta entrenamiento independiente en cada segmento y consolida métricas estadísticas globales para evaluar estabilidad, rendimiento y calidad predictiva.

Se trata de una práctica aplicada de:

- Ciencia de Datos Distribuida  
- Programación Concurrente  
- Integración Lua/C/C++  
- Ingeniería de Rendimiento  
- Machine Learning Escalable  

---

# Objetivos de la Actividad

## Objetivo General

Diseñar e implementar una solución de análisis predictivo distribuido para estimar el precio de venta de vehículos usando múltiples procesos concurrentes.

## Objetivos Específicos

- Procesar datasets grandes de forma paralela.
- Utilizar múltiples workers independientes.
- Implementar particionado automático de datos.
- Entrenar modelos de regresión lineal por worker.
- Medir métricas estadísticas por partición.
- Consolidar resultados globales.
- Optimizar rendimiento usando extensiones en C/C++.

---

# Dataset Utilizado

Se trabajó con un dataset de ventas de automóviles (`car_prices.csv`) que contiene miles de registros históricos de subastas y ventas.

## Variables principales utilizadas

| Variable | Descripción |
|--------|-------------|
| sellingprice | Precio real de venta |
| odometer | Kilometraje del vehículo |
| mmr | Valor estimado de mercado |

## Variable Objetivo

Se buscó predecir:

sellingprice

A partir de:

odometer + mmr

---

# Arquitectura Implementada

## Backend Concurrente

El sistema usa **Moduler**, una arquitectura tipo scheduler/worker que ejecuta scripts LuaJIT en paralelo.

## Flujo General

Dataset CSV => Particionado Automático => 10 Workers Paralelos => Entrenamiento Independiente => JSON por Worker => Consolidación Python => Reporte Final

---

# Tecnologías Utilizadas

| Tecnología | Uso |
|-----------|-----|
| LuaJIT | Workers de procesamiento |
| C++ | Scheduler principal |
| C | Librerías estadísticas nativas |
| Python | Consolidación y gráficas |
| JSON | Intercambio de resultados |
| CSV | Fuente de datos |

---

# Librerías Desarrolladas

## csvfast.cpp

Módulo nativo de alto rendimiento para lectura de CSV.

### Funciones principales

- read_columns()
- save_columns()
- each()
- count_rows()
- variance()

### Ventajas

- Lectura columnar rápida
- Limpieza automática de caracteres residuales
- Conversión automática numérica
- Menor consumo de memoria

---

## cstats.c

Librería estadística nativa en C.

### Funciones implementadas

- mean()
- var()
- std()
- mse()
- r2()
- corr()

### Beneficio

Reduce carga de Lua y acelera operaciones sobre grandes volúmenes de datos.

---

# Modelo de Machine Learning

Se implementó una **Regresión Lineal Múltiple**:

sellingprice = β0 + β1(odometer) + β2(mmr)

---

# Distribución del Trabajo

Se ejecutaron **10 workers concurrentes**, cada uno procesando aproximadamente **55,884 registros**.

---

# Métricas Evaluadas

| Métrica | Significado |
|--------|-------------|
| R² Train | Ajuste en entrenamiento |
| R² Test | Generalización |
| MSE | Error cuadrático medio |
| RMSE | Error medio |
| Corr Odometer | Correlación con precio |
| Corr MMR | Correlación con precio |

---

# Resultados Generales

| Métrica | Valor |
|--------|------|
| R² Train | 0.9676 |
| R² Test | 0.9625 |
| RMSE Test | 0.1890 |
| Corr Odometer | -0.582 |
| Corr MMR | 0.983 |

---

# Interpretación

- Más kilometraje implica menor precio.
- Mayor MMR implica mayor precio de venta.
- El modelo presenta fuerte capacidad predictiva.

---

# Mejor Worker

- Worker 10
- R² Test = 0.978163

# Peor Worker

- Worker 8
- R² Test = 0.950991


Esto es a nivel conceptual. Puede variar debido al shuffle que se hace en LuaJIT.
---

# Mejoras Futuras

- Ridge / Lasso
- Árboles de decisión
- Random Forest distribuido
- Redes neuronales
- Dashboard en tiempo real

---

# Conclusión

La actividad demuestra que es posible construir una plataforma propia de análisis distribuido usando LuaJIT, C y C++, logrando alto rendimiento, escalabilidad y buenos resultados predictivos.

El proyecto integra conocimientos de sistemas, concurrencia, optimización y ciencia de datos aplicada.

---