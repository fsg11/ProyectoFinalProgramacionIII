defmodule EmergenciasWeb.PersonasLive do
  @moduledoc "Personas: reporte, búsqueda, cambios de estado, historial y mensajes familiares."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Mensajes, Persona, Personas, Util}

  @impl true
  def mount(_parametros, _sesion, socket) do
    socket =
      socket
      |> assign(:page_title, "Personas y mensajes")
      |> assign(:filtros, %{})
      |> assign(:destinatario, nil)

    {:ok, cargar(socket)}
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("filtrar", p, socket) do
    filtros = %{"nombre" => param(p, "nombre"), "zona" => param(p, "zona"), "estado" => param(p, "estado")}
    {:noreply, socket |> assign(:filtros, filtros) |> cargar()}
  end

  def handle_event("reportar", p, socket) do
    partes = [
      "report_person",
      param(p, "documento"),
      param(p, "nombre"),
      param(p, "zona"),
      param(p, "estado"),
      param(p, "edad")
    ]

    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("actualizar", %{"estado" => ""}, socket), do: {:noreply, socket}

  def handle_event("actualizar", %{"documento" => documento, "estado" => estado}, socket) do
    {:noreply, socket |> ejecutar(["update_person", documento, estado]) |> cargar()}
  end

  def handle_event("historial", %{"documento" => documento}, socket) do
    {:noreply, ejecutar(socket, ["person_history", documento])}
  end

  def handle_event("ver_mensajes", %{"documento" => documento}, socket) do
    {:noreply, socket |> assign(:destinatario, documento) |> cargar()}
  end

  def handle_event("enviar", p, socket) do
    destinatario = param(p, "destinatario")
    partes = ["send_family_message", destinatario, param(p, "contenido")]
    {:noreply, socket |> assign(:destinatario, destinatario) |> ejecutar(partes) |> cargar()}
  end

  def handle_event("marcar", %{"id" => id, "estado" => estado}, socket) do
    {:noreply, socket |> ejecutar(["mark_message", id, estado]) |> cargar()}
  end

  defp cargar(socket) do
    filtros =
      socket.assigns.filtros
      |> Enum.reject(fn {_clave, valor} -> valor == "" end)
      |> Enum.map(fn {clave, valor} -> {clave, Util.normalizar(valor)} end)

    mensajes =
      case socket.assigns.destinatario do
        nil -> []
        destinatario -> Mensajes.listar(destinatario)
      end

    socket
    |> assign(:personas, Personas.buscar(filtros))
    |> assign(:mensajes, mensajes)
    |> assign(:codigos, codigos_zona())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/personas" tema="personas">
      <.encabezado
        titulo="Personas y mensajes familiares"
        decoracion="personas"
        subtitulo="Registro de personas afectadas, su estado y los mensajes que dejan sus familiares."
      />

      <div class="columnas">
        <.seccion titulo="Reportar persona">
          <form id={"form-persona-#{@version}"} phx-submit="reportar" class="formulario rejilla">
            <.campo etiqueta="Documento" nombre="documento" requerido ayuda="1094" />
            <.campo etiqueta="Nombre completo" nombre="nombre" requerido />
            <.selector etiqueta="Zona" nombre="zona" opciones={@codigos} valor={@usuario.zona} />
            <.selector etiqueta="Estado" nombre="estado" opciones={Persona.estados()} valor="reportada" />
            <.campo etiqueta="Edad (opcional)" nombre="edad" tipo="number" min="0" />
            <div class="acciones-formulario">
              <button type="submit" class="boton boton-primario">Reportar</button>
            </div>
          </form>
        </.seccion>

        <.seccion titulo="Enviar mensaje familiar">
          <form id={"form-mensaje-#{@version}"} phx-submit="enviar" class="formulario">
            <.campo
              etiqueta="Documento del destinatario"
              nombre="destinatario"
              requerido
              valor={@destinatario}
              lista="documentos"
            />
            <label class="campo">
              <span>Mensaje<em>*</em></span>
              <textarea name="contenido" rows="3" required placeholder="Estoy bien, estoy en el albergue norte"></textarea>
            </label>
            <button type="submit" class="boton boton-primario">Enviar mensaje</button>
          </form>
          <.sugerencias id="documentos" opciones={Enum.map(@personas, & &1.documento)} />
        </.seccion>
      </div>

      <.resultado resultado={@resultado} />

      <.seccion titulo={"Personas (#{length(@personas)})"}>
        <form id="filtros" phx-change="filtrar" class="filtros">
          <.campo etiqueta="Nombre contiene" nombre="nombre" valor={@filtros["nombre"]} />
          <.selector etiqueta="Zona" nombre="zona" opciones={@codigos} valor={@filtros["zona"]} vacio="Todas" />
          <.selector etiqueta="Estado" nombre="estado" opciones={Persona.estados()} valor={@filtros["estado"]} vacio="Todos" />
        </form>

        <.vacio :if={@personas == []} icono="persona" texto="No hay personas con esos filtros." />
        <div class="tabla-contenedor">
          <table :if={@personas != []} class="tabla">
            <thead>
              <tr><th>Documento</th><th>Nombre</th><th>Edad</th><th>Zona</th><th>Estado</th><th>Acciones</th></tr>
            </thead>
            <tbody>
              <tr :for={p <- @personas} id={"persona-#{p.documento}"}>
                <td><strong>{p.documento}</strong></td>
                <td><span class="con-persona"><span class="avatar"><.icono_persona /></span>{p.nombre}</span></td>
                <td>{p.edad}</td>
                <td>{p.zona}</td>
                <td><.insignia texto={p.estado} /></td>
                <td>
                  <div class="acciones-fila en-linea">
                    <form :if={puede?(@usuario, "update_person")} id={"estado-#{p.documento}"} phx-change="actualizar" class="en-linea">
                      <input type="hidden" name="documento" value={p.documento} />
                      <select name="estado" title="Cambiar estado">
                        <option value="">Cambiar estado…</option>
                        <option :for={e <- Persona.estados()} :if={e != p.estado} value={e}>
                          {String.replace(e, "_", " ")}
                        </option>
                      </select>
                    </form>
                    <button type="button" class="boton boton-mini boton-claro" phx-click="historial" phx-value-documento={p.documento}>
                      Historial
                    </button>
                    <button type="button" class="boton boton-mini boton-claro" phx-click="ver_mensajes" phx-value-documento={p.documento}>
                      Mensajes
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </.seccion>

      <.seccion :if={@destinatario} titulo={"Mensajes para #{@destinatario}"}>
        <.vacio :if={@mensajes == []} icono="persona" texto="No hay mensajes para esta persona." />
        <ul class="mensajes">
          <li :for={m <- @mensajes} class="mensaje">
            <div>
              <span class="avatar avatar-mini"><.icono_persona /></span> <strong>{m.id}</strong> · de <strong>{m.remitente}</strong> · <small>{m.fecha}</small>
              <.insignia texto={m.estado} />
            </div>
            <p>{m.contenido}</p>
            <button
              :if={puede?(@usuario, "mark_message")}
              type="button"
              class="boton boton-mini boton-claro"
              phx-click="marcar"
              phx-value-id={m.id}
              phx-value-estado={if m.estado == "entregado", do: "pendiente", else: "entregado"}
            >
              Marcar como {if m.estado == "entregado", do: "pendiente", else: "entregado"}
            </button>
          </li>
        </ul>
      </.seccion>
    </Layouts.app>
    """
  end
end
