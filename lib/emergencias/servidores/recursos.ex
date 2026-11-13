defmodule Emergencias.Recursos do
  @moduledoc """
  GenServer que administra el inventario de recursos y su historial de movimientos.

  ## ¿Por qué evita inconsistencias?

  Un GenServer atiende sus mensajes UNO A LA VEZ. Si dos usuarios piden al
  mismo tiempo las últimas unidades de un recurso, sus solicitudes quedan en
  el buzón del proceso y se procesan en orden: la primera descuenta el
  inventario y la segunda ve el inventario ya actualizado. Por eso la
  cantidad asignada nunca puede superar la cantidad disponible.

  Estado:

      %{
        recursos: %{"R001" => %Recurso{}, ...},
        movimientos: [%{fecha, tipo, codigo, cantidad, detalle}, ...]  # el más reciente primero
      }
  """

  use GenServer
  alias Emergencias.{Persistencia, Recurso, Util}

  @archivo "recursos.txt"
  @archivo_movimientos "movimientos.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(recurso, usuario), do: GenServer.call(__MODULE__, {:registrar, recurso, usuario})

  def obtener(codigo), do: GenServer.call(__MODULE__, {:obtener, codigo})

  def entrada(codigo, cantidad, detalle),
    do: GenServer.call(__MODULE__, {:entrada, codigo, cantidad, detalle})

  def salida(codigo, cantidad, detalle),
    do: GenServer.call(__MODULE__, {:salida, codigo, cantidad, detalle})

  @doc """
  Descuenta `cantidad` unidades de los recursos que coincidan con `criterio`
  (código, nombre o categoría). Es todo o nada: si no alcanza, no descuenta nada.
  Retorna {:ok, [{codigo, cantidad_tomada}, ...]} o {:error, mensaje}.
  """
  def consumir(criterio, cantidad, zona, detalle),
    do: GenServer.call(__MODULE__, {:consumir, criterio, cantidad, zona, detalle})

  def transferir(codigo, origen, destino, cantidad, usuario),
    do: GenServer.call(__MODULE__, {:transferir, codigo, origen, destino, cantidad, usuario})

  @doc """
  Elimina un recurso y sus movimientos. Solo lo usa `simulate_conflict` para
  no dejar datos de la simulación en el inventario ni en el historial.
  """
  def eliminar(codigo), do: GenServer.call(__MODULE__, {:eliminar, codigo})

  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  def criticos(umbral), do: GenServer.call(__MODULE__, {:criticos, umbral})

  def movimientos(codigo \\ nil), do: GenServer.call(__MODULE__, {:movimientos, codigo})

  def resumen, do: GenServer.call(__MODULE__, :resumen)

  @impl true
  def init(:ok) do
    recursos =
      @archivo
      |> Persistencia.leer(&Recurso.desde_campos/1)
      |> Map.new(fn r -> {r.codigo, r} end)

    movimientos =
      @archivo_movimientos
      |> Persistencia.leer(&movimiento_desde_campos/1)
      |> Enum.reverse()

    {:ok, %{recursos: recursos, movimientos: movimientos}}
  end

  @impl true
  def handle_call({:registrar, recurso, usuario}, _from, estado) do
    if Map.has_key?(estado.recursos, recurso.codigo) do
      {:reply, {:error, "Ya existe un recurso con el código #{recurso.codigo}"}, estado}
    else
      nuevo_estado =
        estado
        |> actualizar_recurso(recurso)
        |> registrar_movimiento("registro", recurso.codigo, recurso.cantidad, "Registro por #{usuario}")

      guardar(nuevo_estado)
      {:reply, {:ok, recurso}, nuevo_estado}
    end
  end

  def handle_call({:obtener, codigo}, _from, estado) do
    {:reply, buscar(estado, codigo), estado}
  end

  def handle_call({:entrada, codigo, cantidad, detalle}, _from, estado) do
    with {:ok, recurso} <- buscar(estado, codigo),
         {:ok, actualizado} <- Recurso.entrada(recurso, cantidad) do
      nuevo_estado =
        estado
        |> actualizar_recurso(actualizado)
        |> registrar_movimiento("entrada", actualizado.codigo, cantidad, detalle)

      guardar(nuevo_estado)
      {:reply, {:ok, actualizado}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:salida, codigo, cantidad, detalle}, _from, estado) do
    with {:ok, recurso} <- buscar(estado, codigo),
         {:ok, actualizado} <- Recurso.salida(recurso, cantidad) do
      nuevo_estado =
        estado
        |> actualizar_recurso(actualizado)
        |> registrar_movimiento("salida", actualizado.codigo, cantidad, detalle)

      guardar(nuevo_estado)
      {:reply, {:ok, actualizado}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:consumir, criterio, cantidad, zona, detalle}, _from, estado) do
    lotes =
      estado.recursos
      |> Map.values()
      |> Enum.filter(fn recurso -> Recurso.coincide?(recurso, criterio) end)
      |> Recurso.ordenar_para_consumo(zona)

    disponible = Recurso.total(lotes)

    cond do
      lotes == [] ->
        {:reply, {:error, "No existe ningún recurso con código o categoría '#{criterio}'"}, estado}

      cantidad > disponible ->
        {:reply,
         {:error,
          "Inventario insuficiente de #{criterio}: se solicitan #{cantidad} y solo hay #{disponible} disponibles"},
         estado}

      true ->
        reparto = Recurso.repartir(lotes, cantidad)

        nuevo_estado =
          Enum.reduce(reparto, estado, fn {codigo, tomado}, acumulado ->
            {:ok, actualizado} = Recurso.salida(Map.fetch!(acumulado.recursos, codigo), tomado)

            acumulado
            |> actualizar_recurso(actualizado)
            |> registrar_movimiento("asignacion", codigo, tomado, detalle)
          end)

        guardar(nuevo_estado)
        {:reply, {:ok, reparto}, nuevo_estado}
    end
  end

  def handle_call({:transferir, codigo, origen, destino, cantidad, usuario}, _from, estado) do
    with {:ok, recurso} <- buscar(estado, codigo),
         :ok <- validar_transferencia(recurso, origen, destino),
         {:ok, origen_actualizado} <- Recurso.salida(recurso, cantidad),
         {:ok, destino_actualizado} <- Recurso.entrada(lote_destino(estado, recurso, destino), cantidad) do
      detalle = "Transferencia #{origen} -> #{destino} por #{usuario}"

      nuevo_estado =
        estado
        |> actualizar_recurso(origen_actualizado)
        |> actualizar_recurso(destino_actualizado)
        |> registrar_movimiento("transferencia_salida", origen_actualizado.codigo, cantidad, detalle)
        |> registrar_movimiento("transferencia_entrada", destino_actualizado.codigo, cantidad, detalle)

      guardar(nuevo_estado)
      {:reply, {:ok, origen_actualizado, destino_actualizado}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:eliminar, codigo}, _from, estado) do
    movimientos = Enum.reject(estado.movimientos, fn m -> m.codigo == codigo end)
    nuevo_estado = %{recursos: Map.delete(estado.recursos, codigo), movimientos: movimientos}

    guardar(nuevo_estado)

    Persistencia.guardar(@archivo_movimientos, Enum.reverse(movimientos), fn m ->
      [m.fecha, m.tipo, m.codigo, m.cantidad, m.detalle]
    end)

    {:reply, :ok, nuevo_estado}
  end

  def handle_call({:listar, filtros}, _from, estado) do
    lista =
      estado.recursos
      |> Map.values()
      |> Enum.filter(fn recurso -> Util.cumple_filtros?(recurso, filtros) end)
      |> Enum.sort_by(fn recurso -> {recurso.categoria, recurso.codigo} end)

    {:reply, lista, estado}
  end

  def handle_call({:criticos, umbral}, _from, estado) do
    lista =
      estado.recursos
      |> Map.values()
      |> Enum.filter(fn recurso -> recurso.cantidad <= umbral end)
      |> Enum.sort_by(fn recurso -> recurso.cantidad end)

    {:reply, lista, estado}
  end

  def handle_call({:movimientos, codigo}, _from, estado) do
    lista =
      estado.movimientos
      |> Enum.filter(fn m -> codigo == nil or m.codigo == codigo end)
      |> Enum.reverse()

    {:reply, lista, estado}
  end

  def handle_call(:resumen, _from, estado) do
    recursos = Map.values(estado.recursos)

    por_categoria =
      Enum.reduce(recursos, %{}, fn r, acumulado ->
        Map.update(acumulado, "#{r.categoria} (#{r.unidad})", r.cantidad, &(&1 + r.cantidad))
      end)

    resumen = %{
      lotes: length(recursos),
      por_categoria: por_categoria,
      agotados: Enum.count(recursos, fn r -> r.cantidad == 0 end),
      movimientos: length(estado.movimientos)
    }

    {:reply, resumen, estado}
  end

  defp buscar(estado, codigo) do
    case Map.fetch(estado.recursos, codigo) do
      {:ok, recurso} -> {:ok, recurso}
      :error -> {:error, "No existe el recurso #{codigo}"}
    end
  end

  defp actualizar_recurso(estado, recurso) do
    %{estado | recursos: Map.put(estado.recursos, recurso.codigo, recurso)}
  end

  defp registrar_movimiento(estado, tipo, codigo, cantidad, detalle) do
    movimiento = %{
      fecha: Util.fecha_actual(),
      tipo: tipo,
      codigo: codigo,
      cantidad: cantidad,
      detalle: detalle
    }

    Persistencia.agregar(@archivo_movimientos, [
      movimiento.fecha,
      tipo,
      codigo,
      cantidad,
      detalle
    ])

    %{estado | movimientos: [movimiento | estado.movimientos]}
  end

  defp validar_transferencia(recurso, origen, destino) do
    cond do
      recurso.ubicacion != origen ->
        {:error, "El recurso #{recurso.codigo} está en #{recurso.ubicacion}, no en #{origen}"}

      origen == destino ->
        {:error, "El origen y el destino deben ser diferentes"}

      true ->
        :ok
    end
  end

  defp lote_destino(estado, recurso, destino) do
    existente =
      Enum.find(Map.values(estado.recursos), fn r ->
        r.nombre == recurso.nombre and r.unidad == recurso.unidad and r.ubicacion == destino
      end)

    case existente do
      nil -> %{recurso | codigo: "#{recurso.codigo}-#{destino}", cantidad: 0, ubicacion: destino}
      lote -> lote
    end
  end

  defp guardar(estado) do
    Persistencia.guardar(@archivo, Map.values(estado.recursos), &Recurso.a_campos/1)
  end

  defp movimiento_desde_campos([fecha, tipo, codigo, cantidad, detalle]) do
    %{
      fecha: fecha,
      tipo: tipo,
      codigo: codigo,
      cantidad: String.to_integer(cantidad),
      detalle: detalle
    }
  end

  defp movimiento_desde_campos(_campos), do: nil
end
