# SSBU Online Deluxe (Edición Quickplay & Stealth)

[![Versión del Juego](https://img.shields.io/badge/SSBU-13.0.5-orange.svg)](https://www.smashbros.com/)
[![Plataforma](https://img.shields.io/badge/Plataforma-Nintendo%20Switch%20%7C%20Emulador%20Eden-blue.svg)](https://github.com)
[![Rust](https://img.shields.io/badge/Rust-Edici%C3%B3n%202021-red.svg)](https://www.rust-lang.org/)
[![Skyline](https://img.shields.io/badge/Skyline-Plugin-brightgreen.svg)](https://github.com/skyline-dev/skyline)
[![Licencia](https://img.shields.io/badge/Licencia-GPL%20v3.0-lightgrey.svg)](LICENSE)

Un mod avanzado de optimización de rendimiento, reducción de latencia de entrada (input lag) y mejoras de red para **Super Smash Bros. Ultimate (v13.0.5)**.

Este repositorio es un fork mejorado de [saad-script/ssbu-online-deluxe](https://github.com/saad-script/ssbu-online-deluxe), diseñado específicamente para desbloquear el **control total de perfiles de renderizado y el Latency Slider en el modo Partida Rápida (Quickplay) y Smash VIP (Elite Smash) oficiales de Nintendo**, resolver de raíz los cuelgues (crashes) en pantallas de carga y transiciones de matchmaking, e introducir un **Modo Stealth (Sigilo)** sin rastro mediante hotpatching de memoria a nivel de kernel.

> [!NOTE]
> Read this document in English: [README.md](README.md).

---

## 🌟 ¿Qué hay de nuevo en este Fork?

| Característica | Repositorio Original (saad-script v1.4.1) | Este Fork (Edición Quickplay & Stealth) |
| :--- | :--- | :--- |
| **Quickplay y Smash VIP Oficial** | ❌ Deshabilitado (bloqueado a Vanilla) | ✅ **Completamente Desbloqueado**: Perfiles LessLag, LLUltra, LLDoubles y Latency Slider funcionan en Quickplay |
| **Restricción de ssbusync** | ⚠️ ssbusync fuerza modo Vanilla al entrar a Quickplay | ✅ **Bypass Automático**: Marca modo Arena periódicamente manteniendo las optimizaciones activas |
| **Corrección de Drift de Perfiles** | ❌ Inexistente (el juego podía resetear los gráficos) | ✅ **Detección Activa de Drift**: Si el motor revierte las flags gráficas, el mod las reaplica al instante en pleno combate |
| **Estabilidad en Matchmaking y Cargas** | ⚠️ Frecuentes crasheos en transiciones, salas de espera y pantallas de carga | ✅ **Periodo de Gracia de 300 Frames**: Pausa operaciones riesgosas en transiciones y añade protección null-pointer |
| **Modo Sigilo (Anti-Detección)** | ❌ No disponible (emite baliza `0x45`, sufijos de red y paquetes custom) | ✅ **Parche de Memoria Kernel SVC 0x6**: Cero paquetes emitidos, anula baliza `0x45`, invisible para oponentes |
| **Resolución Dinámica en Quickplay** | ❌ Excluida explícitamente en el código | ✅ **Habilitada**: Mantiene los 60 FPS estables en golpes críticos, zoom-in y Gigaflare de Sefirot |
| **Manejo de Errores de ssbusync-guest** | ⚠️ Crashea con pánico si el símbolo de API remota no responde | ✅ **Crate Vendeado y Parcheado**: Falla silenciosa y segura sin cerrar el juego |

---

## 🚀 Mejoras Principales y Arquitectura Técnica

### 1. ⚔️ Integración Completa con Quickplay y Smash VIP
En la versión original, las optimizaciones de renderizado (`ssbusync`) y la modificación de frames de retraso estaban restringidas exclusivamente a Arenas y Online Local. En servidores oficiales de Nintendo, `ssbusync` detectaba la ausencia de una arena y reseteaba los gráficos al modo Vanilla estándar.

- **Marcado Dinámico de Arena (`ssbusync_restrict_mark_arena_mode`)**: Inyecta el símbolo de arena en las llamadas a `ssbusync` durante Quickplay y Smash VIP.
- **Throttling Inteligente**: Dado que `ssbusync` limpia sus flags en cada transición de escena, este fork refresca el estado cada ~60 frames de manera throttled para no saturar el log ni consumir CPU.
- **Detección de Deriva (Drift) de Render**: Durante la partida en vivo, el mod compara frame a frame las flags de hardware activas contra el perfil elegido por el jugador (`LessLag`, `LLUltra`, etc.). Si el juego intenta volver a Vanilla, lo fuerza de nuevo inmediatamente.
- **Latency Slider en Quickplay**: Permite ajustar los frames de buffer de entrada (`0f` a `25f`, o `Auto`) en Quickplay y Elite Smash.

### 2. 🛡️ Arquitectura Anti-Crasheos y Estabilidad
El matchmaking de Quickplay alterna rápidamente entre búsqueda en segundo plano, la sala de entrenamiento previa, carga de escenarios y la partida real. La versión original sufría cuelgues críticos:

- **Frames de Gracia en Transiciones (`TRANSITION_GRACE_FRAMES = 300`)**: Al iniciar una carga o cambio de pantalla, el mod activa una ventana de gracia de 300 frames (~5 segundos) donde suspende de forma segura la manipulación de paneles UI y llamadas a la GPU, evitando accesos a memoria destruida durante el cambio de escena.
- **Protección Null-Pointer**: Se incorporó validación estricta de punteros nulos (`reg_ptr.is_null()`) en el hook del slider de latencia, eliminando los clásicos cierres forzosos al conectar con rivales.
- **Preservación de Estado de Matchmaking**: Se previene que el hook del menú principal resetee erróneamente el estado de conexión a `Offline` durante las transiciones internas de Quickplay.
- **Fallback para Partidas no Catalogadas**: Si una partida inicia sin panel de arena registrado, el mod la clasifica automáticamente como Quickplay en lugar de quedar en un estado nulo indefinido.

### 3. 🕶️ Modo Stealth (Sigilo y Anti-Detección)
Cuando se juega online contra rivales que también tienen mods, `libssbu_pia_manager` añade una baliza de 2 bytes (`[0x45, <tipo_conexion>]`) a los paquetes PIA entre jugadores. Este identificador revela que la consola está modificada (`is_modded`) y muestra etiquetas como `[Wired]` o `[Wifi]`. Además, SSBU Online Deluxe por defecto transmite paquetes extendidos con tu latencia y perfil seleccionado.

Activando `stealth_mode = true` en el `config.toml`:

- **Hotpatching en Memoria con Llamadas al Kernel**:
  - Utiliza la syscall de Nintendo Switch `svcQueryMemory` (SVC 0x6) para inspeccionar la sección `.text` de `libssbu_pia_manager`.
  - Escanea por firma binaria para localizar la instrucción de la baliza y parchea en caliente:
    ```text
    mov w8, #0x45   --->   mov w8, #0x00
    ```
  - `libssbu_pia_manager` jamás emitirá la etiqueta `0x45`. Para cualquier rival con mods o monitor de red, tu consola es **100% indistinguible de una Nintendo Switch totalmente original/vanilla**.
- **Cero Emisión de Paquetes**: Deshabilita el hook de transmisión de datos custom PIA (`send_pia_data_hook`), vaciando el buffer de salida.
- **Recepción Unidireccional (Antisocial)**: No emites absolutamente nada, pero tu consola sigue recibiendo y mostrando el ping, estabilidad y perfiles de los rivales que no usen sigilo.

> ⚠️ **Nota**: El sigilo completo te deja "ciego" a la info extendida de oponentes (slider de latencia, perfil de render). La baliza 0x45 del manager funciona como token de capacidad — al suprimirla, los peers rechazan compartir su info extendida contigo. Si quieres ver la info de los oponentes sin emitir la tuya, usa `lurk_mode`.

#### Modo Lurk (Alternativa Recomendada)

Configurando `lurk_mode = true` (con `stealth_mode = false`) se obtiene un punto intermedio:

- **Sin Emisión**: El hook de envío de datos PIA custom NO se registra — tu latencia y perfil de render nunca se transmiten.
- **Baliza Preservada**: La baliza 0x45 fluye normalmente, así que los peers te tratan como estación capaz y **comparten su info extendida contigo** (slider de latencia, perfil de render, etc.).
- **Compromiso**: Los peers con el mod **pueden** ver que estás modificado y tu tipo de interfaz `[Wired]`/`[Wifi]`. Sin embargo, no pueden ver tu slider de latencia ni tu perfil de render.

Si ambos `stealth_mode` y `lurk_mode` están en `true`, `stealth_mode` tiene prioridad (sigilo completo, aceptando quedarse ciego).

### 4. ⚡ Escalador de Rendimiento en Quickplay
Se eliminó la restricción que desactivaba el escalador en Quickplay. La resolución dinámica ahora actúa durante los zoom-ins de golpes finales y movimientos pesados (como el Gigaflare de Sefirot), garantizando 60 FPS sin caídas de frames en el juego competitivo.

### 5. 📦 Parche de `smash-ultelier`
Se vendió y modificó la librería invitada `vendor/smash-ultelier/crates/sync-guest/src/lib.rs` eliminando el fallo fatal:
```rust
panic!("[ssbusync] Unable to read remote api version");
```
Si la versión de la API no está presente o difiere, continúa de manera segura sin interrumpir la ejecución del juego.

---

## 🎮 Controles y Atajos

### Interfaz Nativa del Juego (Pantalla de Selección de Personajes y Arena)

> **Nota para mandos**: `Todos los gatillos superiores` = `L + R + Z` en mando de GameCube, o `ZL + ZR + L + R` en Pro Controller / Joy-Cons.

| Acción | Combinación | Descripción |
| :--- | :--- | :--- |
| **Ajustar Latencia** | `Cruceta Izquierda` / `Derecha` | Cambia el búfer de frames (`Auto`, `0f` a `25f`) |
| **Cambiar Perfil de Render** | `Cruceta Arriba` / `Abajo` | Alterna perfil (`Auto`, `Vanilla`, `LessLag`, `LLUltra`, `LLDoubles`) |
| **Activar FPS Boost (FPS++)** | `Todos los gatillos + X` | Alterna modo FPS Boost (Exclusivo de emulador) |
| **Modo Streamer** | `Todos los gatillos + Y` | Muestra u oculta la interfaz nativa en pantalla |
| **Alternar Info de Rivales** | `L + R + Cruceta Izquierda/Derecha` | Cambia entre la info de los rivales en partidas de más de 2 jugadores |

### Menú Overlay ImGui (Opcional)

| Acción | Combinación | Descripción |
| :--- | :--- | :--- |
| **Cambiar Modo de Ventana** | `L + R + Cruceta Abajo` | Rota entre `Hidden` (Oculto), `Full Info` y `Performance Info` |
| **Navegar Opciones** | `Cruceta Arriba` / `Abajo` | Selecciona la fila en modo Full Info |
| **Modificar Valor** | `Cruceta Izquierda` / `Derecha` | Cambia el valor de la opción seleccionada |
| **FPS Boost vía Overlay** | `Todos los gatillos + X` | Alterna FPS Boost al seleccionar la fila `NetProfile` |

---

## 🏎️ Guía de Perfiles de Renderizado

- **Auto**: Selecciona automáticamente el perfil ideal según si juegas en Consola o Emulador y la cantidad de jugadores (1v1 o Dobles).
- **Vanilla**: Pipeline gráfico original del juego sin modificaciones.
- **LessLag**: Elimina el buffer de cuadros interno, recortando **3 frames completos** de input delay nativo. Muy recomendado y estable en consola.
- **LLUltra (LessLag Ultra)**: Recorta **4 frames completos** de input delay nativo.
  - *En consola*: Utiliza escalado dinámico de resolución en momentos de alta carga para prevenir tirones.
- **LLDoubles (Recomendado para Dobles y +3 jugadores)**: Recorta **2 frames completos** de input delay, ofreciendo un margen térmico y de GPU óptimo cuando hay muchos personajes y efectos en pantalla.
- **FPS++ (Solo Emulador)**: Exprime la tasa de cuadros y reduce la latencia en emuladores de PC compatibles.

---

## ⚙️ Archivo de Configuración (`config.toml`)

Ubicación del archivo en la tarjeta SD:
```text
sd:/ultimate/ssbu_online_deluxe/config.toml
```

### Ejemplo Completo Recomendado:

```toml
# ==========================================================
# SSBU Online Deluxe - Archivo de Configuración
# ==========================================================

# Activa el Modo Sigilo: te hace aparecer como consola Vanilla
# ante otros jugadores y herramientas de detección.
# NOTA: El sigilo completo te deja "ciego" a la info extendida de oponentes.
stealth_mode = false

# Activa el Modo Lurk para un punto intermedio de privacidad:
# - Tu latencia/perfil de render NO se transmite a nadie.
# - Los peers SÍ pueden ver que estás modificado y tu tipo [Wired]/[Wifi].
# - TÚ SÍ puedes ver la latencia, perfil de render, etc. de los oponentes.
# stealth_mode tiene prioridad cuando ambos están en true.
lurk_mode = true

# Overclock integrado de Switch.
# Ponlo en 'false' si ya utilizas un sysmodule externo como sys-clk.
overclocker = true

[render_profile_config]
# Perfil a utilizar en los menús (recomendado: "Vanilla")
menu = "Vanilla"

# Perfiles para partidas offline
offline_match.singles = "Vanilla"
offline_match.doubles = "Vanilla"

# Perfiles aplicados en modo 'Auto' para partidas online
online_match.singles = "LessLagUltra"
online_match.doubles = "LessLag"
```

---

## 📦 Guía de Instalación

> [!WARNING]
> Desinstala cualquier versión previa de **Latency Slider**, mods de **VSync** o **Less Lag** antes de instalar este mod para evitar incompatibilidades.

### Prerrequisitos Necesarios
Asegúrate de contar con los siguientes componentes en tu Switch o emulador:
1. **Skyline** (Utiliza la versión incluida en el paquete de release)
2. **Arcropolis**
3. **NRO Hook**
4. **Smashline**
5. **imgui-smash**
6. **ssbu-pia-manager**
7. **ssbusync** (Utiliza la versión compatible incluida en el release)

### Estructura de Carpetas en la MicroSD

```text
sdcard/
├── atmosphere/
│   └── contents/
│       ├── 00FF0000A11CE0FF/           <-- (Sysmodule de Overclock)
│       │   ├── exefs.nsp
│       │   └── flags/boot2.flag
│       └── 01006A800016E000/           <-- Title ID de Super Smash Bros. Ultimate
│           ├── exefs/
│           │   ├── main.npdm
│           │   └── subsdk9
│           └── romfs/
│               └── skyline/
│                   └── plugins/
│                       ├── libarcropolis.nro
│                       ├── libimgui_smash.nro
│                       ├── libnro_hook.nro
│                       ├── libnx_over.nro
│                       ├── libsmashline_plugin.nro
│                       ├── libssbu_online_deluxe.nro   <-- ESTE MOD
│                       ├── libssbu_pia_manager.nro
│                       └── libssbusync.nro
└── ultimate/
    └── ssbu_online_deluxe/
        └── config.toml                         <-- (Archivo de configuración opcional)
```

---

## 🛠️ Compilación desde el Código Fuente

### Requisitos
- [Rust](https://rustup.rs/) (Toolchain Nightly)
- `cargo-skyline` (`cargo install cargo-skyline`)
- Target: `aarch64-skyline-switch`

### Comando de Compilación
```bash
cargo skyline build --release
```
El archivo compilado se generará en:
```text
target/aarch64-skyline-switch/release/libssbu_online_deluxe.nro
```

---

## ⚠️ Seguridad Online y Descargo de Responsabilidad

- **Comportamiento de Red**: Este mod trabaja única y exclusivamente en la capa de red P2P (Peer-to-Peer) entre consolas y en el renderizado local de la consola. Los servidores de Nintendo no intervienen en el tráfico P2P de combate.
- **SSBU 13.0.5**: La versión 13.0.5 no introdujo cambios en las verificaciones de paquetes de red P2P.
- **Responsabilidad**: Cualquier modificación en consolas online conlleva un riesgo no nulo de restricción de cuenta o consola. Utilízalo bajo tu propia discreción. El uso de `stealth_mode = true` está ampliamente recomendado para maximizar la privacidad.

---

## 🙌 Créditos y Agradecimientos

Este proyecto se apoya en el trabajo de investigadores y desarrolladores de la comunidad:

- **[saad-script](https://github.com/saad-script)** — Creador original de [ssbu-online-deluxe](https://github.com/saad-script/ssbu-online-deluxe).
- **Bludev** — Pionero en la investigación del sistema de renderizado de SSBU e implementaciones originales de Less Lag y Latency Slider.
- **BlankMauser** — Desarrollador de SsbuSync y smash-ultelier; orientación fundamental en los internals gráficos de SSBU.
- **Kinnay y colaboradores de NintendoClients** — Documentación y análisis de la infraestructura de red PIA.
- **Coolsonickirby** — Creador de `imgui-smash` y `imgui-api`.
- **Equipo de HDR** — Por Smashline y el sistema de hooks.
- **Equipo de Skyline** — Por la plataforma base de modding en Nintendo Switch.

---

## 📄 Licencia

Este proyecto está licenciado bajo la **Licencia Pública General GNU v3.0 (GPLv3)** — consulta el archivo [LICENSE](LICENSE) para más detalles.
