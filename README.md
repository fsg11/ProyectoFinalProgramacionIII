# Sistema Distribuido de Coordinación y Gestión de Emergencias

Proyecto final de **Programación III** (Universidad del Quindío, 2026-2), desarrollado en Elixir.
Simula una plataforma para coordinar la atención después de un terremoto: usuarios, zonas,
necesidades, recursos, comunicación entre familiares, mascotas perdidas/encontradas y albergues.

---

## 1. Cómo ejecutar

Requisitos: Elixir 1.14 o superior. El núcleo del sistema no usa dependencias externas; solo la
interfaz web opcional usa Phoenix (sección 1.5), por eso la primera vez hay que descargarlas.

```bash
mix deps.get
mix.bat phx.server
```

### 1.1 Consola local (un solo nodo)

```bash
mix run -e "Emergencias.consola()"
```

o dentro de `iex -S mix`:

```elixir
Emergencias.consola()
```

### 1.2 Modo distribuido (varios usuarios en distintas terminales)

Terminal 1, **servidor** (arranca los GenServers y el servicio remoto):

```bash
iex --sname servidor@localhost -S mix
```

Terminales 2, 3, …, **clientes** (no arrancan sus propios GenServers, solo envían mensajes):

```bash
elixir --sname cliente1@localhost -S mix run --no-start -e "Emergencias.cliente(:servidor@localhost)"
elixir --sname cliente2@localhost -S mix run --no-start -e "Emergencias.cliente(:servidor@localhost)"
```

Si los nodos están en computadores distintos, use `--name` con la IP y la misma cookie
(`--cookie emergencias`), como en el ejemplo `30B-Cookie` del curso.

### 1.3 Ejecutar el flujo de ejemplo del enunciado

```bash
rm -rf datos          # opcional: empezar sin datos
mix run -e 'Emergencias.guion("guiones/flujo_ejemplo.txt")'
```

### 1.4 Pruebas

```bash
mix test
```

Las pruebas nunca tocan los datos reales de `datos/`: cada prueba arranca el sistema con una
carpeta vacía nueva dentro de la carpeta temporal del sistema operativo. Así también funcionan si el
proyecto está en una carpeta sincronizada (OneDrive), que bloquea el borrado de archivos.

En Windows, si PowerShell muestra "running scripts is disabled", use `mix.bat test` o ejecute una
vez `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`.

### 1.5 Interfaz web (opcional, Phoenix LiveView)

```bash
mix phx.server
```

Abra **http://localhost:4000** en el navegador. Para usar a la vez la web y los clientes de consola
de otros nodos, inicie el servidor así:

```bash
iex --sname servidor@localhost -S mix phx.server
```

El servidor web solo escucha con `phx.server`; la consola, los guiones y las pruebas no ocupan el
puerto 4000.

| Página | Qué permite |
|--------|-------------|
| Inicio de sesión | `connect` con registro automático (mismas reglas de roles que la consola) |
| Panel general | indicadores, próximas necesidades, ocupación de albergues, recursos críticos y botón de `simulate_conflict` |
| Zonas | árbol zona → sector → punto (componente recursivo), registro y `zone_status` |
| Necesidades | registro, filtros, avance de cada necesidad, asignación de recursos y cambio de estado |
| Recursos | inventario, registro de lotes, entradas y salidas, transferencias e historial |
| Personas y mensajes | reporte, búsqueda, cambio de estado, historial y mensajes familiares |
| Mascotas | reportes, búsqueda de coincidencias con puntaje y confirmación |
| Albergues | ocupación, ingresos y salidas de personas |
| Usuarios y roles | `set_role` (coordinador o superior), lista de usuarios (administrador) y bitácora |

**Cómo está construida**

- **Una sola lógica para la web y la consola.** La web no tiene reglas de negocio propias: cada
  botón o formulario arma una línea de comando y la ejecuta con `Comandos.ejecutar/2`, igual que la
  consola. Por eso aplica los mismos permisos, validaciones, bitácora y control de concurrencia.
- **Botones según el rol.** La interfaz muestra solo las acciones que el rol permite. Aun así, el
  permiso lo vuelve a verificar el servidor en cada comando.
- **Tiempo real.** Cada comando publica un aviso por `Phoenix.PubSub` (`Emergencias.Notificador`).
  Las páginas abiertas se recargan al instante, aunque el cambio se haya hecho desde la consola o
  desde un cliente de otro nodo. Con cada aviso también se vuelven a validar la sesión y el rol.
- **Sesión.** La cookie del navegador guarda el usuario y el token, y cada página los valida con el
  GenServer `Usuarios`. Un usuario tiene una sola sesión activa: si inicia sesión en otro lugar,
  la anterior se cierra.
- **Sin Node.js.** El JavaScript de Phoenix y LiveView se sirve desde las dependencias, y el CSS
  está escrito a mano en `priv/static/css/app.css`.
- Las claves de `config/config.exs` son de desarrollo. Para publicar el sistema se deben generar
  nuevas con `mix phx.gen.secret`.

---

## 2. Comandos

Escriba `help` dentro de la consola para ver la lista. Los textos con espacios van entre comillas.
Los filtros se escriben como `campo=valor`.

| Nivel | Rol mínimo | Comandos |
|-------|------------|----------|
| – | cualquiera | `connect usuario contraseña [tipo] [zona] ["nombre completo"]`, `disconnect`, `help`, `exit` |
| 1 | ciudadano | `list_zones`, `zone_status`, `register_need`, `list_needs`, `pending_needs`, `list_resources`, `report_person`, `find_person`, `person_history`, `send_family_message`, `list_family_messages`, `report_pet`, `list_pets`, `check_shelter`, `list_shelters` |
| 2 | voluntario | `register_resource`, `resource_in`, `resource_out`, `movements`, `critical_resources`, `update_person`, `mark_message`, `match_pets`, `register_entry`, `register_exit` |
| 3 | coordinador | `register_zone`, `update_need`, `assign_resource`, `transfer_resource`, `confirm_match`, `register_shelter`, `summary`, `simulate_conflict`, `activity`, `set_role` |
| 4 | administrador | `users` |

Cada rol puede usar también los comandos de los niveles inferiores.

Ejemplos:

```text
connect laura 1234 coordinador centro "Laura Gómez"
register_zone centro "Zona Centro" critico 500
register_zone sector3 "Sector 3" alto 120 centro          # sector de la zona centro
register_need agua 30 critica sector3 "Punto de atención sector 3"
list_needs zona=sector3 prioridad=critica
register_resource R001 agua 50 litros centro_acopio_1
assign_resource N001 agua 30          # por categoría o por código: assign_resource N001 R001 30
report_person 1094 "Andrés Pérez" zona_norte localizada 34
send_family_message 1094 "Estoy bien, estoy en el albergue norte"
report_pet lost perro "Luna" negra mediana zona_norte 3001234567 "collar rojo"
report_pet found perro desconocido negro mediano zona_norte 3007654321
match_pets
confirm_match M001 M002
register_shelter A01 "Albergue Norte" zona_norte 150
transfer_resource R001 centro_acopio_1 A01 10   # destino: albergue registrado o ubicación con recursos
register_entry A01 1094
summary
simulate_conflict
```

### Reglas de conexión

- Si el usuario **no existe**, se registra automáticamente con la zona indicada.
  - Mientras no exista ningún coordinador ni administrador (arranque del sistema), puede
    registrarse con cualquier tipo. Así se crean los primeros responsables.
  - Después, el registro automático **solo crea ciudadanos**. Los roles `voluntario`,
    `coordinador` y `administrador` los asigna un coordinador o administrador con
    `set_role usuario tipo`. Nadie puede otorgar un rol superior al propio, modificar a alguien
    de rol superior ni cambiar su propio rol. Solo puede existir un administrador.
- Si **existe**, se valida la contraseña. Nunca se guarda en texto plano: se guarda como hash
  PBKDF2-HMAC-SHA256 (100 000 iteraciones) con una sal aleatoria por usuario, y se compara en
  tiempo constante. Las contraseñas guardadas con el formato anterior (SHA-256 sin sal) se
  aceptan y se vuelven a cifrar automáticamente en el siguiente inicio de sesión.
- Al conectarse, el servidor entrega un *token* de sesión. Cada comando envía el usuario y el
  token, y el servidor verifica la sesión y el rol antes de ejecutar. `disconnect` también
  exige el token, así un cliente no puede cerrar la sesión de otro usuario.

---

## 3. Estructura del proyecto

```text
emergencias/
├── mix.exs
├── config/config.exs                 # carpeta de datos (datos/ o datos_test/)
├── lib/
│   ├── emergencias.ex                # atajos: consola/0, cliente/1, guion/1
│   ├── emergencias/
│   │   ├── application.ex            # arranque y supervisor principal
│   │   ├── supervisor_dominio.ex     # supervisor de los GenServers
│   │   ├── bitacora.ex               # proceso spawn/receive: actividad de usuarios
│   │   ├── servidor_remoto.ex        # proceso spawn/receive: clientes de otros nodos
│   │   ├── comandos.ex               # intérprete de comandos y permisos
│   │   ├── consola.ex                # interfaz de texto (local, remota y guion)
│   │   ├── persistencia.ex           # archivos de texto plano
│   │   ├── util.ex                   # utilidades (separar comandos, validar números…)
│   │   ├── modelos/                  # estructuras + funciones PURAS
│   │   │   ├── usuario.ex  zona.ex  necesidad.ex  recurso.ex
│   │   │   └── persona.ex  mensaje.ex  mascota.ex  albergue.ex
│   │   ├── servidores/               # GenServers (estado + concurrencia)
│   │   │   ├── usuarios.ex  zonas.ex  necesidades.ex  recursos.ex
│   │   │   └── personas.ex  mensajes.ex  mascotas.ex  albergues.ex
│   │   └── notificador.ex            # avisa cambios a la web (Phoenix.PubSub)
│   ├── emergencias_web.ex            # interfaz web opcional (Phoenix LiveView)
│   └── emergencias_web/
│       ├── endpoint.ex  router.ex  autenticacion.ex  acciones.ex
│       ├── componentes/              # marco de página y componentes visuales
│       ├── controladores/            # inicio y cierre de sesión
│       └── live/                     # una página LiveView por sección
├── priv/static/css/app.css           # estilos de la interfaz web
├── test/                             # pruebas ExUnit
├── guiones/flujo_ejemplo.txt         # flujo de ejemplo del enunciado
├── docs/                             # diagramas (PNG) y sus fuentes Mermaid
└── datos/                            # se crea al ejecutar: archivos .txt
```

**Separación de responsabilidades**

- `modelos/`: funciones puras. Reciben datos y retornan `{:ok, valor}` o `{:error, mensaje}`.
  No leen teclado, no escriben archivos y no envían mensajes.
- `servidores/`: guardan el estado, reciben solicitudes concurrentes y llaman a los modelos.
- `persistencia.ex`: único módulo que lee y escribe en disco.
- `comandos.ex`: traduce el texto del usuario en llamadas a los servidores.
- `consola.ex` / `servidor_remoto.ex`: entrada y salida, local o entre nodos.

---

## 4. Decisiones de diseño

### 4.1 Estructuras de datos

| Estructura | Dónde | Por qué |
|------------|-------|---------|
| `defstruct` (structs) | `modelos/*.ex` | Cada entidad tiene campos fijos y conocidos; se pueden usar en pattern matching. |
| Mapa `codigo => struct` | estado de cada GenServer | Búsqueda directa por identificador y fácil verificación de ids repetidos (`Map.has_key?`). |
| Lista | historial de movimientos, historial de personas, resultados | Se agregan elementos al inicio (`[nuevo \| lista]`), operación barata; se recorren en orden. |
| Tuplas | `{:ok, valor}`, `{:error, mensaje}`, `{codigo, cantidad}` del reparto, `{perdida, encontrada, puntaje}` | Resultados de tamaño fijo que se reconocen con pattern matching. |
| `MapSet` | ocupantes de un albergue, códigos de una zona y sus sectores, palabras de las características de mascotas | No permite duplicados: una persona no puede ingresar dos veces; pertenencia rápida (`MapSet.member?`) e intersección para la similitud. |
| Árbol de mapas anidados `%{zona: z, hijos: [...]}` | `Zona.construir_arbol/2` | Representa la jerarquía zona → sector → punto de atención. |
| Mapa de conteos | `Enum.frequencies_by/2` en resúmenes | Estadísticas por estado, prioridad o nivel. |

### 4.2 Funciones recursivas propias

| Función | Archivo | Qué hace |
|---------|---------|----------|
| `Util.separar/4` (usada por `separar_palabras/1`) | `util.ex` | Recorre la línea letra por letra para separar palabras respetando comillas. |
| `Zona.construir_arbol/2` | `modelos/zona.ex` | Construye el árbol zona → sectores → puntos desde la lista plana. |
| `Zona.buscar_nodo/2` | `modelos/zona.ex` | Busca un código en profundidad dentro del árbol. |
| `Zona.total_afectados/1` | `modelos/zona.ex` | Suma los afectados de la zona y de todos sus descendientes. |
| `Zona.codigos_subarbol/1` | `modelos/zona.ex` | Lista los códigos de una zona y todos sus sectores/puntos. |
| `Zona.contar_por_nivel/1` | `modelos/zona.ex` | Cuenta nodos por nivel de afectación en todo el subárbol. |
| `Zona.formatear/2` | `modelos/zona.ex` | Imprime el árbol con sangría. |
| `Recurso.total/1` | `modelos/recurso.ex` | Suma las cantidades de una lista de lotes. |
| `Recurso.repartir/2` | `modelos/recurso.ex` | Decide cuánto tomar de cada lote para cubrir una asignación. |
| `Consola.ciclo/2`, `Bitacora.atender_mensajes/0`, `ServidorRemoto.esperar_solicitudes/0` | varios | Ciclos de lectura y de recepción de mensajes. |

La estructura zona → sectores → puntos se usa recursivamente en el comando `zone_status`, que
muestra estadísticas acumuladas de una zona y todos sus sectores.

### 4.3 Concurrencia y consistencia

- **Procesos con `spawn`/`receive`**: `Bitacora` y `ServidorRemoto` son procesos simples
  como los de los ejemplos 30A/30D. `ServidorRemoto` crea un **proceso nuevo por cada
  solicitud**, de modo que varios usuarios trabajan en paralelo.
- **GenServer**: cada área del dominio es un GenServer. Un GenServer procesa los mensajes de
  su buzón **uno a la vez**, así que dos operaciones sobre el mismo dato nunca se mezclan.
- **Conflicto resuelto** (regla obligatoria): si dos usuarios piden 30 y 25 litros de un recurso
  con 50, ambas solicitudes llegan al GenServer `Necesidades`, que las atiende en orden y le pide
  a `Recursos` descontar el inventario. La primera se confirma y la segunda recibe
  `Inventario insuficiente`. El descuento es **todo o nada** y la cantidad nunca queda negativa.
  Se demuestra con el comando `simulate_conflict` (usa `Task.async`) y con las pruebas de
  `test/concurrencia_test.exs` (incluye 100 solicitudes simultáneas sobre 50 unidades).
- **No cerrar dos veces**: necesidades atendidas/canceladas y mascotas resueltas son estados
  finales; un segundo cierre retorna `{:error, ...}`.
- **Capacidad de albergues**: 30 ingresos simultáneos a un albergue de 10 cupos dejan
  exactamente 10 personas (probado).
- **Una persona, un albergue**: el GenServer `Albergues` verifica en todos los albergues antes de
  confirmar un ingreso; 4 ingresos simultáneos de la misma persona a 4 albergues confirman solo 1
  (probado). `register_entry` exige además que la persona esté registrada y que su estado permita
  pasar a `en_albergue`. Si el cambio de estado falla después del ingreso, el ingreso se revierte.
- **Salida de albergues**: `register_exit` pasa a la persona a `localizada` solo si seguía
  `en_albergue`; si su estado ya cambió (por ejemplo `reunificada`) libera el cupo sin
  sobrescribirlo. Si el cambio de estado falla, la salida se revierte.
- **Transferencias**: el destino de `transfer_resource` debe ser un albergue registrado o una
  ubicación donde ya existan recursos (centro de acopio); si no, no se mueve nada.
- **Simulación sin residuos**: `simulate_conflict` usa los GenServers reales y al terminar elimina
  el recurso, las necesidades y los movimientos que creó, aunque algún paso falle. El contador de
  necesidades continúa desde el id más alto, así un id eliminado no se reutiliza al reiniciar.

### 4.4 Supervisión

```text
Emergencias.Supervisor (one_for_one)
├── Bitacora            (proceso spawn_link/receive)
├── SupervisorDominio   (one_for_one)
│   └── Usuarios, Zonas, Recursos, Necesidades, Personas, Mensajes, Mascotas, Albergues
├── ServidorRemoto      (proceso spawn_link/receive)
├── Phoenix.PubSub      (avisos de cambios para la interfaz web)
└── EmergenciasWeb.Endpoint (interfaz web; solo escucha con `mix phx.server`)
```

Se usa `one_for_one` porque los GenServers son independientes: si uno falla, solo ese se
reinicia y, al iniciar, vuelve a cargar su información desde los archivos. Una prueba mata el
proceso `Recursos` y verifica que el supervisor lo reinicia sin perder datos.

### 4.5 Persistencia

Archivos de texto plano en `datos/`, un registro por línea y campos separados por `|`:

| Archivo | Contenido |
|---------|-----------|
| `usuarios.txt` | usuario\|hash_contraseña\|nombre\|tipo\|zona (hash: `pbkdf2_sha256$iteraciones$sal$hash`) |
| `zonas.txt` | codigo\|nombre\|tipo\|nivel\|afectados\|padre |
| `necesidades.txt` | id\|tipo\|cantidad\|asignada\|prioridad\|zona\|descripcion\|responsable\|estado\|destino\|fecha |
| `recursos.txt` | codigo\|nombre\|categoria\|cantidad\|unidad\|ubicacion\|zona |
| `movimientos.txt` | fecha\|tipo\|codigo\|cantidad\|detalle (solo se agrega) |
| `personas.txt` | documento\|nombre\|edad\|zona\|estado |
| `historial_personas.txt` | fecha\|documento\|anterior\|nuevo\|usuario (solo se agrega) |
| `mensajes.txt` | id\|fecha\|remitente\|destinatario\|contenido\|estado |
| `mascotas.txt` | id\|tipo\|especie\|nombre\|caracteristicas\|color\|tamano\|zona\|contacto\|estado\|coincidencia |
| `albergues.txt` | codigo\|nombre\|zona\|capacidad\|documentos_separados_por_coma |
| `bitacora.txt` | fecha\|usuario\|accion (solo se agrega) |

### 4.6 Criterio de similitud de mascotas

Si la especie es diferente el puntaje es 0. Si es igual: especie 30 + zona 25 + color 20 +
tamaño 15 + nombre 10 (si ambos se conocen y coinciden) + 5 por cada palabra en común en las
características (máximo 10). Máximo 100. Desde **60** puntos se considera posible coincidencia.
Color y tamaño se comparan por sus 4 primeras letras, así *negra/negro* y *mediana/mediano*
coinciden.

`confirm_match` exige la misma especie y un puntaje de al menos 60. Cada vez que se ejecuta
`match_pets` o se confirma una coincidencia, los estados se recalculan: un reporte abierto queda en
`posible_coincidencia` solo si todavía coincide con otro reporte abierto; si no, vuelve a `activa`.

### 4.7 Prioridad de necesidades

La prioridad se convierte en número (`critica`=1, `alta`=2, `media`=3, `baja`=4). `list_needs`
y `pending_needs` ordenan por prioridad y luego por antigüedad; la primera de `pending_needs`
es la siguiente a atender.

---

## 5. Diagramas

Las imágenes están en `docs/` y sus fuentes (Mermaid) en `docs/fuentes/`.

| Diagrama | Archivo |
|----------|---------|
| Arquitectura de módulos | ![](docs/1_arquitectura.png) |
| Modelo de datos | ![](docs/2_modelo_datos.png) |
| Secuencia: asignación concurrente | ![](docs/3_secuencia.png) |
| Procesos y supervisión (OTP) | ![](docs/4_supervision.png) |

---

## 6. Lista de verificación

| Requisito | Dónde |
|-----------|-------|
| Gestión de usuarios | `servidores/usuarios.ex`, comando `connect`, roles en `comandos.ex` |
| Zonas y sectores | `modelos/zona.ex`, `servidores/zonas.ex`, `zone_status` |
| Necesidades | `modelos/necesidad.ex`, `servidores/necesidades.ex` |
| Recursos | `modelos/recurso.ex`, `servidores/recursos.ex` |
| Comunicación entre familiares | `servidores/personas.ex`, `servidores/mensajes.ex` |
| Mascotas | `modelos/mascota.ex`, `servidores/mascotas.ex` |
| Albergues | `modelos/albergue.ex`, `servidores/albergues.ex` |
| Estructuras de datos justificadas | sección 4.1 |
| Al menos 4 funciones recursivas | sección 4.2 |
| Procesos concurrentes | `bitacora.ex`, `servidor_remoto.ex`, `Task.async` en `simulate_conflict` |
| GenServer | `servidores/*.ex` |
| Supervisor | `application.ex`, `supervisor_dominio.ex` |
| Conflicto concurrente resuelto | `simulate_conflict`, `test/concurrencia_test.exs` |
| Persistencia | `persistencia.ex`, carpeta `datos/` |
| Pruebas | carpeta `test/` |
| Interfaz web con Phoenix (opcional) | `lib/emergencias_web/`, sección 1.5, `test/interfaz_web_test.exs` |
