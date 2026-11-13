defmodule EmergenciasWeb.UsuariosLive do
  @moduledoc "Asignación de roles, lista de usuarios y bitácora."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Bitacora, Usuario, Usuarios}

  @impl true
  def mount(_parametros, _sesion, socket) do
    socket = assign(socket, :page_title, "Usuarios y roles")

    if puede?(socket.assigns.usuario, "set_role") do
      {:ok, cargar(socket)}
    else
      {:ok, socket |> put_flash(:error, "Permiso denegado: solo coordinadores.") |> push_navigate(to: ~p"/panel")}
    end
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("rol", p, socket) do
    {:noreply, socket |> ejecutar(["set_role", param(p, "usuario"), param(p, "tipo")]) |> cargar()}
  end

  defp cargar(socket) do
    usuario = socket.assigns.usuario

    socket
    |> assign(:usuarios, if(puede?(usuario, "users"), do: Usuarios.listar(), else: nil))
    |> assign(
      :actividad,
      if(puede?(usuario, "activity"), do: Bitacora.consultar() |> Enum.take(-20) |> Enum.reverse(), else: [])
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/usuarios">
      <.encabezado
        titulo="Usuarios y roles"
        subtitulo="Nadie puede otorgar un rol mayor al suyo, modificar a alguien de rol mayor ni cambiar su propio rol."
      />

      <.seccion titulo="Asignar rol">
        <form id={"form-rol-#{@version}"} phx-submit="rol" class="formulario rejilla">
          <.campo etiqueta="Usuario" nombre="usuario" requerido lista="lista-usuarios" />
          <.selector etiqueta="Nuevo rol" nombre="tipo" opciones={Usuario.tipos()} valor="voluntario" />
          <div class="acciones-formulario">
            <button type="submit" class="boton boton-primario">Asignar rol</button>
          </div>
        </form>
        <.sugerencias :if={@usuarios} id="lista-usuarios" opciones={Enum.map(@usuarios, fn {u, _} -> u.usuario end)} />
      </.seccion>

      <.resultado resultado={@resultado} />

      <.seccion :if={@usuarios} titulo={"Usuarios registrados (#{length(@usuarios)})"}>
        <table class="tabla">
          <thead><tr><th>Usuario</th><th>Nombre</th><th>Rol</th><th>Zona</th><th>Conexión</th></tr></thead>
          <tbody>
            <tr :for={{u, conectado} <- @usuarios}>
              <td><strong>{u.usuario}</strong></td>
              <td>{u.nombre}</td>
              <td><.insignia texto={u.tipo} /></td>
              <td>{u.zona}</td>
              <td><.insignia texto={if conectado, do: "conectado", else: "desconectado"} /></td>
            </tr>
          </tbody>
        </table>
      </.seccion>

      <.seccion :if={@actividad != []} titulo="Bitácora de actividad (últimos 20)">
        <ul class="lista actividad">
          <li :for={r <- @actividad}>
            <small>{r.fecha}</small> <strong>{r.usuario}</strong> <code>{r.accion}</code>
          </li>
        </ul>
      </.seccion>
    </Layouts.app>
    """
  end
end
