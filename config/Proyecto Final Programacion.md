## Universidad del Quindío Ingeniería de Sistemas y Computación Programación III

Proyecto final:

Sistema Distribuido de Coordinación y

Gestión de Emergencias en Elixir

Contexto: atención y coordinación posterior a un terremoto


## 1. Definición del Proyecto final

## 1.1 Equipo de trabajo

Indicar en la tabla los participantes del proyecto.

| Nombre completos | Código | Correo |
| --- | --- | --- |

## 1.2 Enunciado del proyecto

Después de un terremoto de gran magnitud, diferentes sectores de una ciudad o región presentan afectaciones en infraestructura, comunicación, movilidad y acceso a recursos básicos. Los organismos de atención, voluntarios, albergues y ciudadanos necesitan registrar información y coordinar acciones sin depender de un único flujo secuencial de trabajo. Se debe implementar en Elixir un sistema multiusuario que simule una plataforma distribuida para apoyar la gestión de la emergencia. El sistema permitirá registrar y consultar personas afectadas, necesidades puntuales, recursos disponibles, albergues, reportes de mascotas perdidas o encontradas y mensajes destinados a facilitar la comunicación entre familiares.

Los diferentes componentes del sistema deberán trabajar de manera concurrente. Algunos elementos del dominio serán administrados como procesos independientes y otros mediante GenServer, permitiendo mantener estado, recibir solicitudes y responder a diferentes usuarios de forma simultánea.

El sistema debe evitar inconsistencias cuando varias operaciones ocurran al mismo tiempo. Por ejemplo, si dos solicitudes intentan reservar las últimas unidades disponibles de un recurso, solo podrán confirmarse las asignaciones que correspondan al inventario real. De igual manera, un mismo reporte de persona o mascota no debe resolverse dos veces.

Además de la concurrencia, el proyecto debe aplicar estructuras de datos funcionales, recursividad, paso de mensajes, supervisión, persistencia y separación clara de responsabilidades entre módulos. El propósito es construir una solución integrada que permita evidenciar los principales conceptos estudiados durante el curso.

## 1.3 Objetivos de Aprendizaje

- Aplicar programación funcional en Elixir mediante funciones puras, pattern matching, guards, estructuras inmutables y composición de funciones.

- Modelar información utilizando listas, mapas, tuplas, MapSet y estructuras anidadas.


- Diseñar e implementar algoritmos recursivos sobre listas y estructuras jerárquicas.

- Aplicar concurrencia mediante procesos de Elixir y paso de mensajes.

- Implementar componentes con estado usando GenServer.

- Organizar procesos mediante Supervisores.

- Resolver problemas de concurrencia relacionados con recursos compartidos y operaciones simultáneas.

- Implementar persistencia en archivos de texto plano.

- Construir un sistema multiusuario donde diferentes operaciones puedan ejecutarse de forma paralela.

- Analizar y justificar decisiones de diseño relacionadas con estructuras, recursividad, procesos y supervisión.

## 1.4.1. Gestión de Usuarios

El sistema debe permitir registrar y autenticar usuarios que participen en la coordinación de la emergencia.

- Registrar usuario con nombre de usuario, contraseña, nombre completo, tipo de usuario y zona principal.

- Tipos de usuario sugeridos: ciudadano, voluntario, coordinador y administrador.

- Permitir conexión y desconexión del usuario.

- Validar credenciales cuando el usuario ya existe.

- Restringir determinadas operaciones según el tipo de usuario.

- Registrar la actividad realizada por cada usuario.

## 1.4.2. Conexión

- Conectarse (connect username password).

- Si no existe → registro automático.

- Desconectarse (disconnect).

## Reglas:

- Si el usuario no existe, se registra automáticamente.

- Si ya existe, debe validarse la contraseña.

- Un usuario autenticado puede ejecutar acciones según su rol.

## 1.4.3. Gestión de zonas afectadas

La emergencia se organiza por zonas. Una zona puede contener sectores y puntos de atención.

- Registrar zonas y sectores afectados.

- Asignar un nivel de afectación: crítico, alto, medio o bajo.

- Registrar número estimado de personas afectadas.

- Asociar albergues, necesidades, recursos y reportes a una zona.

- Consultar el estado general de una zona.

- Obtener estadísticas acumuladas de una zona y sus sectores.


- La estructura zona → sectores → puntos de atención deberá utilizarse en al menos un requisito recursivo del proyecto.

## 1.4.4. Gestión de necesidades puntuales

Los usuarios podrán registrar solicitudes de ayuda asociadas a una persona, familia, albergue o zona.

- Cada necesidad debe tener un identificador único.

- Registrar tipo de necesidad: agua, alimentos, medicamentos, primeros auxilios, refugio, transporte, rescate u otra.

- Registrar descripción, cantidad requerida, zona, prioridad, responsable del reporte y estado.

- Estados mínimos: pendiente, asignada, en atención, atendida y cancelada.

- Consultar necesidades por zona, tipo, prioridad y estado.

- Asignar recursos disponibles a una necesidad.

- Evitar que una necesidad atendida vuelva a consumir recursos.

La prioridad no será meramente informativa: deberá utilizarse para ordenar o seleccionar solicitudes de atención.

## 1.4.5. Gestión de recursos y centros de apoyo

El sistema debe administrar recursos disponibles en centros de acopio, albergues o puntos de atención.

- Registrar recursos con código, nombre, categoría, cantidad disponible, unidad de medida y ubicación.

- Registrar entradas y salidas de inventario.

- Consultar disponibilidad por tipo de recurso y zona.

- Asignar recursos a una necesidad.

- Impedir cantidades negativas.

- Conservar el historial de movimientos.

- Permitir transferencias de recursos entre centros de apoyo.

Regla de concurrencia obligatoria: si varias solicitudes intentan tomar simultáneamente el mismo recurso, el sistema debe garantizar que la cantidad asignada nunca supere el inventario disponible.

## 1.4.6. Comunicación entre familiares

El sistema debe ofrecer un mecanismo para registrar información que ayude a familiares a localizar personas y dejar mensajes.

- Registrar una persona afectada con identificador, nombre, documento o dato de referencia, edad, zona y estado.

- Estados sugeridos: sin información, reportada, localizada, trasladada, en albergue y reunificada.

- Permitir buscar personas por nombre, documento, zona o estado.

- Permitir registrar mensajes dirigidos a una persona o familia.

- Guardar fecha, remitente, destinatario, contenido y estado del mensaje.


- Permitir marcar mensajes como entregados o pendientes.

- Conservar historial de cambios de estado de una persona.

## 1.4.7. Gestión de mascotas perdidas y encontradas

El sistema debe permitir reportar mascotas extraviadas y animales encontrados durante la emergencia.

- Registrar reporte con identificador, tipo de reporte, especie, nombre si se conoce, características, color, tamaño, zona, contacto y estado.

- Tipos de reporte: perdida y encontrada.

- Estados mínimos: activa, posible coincidencia y resuelta.

- Consultar reportes por especie, zona y estado.

- Buscar posibles coincidencias entre reportes de mascotas perdidas y encontradas.

- Registrar la coincidencia confirmada y cerrar ambos reportes relacionados.

El algoritmo de búsqueda de coincidencias deberá considerar varios atributos y producir un puntaje o criterio de similitud definido por el equipo.

## 1.4.8. Gestión de albergues

- Registrar albergues con código, nombre, zona, capacidad máxima y ocupación actual.

- Registrar ingreso y salida de personas.

- Consultar cupos disponibles.

- Asociar recursos y necesidades al albergue.

- Impedir que la ocupación supere la capacidad máxima.

- Generar un reporte de albergues con mayor nivel de ocupación.

## 1.4.9. Persistencia

El sistema debe usar archivos de texto plano para conservar la información.

## 1.4.9 Validaciones y manejo de errores

- Los identificadores no pueden repetirse.

- Las cantidades y capacidades no pueden ser negativas.

- No se pueden asignar más recursos de los disponibles.

- No se puede superar la capacidad de un albergue.

- No se puede cerrar dos veces una necesidad o un reporte.

- Los estados deben seguir transiciones válidas.

- Las funciones de dominio deberán evitar lanzar errores para situaciones esperadas y retornar tuplas de resultado cuando corresponda.

- Las entradas provenientes del usuario deben validarse antes de modificar el estado.

## 1.4.10. Comandos de referencia

Los nombres son sugeridos. El grupo puede modificarlos, pero debe conservar las funcionalidades.


connect usuario contraseña tipo zona disconnect

register_zone codigo nombre nivel register_need tipo cantidad prioridad zona descripcion list_needs list_needs zona=centro prioridad=critica assign_resource need001 agua 20

register_resource R001 agua 200 litros centro_acopio_1 list_resources

transfer_resource R001 centro_acopio_1 albergue_2 30 report_person documento nombre zona estado find_person documento send_family_message documento "Estoy bien, estoy en el albergue norte" list_family_messages documento

report_pet lost perro "Luna" negra mediana zona_norte contacto report_pet found perro desconocido negra mediana zona_norte contacto match_pets

register_shelter A01 "Albergue Norte" zona_norte 150 check_shelter A01 register_entry A01 documento register_exit A01 documento

summary critical_resources pending_needs


## 1.4.10. Flujo de ejemplo

- Laura se conecta como coordinadora de la zona centro.

- Registra una necesidad crítica de 30 litros de agua para un punto de atención.

- El centro de acopio registra 50 litros disponibles.

- Al mismo tiempo, otro usuario registra una necesidad de 25 litros sobre el mismo recurso.

- El sistema procesa ambas solicitudes sin permitir que se asignen 55 litros cuando solamente existen 50.

- Un ciudadano registra a Andrés como persona localizada en el Albergue Norte.

- Un familiar deja un mensaje para Andrés.

- Un voluntario registra una mascota encontrada en la misma zona donde existe un reporte previo de una mascota perdida.

- El sistema calcula posibles coincidencias.

- Un coordinador consulta el resumen global y observa recursos restantes, necesidades pendientes, personas localizadas, mensajes y reportes de mascotas.

Ejemplo conceptual de operación:

connect laura 1234 coordinador centro register_need agua 30 critica centro "Punto de atención sector 3" register_resource R001 agua 50 litros centro_acopio_1 assign_resource N001 agua 30 summary

## 2. Desarrollo del Proyecto final

En las siguientes secciones se muestra el desarrollo del proyecto, complete la información solicitada.

## 2.1. Diagrama de Arquitectura de Módulos

Colocar una imagen del modelo de datos que represente el enunciado.


## 1.6 Modelo de datos

Colocar una imagen del modelo de datos que represente el enunciado.

- 1.7 Diagrama de Secuencia

- 1.8 Diagrama de Procesos y Supervisión (OTP Tree)


## 3. Estructuración del proyecto

En las siguientes secciones cumpir con lo que se solicita y colocar una imagen de acuerdo a la sección.

## 2.1 Estructura del proyecto

Utilizar la estructura de trabajo.

## 4. Demostración

## 4.1 Video de demostración

Realizar un vídeo haciendo una demostración de la aplicación desarrollada cumpliendo con lo solicitado.

## 5. Repositorio

## 5.1 Link repositorio

Entregar el link del repositorio.


## Lista de verificación final

El sistema gestiona usuarios.

El sistema gestiona zonas y sectores.

- El sistema gestiona necesidades.

- El sistema gestiona recursos.

- Existe comunicación entre familiares.

- Existe gestión de mascotas perdidas y encontradas.

- Existe gestión de albergues.

- Se utilizan varias estructuras de datos justificadas.

- Existen al menos cuatro funciones recursivas propias.

- Existen procesos concurrentes.

- Se utiliza GenServer.

- Existe Supervisor y/o DynamicSupervisor.

- Se demuestra un conflicto concurrente resuelto correctamente.

- Existe persistencia.

- da Existen pruebas.

- Los diagramas corresponden al código final.

- Todos los integrantes participan en el repositorio y la sustentación.

## Nota: El texto está sujeto a cambios si encuentra un error lo corrige y notifica.
