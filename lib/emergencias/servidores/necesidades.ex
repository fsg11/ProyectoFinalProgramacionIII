defmodule Emergencias.Necesidades do
  @moduledoc """
  GenServer que administra las necesidades puntuales.

  La asignación de recursos se coordina aquí: primero se valida la
  necesidad (no atendida, no cancelada, no excede lo que falta) y luego se
  le pide al GenServer de Recursos que descuente el inventario. Como este
  GenServer atiende una solicitud a la vez, una misma necesidad tampoco
  puede recibir dos asignaciones simultáneas que la excedan.

  Estado:

      %{necesidades: %{"N001" => %Necesidad{}, ...}, contador: 1}
  """

  use GenServer
  alias Emergencias.{Necesidad, Persistencia, Recursos, Util}

  @archivo "necesidades.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def registrar(datos), do: GenServer.call(__MODULE__, {:registrar, datos})

  def obtener(id), do: GenServer.call(__MODULE__, {:obtener, id})

  def listar(filtros \\ []), do: GenServer.call(__MODULE__, {:listar, filtros})

  def pendientes(zona \\ nil), do: GenServer.call(__MODULE__, {:pendientes, zona})

  def cambiar_estado(id, estado), do: GenServer.call(__MODULE__, {:cambiar_estado, id, estado})

  def asignar(id, criterio, cantidad, usuario),
    do: GenServer.call(__MODULE__, {:asignar, id, criterio, cantidad, usuario}, 10_000)

  @doc "Elimina una necesidad. Solo lo usa `simulate_conflict` para limpiar sus datos."
  def eliminar(id), do: GenServer.call(__MODULE__, {:eliminar, id})

  def resumen, do: GenServer.call(__MODULE__, :resumen)

  @impl true
  def init(:ok) do
    necesidades =
      @archivo
      |> Persistencia.leer(&Necesidad.desde_campos/1)
      |> Map.new(fn n -> {n.id, n} end)

    {:ok, %{necesidades: necesidades, contador: mayor_numero(necesidades)}}
  end

  @impl true
  def handle_call({:registrar, datos}, _from, estado) do
    contador = estado.contador + 1
    id = Util.generar_id("N", contador)

    case Necesidad.crear(Map.put(datos, :id, id)) do
      {:ok, necesidad} ->
        nuevo_estado = %{
          necesidades: Map.put(estado.necesidades, id, necesidad),
          contador: contador
        }

        guardar(nuevo_estado)
        {:reply, {:ok, necesidad}, nuevo_estado}

      {:error, mensaje} ->
        {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:obtener, id}, _from, estado) do
    {:reply, buscar(estado, id), estado}
  end

  def handle_call({:listar, filtros}, _from, estado) do
    lista =
      estado.necesidades
      |> Map.values()
      |> Enum.filter(fn n -> Util.cumple_filtros?(n, filtros) end)
      |> Necesidad.ordenar_por_prioridad()

    {:reply, lista, estado}
  end

  def handle_call({:pendientes, zona}, _from, estado) do
    lista =
      estado.necesidades
      |> Map.values()
      |> Enum.filter(fn n -> Necesidad.abierta?(n) and (zona == nil or n.zona == zona) end)
      |> Necesidad.ordenar_por_prioridad()

    {:reply, lista, estado}
  end

  def handle_call({:cambiar_estado, id, nuevo}, _from, estado) do
    with {:ok, necesidad} <- buscar(estado, id),
         {:ok, actualizada} <- Necesidad.cambiar_estado(necesidad, nuevo) do
      nuevo_estado = actualizar(estado, actualizada)
      guardar(nuevo_estado)
      {:reply, {:ok, actualizada}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:eliminar, id}, _from, estado) do
    nuevo_estado = %{estado | necesidades: Map.delete(estado.necesidades, id)}
    guardar(nuevo_estado)
    {:reply, :ok, nuevo_estado}
  end

  def handle_call({:asignar, id, criterio, cantidad, usuario}, _from, estado) do
    with {:ok, necesidad} <- buscar(estado, id),
         :ok <- Necesidad.validar_asignacion(necesidad, cantidad),
         {:ok, reparto} <-
           Recursos.consumir(criterio, cantidad, necesidad.zona, "Asignado a #{necesidad.id} por #{usuario}") do
      actualizada = Necesidad.registrar_asignacion(necesidad, cantidad)
      nuevo_estado = actualizar(estado, actualizada)
      guardar(nuevo_estado)
      {:reply, {:ok, actualizada, reparto}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call(:resumen, _from, estado) do
    necesidades = Map.values(estado.necesidades)

    resumen = %{
      total: length(necesidades),
      por_estado: Enum.frequencies_by(necesidades, fn n -> n.estado end),
      por_prioridad:
        necesidades
        |> Enum.filter(&Necesidad.abierta?/1)
        |> Enum.frequencies_by(fn n -> n.prioridad end)
    }

    {:reply, resumen, estado}
  end

  defp buscar(estado, id) do
    id = String.upcase(id)

    case Map.fetch(estado.necesidades, id) do
      {:ok, necesidad} -> {:ok, necesidad}
      :error -> {:error, "No existe la necesidad #{id}"}
    end
  end

  defp actualizar(estado, necesidad) do
    %{estado | necesidades: Map.put(estado.necesidades, necesidad.id, necesidad)}
  end

  defp guardar(estado) do
    Persistencia.guardar(@archivo, Map.values(estado.necesidades), &Necesidad.a_campos/1)
  end

  # El contador sigue desde el id más alto para no reutilizar ids eliminados.
  defp mayor_numero(necesidades) do
    necesidades
    |> Map.keys()
    |> Enum.map(fn id ->
      case Integer.parse(String.slice(id, 1..-1//1)) do
        {numero, ""} -> numero
        _ -> 0
      end
    end)
    |> Enum.max(fn -> 0 end)
  end
end
