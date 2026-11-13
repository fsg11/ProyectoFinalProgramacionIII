defmodule Emergencias.Comandos do
  @moduledoc """
  Intérprete de comandos. Recibe una línea de texto y la sesión actual,
  valida permisos y entradas, llama a los GenServers y retorna:

      {texto_de_respuesta, nueva_sesion}

  La sesión es `nil` (nadie conectado) o `%{usuario: "laura", token: "..."}`.
  Este módulo lo usan tanto la consola local como el servidor remoto.
  """

  alias Emergencias.{Albergue, Bitacora, Mascota, Necesidad, Persona, Recurso, Usuario, Util, Zona}

  alias Emergencias.{
    Albergues,
    Mascotas,
    Mensajes,
    Necesidades,
    Personas,
    Recursos,
    Usuarios,
    Zonas
  }

  # comando => {nivel mínimo, forma de uso}
  @comandos %{
    "list_zones" => {1, "list_zones"},
    "zone_status" => {1, "zone_status codigo_zona"},
    "register_zone" =>
      {3, "register_zone codigo \"nombre\" nivel(critico|alto|medio|bajo) [afectados] [codigo_padre]"},
    "register_need" =>
      {1, "register_need tipo cantidad prioridad(critica|alta|media|baja) zona \"descripcion\" [destino]"},
    "list_needs" => {1, "list_needs [zona=..] [tipo=..] [prioridad=..] [estado=..]"},
    "pending_needs" => {1, "pending_needs [zona]"},
    "update_need" => {3, "update_need id_necesidad en_atencion|atendida|cancelada"},
    "assign_resource" => {3, "assign_resource id_necesidad codigo_o_categoria cantidad"},
    "register_resource" =>
      {2, "register_resource codigo nombre cantidad unidad ubicacion [categoria] [zona]"},
    "resource_in" => {2, "resource_in codigo cantidad [\"detalle\"]"},
    "resource_out" => {2, "resource_out codigo cantidad [\"detalle\"]"},
    "list_resources" => {1, "list_resources [categoria=..] [zona=..] [ubicacion=..]"},
    "transfer_resource" => {3, "transfer_resource codigo origen destino cantidad"},
    "movements" => {2, "movements [codigo]"},
    "critical_resources" => {2, "critical_resources [umbral]"},
    "report_person" => {1, "report_person documento \"nombre\" zona estado [edad]"},
    "update_person" => {2, "update_person documento estado"},
    "find_person" => {1, "find_person documento | nombre=.. | zona=.. | estado=.."},
    "person_history" => {1, "person_history documento"},
    "send_family_message" => {1, "send_family_message destinatario \"mensaje\""},
    "list_family_messages" => {1, "list_family_messages destinatario"},
    "mark_message" => {2, "mark_message id_mensaje entregado|pendiente"},
    "report_pet" =>
      {1, "report_pet lost|found especie \"nombre\" color tamano zona contacto [\"caracteristicas\"]"},
    "list_pets" => {1, "list_pets [especie=..] [zona=..] [estado=..] [tipo=..]"},
    "match_pets" => {2, "match_pets"},
    "confirm_match" => {3, "confirm_match id_perdida id_encontrada"},
    "register_shelter" => {3, "register_shelter codigo \"nombre\" zona capacidad"},
    "check_shelter" => {1, "check_shelter codigo"},
    "list_shelters" => {1, "list_shelters"},
    "register_entry" => {2, "register_entry codigo_albergue documento"},
    "register_exit" => {2, "register_exit codigo_albergue documento"},
    "summary" => {3, "summary"},
    "simulate_conflict" => {3, "simulate_conflict"},
    "activity" => {3, "activity [usuario]"},
    "set_role" => {3, "set_role usuario ciudadano|voluntario|coordinador|administrador"},
    "users" => {4, "users"}
  }

  @umbral_critico 20

  def ejecutar(linea, sesion) do
    case Util.separar_palabras(linea) do
      [] ->
        {"", sesion}

      [comando | argumentos] ->
        resultado = procesar(String.downcase(comando), argumentos, sesion)
        Emergencias.Notificador.notificar()
        resultado
    end
  end

  @doc """
  Nivel mínimo que exige un comando (1 ciudadano ... 4 administrador), o nil
  si no existe. Lo usa la interfaz web para mostrar solo lo permitido.
  """
  def nivel_requerido(comando) do
    case Map.fetch(@comandos, comando) do
      {:ok, {nivel, _uso}} -> nivel
      :error -> nil
    end
  end

  @doc "Forma de uso de un comando, o nil si no existe."
  def uso(comando) do
    case Map.fetch(@comandos, comando) do
      {:ok, {_nivel, uso}} -> uso
      :error -> nil
    end
  end

  defp procesar("help", _argumentos, sesion), do: {ayuda(), sesion}

  defp procesar("connect", argumentos, nil), do: conectar(argumentos)

  defp procesar("connect", _argumentos, sesion),
    do: {"Ya hay una sesión activa (#{sesion.usuario}). Use disconnect primero.", sesion}

  defp procesar(_comando, _argumentos, nil),
    do: {"Debe conectarse primero: connect usuario contraseña [tipo] [zona] [\"nombre completo\"]", nil}

  # Solo se cierra la sesión si el token coincide con el de la sesión activa.
  defp procesar("disconnect", _argumentos, sesion) do
    case Usuarios.desconectar(sesion.usuario, sesion.token) do
      :ok ->
        Bitacora.registrar(sesion.usuario, "disconnect")
        {"Sesión cerrada. Hasta pronto, #{sesion.usuario}.", nil}

      {:error, mensaje} ->
        {mensaje, nil}
    end
  end

  defp procesar(comando, argumentos, sesion) do
    case Usuarios.validar_sesion(sesion.usuario, sesion.token) do
      {:ok, usuario} -> procesar_autenticado(comando, argumentos, usuario, sesion)
      {:error, mensaje} -> {mensaje, nil}
    end
  end

  defp procesar_autenticado(comando, argumentos, usuario, sesion) do
    case Map.fetch(@comandos, comando) do
      :error ->
        {"Comando desconocido: #{comando}. Escriba help para ver los comandos.", sesion}

      {:ok, {nivel, _uso}} ->
        if Usuario.nivel(usuario.tipo) >= nivel do
          Bitacora.registrar(usuario.usuario, Enum.join([comando | argumentos], " "))
          {ejecutar_comando(comando, argumentos, usuario), sesion}
        else
          {"Permiso denegado: un #{usuario.tipo} no puede usar #{comando}.", sesion}
        end
    end
  end

  defp conectar([usuario, contrasena | resto]) do
    {tipo, zona, nombre} = datos_registro(resto, usuario)

    case Usuarios.conectar(usuario, contrasena, tipo, zona, nombre) do
      {:ok, :registrado, datos, token} ->
        Bitacora.registrar(usuario, "connect (registro automático)")
        {"Usuario nuevo registrado y conectado: #{datos}", %{usuario: usuario, token: token}}

      {:ok, :autenticado, datos, token} ->
        Bitacora.registrar(usuario, "connect")
        {"Bienvenido(a) de nuevo: #{datos}", %{usuario: usuario, token: token}}

      {:error, mensaje} ->
        {"Error: #{mensaje}", nil}
    end
  end

  defp conectar(_argumentos),
    do: {"Uso: connect usuario contraseña [tipo] [zona] [\"nombre completo\"]", nil}

  defp datos_registro([], usuario), do: {"ciudadano", "sin_zona", usuario}
  defp datos_registro([tipo], usuario), do: {Util.normalizar(tipo), "sin_zona", usuario}
  defp datos_registro([tipo, zona], usuario), do: {Util.normalizar(tipo), zona, usuario}
  defp datos_registro([tipo, zona, nombre | _], _usuario), do: {Util.normalizar(tipo), zona, nombre}

  defp ejecutar_comando("register_zone", [codigo, nombre, nivel | resto], _usuario) do
    afectados = Enum.at(resto, 0, "0")
    padre = Enum.at(resto, 1, "-")

    with {:ok, cantidad} <- Util.entero(afectados, "afectados"),
         {:ok, zona} <- Zonas.registrar(codigo, nombre, Util.normalizar(nivel), cantidad, padre) do
      "Registrado: #{zona}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("list_zones", _argumentos, _usuario) do
    case Zonas.arbol() do
      [] -> "No hay zonas registradas."
      arbol -> "Zonas registradas:\n" <> Enum.map_join(arbol, "\n", &Zona.formatear(&1, 1))
    end
  end

  defp ejecutar_comando("zone_status", [codigo], _usuario) do
    case Zonas.subarbol(codigo) do
      {:ok, nodo} -> estado_zona(nodo)
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando(
         "register_need",
         [tipo, cantidad, prioridad, zona, descripcion | resto],
         usuario
       ) do
    datos = %{
      tipo: Util.normalizar(tipo),
      prioridad: Util.normalizar(prioridad),
      zona: zona,
      descripcion: descripcion,
      responsable: usuario.usuario,
      destino: Enum.at(resto, 0, "-")
    }

    with {:ok, cantidad} <- Util.entero_positivo(cantidad, "cantidad"),
         :ok <- validar_zona(zona),
         {:ok, necesidad} <- Necesidades.registrar(Map.put(datos, :cantidad, cantidad)) do
      "Necesidad registrada: #{necesidad}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("list_needs", argumentos, _usuario) do
    lista = Necesidades.listar(Util.filtros(argumentos))
    "Necesidades (ordenadas por prioridad):\n" <> Util.lista_a_texto(lista, &"  #{&1}")
  end

  defp ejecutar_comando("pending_needs", argumentos, _usuario) do
    lista = Necesidades.pendientes(List.first(argumentos))

    "Necesidades pendientes (la primera es la siguiente a atender):\n" <>
      Util.lista_a_texto(lista, fn n -> "  #{n}  -> faltan #{Necesidad.faltante(n)}" end)
  end

  defp ejecutar_comando("update_need", [id, estado], _usuario) do
    case Necesidades.cambiar_estado(id, Util.normalizar(estado)) do
      {:ok, necesidad} -> "Necesidad actualizada: #{necesidad}"
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("assign_resource", [id, criterio, cantidad], usuario) do
    with {:ok, cantidad} <- Util.entero_positivo(cantidad, "cantidad"),
         {:ok, necesidad, reparto} <- Necesidades.asignar(id, criterio, cantidad, usuario.usuario) do
      detalle = Enum.map_join(reparto, ", ", fn {codigo, tomado} -> "#{codigo}: #{tomado}" end)
      "Asignación confirmada (#{detalle}).\n  #{necesidad}"
    else
      {:error, mensaje} -> "Asignación rechazada: #{mensaje}"
    end
  end

  defp ejecutar_comando(
         "register_resource",
         [codigo, nombre, cantidad, unidad, ubicacion | resto],
         usuario
       ) do
    nombre = Util.normalizar(nombre)
    categoria = resto |> Enum.at(0, nombre) |> Util.normalizar()
    zona = Enum.at(resto, 1, usuario.zona)

    with {:ok, cantidad} <- Util.entero(cantidad, "cantidad"),
         {:ok, recurso} <- Recurso.crear(codigo, nombre, categoria, cantidad, unidad, ubicacion, zona),
         {:ok, recurso} <- Recursos.registrar(recurso, usuario.usuario) do
      "Recurso registrado: #{recurso}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("resource_in", [codigo, cantidad | resto], usuario) do
    detalle = Enum.at(resto, 0, "Entrada registrada por #{usuario.usuario}")

    with {:ok, cantidad} <- Util.entero_positivo(cantidad, "cantidad"),
         {:ok, recurso} <- Recursos.entrada(codigo, cantidad, detalle) do
      "Entrada registrada: #{recurso}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("resource_out", [codigo, cantidad | resto], usuario) do
    detalle = Enum.at(resto, 0, "Salida registrada por #{usuario.usuario}")

    with {:ok, cantidad} <- Util.entero_positivo(cantidad, "cantidad"),
         {:ok, recurso} <- Recursos.salida(codigo, cantidad, detalle) do
      "Salida registrada: #{recurso}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("list_resources", argumentos, _usuario) do
    lista = Recursos.listar(Util.filtros(argumentos))
    "Recursos:\n" <> Util.lista_a_texto(lista, &"  #{&1}")
  end

  defp ejecutar_comando("transfer_resource", [codigo, origen, destino, cantidad], usuario) do
    with {:ok, cantidad} <- Util.entero_positivo(cantidad, "cantidad"),
         :ok <- validar_destino(destino),
         {:ok, de, para} <- Recursos.transferir(codigo, origen, destino, cantidad, usuario.usuario) do
      "Transferencia realizada.\n  Origen : #{de}\n  Destino: #{para}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("movements", argumentos, _usuario) do
    lista = Recursos.movimientos(List.first(argumentos))

    "Historial de movimientos:\n" <>
      Util.lista_a_texto(lista, fn m ->
        "  [#{m.fecha}] #{m.tipo} #{m.codigo} #{m.cantidad} - #{m.detalle}"
      end)
  end

  defp ejecutar_comando("critical_resources", argumentos, _usuario) do
    case Util.entero(Enum.at(argumentos, 0, "#{@umbral_critico}"), "umbral") do
      {:ok, umbral} ->
        lista = Recursos.criticos(umbral)
        "Recursos con #{umbral} unidades o menos:\n" <> Util.lista_a_texto(lista, &"  #{&1}")

      {:error, mensaje} ->
        "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("report_person", [documento, nombre, zona, estado | resto], usuario) do
    with {:ok, edad} <- Util.entero(Enum.at(resto, 0, "0"), "edad"),
         :ok <- validar_zona(zona),
         {:ok, persona} <- Persona.crear(documento, nombre, edad, zona, Util.normalizar(estado)),
         {:ok, persona} <- Personas.registrar(persona, usuario.usuario) do
      "Persona registrada: #{persona}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("update_person", [documento, estado], usuario) do
    case Personas.cambiar_estado(documento, Util.normalizar(estado), usuario.usuario) do
      {:ok, persona} -> "Estado actualizado: #{persona}"
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("find_person", [_ | _] = argumentos, _usuario) do
    filtros =
      case Util.filtros(argumentos) do
        [] -> [{"documento", Util.normalizar(List.first(argumentos))}]
        filtros -> filtros
      end

    lista = Personas.buscar(filtros)

    "Personas encontradas:\n" <>
      Util.lista_a_texto(lista, fn p ->
        mensajes = Mensajes.listar(p.documento)
        "  #{p} | mensajes: #{length(mensajes)}"
      end)
  end

  defp ejecutar_comando("person_history", [documento], _usuario) do
    lista = Personas.historial(documento)

    "Historial de estados de #{documento}:\n" <>
      Util.lista_a_texto(lista, fn h ->
        "  [#{h.fecha}] #{h.anterior} -> #{h.nuevo} (por #{h.usuario})"
      end)
  end

  defp ejecutar_comando("send_family_message", [destinatario, contenido | _], usuario) do
    case Mensajes.enviar(usuario.usuario, destinatario, contenido) do
      {:ok, mensaje} ->
        nota =
          case Personas.obtener(destinatario) do
            {:ok, persona} -> "Destinatario: #{persona.nombre} (#{persona.estado})."
            {:error, _} -> "Destinatario no registrado como persona; se guardó como mensaje para familia."
          end

        "Mensaje registrado: #{mensaje}\n  #{nota}"

      {:error, mensaje} ->
        "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("list_family_messages", [destinatario], _usuario) do
    lista = Mensajes.listar(destinatario)
    "Mensajes para #{destinatario}:\n" <> Util.lista_a_texto(lista, &"  #{&1}")
  end

  defp ejecutar_comando("mark_message", [id, estado], _usuario) do
    case Mensajes.marcar(id, Util.normalizar(estado)) do
      {:ok, mensaje} -> "Mensaje actualizado: #{mensaje}"
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando(
         "report_pet",
         [tipo, especie, nombre, color, tamano, zona, contacto | resto],
         _usuario
       ) do
    datos = %{
      tipo: tipo_reporte(Util.normalizar(tipo)),
      especie: Util.normalizar(especie),
      nombre: nombre,
      color: Util.normalizar(color),
      tamano: Util.normalizar(tamano),
      zona: zona,
      contacto: contacto,
      caracteristicas: Enum.at(resto, 0, "")
    }

    with :ok <- validar_zona(zona),
         {:ok, reporte} <- Mascotas.registrar(datos) do
      "Reporte registrado: #{reporte}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("list_pets", argumentos, _usuario) do
    lista = Mascotas.listar(Util.filtros(argumentos))
    "Reportes de mascotas:\n" <> Util.lista_a_texto(lista, &"  #{&1}")
  end

  defp ejecutar_comando("match_pets", _argumentos, _usuario) do
    case Mascotas.buscar_coincidencias() do
      [] ->
        "No se encontraron posibles coincidencias (umbral #{Mascota.umbral()} puntos)."

      coincidencias ->
        "Posibles coincidencias (umbral #{Mascota.umbral()} puntos):\n" <>
          Enum.map_join(coincidencias, "\n", fn {perdida, encontrada, puntaje} ->
            "  #{puntaje} pts: perdida #{perdida.id} (#{perdida.nombre}) <-> encontrada #{encontrada.id}" <>
              "  => confirm_match #{perdida.id} #{encontrada.id}"
          end)
    end
  end

  defp ejecutar_comando("confirm_match", [id_perdida, id_encontrada], _usuario) do
    case Mascotas.confirmar(id_perdida, id_encontrada) do
      {:ok, perdida, encontrada} -> "Coincidencia confirmada:\n  #{perdida}\n  #{encontrada}"
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("register_shelter", [codigo, nombre, zona, capacidad], _usuario) do
    with {:ok, capacidad} <- Util.entero_positivo(capacidad, "capacidad"),
         :ok <- validar_zona(zona),
         {:ok, albergue} <- Albergue.crear(codigo, nombre, zona, capacidad),
         {:ok, albergue} <- Albergues.registrar(albergue) do
      "Albergue registrado: #{albergue}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("check_shelter", [codigo], _usuario) do
    case Albergues.obtener(codigo) do
      {:ok, albergue} ->
        recursos = Recursos.listar([{"ubicacion", Util.normalizar(codigo)}])
        necesidades = Necesidades.listar([{"destino", Util.normalizar(codigo)}])

        """
        #{albergue}
          Personas alojadas: #{Enum.join(Enum.sort(albergue.ocupantes), ", ")}
          Recursos en el albergue:
        #{Util.lista_a_texto(recursos, &"    #{&1}")}
          Necesidades asociadas:
        #{Util.lista_a_texto(necesidades, &"    #{&1}")}
        """

      {:error, mensaje} ->
        "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("list_shelters", _argumentos, _usuario) do
    lista = Albergues.reporte_ocupacion()
    "Albergues (de mayor a menor ocupación):\n" <> Util.lista_a_texto(lista, &"  #{&1}")
  end

  # Si el cambio de estado falla, se deshace el ingreso (acción compensatoria).
  defp ejecutar_comando("register_entry", [codigo, documento], usuario) do
    with {:ok, persona} <- Personas.obtener(documento),
         :ok <- validar_ingreso_persona(persona),
         {:ok, albergue} <- Albergues.ingresar(codigo, documento),
         :ok <- marcar_en_albergue(persona, codigo, usuario) do
      "Ingreso registrado: #{albergue}\n  Estado de #{persona.nombre}: en_albergue."
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  # Si el cambio de estado falla, se deshace la salida (acción compensatoria).
  defp ejecutar_comando("register_exit", [codigo, documento], usuario) do
    with {:ok, albergue} <- Albergues.salir(codigo, documento),
         {:ok, detalle} <- marcar_salida(codigo, documento, usuario) do
      "Salida registrada: #{albergue}\n  #{detalle}"
    else
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("summary", _argumentos, _usuario), do: resumen_global()

  defp ejecutar_comando("simulate_conflict", _argumentos, usuario), do: simular_conflicto(usuario)

  defp ejecutar_comando("activity", argumentos, _usuario) do
    registros = Bitacora.consultar(List.first(argumentos))

    "Actividad registrada:\n" <>
      Util.lista_a_texto(registros, fn r -> "  [#{r.fecha}] #{r.usuario}: #{r.accion}" end)
  end

  defp ejecutar_comando("set_role", [objetivo, tipo], usuario) do
    case Usuarios.cambiar_rol(usuario.usuario, objetivo, Util.normalizar(tipo)) do
      {:ok, actualizado} -> "Rol actualizado: #{actualizado}"
      {:error, mensaje} -> "Error: #{mensaje}"
    end
  end

  defp ejecutar_comando("users", _argumentos, _usuario) do
    "Usuarios:\n" <>
      Util.lista_a_texto(Usuarios.listar(), fn {u, conectado} ->
        "  #{u}" <> if(conectado, do: " (conectado)", else: "")
      end)
  end

  # Si ninguna cláusula anterior coincidió, el número de argumentos es incorrecto.
  defp ejecutar_comando(comando, _argumentos, _usuario) do
    {_nivel, uso} = Map.fetch!(@comandos, comando)
    "Uso: #{uso}"
  end

  defp validar_zona(zona) do
    if Zonas.existe?(zona), do: :ok, else: {:error, "La zona #{zona} no está registrada"}
  end

  defp validar_ingreso_persona(%{estado: "en_albergue"}), do: :ok

  defp validar_ingreso_persona(persona) do
    case Persona.cambiar_estado(persona, "en_albergue") do
      {:ok, _persona} -> :ok
      {:error, mensaje} -> {:error, "No se puede ingresar a la persona al albergue. #{mensaje}"}
    end
  end

  defp marcar_en_albergue(%{estado: "en_albergue"}, _codigo, _usuario), do: :ok

  defp marcar_en_albergue(persona, codigo, usuario) do
    case Personas.cambiar_estado(persona.documento, "en_albergue", usuario.usuario) do
      {:ok, _persona} ->
        :ok

      {:error, mensaje} ->
        Albergues.salir(codigo, persona.documento)
        {:error, "Ingreso revertido: #{mensaje}"}
    end
  end

  defp marcar_salida(codigo, documento, usuario) do
    case Personas.obtener(documento) do
      {:ok, %{estado: "en_albergue"} = persona} ->
        case Personas.cambiar_estado(documento, "localizada", usuario.usuario) do
          {:ok, _persona} ->
            {:ok, "Estado de #{persona.nombre}: localizada."}

          {:error, mensaje} ->
            Albergues.ingresar(codigo, documento)
            {:error, "Salida revertida: #{mensaje}"}
        end

      {:ok, persona} ->
        {:ok, "Estado de #{persona.nombre} sin cambios: #{persona.estado}."}

      {:error, _mensaje} ->
        {:ok, "La persona #{documento} no tiene registro; solo se liberó el cupo."}
    end
  end

  defp validar_destino(destino) do
    cond do
      match?({:ok, _}, Albergues.obtener(destino)) ->
        :ok

      Enum.any?(Recursos.listar(), fn recurso -> recurso.ubicacion == destino end) ->
        :ok

      true ->
        {:error,
         "El destino #{destino} no existe: debe ser un albergue registrado o una ubicación con recursos"}
    end
  end

  defp tipo_reporte(tipo) when tipo in ["lost", "perdida", "perdido"], do: "perdida"
  defp tipo_reporte(tipo) when tipo in ["found", "encontrada", "encontrado"], do: "encontrada"
  defp tipo_reporte(tipo), do: tipo

  # Estado general de una zona y TODOS sus sectores y puntos (usa recursión).
  defp estado_zona(nodo) do
    codigos = nodo |> Zona.codigos_subarbol() |> MapSet.new()

    necesidades = Enum.filter(Necesidades.listar(), &MapSet.member?(codigos, &1.zona))
    abiertas = Enum.filter(necesidades, &Necesidad.abierta?/1)
    albergues = Enum.filter(Albergues.listar(), &MapSet.member?(codigos, &1.zona))
    recursos = Enum.filter(Recursos.listar(), &MapSet.member?(codigos, &1.zona))
    personas = Personas.buscar([]) |> Enum.filter(&MapSet.member?(codigos, &1.zona))

    """
    === Estado de #{nodo.zona.tipo} #{nodo.zona.codigo} - #{nodo.zona.nombre} ===
    Estructura:
    #{Zona.formatear(nodo, 1)}
    Personas afectadas (acumulado con sectores y puntos): #{Zona.total_afectados(nodo)}
    Nodos por nivel de afectación: #{Util.formatear_conteo(Zona.contar_por_nivel(nodo))}
    Necesidades por estado: #{Util.formatear_conteo(Enum.frequencies_by(necesidades, & &1.estado))}
    Necesidades abiertas por prioridad:
    #{Util.lista_a_texto(abiertas, &"  #{&1}")}
    Recursos en la zona:
    #{Util.lista_a_texto(recursos, &"  #{&1}")}
    Albergues:
    #{Util.lista_a_texto(albergues, &"  #{&1}")}
    Personas registradas por estado: #{Util.formatear_conteo(Enum.frequencies_by(personas, & &1.estado))}
    """
  end

  defp resumen_global do
    necesidades = Necesidades.resumen()
    recursos = Recursos.resumen()
    personas = Personas.resumen()
    mensajes = Mensajes.resumen()
    mascotas = Mascotas.resumen()
    albergues = Albergues.resumen()
    criticos = Recursos.criticos(@umbral_critico)

    """
    ================= RESUMEN GLOBAL =================
    Recursos: #{recursos.lotes} lotes, #{recursos.agotados} agotados, #{recursos.movimientos} movimientos
      Disponible por categoría: #{Util.formatear_conteo(recursos.por_categoria)}
      Recursos críticos (<= #{@umbral_critico}): #{length(criticos)}
    Necesidades: #{necesidades.total}
      Por estado: #{Util.formatear_conteo(necesidades.por_estado)}
      Abiertas por prioridad: #{Util.formatear_conteo(necesidades.por_prioridad)}
    Personas: #{personas.total}
      Por estado: #{Util.formatear_conteo(personas.por_estado)}
    Mensajes: #{mensajes.total}
      Por estado: #{Util.formatear_conteo(mensajes.por_estado)}
    Mascotas: #{mascotas.total}
      Por tipo: #{Util.formatear_conteo(mascotas.por_tipo)}
      Por estado: #{Util.formatear_conteo(mascotas.por_estado)}
    Albergues: #{albergues.total} con ocupación #{albergues.ocupacion}/#{albergues.capacidad}
    ==================================================
    """
  end

  # Dos solicitudes simultáneas (30 y 25) sobre un recurso de 50 unidades.
  # Al terminar se eliminan los datos creados por la simulación.
  defp simular_conflicto(usuario) do
    codigo = "SIM" <> Integer.to_string(System.unique_integer([:positive]))
    marca = "SIMULACION de conflicto #{codigo}"

    try do
      ejecutar_simulacion(usuario, codigo, marca)
    after
      Recursos.eliminar(codigo)

      Necesidades.listar()
      |> Enum.filter(fn n -> n.descripcion == marca end)
      |> Enum.each(fn n -> Necesidades.eliminar(n.id) end)
    end
  end

  defp ejecutar_simulacion(usuario, codigo, marca) do
    datos_necesidad = %{
      tipo: "agua",
      prioridad: "critica",
      zona: usuario.zona,
      descripcion: marca,
      responsable: usuario.usuario,
      destino: "-"
    }

    with {:ok, recurso} <-
           Recurso.crear(codigo, "agua_simulacion", "agua_simulacion", 50, "litros", "centro_simulacion", usuario.zona),
         {:ok, _recurso} <- Recursos.registrar(recurso, usuario.usuario),
         {:ok, n1} <- Necesidades.registrar(Map.put(datos_necesidad, :cantidad, 30)),
         {:ok, n2} <- Necesidades.registrar(Map.put(datos_necesidad, :cantidad, 25)) do
      # Las dos asignaciones se lanzan AL MISMO TIEMPO en procesos distintos.
      tareas = [
        Task.async(fn -> {n1.id, 30, Necesidades.asignar(n1.id, codigo, 30, "usuario_A")} end),
        Task.async(fn -> {n2.id, 25, Necesidades.asignar(n2.id, codigo, 25, "usuario_B")} end)
      ]

      resultados = Enum.map(tareas, fn tarea -> Task.await(tarea, 10_000) end)

      final =
        case Recursos.obtener(codigo) do
          {:ok, r} -> r.cantidad
          {:error, _} -> "?"
        end

      lineas =
        Enum.map_join(resultados, "\n", fn
          {id, cantidad, {:ok, _necesidad, _reparto}} -> "  #{id} pidió #{cantidad}: CONFIRMADA"
          {id, cantidad, {:error, mensaje}} -> "  #{id} pidió #{cantidad}: RECHAZADA (#{mensaje})"
        end)

      """
      === Simulación de conflicto concurrente ===
      Recurso #{codigo}: 50 litros disponibles.
      Dos solicitudes simultáneas: #{n1.id} pide 30 y #{n2.id} pide 25 (total 55 > 50).
      #{lineas}
      Inventario final de #{codigo}: #{final} litros (nunca queda negativo).
      Los datos de la simulación se eliminaron al terminar.
      """
    else
      {:error, mensaje} -> "Error en la simulación: #{mensaje}"
    end
  end

  defp ayuda do
    comandos =
      @comandos
      |> Enum.sort_by(fn {nombre, {nivel, _uso}} -> {nivel, nombre} end)
      |> Enum.map_join("\n", fn {_nombre, {nivel, uso}} -> "  [#{nivel}] #{uso}" end)

    """
    Comandos generales:
      connect usuario contraseña [tipo] [zona] ["nombre completo"]
      disconnect
      help
      exit
    Comandos según nivel ([1] ciudadano, [2] voluntario, [3] coordinador, [4] administrador):
    #{comandos}
    """
  end
end
