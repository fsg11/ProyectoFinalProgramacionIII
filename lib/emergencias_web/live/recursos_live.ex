defmodule EmergenciasWeb.RecursosLive do
  @moduledoc "Inventario: registro de lotes, entradas, salidas, transferencias e historial."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Albergues, Recursos}

  @umbral_critico 20

  @impl true
  def mount(_parametros, _sesion, socket) do
    {:ok, socket |> assign(:page_title, "Recursos") |> assign(:umbral, @umbral_critico) |> cargar()}
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("registrar", p, socket) do
    nombre = param(p, "nombre")
    categoria = if param(p, "categoria") == "", do: nombre, else: param(p, "categoria")

    partes = [
      "register_resource",
      param(p, "codigo"),
      nombre,
      param(p, "cantidad"),
      param(p, "unidad"),
      param(p, "ubicacion"),
      categoria,
      param(p, "zona")
    ]

    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("movimiento", p, socket) do
    comando = if param(p, "tipo") == "salida", do: "resource_out", else: "resource_in"
    partes = [comando, param(p, "codigo"), param(p, "cantidad"), param(p, "detalle")]
    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("transferir", p, socket) do
    codigo = param(p, "codigo")

    origen =
      case Recursos.obtener(codigo) do
        {:ok, recurso} -> recurso.ubicacion
        {:error, _mensaje} -> "-"
      end

    partes = ["transfer_resource", codigo, origen, param(p, "destino"), param(p, "cantidad")]
    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  defp cargar(socket) do
    lista = Recursos.listar()

    movimientos =
      if puede?(socket.assigns.usuario, "movements"),
        do: Recursos.movimientos() |> Enum.take(-15) |> Enum.reverse(),
        else: []

    destinos =
      (Enum.map(Albergues.listar(), & &1.codigo) ++ Enum.map(lista, & &1.ubicacion))
      |> Enum.uniq()
      |> Enum.sort()

    socket
    |> assign(:lista, lista)
    |> assign(:movimientos, movimientos)
    |> assign(:destinos, destinos)
    |> assign(:codigos, codigos_zona())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/recursos">
      <.encabezado
        titulo="Recursos"
        subtitulo={"Inventario por lote y ubicación. Los lotes con #{@umbral} unidades o menos se marcan como críticos."}
      />

      <.seccion titulo={"Inventario (#{length(@lista)} lotes)"}>
        <.vacio :if={@lista == []} texto="No hay recursos registrados." />
        <div class="tabla-contenedor">
          <table :if={@lista != []} class="tabla">
            <thead>
              <tr><th>Código</th><th>Nombre</th><th>Categoría</th><th>Disponible</th><th>Ubicación</th><th>Zona</th></tr>
            </thead>
            <tbody>
              <tr :for={r <- @lista} class={r.cantidad <= @umbral && "fila-critica"}>
                <td><strong>{r.codigo}</strong></td>
                <td>{r.nombre}</td>
                <td>{r.categoria}</td>
                <td>
                  <strong>{r.cantidad}</strong> {r.unidad}
                  <.insignia :if={r.cantidad == 0} texto="agotado" />
                  <.insignia :if={r.cantidad > 0 and r.cantidad <= @umbral} texto="critico" />
                </td>
                <td>{r.ubicacion}</td>
                <td>{r.zona}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </.seccion>

      <.resultado resultado={@resultado} />
      <.sugerencias id="destinos" opciones={@destinos} />

      <div class="columnas">
        <.seccion :if={puede?(@usuario, "register_resource")} titulo="Registrar lote">
          <form id={"form-recurso-#{@version}"} phx-submit="registrar" class="formulario rejilla">
            <.campo etiqueta="Código" nombre="codigo" requerido ayuda="R001" />
            <.campo etiqueta="Nombre" nombre="nombre" requerido ayuda="agua" />
            <.campo etiqueta="Cantidad" nombre="cantidad" tipo="number" min="0" requerido />
            <.campo etiqueta="Unidad" nombre="unidad" requerido ayuda="litros" />
            <.campo etiqueta="Ubicación" nombre="ubicacion" requerido ayuda="centro_acopio_1" lista="destinos" />
            <.campo etiqueta="Categoría (opcional)" nombre="categoria" ayuda="igual al nombre" />
            <.selector etiqueta="Zona" nombre="zona" opciones={@codigos} vacio="— Mi zona —" />
            <div class="acciones-formulario">
              <button type="submit" class="boton boton-primario">Registrar</button>
            </div>
          </form>
        </.seccion>

        <div>
          <.seccion :if={puede?(@usuario, "resource_in")} titulo="Entrada o salida">
            <form id={"form-movimiento-#{@version}"} phx-submit="movimiento" class="formulario rejilla">
              <.selector etiqueta="Lote" nombre="codigo" opciones={Enum.map(@lista, &{"#{&1.codigo} · #{&1.nombre} (#{&1.cantidad})", &1.codigo})} />
              <.selector etiqueta="Tipo" nombre="tipo" opciones={[{"Entrada (+)", "entrada"}, {"Salida (−)", "salida"}]} />
              <.campo etiqueta="Cantidad" nombre="cantidad" tipo="number" min="1" requerido />
              <.campo etiqueta="Detalle" nombre="detalle" ayuda="Donación, entrega..." />
              <div class="acciones-formulario">
                <button type="submit" class="boton boton-primario" disabled={@lista == []}>Registrar movimiento</button>
              </div>
            </form>
          </.seccion>

          <.seccion :if={puede?(@usuario, "transfer_resource")} titulo="Transferir entre ubicaciones">
            <form id={"form-transferir-#{@version}"} phx-submit="transferir" class="formulario rejilla">
              <.selector etiqueta="Lote de origen" nombre="codigo" opciones={Enum.map(@lista, &{"#{&1.codigo} · #{&1.ubicacion} (#{&1.cantidad})", &1.codigo})} />
              <.campo etiqueta="Destino" nombre="destino" requerido lista="destinos" ayuda="A01 o centro de acopio" />
              <.campo etiqueta="Cantidad" nombre="cantidad" tipo="number" min="1" requerido />
              <div class="acciones-formulario">
                <button type="submit" class="boton boton-primario" disabled={@lista == []}>Transferir</button>
              </div>
            </form>
            <p class="nota">El destino debe ser un albergue registrado o una ubicación que ya tenga recursos.</p>
          </.seccion>
        </div>
      </div>

      <.seccion :if={puede?(@usuario, "movements")} titulo="Últimos movimientos">
        <.vacio :if={@movimientos == []} texto="Sin movimientos." />
        <div class="tabla-contenedor">
          <table :if={@movimientos != []} class="tabla compacta">
            <thead><tr><th>Fecha</th><th>Tipo</th><th>Código</th><th>Cantidad</th><th>Detalle</th></tr></thead>
            <tbody>
              <tr :for={m <- @movimientos}>
                <td><small>{m.fecha}</small></td>
                <td><.insignia texto={m.tipo} /></td>
                <td>{m.codigo}</td>
                <td>{m.cantidad}</td>
                <td>{m.detalle}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </.seccion>
    </Layouts.app>
    """
  end
end
