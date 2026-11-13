defmodule Emergencias.Mascotas do
  @moduledoc """
  GenServer para los reportes de mascotas perdidas y encontradas.

  Estado: %{reportes: %{"M001" => %Mascota{}, ...}, contador: 1}

  Como el GenServer procesa un mensaje a la vez, dos coordinadores no pueden
  confirmar al mismo tiempo la misma coincidencia: el segundo encontrará los
  reportes ya resueltos y recibirá un error.
  """

  use GenServer
  alias Emergencias.{Mascota, Persistencia, Util}

  @archivo "mascotas.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(datos), do: GenServer.call(__MODULE__, {:registrar, datos})

  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  @doc "Calcula coincidencias y marca los reportes como posible_coincidencia."
  def buscar_coincidencias, do: GenServer.call(__MODULE__, :buscar_coincidencias)

  def confirmar(id_perdida, id_encontrada),
    do: GenServer.call(__MODULE__, {:confirmar, id_perdida, id_encontrada})

  def resumen, do: GenServer.call(__MODULE__, :resumen)

  @impl true
  def init(:ok) do
    reportes =
      @archivo
      |> Persistencia.leer(&Mascota.desde_campos/1)
      |> Map.new(fn m -> {m.id, m} end)

    {:ok, %{reportes: reportes, contador: map_size(reportes)}}
  end

  @impl true
  def handle_call({:registrar, datos}, _from, estado) do
    contador = estado.contador + 1
    id = Util.generar_id("M", contador)

    case Mascota.crear(Map.put(datos, :id, id)) do
      {:ok, reporte} ->
        nuevo_estado = %{reportes: Map.put(estado.reportes, id, reporte), contador: contador}
        guardar(nuevo_estado)
        {:reply, {:ok, reporte}, nuevo_estado}

      {:error, mensaje} ->
        {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:listar, filtros}, _from, estado) do
    lista =
      estado.reportes
      |> Map.values()
      |> Enum.filter(fn r -> Util.cumple_filtros?(r, filtros) end)
      |> Enum.sort_by(fn r -> r.id end)

    {:reply, lista, estado}
  end

  def handle_call(:buscar_coincidencias, _from, estado) do
    {reportes, coincidencias} = recalcular_posibles(estado.reportes)
    nuevo_estado = %{estado | reportes: reportes}
    guardar(nuevo_estado)
    {:reply, coincidencias, nuevo_estado}
  end

  def handle_call({:confirmar, id_perdida, id_encontrada}, _from, estado) do
    with {:ok, perdida} <- buscar(estado, id_perdida),
         {:ok, encontrada} <- buscar(estado, id_encontrada),
         :ok <- validar_confirmacion(perdida, encontrada) do
      reportes =
        estado.reportes
        |> Map.put(perdida.id, %{perdida | estado: "resuelta", coincidencia: encontrada.id})
        |> Map.put(encontrada.id, %{encontrada | estado: "resuelta", coincidencia: perdida.id})

      {reportes, _coincidencias} = recalcular_posibles(reportes)
      nuevo_estado = %{estado | reportes: reportes}
      guardar(nuevo_estado)
      {:reply, {:ok, Map.fetch!(reportes, perdida.id), Map.fetch!(reportes, encontrada.id)}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call(:resumen, _from, estado) do
    reportes = Map.values(estado.reportes)

    resumen = %{
      total: length(reportes),
      por_tipo: Enum.frequencies_by(reportes, fn r -> r.tipo end),
      por_estado: Enum.frequencies_by(reportes, fn r -> r.estado end)
    }

    {:reply, resumen, estado}
  end

  # Marca "posible_coincidencia" o "activa" según las coincidencias actuales.
  defp recalcular_posibles(reportes) do
    coincidencias = Mascota.buscar_coincidencias(Map.values(reportes))

    con_coincidencia =
      coincidencias
      |> Enum.flat_map(fn {perdida, encontrada, _puntaje} -> [perdida.id, encontrada.id] end)
      |> MapSet.new()

    actualizados =
      Map.new(reportes, fn {id, reporte} ->
        cond do
          reporte.estado == "resuelta" -> {id, reporte}
          MapSet.member?(con_coincidencia, id) -> {id, %{reporte | estado: "posible_coincidencia"}}
          true -> {id, %{reporte | estado: "activa"}}
        end
      end)

    {actualizados, coincidencias}
  end

  defp validar_confirmacion(perdida, encontrada) do
    puntaje = Mascota.similitud(perdida, encontrada)

    cond do
      perdida.tipo != "perdida" ->
        {:error, "El reporte #{perdida.id} no es de una mascota perdida"}

      encontrada.tipo != "encontrada" ->
        {:error, "El reporte #{encontrada.id} no es de una mascota encontrada"}

      perdida.estado == "resuelta" or encontrada.estado == "resuelta" ->
        {:error, "Alguno de los reportes ya fue resuelto; no se puede cerrar dos veces"}

      perdida.especie != encontrada.especie ->
        {:error,
         "No se puede confirmar: la especie no coincide (#{perdida.especie} / #{encontrada.especie})"}

      puntaje < Mascota.umbral() ->
        {:error,
         "No se puede confirmar: similitud de #{puntaje} puntos, menor al umbral de #{Mascota.umbral()}"}

      true ->
        :ok
    end
  end

  defp buscar(estado, id) do
    id = String.upcase(id)

    case Map.fetch(estado.reportes, id) do
      {:ok, reporte} -> {:ok, reporte}
      :error -> {:error, "No existe el reporte de mascota #{id}"}
    end
  end

  defp guardar(estado) do
    Persistencia.guardar(@archivo, Map.values(estado.reportes), &Mascota.a_campos/1)
  end
end
