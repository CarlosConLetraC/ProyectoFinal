## Casos de uso implementados

+ Actividad 4: 
    - Parte 1: ver documentación en `ACTIVIDAD4_parte1.md`
    - Parte 2: ver documentación en `ACTIVIDAD4_parte2.md`


---

# Moduler

Moduler es un motor de ejecución concurrente de scripts LuaJIT con
arquitectura tipo scheduler/worker, diseñado para ejecutar múltiples
programas en paralelo con control de colas, prioridades, retries y
aislamiento por proceso.

Basado en un proyecto previo del autor:
https://github.com/CarlosConLetraC/Moduler/

------------------------------------------------------------------------

# Arquitectura del sistema

El sistema está dividido en tres capas principales:

## Backend (C++)

El backend es el núcleo del sistema.

Responsabilidades:
  - Scheduler con colas (pending, priority, retry)
  - ThreadPool interno
  - Dispatcher event-driven
  - Sistema de retries con backoff
  - Ejecución de LuaJIT por proceso aislado

## ThreadPool (C++)

-   Workers fijos
-   Cola protegida por mutex
-   Ejecución concurrente
-   Control de saturación

## Worker (LuaJIT)

Cada job ejecuta scripts LuaJIT aislados:
  - procesamiento de datos
  - generación de métricas
  - exportación JSON
  - pipelines de ML

------------------------------------------------------------------------

# Características

-   ejecución concurrente de jobs
-   scheduler con prioridades
-   retry system con backoff
-   control de carga
-   aislamiento por proceso
-   pipeline de datos por jobs

------------------------------------------------------------------------

# Actividad 4 - Ciencia de Datos

Cada worker:
  - carga dataset
  - filtra datos inválidos
  - entrena modelo de regresión logística
  - calcula métricas (R2, MSE, RMSE, accuracy)
  - exporta resultados en JSON

Posteriormente se analizan en Python.

------------------------------------------------------------------------

# Casos de uso

-   procesamiento paralelo de datasets
-   entrenamiento de modelos ML ligeros
-   simulación de pipelines
-   laboratorio de sistemas concurrentes

------------------------------------------------------------------------

# Estructura

backend.cpp => scheduler principal\
libbackend/ => scheduler, broker, threadpool\
cpplibs/ => ML y CSV engine\
clibs/ => estadísticas\
import/ => runtime LuaJIT\
program.\*.lua => pipelines\
data/ => datasets

------------------------------------------------------------------------

# Nota

Este sistema es concurrente local, no distribuido en red.

------------------------------------------------------------------------

# Instalación
```bash
git clone --recursive https://github.com/CarlosConLetraC/Actividad4_CienciaDeDatos.git
cd Actividad4_CienciaDeDatos
chmod +x initconsole cmd runclient *.sh
```

------------------------------------------------------------------------

# Configurar el entorno (recomendado usar podman)
```bash
./configurarentorno.sh
```
------------------------------------------------------------------------

# Build
```bash
./build.sh
```
------------------------------------------------------------------------

# Run
```bash
./run.sh
```

------------------------------------------------------------------------